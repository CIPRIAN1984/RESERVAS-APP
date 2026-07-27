-- ITACA — Fiabilidad, Fase 1: alta de usuario atómica.
--
-- Problema que corrige: hasta ahora el registro hacía dos operaciones
-- separadas desde el cliente — auth.signUp() creaba el usuario en auth.users
-- y, en una segunda llamada, la app insertaba la fila en profiles (y en
-- academias para un Dueño). Si esa segunda operación fallaba (red, o
-- confirmación de email activada, en cuyo caso todavía no hay sesión y la
-- política profiles_insert_self bloquea el INSERT), quedaba un usuario
-- huérfano en auth.users sin perfil, atascado en el bucle de registro.
--
-- Solución: un trigger AFTER INSERT sobre auth.users que crea el perfil (y la
-- academia, si procede) en la MISMA transacción que el alta del usuario. Si
-- algo falla, todo el signup se revierte y no queda ningún huérfano. Además
-- saca la lógica sensible del cliente: el rol y el estado ya no los decide la
-- app, los impone el servidor a partir del flujo declarado en la metadata.
--
-- Seguridad: la metadata del signup (raw_user_meta_data) la controla el
-- cliente, así que NO se confía en ella para el rol ni para el estado. El
-- trigger fuerza:
--   * flujo 'registro_academia' -> rol 'dueño', estado 'pendiente_aprobacion'
--   * flujo 'unirse' (por defecto) -> rol 'alumno', estado 'activo', y exige
--     que la academia destino exista y esté 'approved'.
-- Nunca se puede auto-asignar 'administrador' ni 'profesor' desde el registro.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_flujo text := coalesce(v_meta->>'flujo', 'unirse');
  v_nombre text := nullif(trim(v_meta->>'nombre'), '');
  v_apellidos text := nullif(trim(v_meta->>'apellidos'), '');
  v_academia_id uuid;
begin
  -- Sin metadata de ITACA (p. ej. un usuario creado desde el dashboard de
  -- Supabase o el Administrador sembrado a mano): no se toca nada, su perfil
  -- se gestiona por otra vía.
  if v_nombre is null then
    return new;
  end if;

  if v_flujo = 'registro_academia' then
    if nullif(trim(v_meta->>'nombre_academia'), '') is null then
      raise exception 'Falta el nombre de la academia.';
    end if;

    insert into public.academias (nombre, direccion, telefono, email_contacto, estado, created_by)
    values (
      trim(v_meta->>'nombre_academia'),
      nullif(trim(v_meta->>'direccion'), ''),
      nullif(trim(v_meta->>'telefono'), ''),
      nullif(trim(v_meta->>'email_contacto'), ''),
      'pending',
      new.id
    )
    returning id into v_academia_id;

    insert into public.profiles (id, academia_id, rol, nombre, apellidos, estado)
    values (new.id, v_academia_id, 'dueño', v_nombre, v_apellidos, 'pendiente_aprobacion');

  else
    -- Flujo por defecto: unirse como alumno a una academia ya aprobada.
    v_academia_id := (v_meta->>'academia_id')::uuid;
    if v_academia_id is null then
      raise exception 'Falta la academia de destino.';
    end if;

    if not exists (
      select 1 from public.academias
      where id = v_academia_id and estado = 'approved'
    ) then
      raise exception 'La academia seleccionada no existe o no está aprobada.';
    end if;

    -- rol y estado los impone el servidor: el auto-registro solo crea alumnos.
    insert into public.profiles (id, academia_id, rol, nombre, apellidos, estado)
    values (new.id, v_academia_id, 'alumno', v_nombre, v_apellidos, 'activo');
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- El perfil y la academia ya solo nacen desde este trigger (security definer).
-- Se retira la capacidad del cliente de insertarlos directamente, que era la
-- vía del flujo antiguo y ahora sería un camino paralelo sin las validaciones
-- de arriba (p. ej. un cliente podría intentar crearse el perfil con
-- rol='profesor'). La lectura/actualización siguen igual.
drop policy if exists profiles_insert_self on public.profiles;
drop policy if exists academias_insert on public.academias;
