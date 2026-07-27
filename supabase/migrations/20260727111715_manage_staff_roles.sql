-- Gestión de roles operativos dentro de una academia.
--
-- El registro público solo crea Alumnos y Dueños. Un Dueño puede convertir en
-- Profesor a un Alumno ya verificado de su propia academia, o devolver un
-- Profesor al rol Alumno. La función no permite modificar roles de plataforma,
-- otros Dueños, miembros de otra academia ni el perfil del llamante.

create or replace function public.cambiar_rol_miembro(
  p_miembro_id uuid,
  p_nuevo_rol text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_academia_id uuid;
  v_actor_rol text;
  v_actor_estado text;
  v_miembro_academia_id uuid;
  v_miembro_rol text;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select academia_id, rol, estado
    into v_actor_academia_id, v_actor_rol, v_actor_estado
    from public.profiles
    where id = v_actor_id;

  if not found
     or v_actor_rol <> 'dueño'
     or v_actor_estado <> 'activo'
     or v_actor_academia_id is null then
    raise exception 'Solo el Dueño activo puede gestionar el equipo.';
  end if;

  if p_nuevo_rol not in ('alumno', 'profesor') then
    raise exception 'El rol solicitado no está permitido.';
  end if;

  if p_miembro_id = v_actor_id then
    raise exception 'No puedes modificar tu propio rol.';
  end if;

  select academia_id, rol
    into v_miembro_academia_id, v_miembro_rol
    from public.profiles
    where id = p_miembro_id
    for update;

  if not found or v_miembro_academia_id <> v_actor_academia_id then
    raise exception 'El miembro no pertenece a tu academia.';
  end if;

  if v_miembro_rol not in ('alumno', 'profesor') then
    raise exception 'No se puede modificar el rol de este miembro.';
  end if;

  update public.profiles
    set rol = p_nuevo_rol
    where id = p_miembro_id;
end;
$$;

comment on function public.cambiar_rol_miembro(uuid, text) is
  'Permite al Dueño activo alternar Alumno/Profesor dentro de su academia.';

revoke all on function public.cambiar_rol_miembro(uuid, text)
  from public, anon;
grant execute on function public.cambiar_rol_miembro(uuid, text)
  to authenticated, service_role;
