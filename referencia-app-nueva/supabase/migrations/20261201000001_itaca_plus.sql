-- ITACA+ (vídeos): complemento de 5 €/mes que se suma a la tarifa, no la sustituye.
-- Solo se puede pedir y tener activo con otra tarifa de pago recurrente en vigor
-- (una membresía que se renueva y cuesta dinero). Si esa tarifa termina, ITACA+
-- deja de funcionar aunque siga asignado.

alter table public.plans add column is_addon boolean not null default false;
comment on column public.plans.is_addon is 'Complemento (ITACA+): se suma a la tarifa principal, no la sustituye';

insert into public.plans (gym_id, slug, name, description, kind, price_cents, billing_period, sessions, sessions_per_month, validity_months, auto_renew, audience, sort, is_addon)
select g.id, 'itaca-plus', 'ITACA+', 'Vídeos de las clases, técnicas sueltas y currículos. Se suma a tu tarifa mensual.',
       'membership', 500, 'month', null, true, null, true, 'all', 50, true
from public.gyms g
where g.id = '00000000-0000-4000-a000-000000000001'
  and not exists (select 1 from public.plans p where p.gym_id = g.id and p.slug = 'itaca-plus');

-- La tarifa principal (para límites de clases) ignora los complementos
create or replace function public.plan_on(p_profile uuid, p_gym uuid, p_day date)
returns public.member_plans
language sql stable security definer set search_path = '' as $$
  select mp.* from public.member_plans mp
  join public.plans pl on pl.id = mp.plan_id and not pl.is_addon
  where mp.profile_id = p_profile and mp.gym_id = p_gym
    and mp.starts_on <= p_day and (mp.ends_on is null or mp.ends_on >= p_day)
  order by mp.starts_on desc, mp.created_at desc
  limit 1
$$;

-- ¿Tiene esta persona una tarifa de pago recurrente en vigor ese día?
create function public.has_recurring_plan(p_profile uuid, p_gym uuid, p_day date) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.member_plans mp
    join public.plans pl on pl.id = mp.plan_id
    where mp.profile_id = p_profile and mp.gym_id = p_gym
      and not pl.is_addon and pl.auto_renew and pl.price_cents > 0
      and mp.starts_on <= p_day and (mp.ends_on is null or mp.ends_on >= p_day)
  )
$$;
revoke execute on function public.plan_on, public.has_recurring_plan from public, anon, authenticated;

-- ¿Tiene ITACA+ activo hoy? (complemento asignado y tarifa recurrente en vigor)
create function public.has_itaca_plus(p_profile uuid default null) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare
  v_profile uuid := coalesce(p_profile, public.current_profile_id());
  v_gym uuid;
  v_day date;
begin
  select m.gym_id into v_gym from public.gym_members m where m.profile_id = v_profile order by m.created_at limit 1;
  if v_gym is null or not public.can_act_for(v_profile, v_gym) then
    return false;
  end if;
  select (now() at time zone g.time_zone)::date into v_day from public.gyms g where g.id = v_gym;
  return public.has_recurring_plan(v_profile, v_gym, v_day) and exists (
    select 1 from public.member_plans mp
    join public.plans pl on pl.id = mp.plan_id and pl.is_addon
    where mp.profile_id = v_profile and mp.gym_id = v_gym
      and mp.starts_on <= v_day and (mp.ends_on is null or mp.ends_on >= v_day)
  );
end $$;
revoke execute on function public.has_itaca_plus from public, anon;
grant execute on function public.has_itaca_plus to authenticated;

