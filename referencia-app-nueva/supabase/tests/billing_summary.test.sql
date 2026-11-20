-- Cobros: previsto del mes a partir de las tarifas asignadas.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into public.gyms (id, name) values ('ae000000-0000-4000-a000-000000000001', 'Sede C');
insert into public.plans (id, gym_id, slug, name, kind, price_cents, billing_period, sessions, auto_renew, validity_months, is_addon) values
  ('ae200000-0000-4000-a000-000000000001', 'ae000000-0000-4000-a000-000000000001', 'blue', 'Blue', 'membership', 6000, 'month', 12, true, null, false),
  ('ae200000-0000-4000-a000-000000000002', 'ae000000-0000-4000-a000-000000000001', 'anual', 'Anual', 'membership', 30000, 'year', 8, false, 12, false),
  ('ae200000-0000-4000-a000-000000000003', 'ae000000-0000-4000-a000-000000000001', 'plus', 'ITACA+', 'membership', 500, 'month', null, true, null, true);
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, jsonb_build_object('full_name', name), now(), now()
from (values
  ('ae900000-0000-4000-a000-000000000001'::uuid, 'c-desk@c.test', 'Recepción C'),
  ('ae900000-0000-4000-a000-000000000002'::uuid, 'c-a@c.test', 'Alumno A'),
  ('ae900000-0000-4000-a000-000000000003'::uuid, 'c-b@c.test', 'Alumno B'),
  ('ae900000-0000-4000-a000-000000000004'::uuid, 'c-c@c.test', 'Alumno C')
) as u (id, email, name);
create temp table pid as select u.email, p.id from auth.users u join public.profiles p on p.user_id = u.id where u.email like 'c-%';
grant select on pid to authenticated;
insert into public.gym_members (gym_id, profile_id, role)
select 'ae000000-0000-4000-a000-000000000001', id, case when email = 'c-desk@c.test' then 'front_desk' else 'member' end::public.gym_role from pid;

create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

select pg_temp.login('c-desk@c.test');
select public.assign_plan((select id from pid where email = 'c-a@c.test'), 'ae200000-0000-4000-a000-000000000001', date_trunc('month', current_date)::date);
select public.assign_plan((select id from pid where email = 'c-a@c.test'), 'ae200000-0000-4000-a000-000000000003', date_trunc('month', current_date)::date);
select public.assign_plan((select id from pid where email = 'c-b@c.test'), 'ae200000-0000-4000-a000-000000000002', date_trunc('month', current_date)::date);
create temp table r as select public.gym_billing_summary('ae000000-0000-4000-a000-000000000001') as j;

select is(((select j from r) ->> 'expected_cents')::int, 6000 + 500 + 2500, 'previsto: Blue 60 € + ITACA+ 5 € + anual 300/12 = 25 €');
select is(((select j from r) ->> 'with_plan')::int, 2, 'dos alumnos con tarifa (ITACA+ no cuenta como tarifa)');
select is(((select j from r) ->> 'without_plan')::int, 1, 'uno sin tarifa');
select is(((select j from r) ->> 'members')::int, 3, 'tres alumnos (recepción no cuenta)');
select is(((select j from r) ->> 'new')::int, 2, 'dos altas este mes');
select is((select (x ->> 'people')::int from jsonb_array_elements((select j from r) -> 'by_plan') x where x ->> 'plan' = 'Blue'), 1, 'desglose por tarifa');
select is((select (x ->> 'addon')::boolean from jsonb_array_elements((select j from r) -> 'by_plan') x where x ->> 'plan' = 'ITACA+'), true, 'ITACA+ marcado como complemento');
select is((select x -> 'members' -> 0 ->> 'name' from jsonb_array_elements((select j from r) -> 'by_plan') x where x ->> 'plan' = 'Blue'), 'Alumno A', 'cada tarifa lista a sus personas');

select pg_temp.login('c-a@c.test');
select throws_ok($$ select public.gym_billing_summary('ae000000-0000-4000-a000-000000000001') $$, '42501', null, 'un alumno no ve los cobros');

select * from finish();
rollback;
