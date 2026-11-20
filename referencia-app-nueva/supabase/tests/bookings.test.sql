-- Pruebas de reservas: aforo, lista de espera, cancelación, edad y permisos.
begin;
create extension if not exists pgtap with schema extensions;
select plan(34);

-- ---------- Datos ----------
insert into public.gyms (id, name) values
  ('b0000000-0000-4000-b000-000000000001', 'Sede R'),
  ('b0000000-0000-4000-b000-000000000002', 'Sede S');
insert into public.disciplines (id, gym_id, slug, name, kind) values
  ('b1000000-0000-4000-b000-000000000001', 'b0000000-0000-4000-b000-000000000001', 'gi', 'Gi', 'gi'),
  ('b1000000-0000-4000-b000-000000000002', 'b0000000-0000-4000-b000-000000000001', 'kids', 'Kids', 'kids');

insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, jsonb_build_object('full_name', name), now(), now()
from (values
  ('b9000000-0000-4000-b000-000000000001'::uuid, 'r-ana@r.test',   'Ana'),
  ('b9000000-0000-4000-b000-000000000002'::uuid, 'r-luis@r.test',  'Luis'),
  ('b9000000-0000-4000-b000-000000000003'::uuid, 'r-eva@r.test',   'Eva'),
  ('b9000000-0000-4000-b000-000000000004'::uuid, 'r-pablo@r.test', 'Pablo'),
  ('b9000000-0000-4000-b000-000000000005'::uuid, 'r-desk@r.test',  'Recepción'),
  ('b9000000-0000-4000-b000-000000000006'::uuid, 'r-coach@r.test', 'Coach'),
  ('b9000000-0000-4000-b000-000000000007'::uuid, 'r-otro@s.test',  'Otro')
) as u (id, email, name);

create temp table pid as
select u.email, p.id from auth.users u join public.profiles p on p.user_id = u.id where u.email like 'r-%';
grant select on pid to authenticated;

insert into public.gym_members (gym_id, profile_id, role)
select g, (select id from pid where email = e), r::public.gym_role
from (values
  ('b0000000-0000-4000-b000-000000000001'::uuid, 'r-ana@r.test', 'member'),
  ('b0000000-0000-4000-b000-000000000001'::uuid, 'r-luis@r.test', 'member'),
  ('b0000000-0000-4000-b000-000000000001'::uuid, 'r-eva@r.test', 'member'),
  ('b0000000-0000-4000-b000-000000000001'::uuid, 'r-pablo@r.test', 'member'),
  ('b0000000-0000-4000-b000-000000000001'::uuid, 'r-desk@r.test', 'front_desk'),
  ('b0000000-0000-4000-b000-000000000001'::uuid, 'r-coach@r.test', 'coach'),
  ('b0000000-0000-4000-b000-000000000002'::uuid, 'r-otro@s.test', 'member')
) as x (g, e, r);

-- Hijo de Ana, 8 años
insert into public.profiles (id, full_name, birth_date) values ('b2000000-0000-4000-b000-000000000001', 'Hijo de Ana', current_date - interval '8 years 2 months');
insert into public.gym_members (gym_id, profile_id) values ('b0000000-0000-4000-b000-000000000001', 'b2000000-0000-4000-b000-000000000001');
insert into public.guardianships (gym_id, guardian_profile_id, minor_profile_id)
values ('b0000000-0000-4000-b000-000000000001', (select id from pid where email = 'r-ana@r.test'), 'b2000000-0000-4000-b000-000000000001');

-- Sesiones puntuales (sin plantilla): una de 2 plazas mañana, una infantil, una dentro de 1 hora, una pasada
insert into public.class_sessions (id, gym_id, discipline_id, name, starts_at, ends_at, capacity) values
  ('b3000000-0000-4000-b000-000000000001', 'b0000000-0000-4000-b000-000000000001', 'b1000000-0000-4000-b000-000000000001', 'Gi 2 plazas', now() + interval '1 day', now() + interval '1 day 90 minutes', 2),
  ('b3000000-0000-4000-b000-000000000003', 'b0000000-0000-4000-b000-000000000001', 'b1000000-0000-4000-b000-000000000001', 'Gi pronto', now() + interval '1 hour', now() + interval '150 minutes', 10),
  ('b3000000-0000-4000-b000-000000000004', 'b0000000-0000-4000-b000-000000000001', 'b1000000-0000-4000-b000-000000000001', 'Gi pasada', now() - interval '3 hours', now() - interval '2 hours', 10);
