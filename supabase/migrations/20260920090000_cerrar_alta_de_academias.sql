-- ITACA — Cierra en el servidor el alta de academias nuevas.
--
-- La pantalla de "crear mi academia" está congelada desde agosto (ver
-- FREEZE.md §4): la ruta no tiene GoRoute y el botón no existe en ningún
-- sitio de la app. Pero el trigger que de verdad crea la fila —
-- `handle_new_user()`, en `auth.users` — seguía aceptando el flujo
-- `registro_academia` completo. Cualquiera que llamara al registro de
-- Supabase Auth con los metadatos correctos (`flujo: 'registro_academia'`,
-- `nombre_academia: '...'`) — sin tocar la app, con una llamada directa a
-- la API pública — se creaba una academia nueva y un perfil de dueño
-- pendiente de aprobar. Esconder el botón nunca cerró esa puerta.
--
-- Se cierra aquí, en el único sitio real donde se puede cerrar: el propio
-- trigger. No se toca ni una tabla ni una columna del esquema
-- multi-academia — sigue conservado por debajo, como está decidido —
-- solo se deja de aceptar la creación de una academia nueva mientras ITACA
-- sea la única academia operativa.

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
    raise exception
      'El alta de nuevas academias está desactivada: ITACA es la única '
      'academia operativa por ahora.';

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