-- ---------- Asignar: los complementos no sustituyen la tarifa principal ----------
create or replace function public.assign_plan(p_profile uuid, p_plan uuid, p_starts_on date default current_date, p_ends_on date default null, p_note text default null)
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
  if v_plan.is_addon and not public.has_recurring_plan(p_profile, v_plan.gym_id, p_starts_on) then
    raise exception '% necesita una tarifa de pago mensual activa: asígnala primero', v_plan.name using errcode = 'P0001', hint = 'needs_recurring';
  end if;
  if v_ends is null and v_plan.validity_months is not null then
    v_ends := (p_starts_on + make_interval(months => v_plan.validity_months))::date - 1;
  end if;
  if v_ends is null and v_plan.kind = 'drop_in' then
    v_ends := p_starts_on;
  end if;
  if v_ends is not null and v_ends < p_starts_on then
    raise exception 'La fecha de fin es anterior al inicio' using errcode = '22023';
  end if;

  -- Solo se cierran las del mismo tipo: la tarifa principal con otra principal,
  -- y un complemento con el mismo complemento
  update public.member_plans mp set ends_on = p_starts_on - 1
  from public.plans pl
  where pl.id = mp.plan_id and mp.profile_id = p_profile and mp.gym_id = v_plan.gym_id
    and (case when v_plan.is_addon then mp.plan_id = p_plan else not pl.is_addon end)
    and mp.starts_on < p_starts_on and (mp.ends_on is null or mp.ends_on >= p_starts_on);
  delete from public.member_plans mp
  using public.plans pl
  where pl.id = mp.plan_id and mp.profile_id = p_profile and mp.gym_id = v_plan.gym_id
    and (case when v_plan.is_addon then mp.plan_id = p_plan else not pl.is_addon end)
    and mp.starts_on >= p_starts_on;

  insert into public.member_plans (gym_id, profile_id, plan_id, starts_on, ends_on, note, created_by)
  values (v_plan.gym_id, p_profile, p_plan, p_starts_on, v_ends, nullif(trim(coalesce(p_note, '')), ''), (select auth.uid()))
  returning id into v_id;

  insert into public.audit_log (gym_id, actor_user_id, table_name, row_id, action, new_data)
  values (v_plan.gym_id, (select auth.uid()), 'member_plans', v_id, 'assign_plan',
          jsonb_build_object('profile_id', p_profile, 'plan', v_plan.slug, 'starts_on', p_starts_on, 'ends_on', v_ends));
  return v_id;
end $$;

-- ---------- Solicitudes: una pendiente por tipo (tarifa principal y complemento) ----------
drop index public.plan_requests_one_pending_idx;
create unique index plan_requests_one_pending_idx on public.plan_requests (profile_id, plan_id) where status = 'pending';

create or replace function public.request_plan(p_plan uuid, p_profile uuid default null, p_note text default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_profile uuid := coalesce(p_profile, public.current_profile_id());
  v_plan public.plans%rowtype;
  v_tz text;
  v_id uuid;
begin
  select * into v_plan from public.plans where id = p_plan and active;
  if not found then
    raise exception 'Tarifa no disponible' using errcode = 'P0002';
  end if;
  if not (v_profile = public.current_profile_id() or public.is_guardian_of(v_profile)) then
    raise exception 'Solo puedes pedir tarifas para ti o para tus hijos' using errcode = '42501';
  end if;
  if not exists (select 1 from public.gym_members m where m.gym_id = v_plan.gym_id and m.profile_id = v_profile and m.status = 'active') then
    raise exception 'La persona no es miembro activo de la sede' using errcode = '42501';
  end if;
  select g.time_zone into v_tz from public.gyms g where g.id = v_plan.gym_id;
  if v_plan.is_addon and not public.has_recurring_plan(v_profile, v_plan.gym_id, (now() at time zone v_tz)::date) then
    raise exception '% necesita una tarifa de pago mensual activa', v_plan.name using errcode = 'P0001', hint = 'needs_recurring';
  end if;
  -- Sustituye a la pendiente anterior del mismo tipo
  update public.plan_requests r set status = 'cancelled', handled_at = now()
  from public.plans pl
  where pl.id = r.plan_id and r.profile_id = v_profile and r.status = 'pending' and pl.is_addon = v_plan.is_addon;
  insert into public.plan_requests (gym_id, profile_id, plan_id, note, requested_by)
  values (v_plan.gym_id, v_profile, p_plan, nullif(trim(coalesce(p_note, '')), ''), (select auth.uid()))
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.close_plan_request() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.plan_requests r set status = 'done', handled_at = now(), handled_by = new.created_by
  from public.plans pl, public.plans assigned
  where pl.id = r.plan_id and assigned.id = new.plan_id
    and r.profile_id = new.profile_id and r.status = 'pending' and pl.is_addon = assigned.is_addon;
  return null;
end $$;
