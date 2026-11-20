-- Pruebas del horario: generate_sessions, cierres, cambio de hora y permisos.
begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

-- Sede para el cambio de hora (fechas fijas en octubre de 2026)
insert into public.gyms (id, name) values ('e0000000-0000-4000-a000-000000000001', 'Sede DST');
insert into public.disciplines (id, gym_id, slug, name, kind)
values ('e1000000-0000-4000-a000-000000000001', 'e0000000-0000-4000-a000-000000000001', 'gi', 'Gi', 'gi');

-- Insertar la plantilla genera ya 12 semanas desde hoy; para la prueba de fechas fijas
-- la creamos inactiva y la activamos después con valid_from en el pasado.
insert into public.class_templates (id, gym_id, discipline_id, name, weekdays, start_time, duration_min, capacity, valid_from, valid_until, active)
values ('e2000000-0000-4000-a000-000000000001', 'e0000000-0000-4000-a000-000000000001', 'e1000000-0000-4000-a000-000000000001',
        'Gi 19:00', '{1,3,5}', '19:00', 90, 20, '2026-10-01', '2026-11-08', false);
select is((select count(*)::int from public.class_sessions where gym_id = 'e0000000-0000-4000-a000-000000000001'), 0,
  'una plantilla inactiva no genera sesiones');
update public.class_templates set active = true where id = 'e2000000-0000-4000-a000-000000000001';

-- Del lunes 19/10/2026, 3 semanas: L-X-V = 9 sesiones (el 25/10 cambia la hora)
select is(public.generate_sessions('e0000000-0000-4000-a000-000000000001', 3, '2026-10-19'), 9,
  'genera 3 semanas de una clase de lunes, miércoles y viernes');
select is(public.generate_sessions('e0000000-0000-4000-a000-000000000001', 3, '2026-10-19'), 0,
  'volver a generar no duplica');
select is(
  (select count(*)::int from public.class_sessions where template_id = 'e2000000-0000-4000-a000-000000000001'
     and to_char(starts_at at time zone 'Europe/Madrid', 'HH24:MI') = '19:00'),
  9, 'todas siguen a las 19:00 hora de Madrid');
select is(
  (select to_char(starts_at at time zone 'UTC', 'HH24:MI') from public.class_sessions
   where template_id = 'e2000000-0000-4000-a000-000000000001' and starts_at::date = '2026-10-23'),
  '17:00', 'antes del cambio de hora: 17:00 UTC (CEST)');
select is(
  (select to_char(starts_at at time zone 'UTC', 'HH24:MI') from public.class_sessions
   where template_id = 'e2000000-0000-4000-a000-000000000001' and starts_at::date = '2026-10-26'),
  '18:00', 'después del cambio de hora: 18:00 UTC (CET)');
select is(
  (select extract(epoch from ends_at - starts_at)::int / 60 from public.class_sessions
   where template_id = 'e2000000-0000-4000-a000-000000000001' limit 1),
  90, 'la sesión dura lo que dice la plantilla');
select is(
  (select count(*)::int from public.class_sessions where template_id = 'e2000000-0000-4000-a000-000000000001' and starts_at::date > '2026-11-08'),
  0, 'respeta valid_until');

-- Cierres
insert into public.closures (id, gym_id, date_from, date_to, reason)
values ('e3000000-0000-4000-a000-000000000001', 'e0000000-0000-4000-a000-000000000001', '2026-10-21', '2026-10-23', 'Puente');
select is(
  (select count(*)::int from public.class_sessions where template_id = 'e2000000-0000-4000-a000-000000000001' and status = 'cancelled'),
  2, 'un cierre cancela las sesiones de esos días (miércoles y viernes)');
select is(
  (select cancel_reason from public.class_sessions where template_id = 'e2000000-0000-4000-a000-000000000001' and status = 'cancelled' limit 1),
  'Puente', 'la sesión cancelada guarda el motivo');
delete from public.closures where id = 'e3000000-0000-4000-a000-000000000001';
select is(
  (select count(*)::int from public.class_sessions where template_id = 'e2000000-0000-4000-a000-000000000001' and status = 'cancelled'),
  0, 'al borrar el cierre las sesiones vuelven a programarse');

insert into public.closures (gym_id, date_from, date_to) values ('e0000000-0000-4000-a000-000000000001', '2026-11-02', '2026-11-02');
delete from public.class_sessions where template_id = 'e2000000-0000-4000-a000-000000000001' and starts_at::date = '2026-11-02';
select is(public.generate_sessions('e0000000-0000-4000-a000-000000000001', 3, '2026-10-19'), 0,
  'generar no crea sesiones en días cerrados');

-- ---------- Sede con usuarios para permisos y cambios de plantilla ----------
insert into public.gyms (id, name) values
  ('f0000000-0000-4000-a000-000000000001', 'Sede F'),
  ('f0000000-0000-4000-a000-000000000002', 'Sede G');
