-- Asistencia: idempotencia, ventana de check-in, QR, permisos.
begin;
create extension if not exists pgtap with schema extensions;
select plan(30);

insert into public.gyms (id, name, checkin_code) values
  ('a5000000-0000-4000-a000-000000000001', 'Sede A', 'codigo-a'),
  ('a5000000-0000-4000-a000-000000000002', 'Sede B', 'codigo-b');
insert into public.disciplines (id, gym_id, slug, name, kind)
values ('a5100000-0000-4000-a000-000000000001', 'a5000000-0000-4000-a000-000000000001', 'gi', 'Gi', 'gi');
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, jsonb_build_object('full_name', n), now(), now()
from (values
  ('a5900000-0000-4000-a000-000000000001'::uuid, 'as-coach@a.test', 'Coach'),
  ('a5900000-0000-4000-a000-000000000002'::uuid, 'as-ana@a.test', 'Ana'),
  ('a5900000-0000-4000-a000-000000000003'::uuid, 'as-luis@a.test', 'Luis'),
  ('a5900000-0000-4000-a000-000000000004'::uuid, 'as-eva@a.test', 'Eva'),
  ('a5900000-0000-4000-a000-000000000005'::uuid, 'as-otro@b.test', 'Otro')
) u (id, email, n);
create temp table pid as select u.email, p.id from auth.users u join public.profiles p on p.user_id = u.id where u.email like 'as-%';
grant select on pid to authenticated;
insert into public.gym_members (gym_id, profile_id, role)
select g, (select id from pid where email = e), r::public.gym_role from (values
  ('a5000000-0000-4000-a000-000000000001'::uuid, 'as-coach@a.test', 'coach'),
  ('a5000000-0000-4000-a000-000000000001'::uuid, 'as-ana@a.test', 'member'),
  ('a5000000-0000-4000-a000-000000000001'::uuid, 'as-luis@a.test', 'member'),
  ('a5000000-0000-4000-a000-000000000001'::uuid, 'as-eva@a.test', 'member'),
  ('a5000000-0000-4000-a000-000000000002'::uuid, 'as-otro@b.test', 'member')
) x (g, e, r);

-- Clase que empieza dentro de 10 minutos (check-in abierto), 2 plazas
insert into public.class_sessions (id, gym_id, discipline_id, name, starts_at, ends_at, capacity) values
  ('a5300000-0000-4000-a000-000000000001', 'a5000000-0000-4000-a000-000000000001', 'a5100000-0000-4000-a000-000000000001', 'Ahora', now() + interval '10 minutes', now() + interval '70 minutes', 2),
  ('a5300000-0000-4000-a000-000000000002', 'a5000000-0000-4000-a000-000000000001', 'a5100000-0000-4000-a000-000000000001', 'Mañana', now() + interval '1 day', now() + interval '1 day 1 hour', 10);
insert into public.bookings (gym_id, session_id, profile_id, status)
values ('a5000000-0000-4000-a000-000000000001', 'a5300000-0000-4000-a000-000000000001', (select id from pid where email = 'as-ana@a.test'), 'booked');

create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- ================= Profesor: idempotencia (modo avión) =================
select pg_temp.login('as-coach@a.test');
select is(public.check_in('a5300000-0000-4000-a000-000000000001', 'c0000000-0000-4000-a000-0000000000a1', (select id from pid where email = 'as-ana@a.test')) ->> 'duplicate', 'false',
  'profesor: marca a Ana');
select is(public.check_in('a5300000-0000-4000-a000-000000000001', 'c0000000-0000-4000-a000-0000000000a1', (select id from pid where email = 'as-ana@a.test')) ->> 'duplicate', 'true',
  'reenviar la misma marca (mismo client_id) no duplica');
select is(public.check_in('a5300000-0000-4000-a000-000000000001', 'c0000000-0000-4000-a000-0000000000a2', (select id from pid where email = 'as-ana@a.test')) ->> 'duplicate', 'true',
  'marcarla desde otro dispositivo tampoco duplica');
select is((select count(*)::int from public.attendances where session_id = 'a5300000-0000-4000-a000-000000000001'), 1, 'una sola asistencia de Ana');

-- Marca hecha sin conexión con la hora del móvil
select lives_ok($$ select public.check_in('a5300000-0000-4000-a000-000000000001', 'c0000000-0000-4000-a000-0000000000b1',
  (select id from pid where email = 'as-luis@a.test'), 'coach', now() - interval '3 minutes') $$, 'profesor: marca sin reserva con la hora del móvil');
select ok((select checked_in_at < now() - interval '2 minutes' from public.attendances where client_id = 'c0000000-0000-4000-a000-0000000000b1'),
  'se guarda la hora en que se marcó, no la de llegada al servidor');

-- Quitar y reenviar la anulación
select is(public.uncheck('a5300000-0000-4000-a000-000000000001', (select id from pid where email = 'as-luis@a.test'), 'c0000000-0000-4000-a000-0000000000b2') ->> 'duplicate', 'false',
  'profesor: quita a Luis');
