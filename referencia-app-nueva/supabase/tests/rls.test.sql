-- Pruebas de permisos (RLS). Cada política intenta leer o cambiar datos
-- ajenos y debe fallar. Todo ocurre en una transacción que se deshace.
begin;
create extension if not exists pgtap with schema extensions;
select plan(33);

-- ---------- Datos propios de la prueba ----------
insert into public.gyms (id, name) values
  ('a0000000-0000-4000-a000-000000000001', 'Sede A'),
  ('b0000000-0000-4000-a000-000000000002', 'Sede B');

insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email,
       jsonb_build_object('full_name', name), now(), now()
from (values
  ('a1000000-0000-4000-a000-000000000001'::uuid, 't-owner@a.test',  'Owner A'),
  ('a1000000-0000-4000-a000-000000000002'::uuid, 't-admin@a.test',  'Admin A'),
  ('a1000000-0000-4000-a000-000000000003'::uuid, 't-coach@a.test',  'Coach A'),
  ('a1000000-0000-4000-a000-000000000004'::uuid, 't-desk@a.test',   'Desk A'),
  ('a1000000-0000-4000-a000-000000000005'::uuid, 't-ana@a.test',    'Ana A'),
  ('a1000000-0000-4000-a000-000000000006'::uuid, 't-luis@a.test',   'Luis A'),
  ('b1000000-0000-4000-a000-000000000001'::uuid, 't-owner@b.test',  'Owner B'),
  ('b1000000-0000-4000-a000-000000000002'::uuid, 't-bea@b.test',    'Bea B')
) as u (id, email, name);

-- El trigger de alta crea un perfil por usuario
select is(
  (select count(*)::int from public.profiles where user_id in (select id from auth.users where email like 't-%')),
  8, 'al registrarse se crea el perfil automáticamente'
);

create temp table pid as
select u.email, p.id from auth.users u join public.profiles p on p.user_id = u.id where u.email like 't-%';
grant select on pid to authenticated;

insert into public.gym_members (gym_id, profile_id, role)
select g, (select id from pid where email = e), r::public.gym_role
from (values
  ('a0000000-0000-4000-a000-000000000001'::uuid, 't-owner@a.test', 'owner'),
  ('a0000000-0000-4000-a000-000000000001'::uuid, 't-admin@a.test', 'admin'),
  ('a0000000-0000-4000-a000-000000000001'::uuid, 't-coach@a.test', 'coach'),
  ('a0000000-0000-4000-a000-000000000001'::uuid, 't-desk@a.test',  'front_desk'),
  ('a0000000-0000-4000-a000-000000000001'::uuid, 't-ana@a.test',   'member'),
  ('a0000000-0000-4000-a000-000000000001'::uuid, 't-luis@a.test',  'member'),
  ('b0000000-0000-4000-a000-000000000002'::uuid, 't-owner@b.test', 'owner'),
  ('b0000000-0000-4000-a000-000000000002'::uuid, 't-bea@b.test',   'member')
) as x (g, e, r);

-- Menor de Ana en la sede A
insert into public.profiles (id, full_name, birth_date)
values ('a2000000-0000-4000-a000-000000000001', 'Menor de Ana', current_date - 3000);
insert into public.gym_members (gym_id, profile_id) values ('a0000000-0000-4000-a000-000000000001', 'a2000000-0000-4000-a000-000000000001');
insert into public.guardianships (gym_id, guardian_profile_id, minor_profile_id)
values ('a0000000-0000-4000-a000-000000000001', (select id from pid where email = 't-ana@a.test'), 'a2000000-0000-4000-a000-000000000001');

-- Entrar como un usuario (rol authenticated con su JWT)
create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;
create function pg_temp.logout() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end $$;

-- ================= Anónimo =================
set local role anon;
select throws_ok('select count(*) from public.profiles', '42501', null, 'anónimo: no puede leer perfiles');
select throws_ok('select count(*) from public.gyms', '42501', null, 'anónimo: no puede leer sedes');
reset role;

-- ================= Alumno (Ana) =================
select pg_temp.login('t-ana@a.test');
select is((select count(*)::int from public.profiles), 2, 'alumno: ve solo su perfil y el de su menor');
select is((select count(*)::int from public.profiles where full_name = 'Luis A'), 0, 'alumno: no ve el perfil de otro alumno');
select is((select count(*)::int from public.gym_members), 2, 'alumno: ve solo sus filas de miembro y las de su menor');
select is((select count(*)::int from public.gyms), 1, 'alumno: ve solo su sede');
select is((select count(*)::int from public.audit_log), 0, 'alumno: no ve el registro de auditoría');

update public.profiles set full_name = 'Hackeado' where full_name = 'Luis A';
select pg_temp.logout();
select is((select full_name from public.profiles where full_name = 'Luis A'), 'Luis A', 'alumno: no puede cambiar el perfil de otro');

select pg_temp.login('t-ana@a.test');
update public.profiles set emergency_contact_phone = '600000000' where user_id = auth.uid();
update public.profiles set emergency_contact_phone = '611111111' where id = 'a2000000-0000-4000-a000-000000000001';
select pg_temp.logout();
select is((select emergency_contact_phone from public.profiles where full_name = 'Ana A'), '600000000', 'alumno: puede cambiar su propio perfil');
select is((select emergency_contact_phone from public.profiles where id = 'a2000000-0000-4000-a000-000000000001'), '611111111', 'tutor: puede cambiar el perfil de su menor');

