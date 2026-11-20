-- Gestión del horario: eliminar clase semanal, clase puntual, cancelar,
-- recuperar y cambiar la clase de un día. Permisos.
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

insert into public.gyms (id, name) values ('e0000000-0000-4000-e000-000000000001', 'Sede H');
insert into public.disciplines (id, gym_id, slug, name, kind) values
  ('e1000000-0000-4000-e000-000000000001', 'e0000000-0000-4000-e000-000000000001', 'gi', 'Gi', 'gi');
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, jsonb_build_object('full_name', name), now(), now()
from (values
  ('e9000000-0000-4000-e000-000000000001'::uuid, 'h-admin@h.test', 'Admin'),
  ('e9000000-0000-4000-e000-000000000002'::uuid, 'h-coach@h.test', 'Coach'),
  ('e9000000-0000-4000-e000-000000000003'::uuid, 'h-alumno@h.test', 'Alumno'),
  ('e9000000-0000-4000-e000-000000000004'::uuid, 'h-otro@h.test', 'Otro')
) as u (id, email, name);
create temp table pid as select u.email, p.id from auth.users u join public.profiles p on p.user_id = u.id where u.email like 'h-%';
grant select on pid to authenticated;
insert into public.gym_members (gym_id, profile_id, role)
select 'e0000000-0000-4000-e000-000000000001', id,
  case email when 'h-admin@h.test' then 'admin' when 'h-coach@h.test' then 'coach' else 'member' end::public.gym_role
from pid;

-- Clase semanal todos los días a las 10:00 (genera 4 semanas)
insert into public.class_templates (id, gym_id, discipline_id, name, weekdays, start_time, duration_min, capacity, valid_from)
values ('e2000000-0000-4000-e000-000000000001', 'e0000000-0000-4000-e000-000000000001', 'e1000000-0000-4000-e000-000000000001',
        'Gi diario', '{1,2,3,4,5,6,7}', '10:00', 60, 2, current_date - 7);
-- Una reserva del alumno en la sesión de pasado mañana
insert into public.bookings (gym_id, session_id, profile_id, status)
select 'e0000000-0000-4000-e000-000000000001', s.id, (select id from pid where email = 'h-alumno@h.test'), 'booked'
from public.class_sessions s where s.template_id = 'e2000000-0000-4000-e000-000000000001' and s.starts_at > now() + interval '1 day' order by s.starts_at limit 1;
create temp table booked_session as
select session_id as id from public.bookings where profile_id = (select id from pid where email = 'h-alumno@h.test');
grant select on booked_session to authenticated;

create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- ================= Permisos =================
select pg_temp.login('h-coach@h.test');
select throws_ok($$ select public.cancel_session((select id from booked_session)) $$, '42501', null, 'un profesor no cancela clases');
select throws_ok($$ select public.delete_class_template('e2000000-0000-4000-e000-000000000001') $$, '42501', null, 'un profesor no elimina clases');
select pg_temp.login('h-alumno@h.test');
select throws_ok($$ select public.create_one_off_session('e0000000-0000-4000-e000-000000000001', 'e1000000-0000-4000-e000-000000000001', 'X', current_date + 3, '18:00', 60) $$,
  '42501', null, 'un alumno no crea clases');

-- ================= Cancelar y recuperar un día =================
select pg_temp.login('h-admin@h.test');
select lives_ok($$ select public.cancel_session((select id from booked_session), 'Profesor enfermo') $$, 'administración cancela la clase de un día');
reset role;
select is((select status::text || ' · ' || cancel_reason from public.class_sessions where id = (select id from booked_session)), 'cancelled · Profesor enfermo', 'queda cancelada con el motivo');
select pg_temp.login('h-admin@h.test');
select lives_ok($$ select public.restore_session((select id from booked_session)) $$, 'y la recupera');
reset role;
select is((select status::text from public.class_sessions where id = (select id from booked_session)), 'scheduled', 'vuelve a estar programada');

-- ================= Cambiar un día =================
select pg_temp.login('h-admin@h.test');
select throws_ok($$ select public.update_session((select id from booked_session), 0) $$, '22023', null, 'el aforo no puede bajar de las reservas');
select lives_ok($$ select public.update_session((select id from booked_session), 5, (select id from pid where email = 'h-coach@h.test')) $$, 'cambia aforo y pone sustituto');
reset role;
select is((select capacity from public.class_sessions where id = (select id from booked_session)), 5, 'aforo cambiado solo ese día');
select is((select substitute_coach_profile_id from public.class_sessions where id = (select id from booked_session)), (select id from pid where email = 'h-coach@h.test'), 'sustituto puesto');
select is((select capacity from public.class_templates where id = 'e2000000-0000-4000-e000-000000000001'), 2, 'la clase semanal no cambia');
select pg_temp.login('h-admin@h.test');
select throws_ok($$ select public.update_session((select id from booked_session), null, (select id from pid where email = 'h-alumno@h.test')) $$, '22023', null, 'un alumno no puede ser sustituto');

-- ================= Clase puntual =================
select isnt(public.create_one_off_session('e0000000-0000-4000-e000-000000000001', 'e1000000-0000-4000-e000-000000000001', 'Seminario', current_date + 3, '18:00', 120, 30), null, 'crea una clase puntual');
reset role;
select is((select count(*)::int from public.class_sessions where name = 'Seminario' and template_id is null and ends_at - starts_at = interval '2 hours'), 1, 'sin clase semanal y con su duración');

-- ================= Eliminar la clase semanal =================
select pg_temp.login('h-admin@h.test');
select lives_ok($$ select public.delete_class_template('e2000000-0000-4000-e000-000000000001') $$, 'elimina la clase semanal');
reset role;
select is((select count(*)::int from public.class_sessions where gym_id = 'e0000000-0000-4000-e000-000000000001' and starts_at > now() and status = 'scheduled' and name = 'Gi diario'), 0,
  'no quedan clases futuras programadas');
select is((select status::text from public.class_sessions where id = (select id from booked_session)), 'cancelled', 'la que tenía reservas queda cancelada, no borrada');

select * from finish();
rollback;
