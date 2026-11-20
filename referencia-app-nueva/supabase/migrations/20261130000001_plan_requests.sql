-- Fase 7 del plan de mejora · Membresías: el alumno (o su tutor) pide una
-- tarifa desde la app; recepción la ve como pendiente en Alumnos y, al
-- asignarla, la solicitud queda atendida. El pago sigue siendo en recepción.

create type public.plan_request_status as enum ('pending', 'done', 'cancelled');

create table public.plan_requests (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  plan_id uuid not null references public.plans (id),
  note text check (note is null or length(note) <= 300),
  status public.plan_request_status not null default 'pending',
  requested_by uuid,
  handled_by uuid,
  handled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- Una sola solicitud pendiente por persona
create unique index plan_requests_one_pending_idx on public.plan_requests (profile_id) where status = 'pending';
create index plan_requests_gym_idx on public.plan_requests (gym_id, status, created_at);
create trigger plan_requests_updated_at before update on public.plan_requests
  for each row execute function public.set_updated_at();

alter table public.plan_requests enable row level security;
revoke all on public.plan_requests from anon;
revoke insert, update, delete on public.plan_requests from authenticated;
create policy plan_requests_select on public.plan_requests for select to authenticated
  using (
    profile_id = public.current_profile_id()
    or public.is_guardian_of(profile_id)
    or public.is_staff(gym_id)
  );

-- Pedir una tarifa (para mí o para un menor a mi cargo). Sustituye a la pendiente anterior.
create function public.request_plan(p_plan uuid, p_profile uuid default null, p_note text default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_profile uuid := coalesce(p_profile, public.current_profile_id());
  v_plan public.plans%rowtype;
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
  update public.plan_requests set status = 'cancelled', handled_at = now()
  where profile_id = v_profile and status = 'pending';
  insert into public.plan_requests (gym_id, profile_id, plan_id, note, requested_by)
  values (v_plan.gym_id, v_profile, p_plan, nullif(trim(coalesce(p_note, '')), ''), (select auth.uid()))
  returning id into v_id;
  return v_id;
end $$;

-- Retirar mi solicitud pendiente
create function public.cancel_plan_request(p_request uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_r public.plan_requests%rowtype;
begin
  select * into v_r from public.plan_requests where id = p_request;
  if not found then
    raise exception 'Solicitud no encontrada' using errcode = 'P0002';
  end if;
  if not (v_r.profile_id = public.current_profile_id() or public.is_guardian_of(v_r.profile_id)
          or public.has_role(v_r.gym_id, array['owner', 'admin', 'front_desk']::public.gym_role[])) then
    raise exception 'No puedes retirar esta solicitud' using errcode = '42501';
  end if;
  update public.plan_requests set status = 'cancelled', handled_at = now(), handled_by = (select auth.uid())
  where id = p_request and status = 'pending';
end $$;

-- Al asignar una tarifa, la solicitud pendiente de esa persona queda atendida
create function public.close_plan_request() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.plan_requests set status = 'done', handled_at = now(), handled_by = new.created_by
  where profile_id = new.profile_id and status = 'pending';
  return null;
end $$;
create trigger member_plans_close_request after insert on public.member_plans
  for each row execute function public.close_plan_request();

-- Solicitudes pendientes de la sede (recepción)
create function public.pending_plan_requests(p_gym uuid)
returns table (id uuid, profile_id uuid, full_name text, plan_id uuid, plan_name text, note text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select r.id, r.profile_id, p.full_name, r.plan_id, pl.name, r.note, r.created_at
  from public.plan_requests r
  join public.profiles p on p.id = r.profile_id
  join public.plans pl on pl.id = r.plan_id
  where r.gym_id = p_gym and r.status = 'pending'
    and public.has_role(p_gym, array['owner', 'admin', 'front_desk']::public.gym_role[])
  order by r.created_at
$$;

revoke execute on function public.request_plan, public.cancel_plan_request, public.pending_plan_requests from public, anon;
grant execute on function public.request_plan, public.cancel_plan_request, public.pending_plan_requests to authenticated;
