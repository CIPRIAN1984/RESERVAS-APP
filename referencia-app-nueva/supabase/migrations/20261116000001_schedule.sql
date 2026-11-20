-- Paso 2 · Horario: disciplinas, clases recurrentes, sesiones y cierres.
-- Las clases recurrentes se definen en hora LOCAL de la sede; las sesiones
-- se guardan en UTC. Así el cambio de hora no mueve las clases.

create type public.session_status as enum ('scheduled', 'cancelled', 'done');
create type public.discipline_kind as enum ('gi', 'nogi', 'kids', 'openmat', 'other');

-- ---------- Disciplinas ----------
create table public.disciplines (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete cascade,
  slug text not null,
  name text not null check (length(trim(name)) > 0),
  kind public.discipline_kind not null default 'other',
  sort smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (gym_id, slug)
);
create trigger disciplines_updated_at before update on public.disciplines
  for each row execute function public.set_updated_at();

-- ---------- Clases recurrentes (plantillas) ----------
create table public.class_templates (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete cascade,
  discipline_id uuid not null references public.disciplines (id),
  name text not null check (length(trim(name)) > 0),
  level text not null default '',
  -- 1 = lunes … 7 = domingo
  weekdays smallint[] not null
    check (cardinality(weekdays) > 0 and weekdays <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]),
  start_time time not null,
  duration_min integer not null check (duration_min between 15 and 600),
  capacity integer not null check (capacity between 1 and 500),
  coach_profile_id uuid references public.profiles (id) on delete set null,
  place text not null default 'Tatami',
  min_age smallint,
  max_age smallint,
  active boolean not null default true,
  valid_from date not null default current_date,
  valid_until date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_until is null or valid_until >= valid_from),
  check (min_age is null or max_age is null or max_age >= min_age)
);
create index class_templates_gym_idx on public.class_templates (gym_id);
create trigger class_templates_updated_at before update on public.class_templates
  for each row execute function public.set_updated_at();

-- ---------- Sesiones concretas ----------
create table public.class_sessions (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete cascade,
  -- vacío = clase puntual sin plantilla
  template_id uuid references public.class_templates (id) on delete set null,
  discipline_id uuid not null references public.disciplines (id),
  name text not null,
  level text not null default '',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  capacity integer not null check (capacity between 1 and 500),
  coach_profile_id uuid references public.profiles (id) on delete set null,
  substitute_coach_profile_id uuid references public.profiles (id) on delete set null,
  place text not null default 'Tatami',
  status public.session_status not null default 'scheduled',
  cancel_reason text,
  -- Cierre que la canceló (para reactivarla si se borra el cierre)
  cancelled_by_closure uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  unique (template_id, starts_at)
);
create index class_sessions_gym_start_idx on public.class_sessions (gym_id, starts_at);
create trigger class_sessions_updated_at before update on public.class_sessions
  for each row execute function public.set_updated_at();

-- ---------- Festivos y cierres ----------
create table public.closures (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete cascade,
  date_from date not null,
  date_to date not null,
  reason text not null default 'Cierre',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (date_to >= date_from)
);
create index closures_gym_idx on public.closures (gym_id, date_from);
create trigger closures_updated_at before update on public.closures
  for each row execute function public.set_updated_at();

-- ---------- generate_sessions ----------
-- Crea las sesiones de las próximas p_weeks semanas desde las plantillas activas,
-- saltando los cierres. Idempotente: volver a ejecutarla no duplica.
create function public.generate_sessions(p_gym uuid, p_weeks integer default 4, p_from date default null)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_tz text;
  v_from date;
  v_count integer;
begin
  if (select auth.uid()) is not null
     and not public.has_role(p_gym, array['owner', 'admin']::public.gym_role[]) then
    raise exception 'Solo propietario o administración generan el horario' using errcode = '42501';
  end if;
  if p_weeks not between 1 and 26 then
    raise exception 'Semanas fuera de rango (1 a 26)' using errcode = '22023';
  end if;

  select g.time_zone into v_tz from public.gyms g where g.id = p_gym;
  if v_tz is null then
    raise exception 'Sede no encontrada' using errcode = '22023';
  end if;
  v_from := coalesce(p_from, (now() at time zone v_tz)::date);

  insert into public.class_sessions (
    gym_id, template_id, discipline_id, name, level, starts_at, ends_at,
    capacity, coach_profile_id, place
  )
  select
    t.gym_id, t.id, t.discipline_id, t.name, t.level,
    (d.day + t.start_time) at time zone v_tz,
    (d.day + t.start_time + make_interval(mins => t.duration_min)) at time zone v_tz,
    t.capacity, t.coach_profile_id, t.place
  from public.class_templates t
  cross join lateral (
    select gs::date as day
    from generate_series(v_from, v_from + (p_weeks * 7 - 1), interval '1 day') gs
  ) d
  where t.gym_id = p_gym
    and t.active
    and extract(isodow from d.day)::smallint = any (t.weekdays)
    and d.day >= t.valid_from
    and (t.valid_until is null or d.day <= t.valid_until)
    and not exists (
      select 1 from public.closures c
      where c.gym_id = t.gym_id and d.day between c.date_from and c.date_to
    )
  on conflict (template_id, starts_at) do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end $$;

