-- ITACA — Fase 8: Tienda y Material (módulo 5).

create table if not exists public.productos (
  id uuid primary key default gen_random_uuid(),
  academia_id uuid not null references public.academias (id),
  nombre text not null,
  descripcion text,
  precio numeric(10, 2) not null check (precio >= 0),
  stock int not null default 0 check (stock >= 0),
  foto_url text,
  activo boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.pedidos (
  id uuid primary key default gen_random_uuid(),
  -- academia_id y precio_snapshot se autocompletan desde el producto vía
  -- trigger (no se confía en el cliente para el precio).
  academia_id uuid not null references public.academias (id),
  alumno_id uuid not null references public.profiles (id),
  producto_id uuid not null references public.productos (id),
  cantidad int not null default 1 check (cantidad > 0),
  estado text not null default 'reservado'
    check (estado in ('reservado', 'confirmado', 'entregado', 'cancelado')),
  precio_snapshot numeric(10, 2),
  created_at timestamptz not null default now()
);

create table if not exists public.prestamos (
  id uuid primary key default gen_random_uuid(),
  -- academia_id se autocompleta desde el perfil del alumno vía trigger.
  academia_id uuid not null references public.academias (id),
  alumno_id uuid not null references public.profiles (id),
  producto_id uuid references public.productos (id),
  descripcion text,
  fecha_prestamo timestamptz not null default now(),
  fecha_devolucion timestamptz,
  gestionado_por uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint prestamos_producto_o_descripcion check (producto_id is not null or descripcion is not null)
);

create index if not exists productos_academia_idx on public.productos (academia_id);
create index if not exists pedidos_academia_idx on public.pedidos (academia_id);
create index if not exists prestamos_academia_idx on public.prestamos (academia_id);

-- ============================================================
-- Triggers de autocompletado
-- ============================================================

create or replace function public.set_pedido_defaults()
returns trigger
language plpgsql
as $$
declare
  v_academia_id uuid;
  v_precio numeric(10, 2);
begin
  select academia_id, precio into v_academia_id, v_precio
    from public.productos where id = new.producto_id;
  new.academia_id := v_academia_id;
  new.precio_snapshot := v_precio;
  return new;
end;
$$;

create trigger pedidos_set_defaults
  before insert on public.pedidos
  for each row execute function public.set_pedido_defaults();

create or replace function public.set_prestamo_academia()
returns trigger
language plpgsql
as $$
begin
  select academia_id into new.academia_id from public.profiles where id = new.alumno_id;
  return new;
end;
$$;

create trigger prestamos_set_academia
  before insert on public.prestamos
  for each row execute function public.set_prestamo_academia();

-- ============================================================
-- RLS: productos
-- ============================================================

alter table public.productos enable row level security;

create policy productos_select on public.productos
  for select
  using (academia_id = public.current_academia_id() or public.current_rol() = 'administrador');

create policy productos_insert on public.productos
  for insert
  with check (
    academia_id = public.current_academia_id()
    and public.current_rol() in ('profesor', 'dueño')
  );

create policy productos_update on public.productos
  for update
  using (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  )
  with check (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

create policy productos_delete on public.productos
  for delete
  using (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

-- ============================================================
-- RLS: pedidos (un alumno solo ve/gestiona los suyos; el staff ve todos
-- los de su academia)
-- ============================================================

alter table public.pedidos enable row level security;

create policy pedidos_select on public.pedidos
  for select
  using (
    alumno_id = auth.uid()
    or (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

create policy pedidos_insert on public.pedidos
  for insert
  with check (
    alumno_id = auth.uid()
    and exists (
      select 1 from public.productos p
      where p.id = producto_id and p.academia_id = public.current_academia_id() and p.activo
    )
  );

create policy pedidos_update on public.pedidos
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
-- RLS: prestamos (gestión de staff; el alumno puede ver los suyos)
-- ============================================================

alter table public.prestamos enable row level security;

create policy prestamos_select on public.prestamos
  for select
  using (
    alumno_id = auth.uid()
    or (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

create policy prestamos_insert on public.prestamos
  for insert
  with check (
    gestionado_por = auth.uid()
    and public.current_rol() in ('profesor', 'dueño')
    and exists (
      select 1 from public.profiles al
      where al.id = alumno_id and al.academia_id = public.current_academia_id()
    )
  );

create policy prestamos_update on public.prestamos
  for update
  using (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  )
  with check (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );
