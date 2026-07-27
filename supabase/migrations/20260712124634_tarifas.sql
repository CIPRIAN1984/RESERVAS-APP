-- ITACA — Fase 9: Tarifas / suscripciones (módulo 6).
--
-- Sin pasarela de pago real todavía: "suscripción automatizada" significa
-- que el propio alumno activa su suscripción (transición de estado), sin
-- aprobación manual. Se dejan columnas nullable (proveedor_pago,
-- referencia_externa, payment_status) para poder enchufar un proveedor de
-- pago real más adelante sin tener que reescribir el esquema.

create table if not exists public.tarifas (
  id uuid primary key default gen_random_uuid(),
  academia_id uuid not null references public.academias (id),
  nombre text not null,
  descripcion text,
  precio numeric(10, 2) not null check (precio >= 0),
  periodicidad text not null check (periodicidad in ('mensual', 'trimestral', 'anual')),
  activo boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.suscripciones (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references public.profiles (id),
  tarifa_id uuid not null references public.tarifas (id),
  -- Se autocompleta desde el perfil del alumno vía trigger.
  academia_id uuid not null references public.academias (id),
  estado text not null default 'activa' check (estado in ('activa', 'cancelada', 'expirada')),
  fecha_inicio timestamptz not null default now(),
  fecha_fin timestamptz,
  proveedor_pago text,
  referencia_externa text,
  payment_status text default 'n/a',
  created_at timestamptz not null default now()
);

-- Una sola suscripción activa por alumno.
create unique index if not exists suscripciones_activa_unica_idx
  on public.suscripciones (alumno_id)
  where estado = 'activa';

create index if not exists tarifas_academia_idx on public.tarifas (academia_id);
create index if not exists suscripciones_academia_idx on public.suscripciones (academia_id);

-- ============================================================
-- Trigger de autocompletado
-- ============================================================

create or replace function public.set_suscripcion_academia()
returns trigger
language plpgsql
as $$
begin
  select academia_id into new.academia_id from public.profiles where id = new.alumno_id;
  return new;
end;
$$;

create trigger suscripciones_set_academia
  before insert on public.suscripciones
  for each row execute function public.set_suscripcion_academia();

-- ============================================================
-- RLS: tarifas
-- ============================================================

alter table public.tarifas enable row level security;

create policy tarifas_select on public.tarifas
  for select
  using (academia_id = public.current_academia_id() or public.current_rol() = 'administrador');

create policy tarifas_insert on public.tarifas
  for insert
  with check (
    academia_id = public.current_academia_id()
    and public.current_rol() in ('profesor', 'dueño')
  );

create policy tarifas_update on public.tarifas
  for update
  using (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  )
  with check (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

create policy tarifas_delete on public.tarifas
  for delete
  using (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

-- ============================================================
-- RLS: suscripciones
-- ============================================================

alter table public.suscripciones enable row level security;

create policy suscripciones_select on public.suscripciones
  for select
  using (
    alumno_id = auth.uid()
    or (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

-- El alumno se suscribe a sí mismo, a una tarifa activa de su propia academia.
create policy suscripciones_insert on public.suscripciones
  for insert
  with check (
    alumno_id = auth.uid()
    and exists (
      select 1 from public.tarifas t
      where t.id = tarifa_id and t.academia_id = public.current_academia_id() and t.activo
    )
  );

-- El alumno puede cancelar la suya (lo usa la RPC suscribirse); staff puede
-- gestionar cualquiera de su academia.
create policy suscripciones_update on public.suscripciones
  for update
  using (
    alumno_id = auth.uid()
    or (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  )
  with check (
    alumno_id = auth.uid()
    or (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

-- ============================================================
-- RPC: suscripción automatizada (cancela la activa anterior si la había,
-- y activa la nueva, de forma atómica). Security invoker: respeta las
-- políticas de arriba, no necesita privilegios elevados.
-- ============================================================

create or replace function public.suscribirse(p_tarifa_id uuid)
returns void
language plpgsql
as $$
begin
  update public.suscripciones
    set estado = 'cancelada', fecha_fin = now()
    where alumno_id = auth.uid() and estado = 'activa';

  insert into public.suscripciones (alumno_id, tarifa_id, estado, fecha_inicio)
  values (auth.uid(), p_tarifa_id, 'activa', now());
end;
$$;
