-- Catálogo de tarifas (adelanto del paso 6).
-- Solo el catálogo: suscripciones, créditos y cobros llegan en el paso 6.

create type public.plan_kind as enum ('membership', 'pack', 'drop_in');
create type public.billing_period as enum ('month', 'quarter', 'year', 'once');
create type public.plan_audience as enum ('adults', 'kids', 'all');

create table public.plans (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete cascade,
  slug text not null,
  name text not null check (length(trim(name)) > 0),
  description text not null default '',
  kind public.plan_kind not null,
  price_cents integer not null check (price_cents >= 0),
  billing_period public.billing_period not null,
  -- null = sesiones ilimitadas
  sessions integer check (sessions is null or sessions > 0),
  -- las sesiones son por mes (membresías) o en total (bonos y pases)
  sessions_per_month boolean not null default true,
  -- validez de un bono o pase; null = sin caducidad
  validity_months integer check (validity_months is null or validity_months > 0),
  auto_renew boolean not null default true,
  audience public.plan_audience not null default 'adults',
  active boolean not null default true,
  sort smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (gym_id, slug)
);
create trigger plans_updated_at before update on public.plans
  for each row execute function public.set_updated_at();

alter table public.plans enable row level security;
revoke all on public.plans from anon;

create policy plans_select on public.plans for select to authenticated
  using (public.has_role(gym_id, enum_range(null::public.gym_role)));
create policy plans_write on public.plans for all to authenticated
  using (public.has_role(gym_id, array['owner', 'admin']::public.gym_role[]))
  with check (public.has_role(gym_id, array['owner', 'admin']::public.gym_role[]));
