-- Punto 5 de la auditoría externa: una asistencia solo se puede validar
-- sobre un alumno que de verdad tiene una reserva 'inscrito' en esa clase
-- (ver 20260920120000_candado_asistencia_reserva_valida.sql).
begin;
select plan(5);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000ea01', 'dueno-candado-a@test.dev'),
  ('00000000-0000-0000-0000-00000000ea02', 'alumno-inscrito-a@test.dev'),
  ('00000000-0000-0000-0000-00000000ea03', 'alumno-espera-a@test.dev'),
  ('00000000-0000-0000-0000-00000000ea04', 'alumno-cancelado-a@test.dev'),
  ('00000000-0000-0000-0000-00000000ea05', 'alumno-sin-reserva-a@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000ea0aa', 'Academia candado asistencia', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-00000000ea01',
   '00000000-0000-0000-0000-0000000ea0aa', 'dueño', 'Dueño candado', 'activo'),
  ('00000000-0000-0000-0000-00000000ea02',
   '00000000-0000-0000-0000-0000000ea0aa', 'alumno', 'Alumno inscrito', 'activo'),
  ('00000000-0000-0000-0000-00000000ea03',
   '00000000-0000-0000-0000-0000000ea0aa', 'alumno', 'Alumno en espera', 'activo'),
  ('00000000-0000-0000-0000-00000000ea04',
   '00000000-0000-0000-0000-0000000ea0aa', 'alumno', 'Alumno cancelado', 'activo'),
  ('00000000-0000-0000-0000-00000000ea05',
   '00000000-0000-0000-0000-0000000ea0aa', 'alumno', 'Alumno sin reserva', 'activo');

insert into public.clases
  (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin,
   aforo_maximo)
values
  ('00000000-0000-0000-0000-0000000ea0c1',
   '00000000-0000-0000-0000-0000000ea0aa',
   '00000000-0000-0000-0000-00000000ea01', 'Clase candado',
   now() - interval '1 hour', now(), 20);

insert into public.inscripciones (clase_id, alumno_id, academia_id, estado) values
  ('00000000-0000-0000-0000-0000000ea0c1', '00000000-0000-0000-0000-00000000ea02',
   '00000000-0000-0000-0000-0000000ea0aa', 'inscrito'),
  ('00000000-0000-0000-0000-0000000ea0c1', '00000000-0000-0000-0000-00000000ea03',
   '00000000-0000-0000-0000-0000000ea0aa', 'espera'),
  ('00000000-0000-0000-0000-0000000ea0c1', '00000000-0000-0000-0000-00000000ea04',
   '00000000-0000-0000-0000-0000000ea0aa', 'cancelado');
-- Alumno ea05 no tiene ninguna fila en inscripciones para esta clase.

create or replace function pg_temp.actuar_como(p_uid uuid)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text,
    true
  );
  perform set_config('role', 'authenticated', true);
end;
$$;

select pg_temp.actuar_como('00000000-0000-0000-0000-00000000ea01');

-- 1. El dueño SÍ puede validar a quien tiene una reserva 'inscrito'.
select lives_ok(
  $$ insert into public.asistencias (clase_id, alumno_id, validado_por)
     values ('00000000-0000-0000-0000-0000000ea0c1',
             '00000000-0000-0000-0000-00000000ea02',
             '00000000-0000-0000-0000-00000000ea01') $$,
  'El dueño valida sin problema a un alumno con reserva inscrita'
);

-- 2. No puede validar a quien nunca reservó esta clase.
select throws_ok(
  $$ insert into public.asistencias (clase_id, alumno_id, validado_por)
     values ('00000000-0000-0000-0000-0000000ea0c1',
             '00000000-0000-0000-0000-00000000ea05',
             '00000000-0000-0000-0000-00000000ea01') $$,
  'new row violates row-level security policy for table "asistencias"',
  'No se puede marcar presente a un alumno sin ninguna reserva en la clase'
);

-- 3. Estar en lista de espera no cuenta como reserva válida.
select throws_ok(
  $$ insert into public.asistencias (clase_id, alumno_id, validado_por)
     values ('00000000-0000-0000-0000-0000000ea0c1',
             '00000000-0000-0000-0000-00000000ea03',
             '00000000-0000-0000-0000-00000000ea01') $$,
  'new row violates row-level security policy for table "asistencias"',
  'Estar en lista de espera no basta para validar asistencia'
);

-- 4. Una reserva cancelada tampoco cuenta.
select throws_ok(
  $$ insert into public.asistencias (clase_id, alumno_id, validado_por)
     values ('00000000-0000-0000-0000-0000000ea0c1',
             '00000000-0000-0000-0000-00000000ea04',
             '00000000-0000-0000-0000-00000000ea01') $$,
  'new row violates row-level security policy for table "asistencias"',
  'Una reserva cancelada no permite validar asistencia'
);

reset role;

-- 5. Ninguno de los tres intentos rechazados dejó fila en asistencias.
select is(
  (select count(*)::int from public.asistencias
    where clase_id = '00000000-0000-0000-0000-0000000ea0c1'
      and alumno_id in ('00000000-0000-0000-0000-00000000ea03',
                         '00000000-0000-0000-0000-00000000ea04',
                         '00000000-0000-0000-0000-00000000ea05')),
  0,
  'Ningún intento sin reserva válida deja rastro en asistencias'
);

select * from finish();
rollback;
