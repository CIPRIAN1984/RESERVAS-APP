-- Sección Tarifas: resumen por alumno, solicitudes pendientes y rechazar.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into public.gyms (id, name) values ('af000000-0000-4000-a000-000000000001', 'Sede T');
insert into public.plans (id, gym_id, slug, name, kind, price_cents, billing_period, sessions, auto_renew, is_addon) values
  ('af200000-0000-4000-a000-000000000001', 'af000000-0000-4000-a000-000000000001', 'blue', 'Blue', 'membership', 6000, 'month', 12, true, false),
  ('af200000-0000-4000-a000-000000000002', 'af000000-0000-4000-a000-000000000001', 'black', 'Black', 'membership', 7000, 'month', 16, true, false),
  ('af200000-0000-4000-a000-000000000003', 'af000000-0000-4000-a000-000000000001', 'plus', 'ITACA+', 'membership', 500, 'month', null, true, true);
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, jsonb_build_object('full_name', name), now(), now()
from (values
  ('af900000-0000-4000-a000-000000000001'::uuid, 't-desk@t.test', 'Recepción T'),
  ('af900000-0000-4000-a000-000000000002'::uuid, 't-ana@t.test', 'Ana T'),
  ('af900000-0000-4000-a000-000000000003'::uuid, 't-bea@t.test', 'Bea T')
) as u (id, email, name);
create temp table pid as select u.email, p.id from auth.users u join public.profiles p on p.user_id = u.id where u.email like 't-%';
grant select on pid to authenticated;
insert into public.gym_members (gym_id, profile_id, role)
select 'af000000-0000-4000-a000-000000000001', id, case when email = 't-desk@t.test' then 'front_desk' else 'member' end::public.gym_role from pid;

create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

select pg_temp.login('t-desk@t.test');
select public.assign_plan((select id from pid where email = 't-ana@t.test'), 'af200000-0000-4000-a000-000000000001');
select public.assign_plan((select id from pid where email = 't-ana@t.test'), 'af200000-0000-4000-a000-000000000003');
select pg_temp.login('t-ana@t.test');
select public.request_plan('af200000-0000-4000-a000-000000000002');
select pg_temp.login('t-bea@t.test');
select public.request_plan('af200000-0000-4000-a000-000000000001');

select pg_temp.login('t-desk@t.test');
create temp table o as select * from public.staff_plan_overview('af000000-0000-4000-a000-000000000001');
select is((select plan_name from o where full_name = 'Ana T'), 'Blue', 'resumen: Ana tiene Blue');
select is((select has_plus from o where full_name = 'Ana T'), true, 'y ITACA+ activo');
select is((select pending_plan from o where full_name = 'Ana T'), 'Black', 'y ha pedido Black');
select is((select plan_name from o where full_name = 'Bea T'), null, 'Bea sin tarifa');
select is((select role::text from o where full_name = 'Recepción T'), 'front_desk', 'incluye al personal con su rol');
select is((select current_plan from public.pending_plan_requests('af000000-0000-4000-a000-000000000001') where full_name = 'Ana T'), 'Blue',
  'la solicitud muestra la tarifa actual (para ver si es una mejora)');
select lives_ok($$ select public.reject_plan_request((select id from public.plan_requests where profile_id = (select id from pid where email = 't-bea@t.test') and status = 'pending'), 'Pásate a hablar') $$,
  'recepción rechaza con motivo');
select is((select count(*)::int from public.pending_plan_requests('af000000-0000-4000-a000-000000000001')), 1, 'queda una pendiente');

select pg_temp.login('t-ana@t.test');
select throws_ok($$ select * from public.staff_plan_overview('af000000-0000-4000-a000-000000000001') $$, '42501', null, 'un alumno no ve el resumen');

select * from finish();
rollback;
