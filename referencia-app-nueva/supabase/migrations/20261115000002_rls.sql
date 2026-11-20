-- Paso 1 · Permisos por rol con seguridad a nivel de fila (RLS).
--
--   Alumno:      su perfil y los de sus menores; sus filas de miembro.
--   Profesor:    además, los alumnos de su sede (perfiles, miembros, tutores).
--   Recepción:   como profesor, y da de alta alumnos y edita sus datos.
--   Admin:       todo lo de su sede salvo cambiar roles.
--   Propietario: todo lo de su sede; es el único que gestiona roles.
--
-- Las funciones de ayuda son SECURITY DEFINER para que las políticas no se
-- llamen a sí mismas en bucle al consultar gym_members.

-- ---------- Funciones de ayuda ----------

create function public.current_profile_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select p.id from public.profiles p where p.user_id = (select auth.uid())
$$;

-- ¿Tiene el usuario actual alguno de estos roles, activo, en la sede?
create function public.has_role(p_gym uuid, p_roles public.gym_role[]) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.gym_members m
    where m.gym_id = p_gym
      and m.profile_id = public.current_profile_id()
      and m.status = 'active'
      and m.role = any (p_roles)
  )
$$;

create function public.is_staff(p_gym uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.has_role(p_gym, array['owner', 'admin', 'coach', 'front_desk']::public.gym_role[])
$$;

create function public.is_guardian_of(p_minor uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.guardianships g
    where g.minor_profile_id = p_minor
      and g.guardian_profile_id = public.current_profile_id()
  )
$$;

-- ¿Es la persona miembro de alguna sede donde el usuario actual tiene uno de estos roles?
create function public.manages_profile(p_profile uuid, p_roles public.gym_role[]) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.gym_members target
    join public.gym_members me on me.gym_id = target.gym_id
    where target.profile_id = p_profile
      and me.profile_id = public.current_profile_id()
      and me.status = 'active'
      and me.role = any (p_roles)
  )
$$;

revoke execute on function public.current_profile_id, public.has_role, public.is_staff,
  public.is_guardian_of, public.manages_profile from public, anon;
grant execute on function public.current_profile_id, public.has_role, public.is_staff,
  public.is_guardian_of, public.manages_profile to authenticated;

-- ---------- Activar RLS ----------
alter table public.gyms enable row level security;
alter table public.profiles enable row level security;
alter table public.gym_members enable row level security;
alter table public.guardianships enable row level security;
alter table public.audit_log enable row level security;

-- Nada para usuarios anónimos
revoke all on public.gyms, public.profiles, public.gym_members, public.guardianships, public.audit_log from anon;

-- ---------- gyms ----------
create policy gyms_select on public.gyms for select to authenticated
  using (public.has_role(id, enum_range(null::public.gym_role)));

create policy gyms_update on public.gyms for update to authenticated
  using (public.has_role(id, array['owner', 'admin']::public.gym_role[]))
  with check (public.has_role(id, array['owner', 'admin']::public.gym_role[]));
-- Alta y baja de sedes: solo con la clave de servicio.

-- ---------- profiles ----------
create policy profiles_select on public.profiles for select to authenticated
  using (
    user_id = (select auth.uid())
    or public.is_guardian_of(id)
    or public.manages_profile(id, array['owner', 'admin', 'coach', 'front_desk']::public.gym_role[])
  );

create policy profiles_update on public.profiles for update to authenticated
  using (
    user_id = (select auth.uid())
    or public.is_guardian_of(id)
    or public.manages_profile(id, array['owner', 'admin', 'front_desk']::public.gym_role[])
  );
-- (Sin WITH CHECK propio: se aplica el mismo USING a la fila nueva.)

-- Nadie cambia a qué cuenta pertenece un perfil desde el cliente
create function public.protect_profile_user_id() returns trigger
language plpgsql as $$
begin
  if new.user_id is distinct from old.user_id and (select auth.uid()) is not null then
    raise exception 'No se puede cambiar la cuenta asociada a un perfil' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger profiles_protect_user_id before update on public.profiles
  for each row execute function public.protect_profile_user_id();
-- Alta de perfiles: al registrarse (trigger) o con add_minor; borrado solo con la clave de servicio.

-- ---------- gym_members ----------
create policy gym_members_select on public.gym_members for select to authenticated
  using (
    profile_id = public.current_profile_id()
    or public.is_guardian_of(profile_id)
    or public.is_staff(gym_id)
  );

-- Recepción y admin dan de alta alumnos; solo el propietario da otros roles
create policy gym_members_insert on public.gym_members for insert to authenticated
  with check (
    public.has_role(gym_id, array['owner']::public.gym_role[])
    or (role = 'member' and public.has_role(gym_id, array['admin', 'front_desk']::public.gym_role[]))
  );

create policy gym_members_update on public.gym_members for update to authenticated
  using (public.has_role(gym_id, array['owner', 'admin', 'front_desk']::public.gym_role[]))
  with check (public.has_role(gym_id, array['owner', 'admin', 'front_desk']::public.gym_role[]));

create policy gym_members_delete on public.gym_members for delete to authenticated
  using (public.has_role(gym_id, array['owner']::public.gym_role[]));

-- Cambiar un rol: solo el propietario, y queda en el registro de auditoría
create function public.guard_role_change() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.role is distinct from old.role then
    if (select auth.uid()) is not null
       and not public.has_role(old.gym_id, array['owner']::public.gym_role[]) then
      raise exception 'Solo el propietario puede cambiar roles' using errcode = '42501';
    end if;
    insert into public.audit_log (gym_id, actor_user_id, table_name, row_id, action, old_data, new_data)
    values (old.gym_id, (select auth.uid()), 'gym_members', old.id, 'role_change',
            jsonb_build_object('role', old.role), jsonb_build_object('role', new.role));
  end if;
  if new.gym_id is distinct from old.gym_id or new.profile_id is distinct from old.profile_id then
    raise exception 'No se puede mover un miembro a otra sede o persona' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger gym_members_guard_role before update on public.gym_members
  for each row execute function public.guard_role_change();

-- ---------- guardianships ----------
create policy guardianships_select on public.guardianships for select to authenticated
  using (
    guardian_profile_id = public.current_profile_id()
    or minor_profile_id = public.current_profile_id()
    or public.is_staff(gym_id)
  );

create policy guardianships_insert on public.guardianships for insert to authenticated
  with check (public.has_role(gym_id, array['owner', 'admin', 'front_desk']::public.gym_role[]));

create policy guardianships_delete on public.guardianships for delete to authenticated
  using (public.has_role(gym_id, array['owner', 'admin', 'front_desk']::public.gym_role[]));

-- ---------- audit_log ----------
create policy audit_log_select on public.audit_log for select to authenticated
  using (public.has_role(gym_id, array['owner', 'admin']::public.gym_role[]));
-- Sin políticas de escritura: solo escriben los triggers.
