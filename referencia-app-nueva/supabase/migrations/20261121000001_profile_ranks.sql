-- Perfil editable y cinturones (adelanto del paso 5).
--
-- El cinturón actual de una persona es su última graduación registrada.
-- El alumno puede declarar el suyo mientras ningún profesor haya registrado
-- una graduación; a partir de ahí solo el personal lo cambia.

alter table public.profiles
  add column phone text check (phone is null or length(phone) <= 30),
  add constraint profiles_full_name_len check (length(full_name) <= 80);

create type public.belt as enum ('blanco', 'gris', 'amarillo', 'naranja', 'verde', 'azul', 'morado', 'marron', 'negro');

create table public.promotions (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  belt public.belt not null,
  stripes smallint not null default 0 check (stripes between 0 and 6),
  promoted_at date not null default current_date,
  -- true: lo indicó el propio alumno (o su tutor); false: lo registró el personal
  self_declared boolean not null default false,
  promoted_by uuid,
  note text check (note is null or length(note) <= 300),
  -- hora exacta de registro: desempata dos cambios del mismo día
  created_at timestamptz not null default clock_timestamp()
);
create index promotions_profile_idx on public.promotions (profile_id, promoted_at desc, created_at desc);

alter table public.promotions enable row level security;
revoke all on public.promotions from anon;
revoke insert, update, delete on public.promotions from authenticated;

create policy promotions_select on public.promotions for select to authenticated
  using (
    profile_id = public.current_profile_id()
    or public.is_guardian_of(profile_id)
    or public.is_staff(gym_id)
  );

-- Cinturón actual (última graduación) de una persona en una sede
create function public.current_rank(p_profile uuid, p_gym uuid)
returns table (belt public.belt, stripes smallint, promoted_at date, self_declared boolean)
language sql stable security definer set search_path = '' as $$
  select pr.belt, pr.stripes, pr.promoted_at, pr.self_declared
  from public.promotions pr
  where pr.profile_id = p_profile and pr.gym_id = p_gym
    and (
      p_profile = public.current_profile_id()
      or public.is_guardian_of(p_profile)
      or public.is_staff(p_gym)
    )
  order by pr.promoted_at desc, pr.created_at desc
  limit 1
$$;

-- El alumno (o su tutor) declara su cinturón actual, solo si el personal aún no ha registrado ninguno
create function public.set_my_rank(p_gym uuid, p_belt public.belt, p_stripes smallint, p_since date default null, p_profile uuid default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_profile uuid := coalesce(p_profile, public.current_profile_id());
begin
  if v_profile is null then
    raise exception 'Hace falta iniciar sesión' using errcode = '42501';
  end if;
  if not (v_profile = public.current_profile_id() or public.is_guardian_of(v_profile)) then
    raise exception 'Solo puedes indicar tu cinturón o el de tus hijos' using errcode = '42501';
  end if;
  if not exists (select 1 from public.gym_members m where m.gym_id = p_gym and m.profile_id = v_profile and m.status = 'active') then
    raise exception 'No eres miembro de esta sede' using errcode = '42501';
  end if;
  if exists (select 1 from public.promotions where profile_id = v_profile and gym_id = p_gym and not self_declared) then
    raise exception 'Tu cinturón ya lo ha registrado tu profesor: pídele a él el cambio' using errcode = 'P0001', hint = 'locked';
  end if;
  if p_stripes < 0 or p_stripes > 6 then
    raise exception 'Número de grados no válido' using errcode = '22023';
  end if;
  if p_since is not null and p_since > current_date then
    raise exception 'La fecha no puede ser futura' using errcode = '22023';
  end if;
  insert into public.promotions (gym_id, profile_id, belt, stripes, promoted_at, self_declared, promoted_by)
  values (p_gym, v_profile, p_belt, p_stripes, coalesce(p_since, current_date), true, (select auth.uid()));
end $$;

-- El personal (profesor, administración, propietario) registra una graduación
create function public.promote(p_gym uuid, p_profile uuid, p_belt public.belt, p_stripes smallint, p_date date default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  if not public.has_role(p_gym, array['owner', 'admin', 'coach']::public.gym_role[]) then
    raise exception 'Solo el personal docente registra graduaciones' using errcode = '42501';
  end if;
  if not exists (select 1 from public.gym_members m where m.gym_id = p_gym and m.profile_id = p_profile) then
    raise exception 'La persona no es miembro de esta sede' using errcode = '42501';
  end if;
  if p_stripes < 0 or p_stripes > 6 then
    raise exception 'Número de grados no válido' using errcode = '22023';
  end if;
  if p_date is not null and p_date > current_date then
    raise exception 'La fecha no puede ser futura' using errcode = '22023';
  end if;
  insert into public.promotions (gym_id, profile_id, belt, stripes, promoted_at, self_declared, promoted_by, note)
  values (p_gym, p_profile, p_belt, p_stripes, coalesce(p_date, current_date), false, (select auth.uid()), nullif(trim(p_note), ''))
  returning id into v_id;
  insert into public.audit_log (gym_id, actor_user_id, table_name, row_id, action, new_data)
  values (p_gym, (select auth.uid()), 'promotions', v_id, 'promotion',
          jsonb_build_object('profile_id', p_profile, 'belt', p_belt, 'stripes', p_stripes));
  return v_id;
end $$;

revoke execute on function public.current_rank, public.set_my_rank, public.promote from public, anon;
grant execute on function public.current_rank, public.set_my_rank, public.promote to authenticated;

-- Lista de alumnos para el personal: datos básicos y cinturón actual
create function public.gym_roster(p_gym uuid)
returns table (
  profile_id uuid, full_name text, avatar_path text, role public.gym_role, status public.member_status,
  birth_date date, has_account boolean, belt public.belt, stripes smallint, promoted_at date, self_declared boolean,
  attended_30d integer
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.full_name, p.avatar_path, m.role, m.status, p.birth_date, p.user_id is not null,
    r.belt, r.stripes, r.promoted_at, r.self_declared,
    (select count(*)::int from public.attendances a
      where a.profile_id = p.id and a.gym_id = p_gym and a.voided_at is null and a.checked_in_at > now() - interval '30 days')
  from public.gym_members m
  join public.profiles p on p.id = m.profile_id
  left join lateral (
    select pr.belt, pr.stripes, pr.promoted_at, pr.self_declared from public.promotions pr
    where pr.profile_id = p.id and pr.gym_id = p_gym
    order by pr.promoted_at desc, pr.created_at desc limit 1
  ) r on true
  where m.gym_id = p_gym and public.is_staff(p_gym)
  order by p.full_name
$$;
revoke execute on function public.gym_roster from public, anon;
grant execute on function public.gym_roster to authenticated;

-- Mi asistencia de un año: por día (para la gráfica de meses y el detalle por días)
create function public.my_attendance_days(p_year integer, p_profile uuid default null)
returns table (day date, classes integer)
language sql stable security definer set search_path = '' as $$
  select (a.checked_in_at at time zone g.time_zone)::date, count(*)::int
  from public.attendances a
  join public.gyms g on g.id = a.gym_id
  where a.profile_id = coalesce(p_profile, public.current_profile_id())
    and (coalesce(p_profile, public.current_profile_id()) = public.current_profile_id()
         or public.is_guardian_of(p_profile))
    and a.voided_at is null
    and extract(year from a.checked_in_at at time zone g.time_zone) = p_year
  group by 1
  order by 1
$$;
revoke execute on function public.my_attendance_days from public, anon;
grant execute on function public.my_attendance_days to authenticated;
