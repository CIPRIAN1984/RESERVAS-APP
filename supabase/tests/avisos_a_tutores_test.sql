-- Tests pgTAP de que los avisos de un menor sin cuenta llegan a su tutor,
-- no a un user_id sin ningún dispositivo registrado.

begin;
select plan(10);

-- ── Semilla ──────────────────────────────────────────────────────────────
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000b1', 'duenoAT@test.dev'),
  ('00000000-0000-0000-0000-0000000000b2', 'tutorAT@test.dev'),
  ('00000000-0000-0000-0000-0000000000b5', 'adultoAT@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-000000000ba1', 'Academia Avisos Tutores', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado, tiene_cuenta) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-000000000ba1', 'dueño', 'Dueño AT', 'activo', true),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-000000000ba1', 'alumno', 'Tutor AT', 'activo', true),
  ('00000000-0000-0000-0000-0000000000b5', '00000000-0000-0000-0000-000000000ba1', 'alumno', 'Adulto AT', 'activo', true);

-- Los hijos: perfiles normales sin cuenta propia (sin fila en auth.users).
insert into public.profiles (id, academia_id, rol, nombre, estado, tiene_cuenta) values
  ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-000000000ba1', 'alumno', 'Hijo Uno AT', 'activo', false),
  ('00000000-0000-0000-0000-0000000000b4', '00000000-0000-0000-0000-000000000ba1', 'alumno', 'Hijo Dos AT', 'activo', false);

insert into public.relaciones_familia (parent_id, child_id) values
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000b3'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000b4');

-- Tres clases futuras.
insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-000000000ba1', '00000000-0000-0000-0000-0000000000b1', 'Clase AT 1', now() + interval '1 day', now() + interval '1 day 1 hour', 2),
  ('00000000-0000-0000-0000-000000000c02', '00000000-0000-0000-0000-000000000ba1', '00000000-0000-0000-0000-0000000000b1', 'Clase AT 2', now() + interval '1 day', now() + interval '1 day 1 hour', 5),
  ('00000000-0000-0000-0000-000000000c03', '00000000-0000-0000-0000-000000000ba1', '00000000-0000-0000-0000-0000000000b1', 'Clase AT 3', now() + interval '1 day', now() + interval '1 day 1 hour', 1);

-- Clase 1: el hijo uno y el adulto independiente, inscritos.
insert into public.inscripciones (clase_id, alumno_id, academia_id, estado) values
  ('00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-000000000ba1', 'inscrito'),
  ('00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-0000000000b5', '00000000-0000-0000-0000-000000000ba1', 'inscrito');

-- Clase 2: solo el hijo uno, inscrito.
insert into public.inscripciones (clase_id, alumno_id, academia_id, estado) values
  ('00000000-0000-0000-0000-000000000c02', '00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-000000000ba1', 'inscrito');

-- Clase 3: aforo 1, hijo uno inscrito, hijo dos en espera.
insert into public.inscripciones (clase_id, alumno_id, academia_id, estado) values
  ('00000000-0000-0000-0000-000000000c03', '00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-000000000ba1', 'inscrito'),
  ('00000000-0000-0000-0000-000000000c03', '00000000-0000-0000-0000-0000000000b4', '00000000-0000-0000-0000-000000000ba1', 'espera');

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- ── 1-3. Cancelar una clase notifica al tutor por el hijo, y al adulto por sí mismo ──
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000b1');
select public.cancelar_clase('00000000-0000-0000-0000-000000000c01');

