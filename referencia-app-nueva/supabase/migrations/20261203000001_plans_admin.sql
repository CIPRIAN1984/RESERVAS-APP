-- Sección Tarifas del personal: tarifa actual de cada alumno, solicitudes
-- pendientes en tiempo real (aviso al personal) y aprobar o rechazar.

-- Tiempo real: el personal recibe las solicitudes al momento
alter publication supabase_realtime add table public.plan_requests;

alter table public.plan_requests add column reject_reason text check (reject_reason is null or length(reject_reason) <= 200);

-- Tarifa actual de cada alumno activo de la sede
create function public.staff_plan_overview(p_gym uuid)
returns table (
  profile_id uuid, full_name text, is_minor boolean, plan_id uuid, plan_name text, price_cents integer,
  starts_on date, ends_on date, has_plus boolean, pending_plan text
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_day date;
begin
  if not public.has_role(p_gym, array['owner', 'admin', 'front_desk']::public.gym_role[]) then
    raise exception 'Solo recepción y administración ven las tarifas' using errcode = '42501';
  end if;
  select (now() at time zone g.time_zone)::date into v_day from public.gyms g where g.id = p_gym;
  return query
  select p.id, p.full_name,
    (p.birth_date is not null and p.birth_date > (current_date - interval '18 years')::date),
    mp.plan_id, pl.name, pl.price_cents, mp.starts_on, mp.ends_on,
    public.has_recurring_plan(p.id, p_gym, v_day) and exists (
      select 1 from public.member_plans a join public.plans ap on ap.id = a.plan_id and ap.is_addon
      where a.profile_id = p.id and a.gym_id = p_gym and a.starts_on <= v_day and (a.ends_on is null or a.ends_on >= v_day)),
    (select string_agg(rp.name, ', ') from public.plan_requests r join public.plans rp on rp.id = r.plan_id
      where r.profile_id = p.id and r.status = 'pending')
  from public.gym_members m
  join public.profiles p on p.id = m.profile_id
  left join lateral (select x.* from public.plan_on(p.id, p_gym, v_day) x where x.id is not null) mp on true
  left join public.plans pl on pl.id = mp.plan_id
  where m.gym_id = p_gym and m.status = 'active' and m.role = 'member' and p.full_name <> 'Usuario eliminado'
  order by p.full_name;
end $$;
revoke execute on function public.staff_plan_overview from public, anon;
grant execute on function public.staff_plan_overview to authenticated;

-- Rechazar una solicitud (con motivo opcional que verá el alumno)
create function public.reject_plan_request(p_request uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_r public.plan_requests%rowtype;
begin
  select * into v_r from public.plan_requests where id = p_request;
  if not found then
    raise exception 'Solicitud no encontrada' using errcode = 'P0002';
  end if;
  if not public.has_role(v_r.gym_id, array['owner', 'admin', 'front_desk']::public.gym_role[]) then
    raise exception 'Solo recepción y administración responden solicitudes' using errcode = '42501';
  end if;
  update public.plan_requests
  set status = 'cancelled', handled_at = now(), handled_by = (select auth.uid()), reject_reason = nullif(trim(coalesce(p_reason, '')), '')
  where id = p_request and status = 'pending';
end $$;
revoke execute on function public.reject_plan_request from public, anon;
grant execute on function public.reject_plan_request to authenticated;

-- Solicitudes pendientes: también si es complemento y el precio, para aprobar desde la lista
drop function public.pending_plan_requests(uuid);
create function public.pending_plan_requests(p_gym uuid)
returns table (id uuid, profile_id uuid, full_name text, plan_id uuid, plan_name text, price_cents integer, is_addon boolean,
               current_plan text, note text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select r.id, r.profile_id, p.full_name, r.plan_id, pl.name, pl.price_cents, pl.is_addon,
    (select cp.name from public.plan_on(r.profile_id, p_gym, current_date) x join public.plans cp on cp.id = x.plan_id),
    r.note, r.created_at
  from public.plan_requests r
  join public.profiles p on p.id = r.profile_id
  join public.plans pl on pl.id = r.plan_id
  where r.gym_id = p_gym and r.status = 'pending'
    and public.has_role(p_gym, array['owner', 'admin', 'front_desk']::public.gym_role[])
  order by r.created_at
$$;
revoke execute on function public.pending_plan_requests from public, anon;
grant execute on function public.pending_plan_requests to authenticated;
