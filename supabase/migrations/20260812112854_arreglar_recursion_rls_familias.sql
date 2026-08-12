-- Arregla la recursión de RLS entre profiles y relaciones_familia
--
-- La migración familias_tutores (20260810100946) añadió políticas que se
-- consultan directamente entre sí dentro de la cláusula `using`:
-- profiles_select/profiles_update leen relaciones_familia, y
-- relaciones_familia_select lee profiles. Postgres evalúa RLS en cada
-- subconsulta, así que al leer un perfil con hijos (o un hijo con padre)
-- puede acabar en recursión y devolver
-- "infinite recursion detected in policy for relation profiles".
--
-- El patrón ya establecido en este proyecto para evitarlo (ver
-- current_academia_id() / current_rol() en 20260712124546) es envolver la
-- consulta en una función security definer: al ejecutarse con los
-- privilegios de su dueño, Postgres no vuelve a evaluar las políticas RLS
-- de la tabla consultada dentro de esa función.

-- ============================================================
-- Funciones auxiliares (mismo patrón que current_academia_id/current_rol)
-- ============================================================

create or replace function public.mi_padre_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select parent_id from public.relaciones_familia where child_id = auth.uid();
$$;

create or replace function public.es_padre_de(p_child_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.relaciones_familia
    where parent_id = auth.uid() and child_id = p_child_id
  );
$$;

create or replace function public.academia_id_de(p_profile_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select academia_id from public.profiles where id = p_profile_id;
$$;

-- ============================================================
-- profiles: reescribe profiles_select y profiles_update con las funciones
-- ============================================================

drop policy if exists profiles_select on public.profiles;

create policy profiles_select on public.profiles
  for select
  using (
    id = auth.uid()
    or public.mi_padre_id() = auth.uid()
    or public.es_padre_de(profiles.id)
    or academia_id = public.current_academia_id()
    or public.current_rol() = 'administrador'
  );

-- profiles_update_self quedaba redundante con profiles_update (ambas
-- políticas de UPDATE se combinan con OR): se retira aquí de paso.
drop policy if exists profiles_update_self on public.profiles;
drop policy if exists profiles_update on public.profiles;

create policy profiles_update on public.profiles
  for update
  using (
    id = auth.uid()
    or public.es_padre_de(profiles.id)
    or public.current_rol() = 'administrador'
  )
  with check (
    id = auth.uid()
    or public.es_padre_de(profiles.id)
    or public.current_rol() = 'administrador'
  );

-- ============================================================
-- relaciones_familia: reescribe relaciones_familia_select
-- ============================================================

drop policy if exists relaciones_familia_select on public.relaciones_familia;

create policy relaciones_familia_select on public.relaciones_familia
  for select
  using (
    parent_id = auth.uid()
    or public.academia_id_de(auth.uid()) = public.academia_id_de(relaciones_familia.parent_id)
    or public.current_rol() = 'administrador'
  );

-- ============================================================
-- Permisos que faltaban (dos fallos aparte, encontrados al probar esto)
-- ============================================================

-- 1) Postgres concede EXECUTE a PUBLIC en toda función nueva por defecto.
-- Las funciones de este fichero se colaron con ese permiso por defecto
-- (igual que pasó con crear_perfil_hijo en la migración
-- 20260810101142): cualquiera sin sesión podía invocarlas. No hacen daño
-- por sí solas (solo leen), pero no deben ser públicas.
revoke execute on function public.mi_padre_id() from public;
revoke execute on function public.es_padre_de(uuid) from public;
revoke execute on function public.academia_id_de(uuid) from public;

grant execute on function public.mi_padre_id() to authenticated;
grant execute on function public.es_padre_de(uuid) to authenticated;
grant execute on function public.academia_id_de(uuid) to authenticated;

-- 2) La migración familias_tutores nunca concedió permisos de tabla sobre
-- relaciones_familia a authenticated ("no necesita grant: las políticas
-- RLS lo controlan" — falso: sin GRANT de tabla, RLS ni se llega a
-- evaluar, Postgres deniega antes por falta de privilegio). Resultado:
-- ningún padre ha podido leer ni escribir relaciones_familia nunca, con
-- o sin el bug de recursión.
grant select, insert, update, delete on public.relaciones_familia to authenticated;
