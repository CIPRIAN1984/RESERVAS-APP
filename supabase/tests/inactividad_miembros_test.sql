-- Inactividad en Miembros (ver 20260830090000_inactividad_miembros.sql):
-- cuándo entrenó cada alumno por última vez. Lo que hay que proteger es que
-- la fecha sea la MÁS RECIENTE (no la primera, ni cualquiera), que quien no
-- tiene ninguna asistencia simplemente no aparezca (el cliente lo entiende
-- como "nunca ha venido"), que un Profesor/Dueño/Administrador nunca cuenten
-- como alumnos inactivos, y el aislamiento de siempre entre academias.
begin;
select plan(5);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000001a01', 'dueno-inactividad-a@test.dev'),
  ('00000000-0000-0000-0000-000000001a02', 'alumno-a-inactividad-a@test.dev'),
  ('00000000-0000-0000-0000-000000001a03', 'alumno-b-inactividad-a@test.dev'),
  ('00000000-0000-0000-0000-000000001b01', 'dueno-inactividad-b@test.dev'),
  ('00000000-0000-0000-0000-000000001b02', 'alumno-inactividad-b@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-00000001a0aa', 'Academia inactividad A', 'approved'),
  ('00000000-0000-0000-0000-00000001a0bb', 'Academia inactividad B', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-000000001a01',
   '00000000-0000-0000-0000-00000001a0aa', 'dueño', 'Dueño A', 'activo'),
  ('00000000-0000-0000-0000-000000001a02',
   '00000000-0000-0000-0000-00000001a0aa', 'alumno', 'Alumno Activo',
   'activo'),
  ('00000000-0000-0000-0000-000000001a03',
   '00000000-0000-0000-0000-00000001a0aa', 'alumno', 'Alumno Nunca',
   'activo'),
  ('00000000-0000-0000-0000-000000001b01',
   '00000000-0000-0000-0000-00000001a0bb', 'dueño', 'Dueño B', 'activo'),
  ('00000000-0000-0000-0000-000000001b02',
   '00000000-0000-0000-0000-00000001a0bb', 'alumno', 'Alumno B', 'activo');

-- Una clase por asistencia: `asistencias` tiene único (clase_id, alumno_id).
insert into public.clases
  (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin,
   aforo_maximo)
values
  ('00000000-0000-0000-0000-00000001a0c1',
   '00000000-0000-0000-0000-00000001a0aa',
   '00000000-0000-0000-0000-000000001a01', 'Clase antigua',
   '2024-01-10', '2024-01-10 01:00', 20),
  ('00000000-0000-0000-0000-00000001a0c2',
   '00000000-0000-0000-0000-00000001a0aa',
   '00000000-0000-0000-0000-000000001a01', 'Clase reciente',
   '2024-03-05', '2024-03-05 01:00', 20),
  ('00000000-0000-0000-0000-00000001a0c3',
   '00000000-0000-0000-0000-00000001a0aa',
   '00000000-0000-0000-0000-000000001a01', 'Clase del Dueño',
   '2024-03-06', '2024-03-06 01:00', 20),
  ('00000000-0000-0000-0000-00000001b0c1',
   '00000000-0000-0000-0000-00000001a0bb',
   '00000000-0000-0000-0000-000000001b01', 'Clase academia B',
   '2024-02-01', '2024-02-01 01:00', 20);

-- Alumno Activo: dos asistencias, la más reciente en marzo.
-- Alumno Nunca: ninguna.
-- El Dueño también tiene una asistencia (a veces entrena con ellos), pero
-- no es un Alumno: no debe contar aquí.
insert into public.asistencias (clase_id, alumno_id, validado_por, fecha)
values
  ('00000000-0000-0000-0000-00000001a0c1', '00000000-0000-0000-0000-000000001a02',
   '00000000-0000-0000-0000-000000001a01', '2024-01-10'),
  ('00000000-0000-0000-0000-00000001a0c2', '00000000-0000-0000-0000-000000001a02',
   '00000000-0000-0000-0000-000000001a01', '2024-03-05'),
  ('00000000-0000-0000-0000-00000001a0c3', '00000000-0000-0000-0000-000000001a01',
   '00000000-0000-0000-0000-000000001a01', '2024-03-06'),
  ('00000000-0000-0000-0000-00000001b0c1', '00000000-0000-0000-0000-000000001b02',
   '00000000-0000-0000-0000-000000001b01', '2024-02-01');

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
    'anon', 'public.ultima_asistencia_por_alumno()', 'EXECUTE'
  ),
  'Sin iniciar sesión no se puede alcanzar la función'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-000000001a01');

-- 1. Se queda con la fecha MÁS RECIENTE, no la primera.
select is(
  (select ultima_asistencia from public.ultima_asistencia_por_alumno()
    where alumno_id = '00000000-0000-0000-0000-000000001a02'),
  '2024-03-05'::timestamptz,
  'Del Alumno Activo se queda con la asistencia de marzo, no la de enero'
);

-- 2. Quien no tiene ninguna asistencia no aparece (el cliente lo entiende
-- como "nunca ha venido" por su ausencia en el resultado).
select is(
  (select count(*)::int from public.ultima_asistencia_por_alumno()
    where alumno_id = '00000000-0000-0000-0000-000000001a03'),
  0,
  'Alumno Nunca no aparece: no tiene ninguna asistencia registrada'
);

-- 3. El Dueño entrenó igual que un alumno, pero no es un Alumno: no cuenta.
select is(
  (select count(*)::int from public.ultima_asistencia_por_alumno()
    where alumno_id = '00000000-0000-0000-0000-000000001a01'),
  0,
  'El Dueño no aparece aunque tenga una asistencia: no es un Alumno'
);

-- 4. Aislamiento por academia: el alumno de la academia B nunca aparece.
select is(
  (select count(*)::int from public.ultima_asistencia_por_alumno()
    where alumno_id = '00000000-0000-0000-0000-000000001b02'),
  0,
  'No se ve la última asistencia de un alumno de otra academia'
);

select * from finish();
rollback;
