-- Fase 8 · Cobros con datos reales: lo previsto del mes según las tarifas que
-- asigna recepción. Aún no hay registro de pagos (llegará con el pago con
-- tarjeta), así que no se muestra "cobrado".
--
-- Previsto al mes por tarifa: mensual = precio; trimestral = precio / 3;
-- anual = precio / 12; bonos y pases = precio si empiezan ese mes.

create function public.gym_billing_summary(p_gym uuid, p_month date default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_tz text;
  v_from date;
  v_to date;
  v_by_plan jsonb;
  v_total bigint;
  v_with_plan int;
  v_members int;
  v_new int;
  v_ended int;
  v_requests int;
begin
  if not public.has_role(p_gym, array['owner', 'admin', 'front_desk']::public.gym_role[]) then
    raise exception 'Solo recepción y administración ven los cobros' using errcode = '42501';
  end if;
  select g.time_zone into v_tz from public.gyms g where g.id = p_gym;
  v_from := date_trunc('month', coalesce(p_month, (now() at time zone v_tz)::date))::date;
  v_to := (v_from + interval '1 month' - interval '1 day')::date;

  with active as (
    select mp.profile_id, pl.id as plan_id, pl.name, pl.is_addon, pl.price_cents, pl.billing_period, pl.kind, mp.starts_on, pl.sort
    from public.member_plans mp
    join public.plans pl on pl.id = mp.plan_id
    join public.gym_members m on m.profile_id = mp.profile_id and m.gym_id = p_gym and m.status = 'active'
    where mp.gym_id = p_gym and mp.starts_on <= v_to and (mp.ends_on is null or mp.ends_on >= v_from)
  ), priced as (
    select a.*,
      case
        when a.kind in ('pack', 'drop_in') or a.billing_period = 'once' then case when a.starts_on between v_from and v_to then a.price_cents else 0 end
        when a.billing_period = 'quarter' then a.price_cents / 3
        when a.billing_period = 'year' then a.price_cents / 12
        else a.price_cents
      end as monthly_cents
    from active a
  )
  select
    coalesce(jsonb_agg(jsonb_build_object('plan', name, 'people', people, 'expected_cents', cents, 'addon', is_addon) order by is_addon, cents desc, name), '[]'::jsonb),
    coalesce(sum(cents), 0)
  into v_by_plan, v_total
  from (
    select name, is_addon, min(sort) as sort, count(distinct profile_id)::int as people, sum(monthly_cents)::bigint as cents
    from priced group by plan_id, name, is_addon
  ) x;

  select count(distinct mp.profile_id)::int into v_with_plan
  from public.member_plans mp join public.plans pl on pl.id = mp.plan_id and not pl.is_addon
  join public.gym_members m on m.profile_id = mp.profile_id and m.gym_id = p_gym and m.status = 'active'
  where mp.gym_id = p_gym and mp.starts_on <= v_to and (mp.ends_on is null or mp.ends_on >= v_from);

  select count(*)::int into v_members from public.gym_members m
  join public.profiles p on p.id = m.profile_id
  where m.gym_id = p_gym and m.status = 'active' and m.role = 'member' and p.full_name <> 'Usuario eliminado';

  select count(*)::int into v_new from public.member_plans mp join public.plans pl on pl.id = mp.plan_id and not pl.is_addon
  where mp.gym_id = p_gym and mp.starts_on between v_from and v_to
    and not exists (select 1 from public.member_plans prev join public.plans pp on pp.id = prev.plan_id and not pp.is_addon
                    where prev.profile_id = mp.profile_id and prev.gym_id = p_gym and prev.starts_on < mp.starts_on and prev.ends_on >= mp.starts_on - 1);
  select count(*)::int into v_ended from public.member_plans mp join public.plans pl on pl.id = mp.plan_id and not pl.is_addon
  where mp.gym_id = p_gym and mp.ends_on between v_from and v_to
    and not exists (select 1 from public.member_plans nxt join public.plans np on np.id = nxt.plan_id and not np.is_addon
                    where nxt.profile_id = mp.profile_id and nxt.gym_id = p_gym and nxt.starts_on = mp.ends_on + 1);
  select count(*)::int into v_requests from public.plan_requests r where r.gym_id = p_gym and r.status = 'pending';

  return jsonb_build_object(
    'month', v_from, 'expected_cents', v_total, 'by_plan', v_by_plan,
    'with_plan', v_with_plan, 'members', v_members, 'without_plan', greatest(0, v_members - v_with_plan),
    'new', v_new, 'ended', v_ended, 'pending_requests', v_requests);
end $$;
revoke execute on function public.gym_billing_summary from public, anon;
grant execute on function public.gym_billing_summary to authenticated;
