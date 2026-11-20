-- Roles desde la app y "da clases".
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into public.gyms (id, name) values ('b5000000-0000-4000-a000-000000000001', 'Sede R2');
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, jsonb_build_object('full_name', name), now(), now()
from (values
  ('b5900000-0000-4000-a000-000000000001'::uuid, 'r2-owner@r.test', 'Dueña'),
  ('b5900000-0000-4000-a000-000000000002'::uuid, 'r2-admin@r.test', 'Admin'),
  ('b5900000-0000-4000-a000-000000000003'::uuid, 'r2-ana@r.test', 'Ana Profe')
) as u (id, email, name);
create temp table pid as select u.email, p.id from auth.users u join public.profiles p on p.user_id = u.id where u.email like 'r2-%';
grant select on pid to authenticated;
insert into public.gym_members (gym_id, profile_id, role)
select 'b5000000-0000-4000-a000-000000000001', id,
  case email when 'r2-owner@r.test' then 'owner' when 'r2-admin@r.test' then 'admin' else 'member' end::public.gym_role from pid;
insert into public.profiles (id, full_name, birth_date) values ('b5300000-0000-4000-a000-000000000001', 'Peque', current_date - interval '10 years');
insert into public.gym_members (gym_id, profile_id) values ('b5000000-0000-4000-a000-000000000001', 'b5300000-0000-4000-a000-000000000001');

create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

select pg_temp.login('r2-admin@r.test');
select throws_ok($$ select public.set_member_role('b5000000-0000-4000-a000-000000000001', (select id from pid where email = 'r2-ana@r.test'), 'coach') $$,
  '42501', null, 'administración no cambia roles');

select pg_temp.login('r2-owner@r.test');
select lives_ok($$ select public.set_member_role('b5000000-0000-4000-a000-000000000001', (select id from pid where email = 'r2-ana@r.test'), 'coach') $$,
  'la propietaria hace profesora a Ana');
select is((select teaches from public.staff_directory where full_name = 'Ana Profe'), true, 'Ana aparece como monitora');
select throws_ok($$ select public.set_member_role('b5000000-0000-4000-a000-000000000001', 'b5300000-0000-4000-a000-000000000001', 'coach') $$,
  '22023', null, 'un menor sin cuenta no puede ser del personal');
select throws_ok($$ select public.set_member_role('b5000000-0000-4000-a000-000000000001', (select id from pid where email = 'r2-owner@r.test'), 'admin') $$,
  'P0001', null, 'la única propietaria no puede quitarse el rol');
select lives_ok($$ select public.set_member_role('b5000000-0000-4000-a000-000000000001', (select id from pid where email = 'r2-owner@r.test'), null, true) $$,
  'la propietaria marca que también da clases');
select is((select teaches from public.staff_directory where full_name = 'Dueña'), true, 'y aparece como monitora sin dejar de ser propietaria');
select is((select role::text from public.staff_directory where full_name = 'Dueña'), 'owner', 'sigue siendo propietaria');
select lives_ok($$ select public.set_member_role('b5000000-0000-4000-a000-000000000001', (select id from pid where email = 'r2-ana@r.test'), 'member') $$,
  'Ana vuelve a ser alumna');
reset role;
select is((select count(*)::int from public.audit_log where gym_id = 'b5000000-0000-4000-a000-000000000001' and action in ('role_change', 'teaches')), 3,
  'los cambios quedan en auditoría');

select * from finish();
rollback;
