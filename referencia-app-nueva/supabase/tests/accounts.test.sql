-- Cuentas: alta pendiente, activación y eliminación.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

-- Esta prueba usa la sede más antigua (la del seed: ITACA)
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('00000000-0000-0000-0000-000000000000', 'ac000000-0000-4000-a000-000000000001', 'authenticated', 'authenticated', 'ac-nuevo@x.test', '{"full_name":"Nuevo Alumno"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'ac000000-0000-4000-a000-000000000002', 'authenticated', 'authenticated', 'ac-borrar@x.test', '{"full_name":"Para Borrar"}', now(), now());

create function pg_temp.login(p_user uuid) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- ================= Alta pendiente =================
select pg_temp.login('ac000000-0000-4000-a000-000000000001');
select is(public.join_default_gym() ->> 'status', 'inactive', 'un usuario nuevo queda pendiente de activar');
select is(public.join_default_gym() ->> 'already', 'true', 'repetir no crea otra alta');
select is((select status::text from public.my_membership_status()), 'inactive', 've su estado: pendiente');
select is((select count(*)::int from public.class_sessions), 0, 'pendiente: no ve el horario');
select is((select count(*)::int from public.staff_directory), 0, 'pendiente: no ve al personal');
select throws_ok($$ select public.book_session((select id from public.class_sessions limit 1)) $$, null, null, 'pendiente: no reserva');
select is((select count(*)::int from public.session_attendees((select id from public.class_sessions limit 1))), 0, 'pendiente: no ve quién va a las clases');

-- Recepción activa la cuenta
reset role;
select pg_temp.login((select id from auth.users where email = 'recepcion@itaca.test'));
update public.gym_members set status = 'active'
where profile_id = (select id from public.profiles where user_id = 'ac000000-0000-4000-a000-000000000001');
select pg_temp.login('ac000000-0000-4000-a000-000000000001');
select is((select status::text from public.my_membership_status()), 'active', 'recepción activa la cuenta');
select ok((select count(*) from public.class_sessions) > 0, 'activo: ya ve el horario');

-- Activación automática si la sede lo configura
reset role;
update public.gyms set settings = settings || '{"auto_approve_members": true}' where id = '00000000-0000-4000-a000-000000000001';
select pg_temp.login('ac000000-0000-4000-a000-000000000002');
select is(public.join_default_gym() ->> 'status', 'active', 'con auto_approve_members el alta queda activa');

-- ================= Eliminar la cuenta =================
select lives_ok($$ select public.delete_my_account() $$, 'el usuario elimina su cuenta');
reset role;
select is((select count(*)::int from auth.users where id = 'ac000000-0000-4000-a000-000000000002'), 0, 'el usuario de acceso desaparece');
select is((select full_name from public.profiles where id = (select profile_id from public.gym_members m join public.profiles p on p.id = m.profile_id
  where p.full_name = 'Usuario eliminado' limit 1)), 'Usuario eliminado', 'el perfil queda anonimizado (la asistencia se conserva sin nombre)');

-- El único propietario no puede borrarse
select pg_temp.login((select id from auth.users where email = 'propietario@itaca.test'));
select throws_ok($$ select public.delete_my_account() $$, 'P0001', 'Eres el único propietario: nombra antes a otro propietario', 'el único propietario no puede eliminar su cuenta');

select * from finish();
rollback;
