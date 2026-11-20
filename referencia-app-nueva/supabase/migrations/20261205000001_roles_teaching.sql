-- Roles desde la app y "da clases".
--  · Solo el propietario cambia roles (el trigger guard_role_change ya lo exige
--    y lo deja en auditoría). Nunca puede quedarse la sede sin propietario.
--  · Los menores y las personas sin cuenta solo pueden ser alumnos.
--  · "Da clases" (teaches): un propietario o administración que también
--    enseña aparece como monitor sin perder su rol. Los profesores, siempre.

alter table public.gym_members add column teaches boolean not null default false;

create or replace view public.staff_directory
with (security_barrier = true) as
select m.gym_id, p.id as profile_id, p.full_name, m.role, (m.role = 'coach' or m.teaches) as teaches
from public.gym_members m
join public.profiles p on p.id = m.profile_id
where m.status = 'active'
  and m.role in ('owner', 'admin', 'coach')
  and public.has_role(m.gym_id, enum_range(null::public.gym_role));

create function public.set_member_role(p_gym uuid, p_profile uuid, p_role public.gym_role default null, p_teaches boolean default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_m public.gym_members%rowtype;
  v_p public.profiles%rowtype;
  v_role public.gym_role;
begin
  select * into v_m from public.gym_members where gym_id = p_gym and profile_id = p_profile;
  if not found then
    raise exception 'La persona no es miembro de la sede' using errcode = 'P0002';
  end if;
  select * into v_p from public.profiles where id = p_profile;
  v_role := coalesce(p_role, v_m.role);

  if v_role is distinct from v_m.role then
    if not public.has_role(p_gym, array['owner']::public.gym_role[]) then
      raise exception 'Solo el propietario cambia roles' using errcode = '42501';
    end if;
    if v_role <> 'member' and (v_p.user_id is null or (v_p.birth_date is not null and v_p.birth_date > (current_date - interval '18 years')::date)) then
      raise exception 'Solo una persona adulta con cuenta en la app puede ser del personal' using errcode = '22023', hint = 'not_eligible';
    end if;
    if v_m.role = 'owner' and v_role <> 'owner' and not exists (
      select 1 from public.gym_members o where o.gym_id = p_gym and o.role = 'owner' and o.status = 'active' and o.profile_id <> p_profile
    ) then
      raise exception 'La sede no puede quedarse sin propietario: nombra antes a otro' using errcode = 'P0001', hint = 'last_owner';
    end if;
  end if;

  if p_teaches is not null and p_teaches is distinct from v_m.teaches
     and not public.has_role(p_gym, array['owner', 'admin']::public.gym_role[]) then
    raise exception 'Solo propietario y administración marcan quién da clases' using errcode = '42501';
  end if;

  update public.gym_members
  set role = v_role,
      status = case when v_role <> 'member' then 'active' else status end,
      teaches = case when v_role in ('owner', 'admin') then coalesce(p_teaches, teaches) else false end
  where id = v_m.id;

  if p_teaches is not null and p_teaches is distinct from v_m.teaches then
    insert into public.audit_log (gym_id, actor_user_id, table_name, row_id, action, old_data, new_data)
    values (p_gym, (select auth.uid()), 'gym_members', v_m.id, 'teaches',
            jsonb_build_object('teaches', v_m.teaches), jsonb_build_object('teaches', p_teaches));
  end if;
end $$;
revoke execute on function public.set_member_role from public, anon;
grant execute on function public.set_member_role to authenticated;
