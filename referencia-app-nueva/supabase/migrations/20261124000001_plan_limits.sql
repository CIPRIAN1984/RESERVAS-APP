-- Tarifa de cada alumno y límite de clases (adelanto de la fase 7).
--
-- Reglas acordadas con ITACA (18/11/2026):
--  · Membresías con N clases al mes: mes natural (del 1 al último día, hora de Madrid).
--  · "1 Día por Semana": una clase por semana (lunes a domingo); en un mes de
--    5 semanas, 5 clases.
--  · Bonos y pases: N clases en total mientras dure la tarifa asignada.
--  · Cuenta como clase usada: una reserva de una clase que aún no ha terminado,
--    una asistencia, o un "no presentado" en una clase en la que alguien se quedó
--    fuera (clase llena o con lista de espera). Las canceladas no cuentan.
--  · La lista de espera no gasta clase; al liberarse una plaza sube el primero
--    que aún tenga clases disponibles.
--  · Recepción y administración pueden apuntar a alguien por encima del límite;
--    queda en el registro de auditoría.
--  · Sin tarifa asignada: se puede reservar sin límite mientras la sede no active
--    settings.require_plan_to_book (así nadie se queda sin reservar mientras
--    recepción asigna las tarifas).
--  · Aforo por defecto de todas las clases: 50.

-- ---------- Tarifas: límite semanal ----------
alter table public.plans
  add column weekly_sessions integer check (weekly_sessions is null or weekly_sessions > 0);
comment on column public.plans.weekly_sessions is 'Clases por semana (lunes a domingo). Si tiene valor, manda sobre sessions';

update public.plans set weekly_sessions = 1, sessions = null where slug = '1-dia-semana';

-- ---------- Aforo 50 ----------
alter table public.class_templates alter column capacity set default 50;
update public.class_templates set capacity = 50 where capacity <> 50;  -- el trigger lo lleva a las sesiones futuras
update public.class_sessions set capacity = 50 where starts_at > now() and status = 'scheduled' and capacity < 50;

-- ---------- Tarifa asignada a cada alumno ----------
create table public.member_plans (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  plan_id uuid not null references public.plans (id),
  starts_on date not null default current_date,
  -- último día incluido; null = sin fecha de fin (se renueva cada mes)
  ends_on date,
  note text check (note is null or length(note) <= 300),
  created_by uuid,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default now(),
  check (ends_on is null or ends_on >= starts_on)
);
create index member_plans_profile_idx on public.member_plans (profile_id, starts_on desc);
create trigger member_plans_updated_at before update on public.member_plans
  for each row execute function public.set_updated_at();

alter table public.member_plans enable row level security;
revoke all on public.member_plans from anon;
-- Se escribe solo con assign_plan / end_plan
revoke insert, update, delete on public.member_plans from authenticated;
create policy member_plans_select on public.member_plans for select to authenticated
  using (
    profile_id = public.current_profile_id()
    or public.is_guardian_of(profile_id)
    or public.is_staff(gym_id)
  );

-- Tarifa vigente de una persona en una fecha (la más reciente que la cubre)
create function public.plan_on(p_profile uuid, p_gym uuid, p_day date)
returns public.member_plans
language sql stable security definer set search_path = '' as $$
  select mp.* from public.member_plans mp
  where mp.profile_id = p_profile and mp.gym_id = p_gym
    and mp.starts_on <= p_day and (mp.ends_on is null or mp.ends_on >= p_day)
  order by mp.starts_on desc, mp.created_at desc
  limit 1
$$;

-- Clases usadas por una persona entre dos instantes (ver reglas arriba)
create function public.classes_used(p_profile uuid, p_from timestamptz, p_to timestamptz)
returns integer
language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.class_sessions s
  where s.starts_at >= p_from and s.starts_at < p_to and s.status = 'scheduled'
    and (
      exists (select 1 from public.attendances a where a.session_id = s.id and a.profile_id = p_profile and a.voided_at is null)
      or (
        exists (select 1 from public.bookings b where b.session_id = s.id and b.profile_id = p_profile and b.status = 'booked')
        and (s.ends_at > now() or s.waitlist_count > 0 or s.booked_count >= s.capacity)
      )
    )
$$;

-- Límite de clases para reservar p_session: tarifa, periodo, usadas y si cabe una más
create function public.plan_allowance(p_profile uuid, p_session uuid)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_s public.class_sessions%rowtype;
  v_tz text;
  v_local timestamp;
  v_mp public.member_plans%rowtype;
  v_plan public.plans%rowtype;
  v_required boolean;
  v_period text;
  v_from timestamptz;
  v_to timestamptz;
  v_limit int;
  v_used int;
