-- Solo se confirma asistencia de una clase que ya ha empezado o empieza en
-- menos de media hora (ver 20260925100000_pasar_lista_solo_con_la_clase_empezada.sql).
begin;
select plan(5);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000a1001', 'dueno-lista@test.dev'),
  ('00000000-0000-0000-0000-0000000a1002', 'alumno-lista@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000a10aa', 'Academia pasar lista', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-0000000a10aa', 'dueño', 'Dueño', 'activo'),
  ('00000000-0000-0000-0000-0000000a1002', '00000000-0000-0000-0000-0000000a10aa', 'alumno', 'Alumno', 'activo');

insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-0000000a1c01', '00000000-0000-0000-0000-0000000a10aa', '00000000-0000-0000-0000-0000000a1001', 'Mañana', now() + interval '1 day', now() + interval '1 day 1 hour', 10),
  ('00000000-0000-0000-0000-0000000a1c02', '00000000-0000-0000-0000-0000000a10aa', '00000000-0000-0000-0000-0000000a1001', 'En dos horas', now() + interval '2 hours', now() + interval '3 hours', 10),
  ('00000000-0000-0000-0000-0000000a1c03', '00000000-0000-0000-0000-0000000a10aa', '00000000-0000-0000-0000-0000000a1001', 'En 20 minutos', now() + interval '20 minutes', now() + interval '80 minutes', 10),
  ('00000000-0000-0000-0000-0000000a1c04', '00000000-0000-0000-0000-0000000a10aa', '00000000-0000-0000-0000-0000000a1001', 'Ya empezó', now() - interval '1 hour', now(), 10);

insert into public.inscripciones (clase_id, alumno_id, academia_id, estado)
select c, '00000000-0000-0000-0000-0000000a1002', '00000000-0000-0000-0000-0000000a10aa', 'inscrito'
  from unnest(array[
    '00000000-0000-0000-0000-0000000a1c01',
    '00000000-0000-0000-0000-0000000a1c02',
    '00000000-0000-0000-0000-0000000a1c03',
    '00000000-0000-0000-0000-0000000a1c04'
  ]::uuid[]) as c;

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000a1001');

select throws_ok(
  $$ insert into public.asistencias (clase_id, alumno_id, validado_por)
     values ('00000000-0000-0000-0000-0000000a1c01', '00000000-0000-0000-0000-0000000a1002', '00000000-0000-0000-0000-0000000a1001') $$,
  'new row violates row-level security policy for table "asistencias"',
  'No se puede confirmar hoy la asistencia a una clase de mañana'
);
select throws_ok(
  $$ insert into public.asistencias (clase_id, alumno_id, validado_por)
     values ('00000000-0000-0000-0000-0000000a1c02', '00000000-0000-0000-0000-0000000a1002', '00000000-0000-0000-0000-0000000a1001') $$,
  'new row violates row-level security policy for table "asistencias"',
  'Ni a una que empieza dentro de dos horas'
);
select lives_ok(
  $$ insert into public.asistencias (clase_id, alumno_id, validado_por)
     values ('00000000-0000-0000-0000-0000000a1c03', '00000000-0000-0000-0000-0000000a1002', '00000000-0000-0000-0000-0000000a1001') $$,
  'Sí a una que empieza en 20 minutos: se marca a la gente según llega'
);
select lives_ok(
  $$ insert into public.asistencias (clase_id, alumno_id, validado_por)
     values ('00000000-0000-0000-0000-0000000a1c04', '00000000-0000-0000-0000-0000000a1002', '00000000-0000-0000-0000-0000000a1001') $$,
  'Y a una que ya ha empezado (o terminado: se puede pasar lista tarde)'
);

reset role;
select is(
  (select count(*)::int from public.asistencias
    where alumno_id = '00000000-0000-0000-0000-0000000a1002'),
  2,
  'Solo quedan las dos asistencias permitidas'
);

select * from finish();
rollback;
