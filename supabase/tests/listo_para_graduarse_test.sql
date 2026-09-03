-- Listo para graduarse (ver 20260901090000_listo_para_graduarse.sql): en
-- bruto, cuántos entrenos lleva cada alumno desde que empezó su cinturón
-- actual, y si es menor de edad. Lo que hay que proteger: que solo cuenten
-- los entrenos DESPUÉS de fecha_inicio_cinturon (uno de antes no debe
-- sumar, o un alumno recién promovido aparecería ya listo para lo
-- siguiente), que detecte bien quién es menor, que un Dueño/Profesor nunca
-- cuente como alumno, y el aislamiento de siempre entre academias.
begin;
select plan(6);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000002a01', 'dueno-graduarse-a@test.dev'),
  ('00000000-0000-0000-0000-000000002a02', 'alumno-a-graduarse-a@test.dev'),
  ('00000000-0000-0000-0000-000000002a03', 'alumno-b-graduarse-a@test.dev'),
  ('00000000-0000-0000-0000-000000002a04', 'padre-graduarse-a@test.dev'),
  ('00000000-0000-0000-0000-000000002b01', 'dueno-graduarse-b@test.dev'),
  ('00000000-0000-0000-0000-000000002b02', 'alumno-graduarse-b@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-00000002a0aa', 'Academia graduarse A', 'approved'),
  ('00000000-0000-0000-0000-00000002a0bb', 'Academia graduarse B', 'approved');

insert into public.profiles
  (id, academia_id, rol, nombre, estado, fecha_inicio_cinturon) values
  ('00000000-0000-0000-0000-000000002a01',
   '00000000-0000-0000-0000-00000002a0aa', 'dueño', 'Dueño A', 'activo',
   '2024-02-01'),
  -- Empezó su cinturón el 1 de febrero: solo cuentan entrenos desde ahí.
  ('00000000-0000-0000-0000-000000002a02',
   '00000000-0000-0000-0000-00000002a0aa', 'alumno', 'Alumno Adulto',
   'activo', '2024-02-01'),
  -- Menor de edad (tiene un padre registrado).
  ('00000000-0000-0000-0000-000000002a03',
   '00000000-0000-0000-0000-00000002a0aa', 'alumno', 'Alumno Menor',
   'activo', '2024-02-01'),
  ('00000000-0000-0000-0000-000000002a04',
   '00000000-0000-0000-0000-00000002a0aa', 'alumno', 'Padre', 'activo',
   '2024-02-01'),
  ('00000000-0000-0000-0000-000000002b01',
   '00000000-0000-0000-0000-00000002a0bb', 'dueño', 'Dueño B', 'activo',
   '2024-02-01'),
  ('00000000-0000-0000-0000-000000002b02',
   '00000000-0000-0000-0000-00000002a0bb', 'alumno', 'Alumno B', 'activo',
   '2024-02-01');

insert into public.relaciones_familia (parent_id, child_id) values
  ('00000000-0000-0000-0000-000000002a04', '00000000-0000-0000-0000-000000002a03');

-- Una clase por asistencia: `asistencias` tiene único (clase_id, alumno_id).
insert into public.clases
  (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin,
   aforo_maximo)
values
  ('00000000-0000-0000-0000-00000002a0c1',
   '00000000-0000-0000-0000-00000002a0aa',
   '00000000-0000-0000-0000-000000002a01', 'Clase antes de promocionar',
   '2024-01-15', '2024-01-15 01:00', 20),
  ('00000000-0000-0000-0000-00000002a0c2',
   '00000000-0000-0000-0000-00000002a0aa',
   '00000000-0000-0000-0000-000000002a01', 'Clase después',
   '2024-02-10', '2024-02-10 01:00', 20),
  ('00000000-0000-0000-0000-00000002a0c3',
   '00000000-0000-0000-0000-00000002a0aa',
   '00000000-0000-0000-0000-000000002a01', 'Clase después 2',
   '2024-02-20', '2024-02-20 01:00', 20),
  ('00000000-0000-0000-0000-00000002b0c1',
   '00000000-0000-0000-0000-00000002a0bb',
   '00000000-0000-0000-0000-000000002b01', 'Clase academia B',
   '2024-02-15', '2024-02-15 01:00', 20);

-- Alumno Adulto: una asistencia ANTES de la fecha de inicio de cinturón (no
-- debe contar) y dos DESPUÉS (sí deben contar) → total esperado: 2.
insert into public.asistencias (clase_id, alumno_id, validado_por, fecha)
values
  ('00000000-0000-0000-0000-00000002a0c1', '00000000-0000-0000-0000-000000002a02',
   '00000000-0000-0000-0000-000000002a01', '2024-01-15'),
  ('00000000-0000-0000-0000-00000002a0c2', '00000000-0000-0000-0000-000000002a02',
   '00000000-0000-0000-0000-000000002a01', '2024-02-10'),
  ('00000000-0000-0000-0000-00000002a0c3', '00000000-0000-0000-0000-000000002a02',
   '00000000-0000-0000-0000-000000002a01', '2024-02-20'),
  ('00000000-0000-0000-0000-00000002b0c1', '00000000-0000-0000-0000-000000002b02',
   '00000000-0000-0000-0000-000000002b01', '2024-02-15');

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

select ok(
  not has_function_privilege(
    'anon', 'public.progreso_graduacion_alumnos()', 'EXECUTE'
  ),
  'Sin iniciar sesión no se puede alcanzar la función'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-000000002a01');

-- 1. Solo cuentan los entrenos DESPUÉS de empezar el cinturón actual.
select is(
  (select asistencias from public.progreso_graduacion_alumnos()
    where alumno_id = '00000000-0000-0000-0000-000000002a02'),
  2::bigint,
  'La asistencia de antes de promocionar no cuenta para el cinturón actual'
);

-- 2. Detecta bien a un menor (tiene un padre/tutor registrado).
select is(
  (select es_menor from public.progreso_graduacion_alumnos()
    where alumno_id = '00000000-0000-0000-0000-000000002a03'),
  true,
  'Alumno Menor se detecta como menor de edad'
);

-- 3. Y a quien no lo es.
select is(
  (select es_menor from public.progreso_graduacion_alumnos()
    where alumno_id = '00000000-0000-0000-0000-000000002a02'),
  false,
  'Alumno Adulto no se detecta como menor'
);

-- 4. El Dueño no es un Alumno: no aparece aunque tenga fecha_inicio_cinturon.
select is(
  (select count(*)::int from public.progreso_graduacion_alumnos()
    where alumno_id = '00000000-0000-0000-0000-000000002a01'),
  0,
  'El Dueño no aparece: no es un Alumno'
);

-- 5. Aislamiento por academia.
select is(
  (select count(*)::int from public.progreso_graduacion_alumnos()
    where alumno_id = '00000000-0000-0000-0000-000000002b02'),
  0,
  'No se ve el progreso de un alumno de otra academia'
);

select * from finish();
rollback;
