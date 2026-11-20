-- Pruebas de add_minor: un tutor da de alta a un menor sin cuenta.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into public.gyms (id, name) values
  ('c0000000-0000-4000-a000-000000000001', 'Sede C'),
  ('d0000000-0000-4000-a000-000000000001', 'Sede D');
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('00000000-0000-0000-0000-000000000000', 'c1000000-0000-4000-a000-000000000001', 'authenticated', 'authenticated', 'm-tutor@c.test', '{"full_name":"Tutor C"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'c1000000-0000-4000-a000-000000000002', 'authenticated', 'authenticated', 'm-otro@c.test',  '{"full_name":"Otro C"}',  now(), now());
insert into public.gym_members (gym_id, profile_id)
select 'c0000000-0000-4000-a000-000000000001', p.id from public.profiles p
where p.user_id in ('c1000000-0000-4000-a000-000000000001', 'c1000000-0000-4000-a000-000000000002');

create function pg_temp.login(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

select pg_temp.login('c1000000-0000-4000-a000-000000000001');

select lives_ok(
  $$ select public.add_minor('c0000000-0000-4000-a000-000000000001', 'Hija de Tutor', current_date - 3000) $$,
  'el tutor añade a su hija de 8 años'
);
select is((select count(*)::int from public.profiles where full_name = 'Hija de Tutor' and user_id is null), 1, 'el menor no tiene cuenta propia');
select is((select count(*)::int from public.guardianships), 1, 'queda registrada la tutela');
select is((select count(*)::int from public.gym_members where profile_id = (select id from public.profiles where full_name = 'Hija de Tutor')), 1, 'el menor es miembro de la sede');

select throws_ok(
  $$ select public.add_minor('c0000000-0000-4000-a000-000000000001', 'Mayor', current_date - 7000) $$,
  '22023', null, 'no admite mayores de 18 años'
);
select throws_ok(
  $$ select public.add_minor('c0000000-0000-4000-a000-000000000001', '  ', current_date - 3000) $$,
  '22023', null, 'exige el nombre'
);
select throws_ok(
  $$ select public.add_minor('d0000000-0000-4000-a000-000000000001', 'Hijo', current_date - 3000) $$,
  '42501', null, 'no se puede añadir un menor en una sede a la que no perteneces'
);

reset role;
select pg_temp.login('c1000000-0000-4000-a000-000000000002');
select is((select count(*)::int from public.profiles where full_name = 'Hija de Tutor'), 0, 'otro alumno de la sede no ve al menor');

reset role;
set local role anon;
select throws_ok(
  $$ select public.add_minor('c0000000-0000-4000-a000-000000000001', 'X', current_date - 3000) $$,
  '42501', null, 'anónimo: no puede usar add_minor'
);

select * from finish();
rollback;