insert into public.disciplines (id, gym_id, slug, name, kind) values
  ('f1000000-0000-4000-a000-000000000001', 'f0000000-0000-4000-a000-000000000001', 'gi', 'Gi', 'gi'),
  ('f1000000-0000-4000-a000-000000000002', 'f0000000-0000-4000-a000-000000000002', 'gi', 'Gi', 'gi');
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, jsonb_build_object('full_name', name), now(), now()
from (values
  ('f9000000-0000-4000-a000-000000000001'::uuid, 's-admin@f.test', 'Admin F'),
  ('f9000000-0000-4000-a000-000000000002'::uuid, 's-coach@f.test', 'Coach F'),
  ('f9000000-0000-4000-a000-000000000003'::uuid, 's-alumno@f.test', 'Alumno F'),
  ('f9000000-0000-4000-a000-000000000004'::uuid, 's-alumno@g.test', 'Alumno G')
) as u (id, email, name);
insert into public.gym_members (gym_id, profile_id, role)
select g, p.id, r::public.gym_role
from (values
  ('f0000000-0000-4000-a000-000000000001'::uuid, 'f9000000-0000-4000-a000-000000000001'::uuid, 'admin'),
  ('f0000000-0000-4000-a000-000000000001'::uuid, 'f9000000-0000-4000-a000-000000000002'::uuid, 'coach'),
  ('f0000000-0000-4000-a000-000000000001'::uuid, 'f9000000-0000-4000-a000-000000000003'::uuid, 'member'),
  ('f0000000-0000-4000-a000-000000000002'::uuid, 'f9000000-0000-4000-a000-000000000004'::uuid, 'member')
) as x (g, u, r)
join public.profiles p on p.user_id = x.u;

insert into public.class_templates (id, gym_id, discipline_id, name, weekdays, start_time, duration_min, capacity, coach_profile_id)
values ('f2000000-0000-4000-a000-000000000001', 'f0000000-0000-4000-a000-000000000001', 'f1000000-0000-4000-a000-000000000001',
        'Gi todos los días', '{1,2,3,4,5,6,7}', '20:00', 60, 20,
        (select id from public.profiles where user_id = 'f9000000-0000-4000-a000-000000000002'));
insert into public.class_templates (gym_id, discipline_id, name, weekdays, start_time, duration_min, capacity)
values ('f0000000-0000-4000-a000-000000000002', 'f1000000-0000-4000-a000-000000000002', 'Clase de G', '{1,2,3,4,5,6,7}', '20:00', 60, 20);

select is((select count(*)::int from public.class_sessions where template_id = 'f2000000-0000-4000-a000-000000000001'), 84,
  'al crear una plantilla se generan 12 semanas (tres meses) de sesiones');
select is(
  (select count(*)::int from public.class_sessions where template_id = 'f2000000-0000-4000-a000-000000000001' and coach_profile_id is not null),
  84, 'las sesiones heredan el profesor de la plantilla');

update public.class_templates set start_time = '21:00' where id = 'f2000000-0000-4000-a000-000000000001';
select is(
  (select count(*)::int from public.class_sessions where template_id = 'f2000000-0000-4000-a000-000000000001'
     and starts_at > now() and to_char(starts_at at time zone 'Europe/Madrid', 'HH24:MI') = '20:00'),
  0, 'al cambiar la hora de la plantilla no quedan sesiones futuras con la hora antigua');
select ok(
  (select count(*) from public.class_sessions where template_id = 'f2000000-0000-4000-a000-000000000001'
     and to_char(starts_at at time zone 'Europe/Madrid', 'HH24:MI') = '21:00') >= 27,
  'y se regeneran a la hora nueva');

update public.class_templates set active = false where id = 'f2000000-0000-4000-a000-000000000001';
select is(
  (select count(*)::int from public.class_sessions where template_id = 'f2000000-0000-4000-a000-000000000001' and starts_at > now()),
  0, 'desactivar una plantilla retira sus sesiones futuras');
update public.class_templates set active = true where id = 'f2000000-0000-4000-a000-000000000001';

create function pg_temp.login(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- Alumno
select pg_temp.login('f9000000-0000-4000-a000-000000000003');
select ok((select count(*) from public.class_sessions) >= 27, 'alumno: ve el horario de su sede');
select is((select count(*)::int from public.class_sessions where gym_id <> 'f0000000-0000-4000-a000-000000000001'), 0,
  'alumno: no ve el horario de otra sede');
select is((select count(*)::int from public.staff_directory), 2, 'alumno: ve el nombre del personal de su sede (admin y profesor)');
select throws_ok(
  $$ insert into public.class_templates (gym_id, discipline_id, name, weekdays, start_time, duration_min, capacity)
     values ('f0000000-0000-4000-a000-000000000001', 'f1000000-0000-4000-a000-000000000001', 'Mía', '{1}', '10:00', 60, 5) $$,
  '42501', null, 'alumno: no crea clases');
select throws_ok($$ select public.generate_sessions('f0000000-0000-4000-a000-000000000001', 4) $$,
  '42501', null, 'alumno: no genera el horario');
-- Con RLS correcta el alumno no "ve" la fila para modificarla: 0 filas, sin error
select lives_ok($$ update public.class_templates set capacity = 1 $$, 'alumno: su intento de editar no llega a ninguna fila');
select lives_ok($$ delete from public.class_sessions $$, 'alumno: su intento de borrar sesiones no llega a ninguna fila');
reset role;
select ok((select count(*) from public.class_sessions where template_id = 'f2000000-0000-4000-a000-000000000001') >= 27,
  'las sesiones siguen ahí tras el intento del alumno');

-- Profesor
select pg_temp.login('f9000000-0000-4000-a000-000000000002');
update public.class_templates set capacity = 99;
reset role;
select is((select capacity from public.class_templates where id = 'f2000000-0000-4000-a000-000000000001'), 20,
  'profesor: no cambia plantillas');

-- Administración
select pg_temp.login('f9000000-0000-4000-a000-000000000001');
insert into public.closures (gym_id, date_from, date_to, reason)
values ('f0000000-0000-4000-a000-000000000001', current_date + 1, current_date + 1, 'Festivo local');
reset role;
select is(
  (select count(*)::int from public.class_sessions where template_id = 'f2000000-0000-4000-a000-000000000001'
     and status = 'cancelled' and cancel_reason = 'Festivo local'),
  1, 'administración: añade un festivo y cancela la clase de ese día');

select * from finish();
rollback;
