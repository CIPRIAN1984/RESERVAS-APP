-- Paso 3 · Reservas con aforo, lista de espera y plazo de cancelación.
-- Las reservas solo se crean y cancelan con book_session / cancel_booking,
-- que bloquean la fila de la sesión: dos peticiones a la vez por la última
-- plaza dan una plaza y una espera.

create type public.booking_status as enum ('booked', 'waitlist', 'cancelled', 'no_show');

alter table public.class_sessions
  add column booked_count integer not null default 0,
  add column waitlist_count integer not null default 0;

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete cascade,
  session_id uuid not null references public.class_sessions (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  status public.booking_status not null,
  late_cancel boolean not null default false,
  booked_by uuid,                       -- auth.uid() de quien hizo la reserva
  cancelled_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default now()
);
-- Una sola reserva activa por alumno y sesión
create unique index bookings_one_active_idx on public.bookings (session_id, profile_id)
  where status in ('booked', 'waitlist');
create index bookings_session_idx on public.bookings (session_id, status, created_at);
create index bookings_profile_idx on public.bookings (profile_id);
create trigger bookings_updated_at before update on public.bookings
  for each row execute function public.set_updated_at();

-- ---------- Contadores de ocupación en la sesión ----------
-- Los alumnos no ven las reservas de otros, pero sí cuántas hay: el contador
-- vive en class_sessions, que todos los miembros pueden leer (y escuchar en
-- tiempo real).
create function public.refresh_session_counts() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_session uuid := coalesce(new.session_id, old.session_id);
begin
  update public.class_sessions s set
    booked_count = (select count(*) from public.bookings b where b.session_id = v_session and b.status = 'booked'),
    waitlist_count = (select count(*) from public.bookings b where b.session_id = v_session and b.status = 'waitlist')
  where s.id = v_session;
  return null;
end $$;
create trigger bookings_counts after insert or update or delete on public.bookings
  for each row execute function public.refresh_session_counts();

