-- Ranking por periodo (ver 20260818073509_ranking_periodo.sql): mismo
-- ranking de siempre, pero con un rango de fechas abierto en vez de un
-- único mes fijo. `p_desde`/`p_hasta` nulos son responsabilidad del
-- cliente (mes/año/siempre se calculan en Flutter); aquí solo se comprueba
-- que la propia RPC filtra bien el rango que le llegue, que sigue
-- incluyendo a los alumnos sin ninguna asistencia, y que sigue aislada por
-- academia.
begin;
select plan(7);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000ea01', 'dueno-ranking-a@test.dev'),
  ('00000000-0000-0000-0000-00000000ea02', 'alumno-a-ranking-a@test.dev'),
  ('00000000-0000-0000-0000-00000000ea03', 'alumno-b-ranking-a@test.dev'),
  ('00000000-0000-0000-0000-00000000ea04', 'alumno-c-ranking-a@test.dev'),
  ('00000000-0000-0000-0000-00000000eb01', 'dueno-ranking-b@test.dev'),
  ('00000000-0000-0000-0000-00000000eb02', 'alumno-ranking-b@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000ea0aa', 'Academia ranking A', 'approved'),
  ('00000000-0000-0000-0000-0000000ea0bb', 'Academia ranking B', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-00000000ea01',
   '00000000-0000-0000-0000-0000000ea0aa', 'dueño', 'Dueño A', 'activo'),
  ('00000000-0000-0000-0000-00000000ea02',
   '00000000-0000-0000-0000-0000000ea0aa', 'alumno', 'Alumno Uno', 'activo'),
  ('00000000-0000-0000-0000-00000000ea03',
   '00000000-0000-0000-0000-0000000ea0aa', 'alumno', 'Alumno Dos', 'activo'),
  ('00000000-0000-0000-0000-00000000ea04',
   '00000000-0000-0000-0000-0000000ea0aa', 'alumno', 'Alumno Sin Clases',
   'activo'),
  ('00000000-0000-0000-0000-00000000eb01',
   '00000000-0000-0000-0000-0000000ea0bb', 'dueño', 'Dueño B', 'activo'),
  ('00000000-0000-0000-0000-00000000eb02',
   '00000000-0000-0000-0000-0000000ea0bb', 'alumno', 'Alumno B', 'activo');

-- Una clase por asistencia: `asistencias` tiene único (clase_id, alumno_id),
-- así que cada asistencia de un mismo alumno necesita su propia clase. La
-- fecha de la clase es irrelevante aquí; lo que cuenta es `asistencias.fecha`.
insert into public.clases
  (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin,
   aforo_maximo)
values
  ('00000000-0000-0000-0000-0000000ea0c1',
   '00000000-0000-0000-0000-0000000ea0aa',
   '00000000-0000-0000-0000-00000000ea01', 'Clase 1',
   '2024-01-10', '2024-01-10 01:00', 20),
  ('00000000-0000-0000-0000-0000000ea0c2',
   '00000000-0000-0000-0000-0000000ea0aa',
   '00000000-0000-0000-0000-00000000ea01', 'Clase 2',
   '2024-01-20', '2024-01-20 01:00', 20),
  ('00000000-0000-0000-0000-0000000ea0c3',
   '00000000-0000-0000-0000-0000000ea0aa',
   '00000000-0000-0000-0000-00000000ea01', 'Clase 3',
   '2024-03-05', '2024-03-05 01:00', 20),
  ('00000000-0000-0000-0000-0000000ea0c4',
   '00000000-0000-0000-0000-0000000ea0aa',
   '00000000-0000-0000-0000-00000000ea01', 'Clase 4',
   '2024-01-25', '2024-01-25 01:00', 20),
  ('00000000-0000-0000-0000-0000000ea0c5',
   '00000000-0000-0000-0000-0000000ea0aa',
   '00000000-0000-0000-0000-00000000ea01', 'Clase 5',
   '2023-12-01', '2023-12-01 01:00', 20),
  ('00000000-0000-0000-0000-0000000eb0c1',
   '00000000-0000-0000-0000-0000000ea0bb',
   '00000000-0000-0000-0000-00000000eb01', 'Clase academia B',
   '2024-01-15', '2024-01-15 01:00', 20);

