-- Deshacer una asistencia confirmada por error (ver
-- 20260818193559_deshacer_asistencia.sql). Antes de esta migración
-- `asistencias` solo tenía GRANT de INSERT para `authenticated`: ni
-- siquiera con la política de fila correcta se podía borrar nada, porque
-- el permiso de tabla ni existía.
begin;
select plan(4);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000da01', 'dueno-deshacer-a@test.dev'),
  ('00000000-0000-0000-0000-00000000da02', 'profesor-deshacer-a@test.dev'),
  ('00000000-0000-0000-0000-00000000da03', 'alumno-deshacer-a@test.dev'),
  ('00000000-0000-0000-0000-00000000db01', 'dueno-deshacer-b@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000da0aa', 'Academia deshacer A', 'approved'),
  ('00000000-0000-0000-0000-0000000da0bb', 'Academia deshacer B', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-00000000da01',
   '00000000-0000-0000-0000-0000000da0aa', 'dueño', 'Dueño A', 'activo'),
  ('00000000-0000-0000-0000-00000000da02',
   '00000000-0000-0000-0000-0000000da0aa', 'profesor', 'Profesor A', 'activo'),
  ('00000000-0000-0000-0000-00000000da03',
   '00000000-0000-0000-0000-0000000da0aa', 'alumno', 'Alumno A', 'activo'),
  ('00000000-0000-0000-0000-00000000db01',
   '00000000-0000-0000-0000-0000000da0bb', 'dueño', 'Dueño B', 'activo');

insert into public.clases
  (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin,
   aforo_maximo)
values
  ('00000000-0000-0000-0000-0000000da0c1',
   '00000000-0000-0000-0000-0000000da0aa',
   '00000000-0000-0000-0000-00000000da02', 'Clase A',
   now() - interval '1 hour', now(), 20);

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

-- 1. GRANT de tabla: sin esto ninguna política de fila importa.
select ok(
  has_table_privilege('authenticated', 'public.asistencias', 'DELETE'),
  'authenticated tiene GRANT de DELETE en asistencias'
);

-- Asistencia marcada por el Dueño (para comprobar que el Profesor también
-- puede deshacerla: no está limitado a "quien la validó").
reset role;
insert into public.asistencias (clase_id, alumno_id, validado_por)
values (
  '00000000-0000-0000-0000-0000000da0c1',
  '00000000-0000-0000-0000-00000000da03',
  '00000000-0000-0000-0000-00000000da01'
);

-- 2. Un alumno no puede deshacer ninguna asistencia.
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000da03');

delete from public.asistencias
  where clase_id = '00000000-0000-0000-0000-0000000da0c1'
    and alumno_id = '00000000-0000-0000-0000-00000000da03';

reset role;

select is(
  (select count(*)::int from public.asistencias
    where clase_id = '00000000-0000-0000-0000-0000000da0c1'
      and alumno_id = '00000000-0000-0000-0000-00000000da03'),
  1,
  'Un alumno no puede deshacer una asistencia: la fila sigue ahí'
);

-- 3-4. El Profesor sí puede, aunque la validara el Dueño.
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000da02');

delete from public.asistencias
  where clase_id = '00000000-0000-0000-0000-0000000da0c1'
    and alumno_id = '00000000-0000-0000-0000-00000000da03';

reset role;

select is(
  (select count(*)::int from public.asistencias
    where clase_id = '00000000-0000-0000-0000-0000000da0c1'
      and alumno_id = '00000000-0000-0000-0000-00000000da03'),
  0,
  'El Profesor deshace una asistencia aunque la validara el Dueño'
);

-- 4. Aislamiento por academia: un dueño de otra academia no puede tocar
-- una asistencia ajena.
insert into public.asistencias (clase_id, alumno_id, validado_por)
values (
  '00000000-0000-0000-0000-0000000da0c1',
  '00000000-0000-0000-0000-00000000da03',
  '00000000-0000-0000-0000-00000000da02'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-00000000db01');

delete from public.asistencias
  where clase_id = '00000000-0000-0000-0000-0000000da0c1'
    and alumno_id = '00000000-0000-0000-0000-00000000da03';

reset role;

select is(
  (select count(*)::int from public.asistencias
    where clase_id = '00000000-0000-0000-0000-0000000da0c1'
      and alumno_id = '00000000-0000-0000-0000-00000000da03'),
  1,
  'Un dueño de otra academia no puede deshacer una asistencia ajena'
);

select * from finish();
rollback;