begin
  select * into v_s from public.class_sessions where id = p_session;
  select g.time_zone, coalesce((g.settings ->> 'require_plan_to_book')::boolean, false)
  into v_tz, v_required from public.gyms g where g.id = v_s.gym_id;
  v_local := v_s.starts_at at time zone v_tz;

  v_mp := public.plan_on(p_profile, v_s.gym_id, v_local::date);
  if v_mp.id is null then
    return jsonb_build_object('ok', not v_required, 'reason', case when v_required then 'no_plan' end,
                              'plan', null, 'period', 'none', 'limit', null, 'used', null);
  end if;
  select * into v_plan from public.plans where id = v_mp.plan_id;

  if v_plan.weekly_sessions is not null then
    v_period := 'week';
    v_limit := v_plan.weekly_sessions;
    v_from := date_trunc('week', v_local) at time zone v_tz;
    v_to := (date_trunc('week', v_local) + interval '1 week') at time zone v_tz;
  elsif v_plan.sessions is null then
    return jsonb_build_object('ok', true, 'plan', v_plan.name, 'period', 'none', 'limit', null, 'used', null, 'ends_on', v_mp.ends_on);
  elsif v_plan.sessions_per_month then
    v_period := 'month';
    v_limit := v_plan.sessions;
    v_from := date_trunc('month', v_local) at time zone v_tz;
    v_to := (date_trunc('month', v_local) + interval '1 month') at time zone v_tz;
  else
    v_period := 'total';
    v_limit := v_plan.sessions;
    v_from := v_mp.starts_on::timestamp at time zone v_tz;
    v_to := coalesce(v_mp.ends_on + 1, 'infinity'::date)::timestamp at time zone v_tz;
  end if;

  v_used := public.classes_used(p_profile, v_from, v_to);
  return jsonb_build_object(
    'ok', v_used < v_limit, 'reason', case when v_used >= v_limit then 'plan_limit' end,
    'plan', v_plan.name, 'period', v_period, 'limit', v_limit, 'used', v_used,
    'from', v_from, 'to', v_to, 'ends_on', v_mp.ends_on);
end $$;

-- Mensaje para el alumno cuando no le quedan clases
create function public._plan_limit_message(p_allow jsonb) returns text
language sql immutable set search_path = '' as $$
  select case p_allow ->> 'reason'
    when 'no_plan' then 'No tienes una tarifa activa. Pásate por recepción.'
    else format('Ya has usado %s %s con tu tarifa %s.',
      case when (p_allow ->> 'limit')::int = 1 then 'tu clase' else format('tus %s clases', p_allow ->> 'limit') end,
      case p_allow ->> 'period' when 'week' then 'de esta semana' when 'month' then 'de este mes' else 'del bono' end,
      p_allow ->> 'plan')
  end
$$;