select is(public.uncheck('a5300000-0000-4000-a000-000000000001', (select id from pid where email = 'as-luis@a.test'), 'c0000000-0000-4000-a000-0000000000b2') ->> 'duplicate', 'true',
  'reenviar la misma anulación no hace nada');
select is((select count(*)::int from public.attendances where session_id = 'a5300000-0000-4000-a000-000000000001' and voided_at is null), 1,
  'quitar no borra: anula (queda Ana activa)');
select is((select count(*)::int from public.attendances where session_id = 'a5300000-0000-4000-a000-000000000001'), 2, 'la marca anulada sigue en el registro');
-- Reenviar la marca original después de anularla no la resucita
select is(public.check_in('a5300000-0000-4000-a000-000000000001', 'c0000000-0000-4000-a000-0000000000b1', (select id from pid where email = 'as-luis@a.test')) ->> 'duplicate', 'true',
  'reenviar la marca antigua tras quitarla no la vuelve a poner');
select is((select count(*)::int from public.attendances where session_id = 'a5300000-0000-4000-a000-000000000001' and voided_at is null), 1, 'Luis sigue quitado');
-- Una marca nueva sí
select is(public.check_in('a5300000-0000-4000-a000-000000000001', 'c0000000-0000-4000-a000-0000000000b3', (select id from pid where email = 'as-luis@a.test')) ->> 'duplicate', 'false',
  'una marca nueva vuelve a ponerlo');
select is(public.uncheck('a5300000-0000-4000-a000-000000000001', (select id from pid where email = 'as-luis@a.test'), 'c0000000-0000-4000-a000-0000000000b4') ->> 'duplicate', 'false',
  'y se puede volver a quitar');

-- ================= Alumno =================
select pg_temp.login('as-ana@a.test');
select is((select count(*)::int from public.attendances), 1, 'alumna: ve solo su asistencia');
select throws_ok($$ select public.check_in('a5300000-0000-4000-a000-000000000001', gen_random_uuid(), (select id from pid where email = 'as-luis@a.test')) $$,
  '42501', null, 'alumna: no marca a otro');
select throws_ok($$ select public.uncheck('a5300000-0000-4000-a000-000000000001', public.current_profile_id(), gen_random_uuid()) $$,
  '42501', null, 'alumna: no quita asistencias');
select throws_ok($$ insert into public.attendances (gym_id, session_id, profile_id, method, client_id, checked_in_at) values
  ('a5000000-0000-4000-a000-000000000001', 'a5300000-0000-4000-a000-000000000002', public.current_profile_id(), 'qr', gen_random_uuid(), now()) $$,
  '42501', null, 'alumna: no puede escribir en la tabla directamente');
select throws_ok($$ select public.check_in('a5300000-0000-4000-a000-000000000002', gen_random_uuid()) $$,
  'P0001', 'El check-in aún no está abierto', 'alumna: no ficha en la clase de mañana');
select throws_ok($$ select checkin_code from public.gyms $$, '42501', null, 'alumna: no ve el código del QR');
select is(public.gym_checkin_code('a5000000-0000-4000-a000-000000000001'), null, 'alumna: la función del código no se lo da');

-- QR: Eva no tiene reserva; queda 1 plaza (Ana tiene la otra)
select pg_temp.login('as-eva@a.test');
select is(public.check_in_by_code('codigo-a', 'c0000000-0000-4000-a000-0000000000e1') ->> 'session_id', 'a5300000-0000-4000-a000-000000000001',
  'alumna sin reserva ficha con el QR en la clase que está abierta');
select is((select status::text from public.bookings where profile_id = public.current_profile_id()), 'booked', 'y se le crea la reserva para que cuadre el aforo');
select is(public.check_in_by_code('codigo-a', 'c0000000-0000-4000-a000-0000000000e1') ->> 'duplicate', 'true', 'escanear dos veces no duplica');

select pg_temp.login('as-luis@a.test');
select throws_ok($$ select public.check_in_by_code('codigo-a', gen_random_uuid()) $$,
  'P0001', 'No hay ninguna clase abierta para fichar ahora mismo', 'sin reserva y con la clase llena no se ficha');
select throws_ok($$ select public.check_in_by_code('codigo-b', gen_random_uuid()) $$,
  '42501', 'No eres miembro de esta sede', 'el QR de otra sede no sirve');
select throws_ok($$ select public.check_in_by_code('inventado', gen_random_uuid()) $$,
  'P0001', 'Este código QR no es de ITACA', 'un código inventado no sirve');

select pg_temp.login('as-otro@b.test');
select is((select count(*)::int from public.attendances), 0, 'alumno de otra sede: no ve asistencias');

select pg_temp.login('as-coach@a.test');
select is(public.gym_checkin_code('a5000000-0000-4000-a000-000000000001'), 'codigo-a', 'personal: obtiene el código para el cartel o el kiosco');
select is((select count(*)::int from public.attendances where session_id = 'a5300000-0000-4000-a000-000000000001' and voided_at is null), 2,
  'profesor: ve las dos asistencias activas (Ana y Eva)');

select * from finish();
rollback;