-- notificaciones_outbox está revocada por completo a authenticated: hay que
-- consultarla como el propio rol de la migración/prueba, no como el dueño.
reset role;
select ok(
  exists (
    select 1 from public.notificaciones_outbox
    where user_id = '00000000-0000-0000-0000-0000000000b2'
      and data ->> 'type' = 'clase_cancelada'
      and data ->> 'clase_id' = '00000000-0000-0000-0000-000000000c01'
  ),
  'Al cancelar la clase del hijo, el aviso llega al tutor'
);
select ok(
  not exists (
    select 1 from public.notificaciones_outbox
    where user_id = '00000000-0000-0000-0000-0000000000b3'
  ),
  'El hijo nunca es el user_id de ningún aviso: no tiene dispositivo al que llegar'
);
select ok(
  exists (
    select 1 from public.notificaciones_outbox
    where user_id = '00000000-0000-0000-0000-0000000000b5'
      and data ->> 'type' = 'clase_cancelada'
  ),
  'El adulto independiente recibe su propio aviso, sin cambios'
);

-- ── 4-5. Editar el horario de una clase notifica al tutor por el hijo ──────
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000b1');
select public.editar_clase(
  '00000000-0000-0000-0000-000000000c02',
  'Clase AT 2 (reprogramada)',
  null,
  now() + interval '3 days',
  now() + interval '3 days 1 hour',
  5
);

reset role;
select ok(
  exists (
    select 1 from public.notificaciones_outbox
    where user_id = '00000000-0000-0000-0000-0000000000b2'
      and data ->> 'type' = 'clase_editada'
      and data ->> 'clase_id' = '00000000-0000-0000-0000-000000000c02'
  ),
  'Al cambiar el horario de la clase del hijo, el aviso llega al tutor'
);
select ok(
  not exists (
    select 1 from public.notificaciones_outbox
    where user_id = '00000000-0000-0000-0000-0000000000b3'
  ),
  'El hijo sigue sin recibir avisos directos tras el cambio de horario'
);

-- ── 6-7. Promoción desde lista de espera de un hijo notifica al tutor ─────
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000b2');
select public.cancelar_reserva(
  '00000000-0000-0000-0000-000000000c03',
  '00000000-0000-0000-0000-0000000000b3'
);

reset role;
select ok(
  exists (
    select 1 from public.notificaciones_outbox
    where user_id = '00000000-0000-0000-0000-0000000000b2'
      and data ->> 'type' = 'waitlist_promoted'
      and data ->> 'clase_id' = '00000000-0000-0000-0000-000000000c03'
  ),
  'Cuando se promociona al hijo dos desde la lista de espera, el aviso llega al tutor'
);
select ok(
  not exists (
    select 1 from public.notificaciones_outbox
    where user_id = '00000000-0000-0000-0000-0000000000b4'
  ),
  'El hijo promocionado tampoco recibe el aviso directamente'
);

-- ── 8-10. Una novedad nueva no duplica el aviso al tutor de dos hijos ─────
reset role;
insert into public.novedades (id, academia_id, autor_id, titulo, contenido) values (
  '00000000-0000-0000-0000-00000000fa01',
  '00000000-0000-0000-0000-000000000ba1',
  '00000000-0000-0000-0000-0000000000b1',
  'Novedad de prueba',
  'Contenido de prueba'
);

select is(
  (
    select count(*)::int from public.notificaciones_outbox
    where data ->> 'novedad_id' = '00000000-0000-0000-0000-00000000fa01'
  ),
  2,
  'La novedad encola exactamente dos avisos: el tutor (una vez, no dos por sus dos hijos) y el adulto independiente'
);
select ok(
  exists (
    select 1 from public.notificaciones_outbox
    where user_id = '00000000-0000-0000-0000-0000000000b2'
      and data ->> 'novedad_id' = '00000000-0000-0000-0000-00000000fa01'
  ),
  'El tutor está entre los avisados de la novedad'
);
select ok(
  exists (
    select 1 from public.notificaciones_outbox
    where user_id = '00000000-0000-0000-0000-0000000000b5'
      and data ->> 'novedad_id' = '00000000-0000-0000-0000-00000000fa01'
  ),
  'El adulto independiente está entre los avisados de la novedad'
);

select * from finish();
rollback;
