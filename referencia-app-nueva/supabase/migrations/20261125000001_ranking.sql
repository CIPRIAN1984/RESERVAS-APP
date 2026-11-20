-- Fase 5 del plan de mejora · Estadísticas: ranking de asistencia.
--
-- El ranking muestra nombre, foto, cinturón y clases de los miembros de la
-- sede en un periodo. Cada uno puede ocultarse (profiles.hide_from_ranking).
-- Los menores no aparecen nunca. Solo lo ven los miembros activos de la sede.

alter table public.profiles add column hide_from_ranking boolean not null default false;

create function public.gym_ranking(p_gym uuid, p_from date, p_to date, p_limit integer default 50)
returns table (
  rank_position integer, profile_id uuid, display_name text, avatar_path text,
  belt public.belt, stripes smallint, classes integer, is_me boolean
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_tz text;
begin
  if not exists (
    select 1 from public.gym_members m
    where m.gym_id = p_gym and m.profile_id = public.current_profile_id() and m.status = 'active'
  ) then
    raise exception 'No perteneces a esta sede' using errcode = '42501';
  end if;
  if p_to < p_from or p_to - p_from > 400 then
    raise exception 'Periodo no válido' using errcode = '22023';
  end if;
  select g.time_zone into v_tz from public.gyms g where g.id = p_gym;

  return query
  with counts as (
    select a.profile_id, count(*)::int as n
    from public.attendances a
    where a.gym_id = p_gym and a.voided_at is null
      and a.checked_in_at >= (p_from::timestamp at time zone v_tz)
      and a.checked_in_at < ((p_to + 1)::timestamp at time zone v_tz)
    group by a.profile_id
  ),
  ranked as (
    select
      rank() over (order by c.n desc)::int as pos,
      p.id, p.full_name, p.avatar_path, c.n
    from counts c
    join public.profiles p on p.id = c.profile_id
    join public.gym_members m on m.profile_id = p.id and m.gym_id = p_gym and m.status = 'active'
    where not p.hide_from_ranking
      and p.full_name <> 'Usuario eliminado'
      and (p.birth_date is null or p.birth_date <= (current_date - interval '18 years')::date)
  )
  select r.pos, r.id, r.full_name, r.avatar_path, cr.belt, cr.stripes, r.n, r.id = public.current_profile_id()
  from ranked r
  -- Cinturón actual (última graduación). El ranking lo muestra a todos los miembros,
  -- por eso no usa current_rank, que solo lo enseña al propio alumno y al personal.
  left join lateral (
    select pr.belt, pr.stripes from public.promotions pr
    where pr.profile_id = r.id and pr.gym_id = p_gym
    order by pr.promoted_at desc, pr.created_at desc
    limit 1
  ) cr on true
  where r.pos <= p_limit or r.id = public.current_profile_id()
  order by r.pos, r.full_name;
end $$;

revoke execute on function public.gym_ranking from public, anon;
grant execute on function public.gym_ranking to authenticated;