-- ---------- Asignar o terminar una tarifa (recepción, administración, propietario) ----------
create function public.assign_plan(p_profile uuid, p_plan uuid, p_starts_on date default current_date, p_ends_on date default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_plan public.plans%rowtype;
  v_ends date := p_ends_on;
  v_id uuid;
begin
  select * into v_plan from public.plans where id = p_plan;
  if not found then
    raise exception 'Tarifa no encontrada' using errcode = 'P0002';
  end if;
  if not public.has_role(v_plan.gym_id, array['owner', 'admin', 'front_desk']::public.gym_role[]) then
    raise exception 'Solo recepción y administración asignan tarifas' using errcode = '42501';
  end if;
  if not exists (select 1 from public.gym_members m where m.gym_id = v_plan.gym_id and m.profile_id = p_profile) then
    raise exception 'La persona no es miembro de la sede' using errcode = '42501';
  end if;
  -- Bonos con validez: fin automático si no se indica
  if v_ends is null and v_plan.validity_months is not null then
    v_ends := (p_starts_on + make_interval(months => v_plan.validity_months))::date - 1;
  end if;
  if v_ends is null and v_plan.kind = 'drop_in' then
    v_ends := p_starts_on;
  end if;
  if v_ends is not null and v_ends < p_starts_on then
    raise exception 'La fecha de fin es anterior al inicio' using errcode = '22023';
  end if;

  -- La tarifa anterior termina el día antes de que empiece la nueva
  update public.member_plans set ends_on = p_starts_on - 1
  where profile_id = p_profile and gym_id = v_plan.gym_id
    and starts_on < p_starts_on and (ends_on is null or ends_on >= p_starts_on);
  -- Las que empezaban a la vez o después quedan sustituidas
  delete from public.member_plans
  where profile_id = p_profile and gym_id = v_plan.gym_id and starts_on >= p_starts_on;

  insert into public.member_plans (gym_id, profile_id, plan_id, starts_on, ends_on, note, created_by)
  values (v_plan.gym_id, p_profile, p_plan, p_starts_on, v_ends, nullif(trim(coalesce(p_note, '')), ''), (select auth.uid()))
  returning id into v_id;

  insert into public.audit_log (gym_id, actor_user_id, table_name, row_id, action, new_data)
  values (v_plan.gym_id, (select auth.uid()), 'member_plans', v_id, 'assign_plan',
          jsonb_build_object('profile_id', p_profile, 'plan', v_plan.slug, 'starts_on', p_starts_on, 'ends_on', v_ends));
  return v_id;
end $$;

create function public.end_plan(p_member_plan uuid, p_ends_on date default current_date) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_mp public.member_plans%rowtype;
begin
  select * into v_mp from public.member_plans where id = p_member_plan;
  if not found then
    raise exception 'Tarifa no encontrada' using errcode = 'P0002';
  end if;
  if not public.has_role(v_mp.gym_id, array['owner', 'admin', 'front_desk']::public.gym_role[]) then
    raise exception 'Solo recepción y administración terminan tarifas' using errcode = '42501';
  end if;
  if p_ends_on < v_mp.starts_on then
    delete from public.member_plans where id = p_member_plan;
  else
    update public.member_plans set ends_on = p_ends_on where id = p_member_plan;
  end if;
  insert into public.audit_log (gym_id, actor_user_id, table_name, row_id, action, new_data)
  values (v_mp.gym_id, (select auth.uid()), 'member_plans', v_mp.id, 'end_plan', jsonb_build_object('ends_on', p_ends_on));
end $$;

-- ---------- Mi tarifa y lo que me queda (para Inicio y Perfil) ----------
create function public.my_plan_status(p_profile uuid default null, p_day date default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_profile uuid := coalesce(p_profile, public.current_profile_id());
  v_gym uuid;
  v_tz text;
  v_day date;
  v_mp public.member_plans%rowtype;
  v_plan public.plans%rowtype;
  v_from timestamptz;
  v_to timestamptz;
  v_period text := 'none';
  v_limit int;
begin
  select m.gym_id into v_gym from public.gym_members m where m.profile_id = v_profile order by m.created_at limit 1;
  if v_gym is null or not public.can_act_for(v_profile, v_gym) then
    raise exception 'No puedes ver la tarifa de esta persona' using errcode = '42501';
  end if;
  select g.time_zone into v_tz from public.gyms g where g.id = v_gym;
  v_day := coalesce(p_day, (now() at time zone v_tz)::date);
  v_mp := public.plan_on(v_profile, v_gym, v_day);
  if v_mp.id is null then
    return jsonb_build_object('plan', null);
  end if;
  select * into v_plan from public.plans where id = v_mp.plan_id;
  if v_plan.weekly_sessions is not null then
    v_period := 'week'; v_limit := v_plan.weekly_sessions;
    v_from := date_trunc('week', v_day::timestamp) at time zone v_tz;
    v_to := (date_trunc('week', v_day::timestamp) + interval '1 week') at time zone v_tz;
  elsif v_plan.sessions is not null and v_plan.sessions_per_month then
    v_period := 'month'; v_limit := v_plan.sessions;
    v_from := date_trunc('month', v_day::timestamp) at time zone v_tz;
    v_to := (date_trunc('month', v_day::timestamp) + interval '1 month') at time zone v_tz;
  elsif v_plan.sessions is not null then
    v_period := 'total'; v_limit := v_plan.sessions;
    v_from := v_mp.starts_on::timestamp at time zone v_tz;
    v_to := coalesce(v_mp.ends_on + 1, 'infinity'::date)::timestamp at time zone v_tz;
  end if;
  return jsonb_build_object(
    'member_plan_id', v_mp.id, 'plan', v_plan.name, 'plan_id', v_plan.id, 'starts_on', v_mp.starts_on, 'ends_on', v_mp.ends_on,
    'period', v_period, 'limit', v_limit,
    'used', case when v_limit is null then null else public.classes_used(v_profile, v_from, v_to) end);
end $$;

-- ---------- book_session: ahora comprueba la tarifa ----------
create or replace function public.book_session(p_session uuid, p_profile uuid default null)
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
  v_allow jsonb;
  v_override boolean := false;
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

  select * into v_existing from public.bookings b
  where b.session_id = p_session and b.profile_id = v_profile and b.status in ('booked', 'waitlist');
  if found then
    return jsonb_build_object('booking_id', v_existing.id, 'status', v_existing.status, 'already', true,
      'position', case when v_existing.status = 'waitlist' then
        (select count(*) from public.bookings w where w.session_id = p_session and w.status = 'waitlist' and w.created_at <= v_existing.created_at)
      end);
  end if;

  -- Tarifa: clases que le quedan. Recepción y administración pueden pasarlo por alto.
  v_allow := public.plan_allowance(v_profile, p_session);
  if not (v_allow ->> 'ok')::boolean then
    if v_profile <> public.current_profile_id()
       and public.has_role(v_s.gym_id, array['owner', 'admin', 'front_desk']::public.gym_role[]) then
      v_override := true;
    else
      raise exception '%', public._plan_limit_message(v_allow) using errcode = 'P0001', hint = v_allow ->> 'reason';
    end if;
  end if;

  v_status := case when v_s.booked_count < v_s.capacity then 'booked' else 'waitlist' end;
  insert into public.bookings (gym_id, session_id, profile_id, status, booked_by)
  values (v_s.gym_id, p_session, v_profile, v_status, (select auth.uid()))
  returning id into v_id;

  if v_override then
    insert into public.audit_log (gym_id, actor_user_id, table_name, row_id, action, new_data)
    values (v_s.gym_id, (select auth.uid()), 'bookings', v_id, 'plan_limit_override', v_allow);
  end if;

  if v_status = 'waitlist' then
    select count(*) into v_position from public.bookings w where w.session_id = p_session and w.status = 'waitlist';
  end if;
  return jsonb_build_object('booking_id', v_id, 'status', v_status, 'already', false, 'position', v_position,
    'plan_override', v_override);
end $$;

-- ---------- cancel_booking: sube el primero de la espera al que le queden clases ----------
create or replace function public.cancel_booking(p_booking uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_b public.bookings%rowtype;
  v_s public.class_sessions%rowtype;
  v_hours numeric;
  v_late boolean := false;
  v_promoted uuid;
  v_w record;
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

  -- Se libera una plaza: pasa el primero de la lista de espera que aún tenga clases
  if v_b.status = 'booked' then
    for v_w in
      select w.id, w.profile_id from public.bookings w
      where w.session_id = v_b.session_id and w.status = 'waitlist'
      order by w.created_at
    loop
      if (public.plan_allowance(v_w.profile_id, v_b.session_id) ->> 'ok')::boolean then
        update public.bookings set status = 'booked' where id = v_w.id;
        v_promoted := v_w.profile_id;
        exit;
      end if;
    end loop;
  end if;
  -- PASO 7: avisar por push y email a v_promoted.

  return jsonb_build_object('status', 'cancelled', 'late', v_late, 'promoted_profile_id', v_promoted);
end $$;

-- ---------- Check-in sin reserva: también respeta la tarifa ----------
create or replace function public._ensure_booking_for_self_checkin(p_session uuid, p_profile uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_s public.class_sessions%rowtype;
  v_allow jsonb;
begin
  if exists (select 1 from public.bookings where session_id = p_session and profile_id = p_profile and status = 'booked') then
    return;
  end if;
  select * into v_s from public.class_sessions where id = p_session for update;
  if v_s.booked_count >= v_s.capacity then
    raise exception 'La clase está completa y no tienes reserva' using errcode = 'P0001', hint = 'full';
  end if;
  v_allow := public.plan_allowance(p_profile, p_session);
  if not (v_allow ->> 'ok')::boolean then
    raise exception '%', public._plan_limit_message(v_allow) using errcode = 'P0001', hint = v_allow ->> 'reason';
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

revoke execute on function public.plan_on, public.classes_used, public.plan_allowance, public._plan_limit_message from public, anon, authenticated;
revoke execute on function public.assign_plan, public.end_plan, public.my_plan_status from public, anon;
grant execute on function public.assign_plan, public.end_plan, public.my_plan_status to authenticated;
