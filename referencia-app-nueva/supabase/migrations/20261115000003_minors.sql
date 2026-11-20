-- Paso 1 · Menores bajo la cuenta de un tutor.
-- En España el consentimiento propio vale desde los 14 años; por debajo,
-- el menor no tiene cuenta y lo gestiona el perfil del tutor.

create function public.add_minor(p_gym uuid, p_full_name text, p_birth_date date)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_guardian uuid := public.current_profile_id();
  v_minor uuid;
begin
  if v_guardian is null then
    raise exception 'Hace falta iniciar sesión' using errcode = '42501';
  end if;
  if not public.has_role(p_gym, enum_range(null::public.gym_role)) then
    raise exception 'No perteneces a esta sede' using errcode = '42501';
  end if;
  if p_birth_date is null or p_birth_date > current_date then
    raise exception 'Fecha de nacimiento no válida' using errcode = '22023';
  end if;
  if p_birth_date <= (current_date - interval '18 years')::date then
    raise exception 'Solo se pueden añadir menores de 18 años' using errcode = '22023';
  end if;
  if length(trim(coalesce(p_full_name, ''))) = 0 then
    raise exception 'Falta el nombre' using errcode = '22023';
  end if;

  insert into public.profiles (full_name, birth_date)
  values (trim(p_full_name), p_birth_date)
  returning id into v_minor;

  insert into public.gym_members (gym_id, profile_id, role) values (p_gym, v_minor, 'member');
  insert into public.guardianships (gym_id, guardian_profile_id, minor_profile_id)
  values (p_gym, v_guardian, v_minor);

  return v_minor;
end $$;

revoke execute on function public.add_minor from public, anon;
grant execute on function public.add_minor to authenticated;
