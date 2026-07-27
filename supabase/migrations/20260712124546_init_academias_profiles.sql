-- ITACA — Fase 2: academias, profiles y aislamiento multi-tenant (RLS)
--
-- Nota de alcance: esta migración cubre solo el núcleo de auth/tenancy
-- (academias + profiles) necesario para el flujo de registro/login/aprobación.
-- Las tablas de los módulos 1-6 (clases, tecnicas, tarifas, etc.) se añadirán
-- en migraciones posteriores, una por fase, siguiendo el mismo patrón de RLS
-- que se establece aquí.

-- ============================================================
-- Tablas
-- ============================================================

create table if not exists public.academias (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  direccion text,
  telefono text,
  email_contacto text,
  estado text not null default 'pending' check (estado in ('pending', 'approved', 'rejected')),
  created_by uuid references auth.users (id),
  approved_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  approved_at timestamptz
);

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  academia_id uuid references public.academias (id),
  rol text not null check (rol in ('administrador', 'dueño', 'profesor', 'alumno')),
  nombre text not null,
  apellidos text,
  foto_url text,
  cinturon text check (cinturon in ('blanco', 'azul', 'morado', 'marron', 'negro')),
  estado text not null default 'activo' check (estado in ('activo', 'pendiente_aprobacion')),
  created_at timestamptz not null default now(),
  -- Solo Administrador puede tener academia_id nulo (alcance de plataforma).
  constraint profiles_academia_requerida_salvo_admin
    check (academia_id is not null or rol = 'administrador')
);

create index if not exists profiles_academia_id_idx on public.profiles (academia_id);
create index if not exists academias_estado_idx on public.academias (estado);

-- ============================================================
-- Funciones auxiliares para RLS (security definer para evitar
-- recursión de RLS sobre la propia tabla profiles).
-- ============================================================

create or replace function public.current_academia_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select academia_id from public.profiles where id = auth.uid();
$$;

create or replace function public.current_rol()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select rol from public.profiles where id = auth.uid();
$$;

-- ============================================================
-- RLS: profiles
-- ============================================================

alter table public.profiles enable row level security;

create policy profiles_select on public.profiles
  for select
  using (
    id = auth.uid()
    or academia_id = public.current_academia_id()
    or public.current_rol() = 'administrador'
  );

-- Un usuario recién registrado crea su propia fila (id = auth.uid()).
create policy profiles_insert_self on public.profiles
  for insert
  with check (id = auth.uid());

-- Cada usuario edita solo su propia fila; Administrador edita cualquiera.
create policy profiles_update on public.profiles
  for update
  using (id = auth.uid() or public.current_rol() = 'administrador')
  with check (id = auth.uid() or public.current_rol() = 'administrador');

-- ============================================================
-- RLS: academias
-- ============================================================

alter table public.academias enable row level security;

-- Lectura: Administrador ve todas; cada usuario ve la suya propia una vez
-- tiene perfil; y quien registró una academia (created_by) puede verla
-- siempre, incluso antes de tener fila en profiles (necesario para que el
-- INSERT ... RETURNING del registro de academia no falle por RLS: Postgres
-- exige poder ver la fila recién insertada, y en ese momento el Dueño
-- todavía no tiene perfil, así que current_academia_id() no sirve).
-- (El listado de academias "aprobadas" para el selector de registro se
-- expone aparte vía la RPC listar_academias_aprobadas, sin dar acceso de
-- tabla completo a usuarios no autenticados/sin academia todavía.)
create policy academias_select on public.academias
  for select
  using (
    id = public.current_academia_id()
    or created_by = auth.uid()
    or public.current_rol() = 'administrador'
  );

-- Cualquier usuario autenticado puede registrar una academia nueva (queda 'pending').
create policy academias_insert on public.academias
  for insert
  with check (created_by = auth.uid());

-- El Dueño edita los datos de su propia academia; Administrador aprueba/rechaza cualquiera.
create policy academias_update on public.academias
  for update
  using (
    (id = public.current_academia_id() and public.current_rol() = 'dueño')
    or public.current_rol() = 'administrador'
  )
  with check (
    (id = public.current_academia_id() and public.current_rol() = 'dueño')
    or public.current_rol() = 'administrador'
  );

-- ============================================================
-- RPCs
-- ============================================================

-- Selector de "unirse a una academia existente" durante el registro:
-- solo expone id/nombre de academias aprobadas, sin requerir acceso de
-- tabla completo (el usuario aún no tiene fila en profiles en ese punto).
create or replace function public.listar_academias_aprobadas()
returns table (id uuid, nombre text)
language sql
stable
security definer
set search_path = public
as $$
  select id, nombre from public.academias where estado = 'approved' order by nombre;
$$;

-- Aprobación de academia por el Administrador: marca la academia como
-- aprobada y activa el perfil del Dueño que la registró.
create or replace function public.aprobar_academia(p_academia_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_rol() <> 'administrador' then
    raise exception 'Solo un administrador puede aprobar academias.';
  end if;

  update public.academias
    set estado = 'approved', approved_by = auth.uid(), approved_at = now()
    where id = p_academia_id;

  update public.profiles
    set estado = 'activo'
    where academia_id = p_academia_id and estado = 'pendiente_aprobacion';

  -- Nota: la siembra de la plantilla de técnicas por defecto (módulo 4,
  -- tabla `tecnicas`) se añadirá aquí en la migración de la fase 7.
end;
$$;
