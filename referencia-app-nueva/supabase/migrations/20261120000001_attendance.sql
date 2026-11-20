-- Paso 4 · Asistencia: lista del profesor (también sin conexión), check-in
-- por QR y modo kiosco.
--
-- Cada marca lleva un client_id generado en el móvil: reenviar la misma
-- marca (por ejemplo al volver la cobertura) nunca crea un duplicado.
-- La asistencia no se borra: se anula (voided_at).

create type public.attendance_method as enum ('coach', 'qr', 'kiosk');

create table public.attendances (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete cascade,
  session_id uuid not null references public.class_sessions (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  method public.attendance_method not null,
  client_id uuid not null unique,
  -- hora en la que se marcó en el dispositivo (puede ser anterior si iba en cola)
  checked_in_at timestamptz not null,
  recorded_by uuid,
  voided_at timestamptz,
  voided_by uuid,
  void_client_id uuid unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index attendances_one_active_idx on public.attendances (session_id, profile_id) where voided_at is null;
create index attendances_profile_idx on public.attendances (profile_id, checked_in_at);
create trigger attendances_updated_at before update on public.attendances
  for each row execute function public.set_updated_at();

-- Código de la sede para el cartel QR (itaca:checkin:<código>)
alter table public.gyms add column checkin_code text not null unique
  default encode(extensions.gen_random_bytes(9), 'hex');

-- ---------- Núcleo común ----------
-- Registra la asistencia de p_profile en p_session. Sin comprobaciones de permiso:
-- solo la llaman check_in y check_in_by_code después de comprobarlos.
create function public._record_attendance(
  p_session uuid, p_profile uuid, p_client_id uuid, p_method public.attendance_method, p_at timestamptz
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_s public.class_sessions%rowtype;
  v_existing public.attendances%rowtype;
  v_id uuid;
begin
  -- Mismo client_id: es un reenvío de la misma marca
  select * into v_existing from public.attendances where client_id = p_client_id;
  if found then
    return jsonb_build_object('attendance_id', v_existing.id, 'status', 'present', 'duplicate', true);
  end if;

  select * into v_s from public.class_sessions where id = p_session for update;

  -- Ya estaba presente (otra marca, otro dispositivo): no se duplica
  select * into v_existing from public.attendances
  where session_id = p_session and profile_id = p_profile and voided_at is null;
  if found then
    return jsonb_build_object('attendance_id', v_existing.id, 'status', 'present', 'duplicate', true);
  end if;

  insert into public.attendances (gym_id, session_id, profile_id, method, client_id, checked_in_at, recorded_by)
  values (v_s.gym_id, p_session, p_profile, p_method, p_client_id, p_at, (select auth.uid()))
  returning id into v_id;
  return jsonb_build_object('attendance_id', v_id, 'status', 'present', 'duplicate', false);
end $$;
revoke execute on function public._record_attendance from public, anon, authenticated;

-- ¿Puede el alumno fichar por su cuenta? Con reserva, sí. Sin reserva, si queda plaza
-- (entonces se le crea la reserva para que el aforo cuadre).
create function public._ensure_booking_for_self_checkin(p_session uuid, p_profile uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_s public.class_sessions%rowtype;
begin
  if exists (select 1 from public.bookings where session_id = p_session and profile_id = p_profile and status = 'booked') then
    return;
  end if;
  select * into v_s from public.class_sessions where id = p_session for update;
  if v_s.booked_count >= v_s.capacity then
    raise exception 'La clase está completa y no tienes reserva' using errcode = 'P0001', hint = 'full';
  end if;
  -- Si estaba en lista de espera y hay hueco, pasa a tener plaza
  update public.bookings set status = 'booked'
  where session_id = p_session and profile_id = p_profile and status = 'waitlist';
  if not found then
    insert into public.bookings (gym_id, session_id, profile_id, status, booked_by)
    values (v_s.gym_id, p_session, p_profile, 'booked', (select auth.uid()));
  end if;
end $$;
revoke execute on function public._ensure_booking_for_self_checkin from public, anon, authenticated;

-- ---------- check_in ----------
-- Profesor, recepción y administración: marcan a cualquier miembro (método 'coach' o 'kiosk').
-- Alumno o tutor: solo a sí mismo o a su menor, dentro de la ventana de check-in.
create function public.check_in(
  p_session uuid,
  p_client_id uuid,
  p_profile uuid default null,
  p_method public.attendance_method default 'coach',
  p_at timestamptz default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_profile uuid := coalesce(p_profile, public.current_profile_id());
  v_at timestamptz := least(coalesce(p_at, now()), now() + interval '5 minutes');
  v_s public.class_sessions%rowtype;
  v_before int;
  v_after int;
  v_staff boolean;
begin
  if v_profile is null then
    raise exception 'Hace falta iniciar sesión' using errcode = '42501';
  end if;
  select * into v_s from public.class_sessions where id = p_session;
  if not found then
    raise exception 'Clase no encontrada' using errcode = 'P0002';
  end if;
  -- Un reenvío de una marca ya guardada se acepta sin más comprobaciones
  if exists (select 1 from public.attendances where client_id = p_client_id and session_id = p_session and profile_id = v_profile) then
    return public._record_attendance(p_session, v_profile, p_client_id, p_method, v_at);
  end if;
  if not exists (select 1 from public.gym_members m where m.gym_id = v_s.gym_id and m.profile_id = v_profile and m.status = 'active') then
    raise exception 'La persona no es miembro activo de la sede' using errcode = '42501';
  end if;
  if v_s.status = 'cancelled' then
    raise exception 'La clase está cancelada' using errcode = 'P0001', hint = 'cancelled';
  end if;

  v_staff := public.is_staff(v_s.gym_id);
  if v_staff then
    -- El personal puede registrar hasta un día después (lista hecha sin conexión)
    if v_at < v_s.starts_at - interval '2 hours' or v_at > v_s.ends_at + interval '1 day' then
      raise exception 'Fuera del horario de la clase' using errcode = 'P0001', hint = 'window';
    end if;
    return public._record_attendance(p_session, v_profile, p_client_id, case when p_method = 'qr' then 'coach' else p_method end, v_at);
  end if;

  if not (v_profile = public.current_profile_id() or public.is_guardian_of(v_profile)) then
    raise exception 'Solo el personal marca la asistencia de otros' using errcode = '42501';
  end if;
  select coalesce((g.settings ->> 'checkin_before_min')::int, 30), coalesce((g.settings ->> 'checkin_after_min')::int, 15)
  into v_before, v_after from public.gyms g where g.id = v_s.gym_id;
  if v_at < v_s.starts_at - make_interval(mins => v_before) then
    raise exception 'El check-in aún no está abierto' using errcode = 'P0001', hint = 'too_early';
  end if;
  if v_at > v_s.starts_at + make_interval(mins => v_after) then
    raise exception 'El check-in de esta clase ya está cerrado' using errcode = 'P0001', hint = 'too_late';
  end if;
  perform public._ensure_booking_for_self_checkin(p_session, v_profile);
  return public._record_attendance(p_session, v_profile, p_client_id, 'qr', v_at);
end $$;

-- ---------- uncheck: el personal quita a quien no está en el tatami ----------
create function public.uncheck(p_session uuid, p_profile uuid, p_client_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_s public.class_sessions%rowtype;
  v_a public.attendances%rowtype;
begin
  select * into v_s from public.class_sessions where id = p_session;
  if not found then
    raise exception 'Clase no encontrada' using errcode = 'P0002';
  end if;
  if not public.is_staff(v_s.gym_id) then
    raise exception 'Solo el personal quita asistencias' using errcode = '42501';
  end if;
  -- Reenvío de la misma anulación
  if exists (select 1 from public.attendances where void_client_id = p_client_id) then
    return jsonb_build_object('status', 'absent', 'duplicate', true);
  end if;
  update public.attendances
  set voided_at = now(), voided_by = (select auth.uid()), void_client_id = p_client_id
  where session_id = p_session and profile_id = p_profile and voided_at is null
  returning * into v_a;
  return jsonb_build_object('status', 'absent', 'duplicate', not found);
end $$;

-- ---------- check_in_by_code: el alumno escanea el QR de la entrada ----------
-- Busca su clase dentro de la ventana de check-in: primero una con reserva;
-- si no, la primera que esté abierta y con plaza.
create function public.check_in_by_code(p_code text, p_client_id uuid, p_at timestamptz default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_profile uuid := public.current_profile_id();
  v_at timestamptz := least(coalesce(p_at, now()), now() + interval '5 minutes');
  v_gym public.gyms%rowtype;
  v_session uuid;
  v_before int;
  v_after int;
  v_res jsonb;
begin
  if v_profile is null then
    raise exception 'Hace falta iniciar sesión' using errcode = '42501';
  end if;
  select * into v_gym from public.gyms where checkin_code = p_code;
  if not found then
    raise exception 'Este código QR no es de ITACA' using errcode = 'P0001', hint = 'bad_code';
  end if;
  -- Reenvío
  select session_id into v_session from public.attendances where client_id = p_client_id and profile_id = v_profile;
  if found then
    return public._record_attendance(v_session, v_profile, p_client_id, 'qr', v_at) || jsonb_build_object('session_id', v_session);
  end if;
  if not exists (select 1 from public.gym_members m where m.gym_id = v_gym.id and m.profile_id = v_profile and m.status = 'active') then
    raise exception 'No eres miembro de esta sede' using errcode = '42501';
  end if;

  v_before := coalesce((v_gym.settings ->> 'checkin_before_min')::int, 30);
  v_after := coalesce((v_gym.settings ->> 'checkin_after_min')::int, 15);

  select s.id into v_session
  from public.class_sessions s
  join public.bookings b on b.session_id = s.id and b.profile_id = v_profile and b.status = 'booked'
  where s.gym_id = v_gym.id and s.status = 'scheduled'
    and v_at between s.starts_at - make_interval(mins => v_before) and s.starts_at + make_interval(mins => v_after)
  order by s.starts_at
  limit 1;

  if v_session is null then
    select s.id into v_session
    from public.class_sessions s
    left join public.disciplines d on d.id = s.discipline_id
    where s.gym_id = v_gym.id and s.status = 'scheduled' and d.kind <> 'kids'
      and v_at between s.starts_at - make_interval(mins => v_before) and s.starts_at + make_interval(mins => v_after)
      and s.booked_count < s.capacity
    order by s.starts_at
    limit 1;
  end if;

  if v_session is null then
    raise exception 'No hay ninguna clase abierta para fichar ahora mismo' using errcode = 'P0001', hint = 'no_session';
  end if;

  v_res := public.check_in(v_session, p_client_id, v_profile, 'qr', v_at);
  return v_res || jsonb_build_object('session_id', v_session);
end $$;

revoke execute on function public.check_in, public.uncheck, public.check_in_by_code from public, anon;
grant execute on function public.check_in, public.uncheck, public.check_in_by_code to authenticated;

-- ---------- Permisos ----------
alter table public.attendances enable row level security;
revoke all on public.attendances from anon;
revoke insert, update, delete on public.attendances from authenticated;

create policy attendances_select on public.attendances for select to authenticated
  using (
    profile_id = public.current_profile_id()
    or public.is_guardian_of(profile_id)
    or public.is_staff(gym_id)
  );

-- El código del QR solo lo ve el personal (para imprimir el cartel o el kiosco).
-- Los alumnos leen gyms, así que la columna se protege aparte.
-- (revocar una sola columna no basta si hay permiso sobre la tabla: se concede columna a columna)
revoke select on public.gyms from authenticated;
grant select (id, name, time_zone, settings, created_at, updated_at) on public.gyms to authenticated;
create function public.gym_checkin_code(p_gym uuid) returns text
language sql stable security definer set search_path = '' as $$
  select g.checkin_code from public.gyms g where g.id = p_gym and public.is_staff(p_gym)
$$;
revoke execute on function public.gym_checkin_code from public, anon;
grant execute on function public.gym_checkin_code to authenticated;

alter publication supabase_realtime add table public.attendances;
