-- Crear una clase repetida varias semanas: todas o ninguna, sin duplicar
-- al repetir y sin saltos de hora; y el botón del horario fijo vuelve a
-- funcionar (auditoría externa del 09/10/2026, punto 5; ver
-- 20261009130000_horario_repetido.sql).
begin;
select plan(14);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000ec001', 'dueno-hr@test.dev'),
  ('00000000-0000-0000-0000-0000000ec002', 'profe-hr@test.dev'),
  ('00000000-0000-0000-0000-0000000ec003', 'alumno-hr@test.dev'),
  ('00000000-0000-0000-0000-0000000ec009', 'sin-perfil-hr@test.dev');

insert into public.academias (id, nombre, estado, zona_horaria) values
  ('00000000-0000-0000-0000-0000000ec0aa', 'Academia horario', 'approved', 'Europe/Madrid');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000ec001', '00000000-0000-0000-0000-0000000ec0aa', 'dueño', 'Dueño', 'activo'),
  ('00000000-0000-0000-0000-0000000ec002', '00000000-0000-0000-0000-0000000ec0aa', 'profesor', 'Profe', 'activo'),
  ('00000000-0000-0000-0000-0000000ec003', '00000000-0000-0000-0000-0000000ec0aa', 'alumno', 'Alumno', 'activo');

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

create or replace function pg_temp.cuantas(p_titulo text) returns int language sql as $$
  select count(*)::int from public.clases
   where academia_id = '00000000-0000-0000-0000-0000000ec0aa' and titulo = p_titulo;
$$;

-- ------------------------------------------------------------
-- 1. Tres martes seguidos que cruzan el cambio de hora (31/10/2027)
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ec001');
select is(
  public.crear_clases('BJJ martes', null, '2027-10-26', '19:00', '20:00', 15, 3),
  3,
  'Crea las tres semanas de una vez'
);
reset role;
select is(
  array(select to_char(fecha_hora_inicio at time zone 'Europe/Madrid', 'DD/MM HH24:MI')
          from public.clases where titulo = 'BJJ martes' order by fecha_hora_inicio),
  array['26/10 19:00', '02/11 19:00', '09/11 19:00'],
  'Las tres a las 19:00 de Logroño, antes y después del cambio de hora'
);
select is(
  array(select to_char(fecha_hora_fin at time zone 'Europe/Madrid', 'HH24:MI')
          from public.clases where titulo = 'BJJ martes' order by fecha_hora_inicio),
  array['20:00', '20:00', '20:00'],
  'Y acaban a las 20:00'
);
select isnt(
  (select to_char(fecha_hora_inicio at time zone 'UTC', 'HH24') from public.clases
    where titulo = 'BJJ martes' order by fecha_hora_inicio limit 1),
  (select to_char(fecha_hora_inicio at time zone 'UTC', 'HH24') from public.clases
    where titulo = 'BJJ martes' order by fecha_hora_inicio desc limit 1),
  'En hora universal sí cambian: sumar 7 días exactos las habría movido una hora'
);

-- ------------------------------------------------------------
-- 2. Repetir no duplica; un error no deja nada a medias
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ec001');
select is(
  public.crear_clases('BJJ martes', null, '2027-10-26', '19:00', '20:00', 15, 4),
  1,
  'Repetir con una semana más solo crea la que faltaba'
);
reset role;
select is(pg_temp.cuantas('BJJ martes'), 4, 'Y no hay ninguna duplicada');

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ec001');
select throws_ok(
  $$ select public.crear_clases('Rota', null, '2027-10-26', '20:00', '19:00', 15, 3) $$,
  'La hora de fin debe ser posterior a la de inicio.',
  'Una hora de fin anterior se rechaza'
);
select throws_ok(
  $$ select public.crear_clases('Demasiadas', null, '2027-10-26', '19:00', '20:00', 15, 53) $$,
  'Se pueden repetir entre 1 y 52 semanas.',
  'Más de 52 semanas se rechaza'
);
reset role;
select is(pg_temp.cuantas('Rota') + pg_temp.cuantas('Demasiadas'), 0, 'Y no queda nada creado a medias');

-- ------------------------------------------------------------
-- 3. Quién puede
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ec002');
select is(
  public.crear_clases('De la profe', 'Con descripción', '2027-11-02', '10:00', '11:00', 8),
  1,
  'Un profesor crea una clase suelta'
);
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ec003');
select throws_ok(
  $$ select public.crear_clases('Del alumno', null, '2027-11-02', '10:00', '11:00', 8) $$,
  'Solo el Dueño o un Profesor pueden crear clases.',
  'Un alumno no'
);
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ec009');
select throws_ok(
  $$ select public.crear_clases('Sin perfil', null, '2027-11-02', '10:00', '11:00', 8) $$,
  'Solo el Dueño o un Profesor pueden crear clases.',
  'Ni una cuenta sin perfil'
);

-- ------------------------------------------------------------
-- 4. El botón del horario fijo vuelve a funcionar
-- ------------------------------------------------------------
reset role;
insert into public.clases_recurrentes (academia_id, profesor_id, titulo, dia_semana, hora_inicio, duracion_min, aforo_maximo)
values ('00000000-0000-0000-0000-0000000ec0aa', '00000000-0000-0000-0000-0000000ec001', 'Fija',
        extract(dow from current_date + 1)::int, '19:00', 60, 15);
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ec001');
select is(
  public.generar_mis_clases_recurrentes(),
  4,
  'Genera las 4 semanas siguientes (antes fallaba siempre)'
);
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ec009');
select throws_ok(
  $$ select public.generar_mis_clases_recurrentes() $$,
  'Solo profesor o dueño pueden generar clases.',
  'Una cuenta sin perfil no genera clases'
);

select * from finish();
rollback;
