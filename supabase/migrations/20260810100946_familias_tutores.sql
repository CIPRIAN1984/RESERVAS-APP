-- Familias y tutores: un padre con varios hijos, cada uno con su perfil

-- ============================================================
-- Tabla: relaciones_familia
-- ============================================================
-- Registra la relación entre un adulto (tutor/padre) y los menores
-- bajo su cuidado. Es explícita por diseño: un alumno regular es su
-- propio padre (o NULL si es menor); un menor tiene parent_id que
-- apunta a su padre/tutor.

create table if not exists public.relaciones_familia (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid not null references public.profiles (id) on delete cascade,
  child_id uuid not null references public.profiles (id) on delete cascade,
  -- Tipo de relación: 'padre', 'madre', 'tutor', etc.
  tipo_relacion text not null default 'padre' check (
    tipo_relacion in ('padre', 'madre', 'tutor', 'apoderado')
  ),
  created_at timestamptz not null default now(),
  -- Un menor solo puede tener un padre/tutor; un padre puede tener varios menores.
  unique(child_id),
  -- Evita ciclos: un menor no puede ser padre de su propio padre.
  constraint no_ciclos_familia check (parent_id != child_id)
);

create index if not exists relaciones_familia_parent_id_idx
  on public.relaciones_familia (parent_id);
create index if not exists relaciones_familia_child_id_idx
  on public.relaciones_familia (child_id);

-- ============================================================
-- RLS: relaciones_familia
-- ============================================================

alter table public.relaciones_familia enable row level security;

-- Un padre ve sus relaciones y las de su academia.
-- Un administrador ve todo.
create policy relaciones_familia_select on public.relaciones_familia
  for select
  using (
    parent_id = auth.uid()
    or (
      select academia_id
      from public.profiles
      where id = auth.uid()
    ) = (
      select academia_id
      from public.profiles
      where id = public.relaciones_familia.parent_id
    )
    or public.current_rol() = 'administrador'
  );

-- Un padre crea relaciones para sus hijos.
create policy relaciones_familia_insert on public.relaciones_familia
  for insert
  with check (parent_id = auth.uid());

-- Un padre edita sus propias relaciones.
create policy relaciones_familia_update on public.relaciones_familia
  for update
  using (parent_id = auth.uid())
  with check (parent_id = auth.uid());

-- Un padre borra sus propias relaciones.
create policy relaciones_familia_delete on public.relaciones_familia
  for delete
  using (parent_id = auth.uid());

-- ============================================================
-- Actualizar RLS de profiles para menores (hijos sin auth propia)
-- ============================================================

-- Un menor puede verlo solo su padre (y Administrador viendo cualquiera).
-- Un padre ve a sus hijos y a los demás de la academia (como antes).
-- Un alumno regular sigue viéndose a sí mismo y a los demás de la academia.

drop policy if exists profiles_select on public.profiles;

create policy profiles_select on public.profiles
  for select
  using (
    -- Yo mismo
    id = auth.uid()
    -- Mi padre (si soy menor)
    or (
      select parent_id
      from public.relaciones_familia
      where child_id = auth.uid()
    ) = auth.uid()
    -- Mis hijos (si soy padre)
    or (
      select exists(
        select 1
        from public.relaciones_familia
        where parent_id = auth.uid()
          and child_id = public.profiles.id
      )
    )
    -- Mis compañeros de academia (si tengo)
    or academia_id = public.current_academia_id()
    -- Soy administrador
    or public.current_rol() = 'administrador'
  );

-- ============================================================
-- Permisos de actualización para menores
-- ============================================================

-- Un menor puede editar su propia foto y datos personales, pero no rol, estado, academia, etc.
-- Un padre puede editar los datos personales y cinturón de sus hijos.
-- Un administrador sigue editándolo todo.

drop policy if exists profiles_update on public.profiles;

create policy profiles_update on public.profiles
  for update
  using (
    -- Yo mismo (cualquier columna)
    id = auth.uid()
    -- Mis hijos (solo ciertos campos: se controla en la app)
    or (
      select exists(
        select 1
        from public.relaciones_familia
        where parent_id = auth.uid()
          and child_id = public.profiles.id
      )
    )
    -- Soy administrador
    or public.current_rol() = 'administrador'
  )
  with check (
    id = auth.uid()
    or (
      select exists(
        select 1
        from public.relaciones_familia
        where parent_id = auth.uid()
          and child_id = public.profiles.id
      )
    )
    or public.current_rol() = 'administrador'
  );

-- ============================================================
-- Función: crear_perfil_hijo (crea perfil + relación familia)
-- ============================================================
-- Llamada desde Edge Function con service_role.
-- Los menores NO tienen auth.users: solo perfiles, accesibles
-- por el padre a través de relaciones_familia.
-- El ID del perfil es único y se usa como referencia.

create or replace function public.crear_perfil_hijo(
  p_parent_id uuid,
  p_academia_id uuid,
  p_nombre text,
  p_apellidos text,
  p_cinturon text default null
) returns table (
  hijo_id uuid,
  familia_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hijo_id uuid;
  v_familia_id uuid;
begin
  -- Crear el perfil del hijo: rol 'alumno', sin cuenta de auth propia.
  insert into public.profiles (
    id,
    academia_id,
    rol,
    nombre,
    apellidos,
    cinturon,
    estado
  ) values (
    gen_random_uuid(),
    p_academia_id,
    'alumno',
    p_nombre,
    p_apellidos,
    p_cinturon,
    'activo'
  ) returning id into v_hijo_id;

  -- Crear la relación familia: parent_id (pasada como argumento), hijo = v_hijo_id.
  insert into public.relaciones_familia (
    parent_id,
    child_id,
    tipo_relacion
  ) values (
    p_parent_id,
    v_hijo_id,
    'padre'
  ) returning id into v_familia_id;

  return query select v_hijo_id, v_familia_id;
end;
$$;

-- No conceder execute directo: la Edge Function es la puerta.
-- La función es security definer para poder insertar en relaciones_familia
-- sin que la RLS de profiles bloquee.

-- ============================================================
-- Permisos finales
-- ============================================================

-- relaciones_familia: authenticated ve sus propias relaciones.
-- No necesita grant: las políticas RLS lo controlan.
