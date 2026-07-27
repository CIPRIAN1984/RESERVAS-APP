-- Bootstrap controlado del primer Administrador de plataforma.
--
-- El registro público nunca acepta el rol Administrador. El primer usuario se
-- crea desde Auth con su correo ya confirmado y, después, esta función se
-- ejecuta desde un contexto de confianza (SQL Editor o service_role).
--
-- La exclusión mutua evita que dos solicitudes concurrentes creen dos
-- administradores. Una vez que existe el primero, la función queda cerrada de
-- forma permanente salvo que ese perfil se elimine de manera explícita.

create or replace function public.bootstrap_initial_admin(
  p_user_id uuid,
  p_nombre text,
  p_apellidos text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_nombre text := nullif(trim(p_nombre), '');
  v_apellidos text := nullif(trim(p_apellidos), '');
begin
  -- Una única transacción puede comprobar y crear el primer administrador.
  perform pg_advisory_xact_lock(
    hashtextextended('reservas.bootstrap_initial_admin', 0)
  );

  if exists (
    select 1
    from public.profiles
    where rol = 'administrador'
  ) then
    raise exception 'El administrador inicial ya existe.';
  end if;

  if v_nombre is null then
    raise exception 'El nombre del administrador es obligatorio.';
  end if;

  if not exists (
    select 1
    from auth.users
    where id = p_user_id
      and email is not null
      and email_confirmed_at is not null
      and deleted_at is null
      and coalesce(is_anonymous, false) = false
  ) then
    raise exception
      'El usuario no existe, no tiene correo confirmado o no es elegible.';
  end if;

  if exists (
    select 1
    from public.profiles
    where id = p_user_id
  ) then
    raise exception 'El usuario seleccionado ya tiene un perfil.';
  end if;

  insert into public.profiles (
    id,
    academia_id,
    rol,
    nombre,
    apellidos,
    estado
  )
  values (
    p_user_id,
    null,
    'administrador',
    v_nombre,
    v_apellidos,
    'activo'
  );

  return p_user_id;
end;
$$;

comment on function public.bootstrap_initial_admin(uuid, text, text) is
  'Crea exactamente el primer Administrador desde un usuario Auth confirmado; '
  'solo invocable por contextos de confianza.';

revoke all on function public.bootstrap_initial_admin(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.bootstrap_initial_admin(uuid, text, text)
  to service_role;