insert into public.class_templates (id, gym_id, discipline_id, name, weekdays, start_time, duration_min, capacity, min_age, max_age, active)
values ('b4000000-0000-4000-b000-000000000001', 'b0000000-0000-4000-b000-000000000001', 'b1000000-0000-4000-b000-000000000002', 'Kids 7/10', '{1}', '17:00', 60, 10, 7, 10, false);
insert into public.class_sessions (id, gym_id, template_id, discipline_id, name, starts_at, ends_at, capacity) values
  ('b3000000-0000-4000-b000-000000000002', 'b0000000-0000-4000-b000-000000000001', 'b4000000-0000-4000-b000-000000000001', 'b1000000-0000-4000-b000-000000000002', 'Kids', now() + interval '2 days', now() + interval '2 days 1 hour', 10);

create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- ================= Aforo y lista de espera =================
select pg_temp.login('r-ana@r.test');
select is(public.book_session('b3000000-0000-4000-b000-000000000001') ->> 'status', 'booked', 'primera reserva: plaza');
select is(public.book_session('b3000000-0000-4000-b000-000000000001') ->> 'already', 'true', 'reservar dos veces no duplica');
select pg_temp.login('r-luis@r.test');
select is(public.book_session('b3000000-0000-4000-b000-000000000001') ->> 'status', 'booked', 'segunda reserva: última plaza');
select pg_temp.login('r-eva@r.test');
select is(public.book_session('b3000000-0000-4000-b000-000000000001') ->> 'status', 'waitlist', 'con la clase llena: lista de espera');
select pg_temp.login('r-pablo@r.test');
select is((public.book_session('b3000000-0000-4000-b000-000000000001') ->> 'position')::int, 2, 'el segundo en llegar es el 2 de la lista');

reset role;
select is((select booked_count from public.class_sessions where id = 'b3000000-0000-4000-b000-000000000001'), 2, 'contador de plazas ocupadas');
select is((select waitlist_count from public.class_sessions where id = 'b3000000-0000-4000-b000-000000000001'), 2, 'contador de lista de espera');

-- ================= Lo que ve cada uno =================
select pg_temp.login('r-eva@r.test');
select is((select count(*)::int from public.bookings), 1, 'alumna: ve solo su reserva');
select is((select waitlist_position from public.my_bookings()), 1, 'my_bookings da su puesto en la lista');
select is((select booked_count from public.class_sessions where id = 'b3000000-0000-4000-b000-000000000001'), 2, 'alumna: ve la ocupación de la clase aunque no vea las reservas');
select throws_ok(
  $$ insert into public.bookings (gym_id, session_id, profile_id, status) values ('b0000000-0000-4000-b000-000000000001', 'b3000000-0000-4000-b000-000000000001', public.current_profile_id(), 'booked') $$,
  '42501', null, 'alumna: no puede saltarse la función e insertar una reserva');
select throws_ok(
  $$ update public.bookings set status = 'booked' $$,
  '42501', null, 'alumna: no puede pasarse de la lista de espera a plaza');
select throws_ok(
  $$ select public.book_session('b3000000-0000-4000-b000-000000000003', (select id from pid where email = 'r-luis@r.test')) $$,
  '42501', null, 'alumna: no puede reservar por otro alumno');

select pg_temp.login('r-coach@r.test');
select is((select count(*)::int from public.bookings where session_id = 'b3000000-0000-4000-b000-000000000001'), 4, 'profesor: ve todas las reservas de la clase');
select throws_ok($$ select public.book_session('b3000000-0000-4000-b000-000000000003', (select id from pid where email = 'r-ana@r.test')) $$,
  '42501', null, 'profesor: no reserva por los alumnos');

select pg_temp.login('r-otro@s.test');
select is((select count(*)::int from public.bookings), 0, 'alumno de otra sede: no ve reservas');
select throws_ok($$ select public.book_session('b3000000-0000-4000-b000-000000000003') $$,
  '42501', null, 'alumno de otra sede: no reserva aquí');

