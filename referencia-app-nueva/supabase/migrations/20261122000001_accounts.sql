-- Fase 3 del plan de mejora · Cuentas: registro con contraseña, alta
-- pendiente de aprobación y eliminación de la cuenta.
--
-- Cualquiera puede registrarse, pero su alta queda PENDIENTE (miembro
-- inactivo) hasta que recepción o administración la activen. Así nadie de
-- fuera ve quién va a las clases. Si la sede pone settings.auto_approve_members
-- = true, el alta queda activa directamente.

-- Une al usuario actual a la sede (la única hoy) si aún no pertenece a ninguna
create function public.join_default_gym() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_profile uuid := public.current_profile_id();
  v_gym public.gyms%rowtype;
  v_status public.member_status;
begin
  if v_profile is null then
    raise exception 'Hace falta iniciar sesión' using errcode = '42501';
  end if;
  if exists (select 1 from public.gym_members where profile_id = v_profile) then
    return (select jsonb_build_object('gym_id', gym_id, 'status', status, 'already', true)
            from public.gym_members where profile_id = v_profile order by created_at limit 1);
  end if;
  select * into v_gym from public.gyms order by created_at limit 1;
  if not found then
    raise exception 'No hay ninguna sede' using errcode = 'P0002';
  end if;
  v_status := case when coalesce((v_gym.settings ->> 'auto_approve_members')::boolean, false) then 'active' else 'inactive' end;
  insert into public.gym_members (gym_id, profile_id, role, status) values (v_gym.id, v_profile, 'member', v_status);
  return jsonb_build_object('gym_id', v_gym.id, 'status', v_status, 'already', false);
end $$;

-- Estado de mi alta en mi sede (para la pantalla "pendiente de activar")
create function public.my_membership_status() returns table (gym_id uuid, gym_name text, role public.gym_role, status public.member_status)
language sql stable security definer set search_path = '' as $$
  select m.gym_id, g.name, m.role, m.status
  from public.gym_members m join public.gyms g on g.id = m.gym_id
  where m.profile_id = public.current_profile_id()
  order by m.created_at
$$;

-- La protección del perfil admite una excepción: la eliminación de la propia
-- cuenta (al borrar el usuario, la base desvincula el perfil)
create or replace function public.protect_profile_user_id() returns trigger
language plpgsql as $$
begin
  if (select auth.uid()) is not null and coalesce(current_setting('itaca.deleting_account', true), '') <> 'on' then
    if new.user_id is distinct from old.user_id then
      raise exception 'No se puede cambiar la cuenta asociada a un perfil' using errcode = '42501';
    end if;
    if new.avatar_path is distinct from old.avatar_path
       and new.avatar_path is not null
       and public.storage_owner_folder(new.avatar_path) is distinct from (select auth.uid()) then
      raise exception 'La foto debe estar en tu propia carpeta' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

-- Eliminar mi cuenta (RGPD): se anonimiza el perfil (la asistencia y los
-- cobros quedan para las estadísticas, sin nombre), se cancelan las reservas
-- futuras y se borra el usuario de acceso.
create function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_profile uuid := public.current_profile_id();
begin
  if v_uid is null or v_profile is null then
    raise exception 'Hace falta iniciar sesión' using errcode = '42501';
  end if;
  -- El último propietario de una sede no puede irse sin dejar a otro
  if exists (
    select 1 from public.gym_members m
    where m.profile_id = v_profile and m.role = 'owner' and m.status = 'active'
      and not exists (
        select 1 from public.gym_members o
        where o.gym_id = m.gym_id and o.role = 'owner' and o.status = 'active' and o.profile_id <> v_profile
      )
  ) then
    raise exception 'Eres el único propietario: nombra antes a otro propietario' using errcode = 'P0001', hint = 'last_owner';
  end if;

  update public.bookings b set status = 'cancelled', cancelled_at = now()
  from public.class_sessions s
  where b.session_id = s.id and b.profile_id = v_profile and b.status in ('booked', 'waitlist') and s.starts_at > now();

  update public.gym_members set status = 'inactive' where profile_id = v_profile;
  update public.profiles set
    full_name = 'Usuario eliminado', birth_date = null, phone = null,
    emergency_contact_name = null, emergency_contact_phone = null, avatar_path = null
  where id = v_profile;

  perform set_config('itaca.deleting_account', 'on', true);
  delete from auth.users where id = v_uid;
  perform set_config('itaca.deleting_account', '', true);
end $$;

revoke execute on function public.join_default_gym, public.my_membership_status, public.delete_my_account from public, anon;
grant execute on function public.join_default_gym, public.my_membership_status, public.delete_my_account to authenticated;
