-- Quién va a cada clase y fotos de perfil.
--
-- Los alumnos ven quién está apuntado a una clase de su sede: solo nombre y
-- foto, nunca fecha de nacimiento ni contactos. De los menores, solo el
-- nombre de pila.
--
-- Fotos: cubo privado "avatars". Cada usuario escribe solo en su carpeta
-- (<auth.uid()>/...). Las leen él mismo y los miembros de sus sedes.

-- ---------- Asistentes de una sesión ----------
create function public.session_attendees(p_session uuid)
returns table (profile_id uuid, display_name text, avatar_path text, is_me boolean)
language sql stable security definer set search_path = '' as $$
  select
    p.id,
    case
      when p.birth_date is not null and p.birth_date > (current_date - interval '18 years')::date
        then split_part(p.full_name, ' ', 1)
      else p.full_name
    end,
    p.avatar_path,
    p.id = public.current_profile_id()
  from public.bookings b
  join public.class_sessions s on s.id = b.session_id
  join public.profiles p on p.id = b.profile_id
  where b.session_id = p_session
    and b.status = 'booked'
    and public.has_role(s.gym_id, enum_range(null::public.gym_role))
  order by (p.id = public.current_profile_id()) desc, b.created_at
$$;
revoke execute on function public.session_attendees from public, anon;
grant execute on function public.session_attendees to authenticated;

-- ---------- ¿Comparte sede el usuario actual con este otro usuario? ----------
create function public.shares_gym_with_user(p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.gym_members me
    join public.gym_members them on them.gym_id = me.gym_id
    join public.profiles tp on tp.id = them.profile_id
    where me.profile_id = public.current_profile_id()
      and me.status = 'active'
      and tp.user_id = p_user
  )
$$;
revoke execute on function public.shares_gym_with_user from public, anon;
grant execute on function public.shares_gym_with_user to authenticated;

-- Carpeta del objeto como uuid (null si no lo es)
create function public.storage_owner_folder(p_name text) returns uuid
language sql immutable set search_path = '' as $$
  select case
    when split_part(p_name, '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then split_part(p_name, '/', 1)::uuid
  end
$$;

-- ---------- Cubo de fotos ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 2097152, array['image/jpeg', 'image/png', 'image/webp']);

create policy avatars_insert_own on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and public.storage_owner_folder(name) = (select auth.uid()));
create policy avatars_update_own on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and public.storage_owner_folder(name) = (select auth.uid()))
  with check (bucket_id = 'avatars' and public.storage_owner_folder(name) = (select auth.uid()));
create policy avatars_delete_own on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and public.storage_owner_folder(name) = (select auth.uid()));
create policy avatars_select_gym on storage.objects for select to authenticated
  using (
    bucket_id = 'avatars'
    and (
      public.storage_owner_folder(name) = (select auth.uid())
      or public.shares_gym_with_user(public.storage_owner_folder(name))
    )
  );

-- ---------- Solo puedes poner como foto un fichero de tu propia carpeta ----------
create or replace function public.protect_profile_user_id() returns trigger
language plpgsql as $$
begin
  if (select auth.uid()) is not null then
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