select pg_temp.login('t-ana@a.test');
update public.gym_members set role = 'owner' where profile_id = public.current_profile_id();
select is((select role::text from public.gym_members where profile_id = public.current_profile_id()), 'member', 'alumno: no puede darse a sí mismo el rol de propietario');
select throws_ok(
  $$ insert into public.gym_members (gym_id, profile_id, role) values ('a0000000-0000-4000-a000-000000000001', (select id from pid where email = 't-ana@a.test'), 'admin') $$,
  '42501', null, 'alumno: no puede añadirse como admin'
);
select throws_ok(
  $$ update public.profiles set user_id = null where user_id = auth.uid() $$,
  '42501', null, 'nadie puede desvincular su cuenta del perfil desde el cliente'
);
select throws_ok(
  $$ insert into public.profiles (full_name) values ('Perfil suelto') $$,
  '42501', null, 'alumno: no puede crear perfiles directamente'
);
select pg_temp.logout();

-- ================= Profesor =================
select pg_temp.login('t-coach@a.test');
select is((select count(*)::int from public.profiles), 7, 'profesor: ve los perfiles de su sede (6 adultos y el menor)');
select is((select count(*)::int from public.profiles where full_name in ('Owner B', 'Bea B')), 0, 'profesor: no ve perfiles de otra sede');
select is((select count(*)::int from public.gym_members), 7, 'profesor: ve los miembros de su sede');
select is((select count(*)::int from public.guardianships), 1, 'profesor: ve los tutores de su sede');
update public.profiles set full_name = 'Cambiado' where full_name = 'Luis A';
select pg_temp.logout();
select is((select count(*)::int from public.profiles where full_name = 'Luis A'), 1, 'profesor: no edita datos de alumnos');

select pg_temp.login('t-coach@a.test');
select throws_ok(
  $$ insert into public.gym_members (gym_id, profile_id) values ('a0000000-0000-4000-a000-000000000001', (select id from pid where email = 't-bea@b.test')) $$,
  '42501', null, 'profesor: no da de alta alumnos'
);
select pg_temp.logout();

-- ================= Recepción =================
select pg_temp.login('t-desk@a.test');
update public.profiles set emergency_contact_name = 'Madre de Luis' where full_name = 'Luis A';
select lives_ok(
  $$ insert into public.gym_members (gym_id, profile_id) values ('a0000000-0000-4000-a000-000000000001', (select id from pid where email = 't-bea@b.test')) $$,
  'recepción: da de alta un alumno'
);
select throws_ok(
  $$ update public.gym_members set role = 'coach' where profile_id = (select id from pid where email = 't-luis@a.test') $$,
  '42501', null, 'recepción: no cambia roles'
);
update public.gyms set name = 'Otra';
select pg_temp.logout();
select is((select emergency_contact_name from public.profiles where full_name = 'Luis A'), 'Madre de Luis', 'recepción: edita datos de alumnos');
select is((select name from public.gyms where id = 'a0000000-0000-4000-a000-000000000001'), 'Sede A', 'recepción: no cambia los ajustes de la sede');

-- ================= Admin =================
select pg_temp.login('t-admin@a.test');
select throws_ok(
  $$ update public.gym_members set role = 'admin' where profile_id = (select id from pid where email = 't-luis@a.test') $$,
  '42501', null, 'admin: no cambia roles'
);
select throws_ok(
  $$ insert into public.gym_members (gym_id, profile_id, role) values ('b0000000-0000-4000-a000-000000000002', (select id from pid where email = 't-luis@a.test'), 'member') $$,
  '42501', null, 'admin: no da de alta en otra sede'
);
update public.gyms set settings = settings || '{"cancel_window_hours": 3}' where id = 'a0000000-0000-4000-a000-000000000001';
select is((select count(*)::int from public.profiles where full_name = 'Bea B'), 1, 'admin: ve a la alumna recién dada de alta por recepción');
select pg_temp.logout();
select is((select (settings ->> 'cancel_window_hours')::int from public.gyms where id = 'a0000000-0000-4000-a000-000000000001'), 3, 'admin: cambia los ajustes de su sede');

-- ================= Propietario =================
select pg_temp.login('t-owner@a.test');
select lives_ok(
  $$ update public.gym_members set role = 'coach' where profile_id = (select id from pid where email = 't-luis@a.test') and gym_id = 'a0000000-0000-4000-a000-000000000001' $$,
  'propietario: cambia roles'
);
select is((select count(*)::int from public.audit_log where action = 'role_change'), 1, 'propietario: el cambio de rol queda en auditoría');
select is((select count(*)::int from public.gyms), 1, 'propietario: no ve otras sedes');
select pg_temp.logout();

-- ================= Otra sede =================
select pg_temp.login('t-owner@b.test');
update public.gym_members set role = 'admin' where profile_id = (select id from pid where email = 't-ana@a.test');
select pg_temp.logout();
select is(
  (select role::text from public.gym_members where profile_id = (select id from pid where email = 't-ana@a.test')),
  'member', 'propietario de otra sede: no cambia roles en la sede A'
);

select * from finish();
rollback;