-- ---------- ¿Puede el usuario actual actuar por esta persona? ----------
create function public.can_act_for(p_profile uuid, p_gym uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select p_profile = public.current_profile_id()
      or public.is_guardian_of(p_profile)
      or public.has_role(p_gym, array['owner', 'admin', 'front_desk']::public.gym_role[])
$$;

-- ---------- book_session ----------
create function public.book_session(p_session uuid, p_profile uuid default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_profile uuid := coalesce(p_profile, public.current_profile_id());
  v_s public.class_sessions%rowtype;
  v_kind public.discipline_kind;
  v_min smallint;
  v_max smallint;
  v_birth date;
  v_age int;
  v_existing public.bookings%rowtype;
  v_status public.booking_status;
  v_id uuid;
  v_position int;
begin
  if v_profile is null then
    raise exception 'Hace falta iniciar sesión' using errcode = '42501';
  end if;

  -- Bloquea la sesión: las reservas a la misma clase se atienden de una en una
  select * into v_s from public.class_sessions where id = p_session for update;
  if not found then
    raise exception 'Clase no encontrada' using errcode = 'P0002';
  end if;
  if not public.can_act_for(v_profile, v_s.gym_id) then
    raise exception 'No puedes reservar por esta persona' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.gym_members m
    where m.gym_id = v_s.gym_id and m.profile_id = v_profile and m.status = 'active'
  ) then
    raise exception 'La persona no es miembro activo de la sede' using errcode = '42501';
  end if;
  if v_s.status <> 'scheduled' then
    raise exception 'La clase está cancelada' using errcode = 'P0001', hint = 'cancelled';
  end if;
  if v_s.ends_at <= now() then
    raise exception 'La clase ya ha terminado' using errcode = 'P0001', hint = 'ended';
  end if;

  -- Edad: clases infantiles según el rango de la plantilla; menores de 14 no van a adultos
  select d.kind into v_kind from public.disciplines d where d.id = v_s.discipline_id;
  select t.min_age, t.max_age into v_min, v_max from public.class_templates t where t.id = v_s.template_id;
  select p.birth_date into v_birth from public.profiles p where p.id = v_profile;
  v_age := case when v_birth is null then null else extract(year from age(v_s.starts_at::date, v_birth))::int end;
  if v_kind = 'kids' then
    if v_age is null or (v_min is not null and v_age < v_min) or (v_max is not null and v_age > v_max) then
      raise exception 'Esta clase infantil no es para su edad' using errcode = 'P0001', hint = 'not_allowed';
    end if;
  elsif v_age is not null and v_age < 14 then
    raise exception 'Las clases de adultos son a partir de 14 años' using errcode = 'P0001', hint = 'not_allowed';
  end if;
  -- PASO 6: comprobar tarifa y deuda.

  select * into v_existing from public.bookings b
  where b.session_id = p_session and b.profile_id = v_profile and b.status in ('booked', 'waitlist');
  if found then
    return jsonb_build_object('booking_id', v_existing.id, 'status', v_existing.status, 'already', true,
      'position', case when v_existing.status = 'waitlist' then
        (select count(*) from public.bookings w where w.session_id = p_session and w.status = 'waitlist' and w.created_at <= v_existing.created_at)
      end);
  end if;

  v_status := case when v_s.booked_count < v_s.capacity then 'booked' else 'waitlist' end;
  insert into public.bookings (gym_id, session_id, profile_id, status, booked_by)
  values (v_s.gym_id, p_session, v_profile, v_status, (select auth.uid()))
  returning id into v_id;

  if v_status = 'waitlist' then
    select count(*) into v_position from public.bookings w where w.session_id = p_session and w.status = 'waitlist';
  end if;
  return jsonb_build_object('booking_id', v_id, 'status', v_status, 'already', false, 'position', v_position);
end $$;

-- ---------- cancel_booking ----------
create function public.cancel_booking(p_booking uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_b public.bookings%rowtype;
  v_s public.class_sessions%rowtype;
  v_hours numeric;
  v_late boolean := false;
  v_promoted uuid;
begin
  select * into v_b from public.bookings where id = p_booking;
  if not found then
    raise exception 'Reserva no encontrada' using errcode = 'P0002';
  end if;
  select * into v_s from public.class_sessions where id = v_b.session_id for update;
  if not public.can_act_for(v_b.profile_id, v_b.gym_id) then
    raise exception 'No puedes cancelar esta reserva' using errcode = '42501';
  end if;
  -- Releer con la sesión bloqueada
  select * into v_b from public.bookings where id = p_booking;
  if v_b.status not in ('booked', 'waitlist') then
    return jsonb_build_object('status', v_b.status, 'late', v_b.late_cancel, 'promoted_profile_id', null);
  end if;
  if v_s.ends_at <= now() then
    raise exception 'La clase ya ha terminado' using errcode = 'P0001', hint = 'ended';
  end if;

  select coalesce((g.settings ->> 'cancel_window_hours')::numeric, 2) into v_hours from public.gyms g where g.id = v_b.gym_id;
  v_late := v_b.status = 'booked' and now() > v_s.starts_at - make_interval(secs => (v_hours * 3600)::int);

  update public.bookings set status = 'cancelled', late_cancel = v_late, cancelled_at = now() where id = p_booking;

  -- Se libera una plaza: pasa el primero de la lista de espera
  if v_b.status = 'booked' then
    update public.bookings set status = 'booked'
    where id = (
      select w.id from public.bookings w
      where w.session_id = v_b.session_id and w.status = 'waitlist'
      order by w.created_at
      limit 1
    )
    returning profile_id into v_promoted;
  end if;
  -- PASO 7: avisar por push y email a v_promoted.

  return jsonb_build_object('status', 'cancelled', 'late', v_late, 'promoted_profile_id', v_promoted);
end $$;

-- ---------- Mis reservas (y las de mis menores) con puesto en la lista ----------
create function public.my_bookings(p_from timestamptz default now() - interval '7 days', p_to timestamptz default now() + interval '60 days')
returns table (
  id uuid, session_id uuid, profile_id uuid, status public.booking_status,
  late_cancel boolean, waitlist_position integer, created_at timestamptz
)
language sql stable security definer set search_path = '' as $$
  select b.id, b.session_id, b.profile_id, b.status, b.late_cancel,
    case when b.status = 'waitlist' then (
      select count(*)::int from public.bookings w
      where w.session_id = b.session_id and w.status = 'waitlist' and w.created_at <= b.created_at
    ) end,
    b.created_at
  from public.bookings b
  join public.class_sessions s on s.id = b.session_id
  where (b.profile_id = public.current_profile_id() or public.is_guardian_of(b.profile_id))
    and s.starts_at >= p_from and s.starts_at < p_to
    and b.status in ('booked', 'waitlist')
  order by s.starts_at
$$;

revoke execute on function public.book_session, public.cancel_booking, public.my_bookings, public.can_act_for from public, anon;
grant execute on function public.book_session, public.cancel_booking, public.my_bookings, public.can_act_for to authenticated;

-- ---------- Permisos ----------
alter table public.bookings enable row level security;
revoke all on public.bookings from anon;
-- Solo lectura: se escribe a través de las funciones
revoke insert, update, delete on public.bookings from authenticated;

create policy bookings_select on public.bookings for select to authenticated
  using (
    profile_id = public.current_profile_id()
    or public.is_guardian_of(profile_id)
    or public.is_staff(gym_id)
  );

-- ---------- Editar una plantilla ya no borra clases con reservas ----------
create or replace function public.sync_template_sessions() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_tz text;
begin
  if tg_op = 'UPDATE' then
    select g.time_zone into v_tz from public.gyms g where g.id = new.gym_id;

    -- Datos que no cambian la hora: se aplican a todas las sesiones futuras
    update public.class_sessions s set
      name = new.name, level = new.level, discipline_id = new.discipline_id,
      capacity = new.capacity, coach_profile_id = new.coach_profile_id, place = new.place
    where s.template_id = new.id and s.starts_at > now() and s.status = 'scheduled';

    -- Sesiones que ya no encajan (día, hora, duración o plantilla desactivada):
    -- se borran solo si nadie las ha reservado
    delete from public.class_sessions s
    where s.template_id = new.id and s.starts_at > now() and s.status = 'scheduled'
      and s.booked_count = 0 and s.waitlist_count = 0
      and (
        not new.active
        or extract(isodow from s.starts_at at time zone v_tz)::smallint <> all (new.weekdays)
        or (s.starts_at at time zone v_tz)::time <> new.start_time
        or s.ends_at - s.starts_at <> make_interval(mins => new.duration_min)
      );
  end if;
  perform public.generate_sessions(new.gym_id, 4);
  return new;
end $$;

-- ---------- Tiempo real: ocupación de las clases y mis reservas ----------
alter publication supabase_realtime add table public.class_sessions;
alter publication supabase_realtime add table public.bookings;