revoke execute on function public.generate_sessions from public, anon;
grant execute on function public.generate_sessions to authenticated;

-- Para la tarea nocturna: todas las sedes
create function public.generate_sessions_all(p_weeks integer default 4) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_total integer := 0;
  v_gym uuid;
begin
  for v_gym in select id from public.gyms loop
    v_total := v_total + public.generate_sessions(v_gym, p_weeks);
  end loop;
  return v_total;
end $$;
revoke execute on function public.generate_sessions_all from public, anon, authenticated;

-- ---------- Cierres: cancelan y reactivan sesiones ----------
create function public.apply_closure() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_tz text;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    update public.class_sessions s
    set status = 'scheduled', cancel_reason = null, cancelled_by_closure = null
    where s.cancelled_by_closure = old.id and s.status = 'cancelled';
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    select g.time_zone into v_tz from public.gyms g where g.id = new.gym_id;
    update public.class_sessions s
    set status = 'cancelled', cancel_reason = new.reason, cancelled_by_closure = new.id
    where s.gym_id = new.gym_id
      and s.status = 'scheduled'
      and (s.starts_at at time zone v_tz)::date between new.date_from and new.date_to;
    return new;
  end if;
  return old;
end $$;

create trigger closures_apply after insert or update or delete on public.closures
  for each row execute function public.apply_closure();

-- ---------- Cambios en una plantilla: rehacer sus sesiones futuras ----------
-- PASO 3: cuando existan reservas, no se borrarán sesiones que las tengan.
create function public.sync_template_sessions() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' then
    delete from public.class_sessions s
    where s.template_id = new.id and s.starts_at > now() and s.status = 'scheduled';
  end if;
  perform public.generate_sessions(new.gym_id, 4);
  return new;
end $$;

create trigger class_templates_sync after insert or update on public.class_templates
  for each row execute function public.sync_template_sessions();

-- ---------- Directorio del personal ----------
-- Los alumnos necesitan ver el nombre del profesor, pero no sus datos personales:
-- esta vista solo expone nombre y rol, y solo de sedes a las que perteneces.
create view public.staff_directory
with (security_barrier = true) as
select m.gym_id, p.id as profile_id, p.full_name, m.role
from public.gym_members m
join public.profiles p on p.id = m.profile_id
where m.status = 'active'
  and m.role in ('owner', 'admin', 'coach')
  and public.has_role(m.gym_id, enum_range(null::public.gym_role));

revoke all on public.staff_directory from anon;
grant select on public.staff_directory to authenticated;

-- ---------- Permisos ----------
alter table public.disciplines enable row level security;
alter table public.class_templates enable row level security;
alter table public.class_sessions enable row level security;
alter table public.closures enable row level security;
revoke all on public.disciplines, public.class_templates, public.class_sessions, public.closures from anon;

-- Leer: cualquier miembro activo de la sede
create policy disciplines_select on public.disciplines for select to authenticated
  using (public.has_role(gym_id, enum_range(null::public.gym_role)));
create policy class_templates_select on public.class_templates for select to authenticated
  using (public.has_role(gym_id, enum_range(null::public.gym_role)));
create policy class_sessions_select on public.class_sessions for select to authenticated
  using (public.has_role(gym_id, enum_range(null::public.gym_role)));
create policy closures_select on public.closures for select to authenticated
  using (public.has_role(gym_id, enum_range(null::public.gym_role)));

-- Escribir: propietario y administración
create policy disciplines_write on public.disciplines for all to authenticated
  using (public.has_role(gym_id, array['owner', 'admin']::public.gym_role[]))
  with check (public.has_role(gym_id, array['owner', 'admin']::public.gym_role[]));
create policy class_templates_write on public.class_templates for all to authenticated
  using (public.has_role(gym_id, array['owner', 'admin']::public.gym_role[]))
  with check (public.has_role(gym_id, array['owner', 'admin']::public.gym_role[]));
create policy class_sessions_write on public.class_sessions for all to authenticated
  using (public.has_role(gym_id, array['owner', 'admin']::public.gym_role[]))
  with check (public.has_role(gym_id, array['owner', 'admin']::public.gym_role[]));
create policy closures_write on public.closures for all to authenticated
  using (public.has_role(gym_id, array['owner', 'admin']::public.gym_role[]))
  with check (public.has_role(gym_id, array['owner', 'admin']::public.gym_role[]));

-- ---------- Tarea nocturna ----------
create extension if not exists pg_cron;
select cron.schedule('generate-sessions-nightly', '15 3 * * *', $$ select public.generate_sessions_all(4) $$);
