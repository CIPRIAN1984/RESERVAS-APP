-- Paso 1 · Núcleo: sedes, personas, miembros por sede y tutores.
-- Todo lleva gym_id (salvo la persona, que puede estar en varias sedes),
-- claves UUID y marcas de creación y modificación.

create type public.gym_role as enum ('owner', 'admin', 'coach', 'front_desk', 'member');
create type public.member_status as enum ('active', 'inactive');

-- Marca updated_at en cada modificación
create function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ---------- Sedes ----------
create table public.gyms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  time_zone text not null default 'Europe/Madrid',
  -- Ajustes: plazo de cancelación, política de no presentados, ventana de check-in…
  settings jsonb not null default '{"cancel_window_hours": 2, "checkin_before_min": 30, "checkin_after_min": 15}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger gyms_updated_at before update on public.gyms
  for each row execute function public.set_updated_at();

-- ---------- Personas ----------
-- user_id vacío = menor sin cuenta, gestionado por su tutor.
create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users (id) on delete set null,
  full_name text not null check (length(trim(full_name)) > 0),
  birth_date date,
  emergency_contact_name text,
  emergency_contact_phone text,
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------- Miembros de una sede (con rol) ----------
create table public.gym_members (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  role public.gym_role not null default 'member',
  status public.member_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (gym_id, profile_id)
);
create index gym_members_profile_idx on public.gym_members (profile_id);
create trigger gym_members_updated_at before update on public.gym_members
  for each row execute function public.set_updated_at();

-- ---------- Tutor → menor ----------
create table public.guardianships (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete cascade,
  guardian_profile_id uuid not null references public.profiles (id) on delete cascade,
  minor_profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (guardian_profile_id, minor_profile_id),
  check (guardian_profile_id <> minor_profile_id)
);
create index guardianships_minor_idx on public.guardianships (minor_profile_id);
create trigger guardianships_updated_at before update on public.guardianships
  for each row execute function public.set_updated_at();

-- ---------- Registro de auditoría (roles, y después cobros y rangos) ----------
create table public.audit_log (
  id bigint generated always as identity primary key,
  gym_id uuid references public.gyms (id) on delete cascade,
  actor_user_id uuid,
  table_name text not null,
  row_id uuid,
  action text not null,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

-- ---------- Alta automática del perfil al registrarse ----------
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (user_id, full_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), split_part(new.email, '@', 1))
  );
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