-- ================= Cancelar y promover =================
select pg_temp.login('r-luis@r.test');
select is(
  public.cancel_booking((select id from public.bookings where status = 'booked')) ->> 'promoted_profile_id',
  (select id::text from pid where email = 'r-eva@r.test'),
  'al cancelar una plaza sube la primera de la lista (Eva)');
select is((select count(*)::int from public.my_bookings()), 0, 'Luis ya no tiene reservas activas');
reset role;
select is((select status::text from public.bookings b join pid on pid.id = b.profile_id where pid.email = 'r-eva@r.test'), 'booked', 'Eva pasa a tener plaza');
select is((select waitlist_count from public.class_sessions where id = 'b3000000-0000-4000-b000-000000000001'), 1, 'queda uno en la lista');
select is((select late_cancel from public.bookings b join pid on pid.id = b.profile_id where pid.email = 'r-luis@r.test'), false, 'cancelar con un día de margen no es tardío');

select pg_temp.login('r-pablo@r.test');
select is((select waitlist_position from public.my_bookings()), 1, 'Pablo sube al puesto 1');
select is(public.cancel_booking((select id from public.bookings limit 1)) ->> 'promoted_profile_id', null, 'salir de la lista de espera no promueve a nadie');

-- Cancelación tardía (clase en 1 hora, plazo de 2 horas)
select pg_temp.login('r-ana@r.test');
select isnt(public.book_session('b3000000-0000-4000-b000-000000000003') ->> 'booking_id', null, 'reserva en la clase de dentro de 1 hora');
select is((public.cancel_booking((select id from public.bookings where session_id = 'b3000000-0000-4000-b000-000000000003')) ->> 'late')::boolean, true,
  'cancelar dentro del plazo de 2 horas es tardío');

-- Clase terminada
select throws_ok($$ select public.book_session('b3000000-0000-4000-b000-000000000004') $$, 'P0001', 'La clase ya ha terminado', 'no se reserva una clase terminada');

-- ================= Edad y tutores =================
select throws_ok($$ select public.book_session('b3000000-0000-4000-b000-000000000002') $$,
  'P0001', 'Esta clase infantil no es para su edad', 'un adulto no reserva en la clase infantil');
select is(public.book_session('b3000000-0000-4000-b000-000000000002', 'b2000000-0000-4000-b000-000000000001') ->> 'status', 'booked',
  'la madre reserva la clase infantil para su hijo de 8 años');
select throws_ok($$ select public.book_session('b3000000-0000-4000-b000-000000000003', 'b2000000-0000-4000-b000-000000000001') $$,
  'P0001', 'Las clases de adultos son a partir de 14 años', 'un niño de 8 años no va a la clase de adultos');
select is((select count(*)::int from public.my_bookings() where profile_id = 'b2000000-0000-4000-b000-000000000001'), 1, 'la madre ve la reserva de su hijo');

-- Recepción reserva por un alumno
select pg_temp.login('r-desk@r.test');
select is(public.book_session('b3000000-0000-4000-b000-000000000003', (select id from pid where email = 'r-luis@r.test')) ->> 'status', 'booked',
  'recepción reserva por un alumno');

-- Clase cancelada por cierre
reset role;
insert into public.closures (gym_id, date_from, date_to, reason)
values ('b0000000-0000-4000-b000-000000000001', (now() + interval '2 days')::date, (now() + interval '2 days')::date, 'Festivo');
select pg_temp.login('r-luis@r.test');
select throws_ok($$ select public.book_session('b3000000-0000-4000-b000-000000000002') $$,
  'P0001', 'La clase está cancelada', 'no se reserva una clase cancelada');

-- ================= Editar la plantilla no borra clases con reservas =================
reset role;
select set_config('request.jwt.claims', '', true);
update public.class_templates set start_time = '18:00', active = true where id = 'b4000000-0000-4000-b000-000000000001';
select is((select count(*)::int from public.class_sessions where id = 'b3000000-0000-4000-b000-000000000002'), 1,
  'la sesión con reservas sigue ahí tras cambiar la plantilla');

select * from finish();
rollback;