-- Alumno Uno: dos asistencias en enero de 2024, una en marzo de 2024.
insert into public.asistencias (clase_id, alumno_id, validado_por, fecha)
values
  ('00000000-0000-0000-0000-0000000ea0c1', '00000000-0000-0000-0000-00000000ea02',
   '00000000-0000-0000-0000-00000000ea01', '2024-01-10'),
  ('00000000-0000-0000-0000-0000000ea0c2', '00000000-0000-0000-0000-00000000ea02',
   '00000000-0000-0000-0000-00000000ea01', '2024-01-20'),
  ('00000000-0000-0000-0000-0000000ea0c3', '00000000-0000-0000-0000-00000000ea02',
   '00000000-0000-0000-0000-00000000ea01', '2024-03-05'),
  -- Alumno Dos: una en enero de 2024, una en diciembre de 2023.
  ('00000000-0000-0000-0000-0000000ea0c4', '00000000-0000-0000-0000-00000000ea03',
   '00000000-0000-0000-0000-00000000ea01', '2024-01-25'),
  ('00000000-0000-0000-0000-0000000ea0c5', '00000000-0000-0000-0000-00000000ea03',
   '00000000-0000-0000-0000-00000000ea01', '2023-12-01'),
  -- Alumno de la academia B, dentro del mismo rango de enero.
  ('00000000-0000-0000-0000-0000000eb0c1', '00000000-0000-0000-0000-00000000eb02',
   '00000000-0000-0000-0000-00000000eb01', '2024-01-15');

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

-- 1-2. Rango de enero de 2024: solo cuentan las asistencias de ese mes.
select is(
  (select asistencias_count from public.ranking_periodo('2024-01-01', '2024-01-31')
    where alumno_id = '00000000-0000-0000-0000-00000000ea02'),
  2::bigint,
  'Alumno Uno: solo las 2 asistencias de enero, no la de marzo'
);

select is(
  (select asistencias_count from public.ranking_periodo('2024-01-01', '2024-01-31')
    where alumno_id = '00000000-0000-0000-0000-00000000ea03'),
  1::bigint,
  'Alumno Dos: solo la asistencia de enero, no la de diciembre de 2023'
);

-- 3. Fuera de rango: marzo no tiene ninguna asistencia de Alumno Dos.
select is(
  (select asistencias_count from public.ranking_periodo('2024-03-01', '2024-03-31')
    where alumno_id = '00000000-0000-0000-0000-00000000ea03'),
  0::bigint,
  'Alumno Dos no tiene ninguna asistencia en marzo de 2024'
);

-- 4-5. Sin rango (desde siempre): cuentan todas, sin importar la fecha.
select is(
  (select asistencias_count from public.ranking_periodo(null, null)
    where alumno_id = '00000000-0000-0000-0000-00000000ea02'),
  3::bigint,
  'Sin rango, Alumno Uno suma sus 3 asistencias de cualquier fecha'
);

select is(
  (select asistencias_count from public.ranking_periodo(null, null)
    where alumno_id = '00000000-0000-0000-0000-00000000ea03'),
  2::bigint,
  'Sin rango, Alumno Dos suma sus 2 asistencias de cualquier fecha'
);

-- 6. Sigue incluyendo a quien no tiene ninguna asistencia, con 0.
select is(
  (select asistencias_count from public.ranking_periodo(null, null)
    where alumno_id = '00000000-0000-0000-0000-00000000ea04'),
  0::bigint,
  'Un alumno sin ninguna asistencia sigue apareciendo, con 0'
);

-- 7. Aislamiento por academia: el alumno de la academia B nunca aparece.
select is(
  (select count(*)::int from public.ranking_periodo(null, null)
    where alumno_id = '00000000-0000-0000-0000-00000000eb02'),
  0,
  'El ranking de la academia A nunca incluye a un alumno de la academia B'
);

select * from finish();
rollback;
