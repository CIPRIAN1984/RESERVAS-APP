-- Solicitudes de tarifa: el alumno o su tutor piden; recepción las ve y al asignar quedan atendidas.
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into public.gyms (id, name) values ('ac000000-0000-4000-a000-000000000001', 'Sede P');
insert into public.plans (id, gym_id, slug, name, kind, price_cents, billing_period, sessions) values
  ('ac200000-0000-4000-a000-000000000001', 'ac000000-0000-4000-a000-000000000001', 'blue', 'Blue', 'membership', 6000, 'month', 12),
  ('ac200000-0000-4000-a000-000000000002', 'ac000000-0000-4000-a000-000000000001', 'black', 'Black', 'membership', 7000, 'month', 16);
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, jsonb_build_object('full_name', name), now(), now()
from (values
  ('ac900000-0000-4000-a000-000000000001'::uuid, 'p-desk@p.test', 'Recepción P'),
  ('ac900000-0000-4000-a000-000000000002'::uuid, 'p-madre@p.test', 'Madre P'),
  ('ac900000-0000-4000-a000-000000000003'::uuid, 'p-otro@p.test', 'Otro P')
) as u (id, email, name);
create temp table pid as select u.email, p.id from auth.users u join public.profiles p on p.user_id = u.id where u.email like 'p-%';
grant select on pid to authenticated;
insert into public.gym_members (gym_id, profile_id, role)
select 'ac000000-0000-4000-a000-000000000001', id, case when email = 'p-desk@p.test' then 'front_desk' else 'member' end::public.gym_role from pid;
insert into public.profiles (id, full_name, birth_date) values ('ac300000-0000-4000-a000-000000000001', 'Hijo P', current_date - interval '9 years');
insert into public.gym_members (gym_id, profile_id) values ('ac000000-0000-4000-a000-000000000001', 'ac300000-0000-4000-a000-000000000001');
insert into public.guardianships (gym_id, guardian_profile_id, minor_profile_id)
values ('ac000000-0000-4000-a000-000000000001', (select id from pid where email = 'p-madre@p.test'), 'ac300000-0000-4000-a000-000000000001');

create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

select pg_temp.login('p-madre@p.test');
select isnt(public.request_plan('ac200000-0000-4000-a000-000000000001'), null, 'la alumna pide Blue');
select isnt(public.request_plan('ac200000-0000-4000-a000-000000000002'), null, 'y cambia de idea: Black');
select is((select count(*)::int from public.plan_requests where profile_id = public.current_profile_id() and status = 'pending'), 1, 'solo queda una pendiente');
select lives_ok($$ select public.request_plan('ac200000-0000-4000-a000-000000000001', 'ac300000-0000-4000-a000-000000000001') $$, 'pide también para su hijo');
select pg_temp.login('p-otro@p.test');
select throws_ok($$ select public.request_plan('ac200000-0000-4000-a000-000000000001', 'ac300000-0000-4000-a000-000000000001') $$, '42501', null, 'otro alumno no pide por un menor ajeno');
select is((select count(*)::int from public.plan_requests), 0, 'y no ve las solicitudes de otros');
select is((select count(*)::int from public.pending_plan_requests('ac000000-0000-4000-a000-000000000001')), 0, 'un alumno no ve la lista de recepción');

select pg_temp.login('p-desk@p.test');
select is((select string_agg(plan_name || '·' || full_name, ', ' order by full_name) from public.pending_plan_requests('ac000000-0000-4000-a000-000000000001')),
  'Blue·Hijo P, Black·Madre P', 'recepción ve las dos pendientes');
select lives_ok($$ select public.assign_plan((select id from pid where email = 'p-madre@p.test'), 'ac200000-0000-4000-a000-000000000002') $$, 'recepción asigna Black');
select is((select count(*)::int from public.pending_plan_requests('ac000000-0000-4000-a000-000000000001')), 1, 'la solicitud de la madre queda atendida');

select * from finish();
rollback;
