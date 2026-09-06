-- Las reservas de los hijos en el calendario (06/09/2026).
--
-- `listar_clases_semana` devuelve ahora `reservas_familia`. Sin esa columna
-- un padre apuntaba al niño, la inscripción se creaba de verdad y la
-- tarjeta seguía diciendo «Reservar plaza»: la funcionalidad no quedaba a
-- medias, parecía rota.
--
-- Lo que se comprueba aquí es lo que de verdad puede fallar: que salga la
-- reserva del hijo, que NO salga la de un niño ajeno (sería filtrar quién
-- lleva a quién), que lo del hijo no se confunda con lo del padre, que la
-- lista de espera se distinga de la plaza confirmada, y que cancelar deje
-- la columna vacía otra vez.

begin;
select plan(9);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000d1', 'padre-cal@test.dev'),
  ('00000000-0000-0000-0000-0000000000d2', 'otro-padre-cal@test.dev'),
  ('00000000-0000-0000-0000-0000000000d3', 'duena-cal@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000000df', 'Academia Calendario', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000000d3',
   '00000000-0000-0000-0000-0000000000df', 'dueño', 'Dueña', 'activo'),
  ('00000000-0000-0000-0000-0000000000d1',
   '00000000-0000-0000-0000-0000000000df', 'alumno', 'Padre', 'activo'),
  ('00000000-0000-0000-0000-0000000000d2',
   '00000000-0000-0000-0000-0000000000df', 'alumno', 'OtroPadre', 'activo');

-- Los dos menores, con id fijo. Se insertan aquí en vez de por `crear_hijo`
-- para que la prueba no dependa de que esa función devuelva un uuid nuevo
-- cada vez: lo que se prueba es el calendario, no el alta.
insert into public.profiles (
  id, academia_id, rol, nombre, estado, tiene_cuenta, entrena
) values
  ('00000000-0000-0000-0000-0000000000f1',
   '00000000-0000-0000-0000-0000000000df', 'alumno', 'Nico', 'activo',
   false, true),
  ('00000000-0000-0000-0000-0000000000f2',
   '00000000-0000-0000-0000-0000000000df', 'alumno', 'Ajeno', 'activo',
   false, true);

insert into public.relaciones_familia (parent_id, child_id) values
  ('00000000-0000-0000-0000-0000000000d1',
   '00000000-0000-0000-0000-0000000000f1'),
  ('00000000-0000-0000-0000-0000000000d2',
   '00000000-0000-0000-0000-0000000000f2');

-- Dos clases: una con sitio y otra con el aforo en 1, para poder llenarla y
-- que el siguiente caiga en lista de espera.
insert into public.clases (
  id, academia_id, profesor_id, titulo,
  fecha_hora_inicio, fecha_hora_fin, aforo_maximo
) values
  ('00000000-0000-0000-0000-0000000000e1',
   '00000000-0000-0000-0000-0000000000df',
   '00000000-0000-0000-0000-0000000000d3',
   'Infantil', now() + interval '1 day', now() + interval '1 day 1 hour', 20),
  ('00000000-0000-0000-0000-0000000000e2',
   '00000000-0000-0000-0000-0000000000df',
   '00000000-0000-0000-0000-0000000000d3',
   'Infantil llena', now() + interval '2 day', now() + interval '2 day 1 hour', 1);

-- ============================================================
-- Sin reservas, la columna llega vacía (no nula)
-- ============================================================

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);

select is(
  (select reservas_familia from public.listar_clases_semana(
     now(), now() + interval '7 day')
   where id = '00000000-0000-0000-0000-0000000000e1'),
  '[]'::jsonb,
  'Sin reservas, reservas_familia es una lista vacía, no null'
);

-- ============================================================
-- El padre apunta a su hijo
-- ============================================================

select is(
  public.reservar_clase(
    '00000000-0000-0000-0000-0000000000e1',
    '00000000-0000-0000-0000-0000000000f1'
  ),
  'inscrito',
  'Un padre puede reservar plaza para su hijo'
);

select is(
  (select reservas_familia from public.listar_clases_semana(
     now(), now() + interval '7 day')
   where id = '00000000-0000-0000-0000-0000000000e1'),
  jsonb_build_array(
    jsonb_build_object(
      'alumno_id', '00000000-0000-0000-0000-0000000000f1',
      'estado', 'inscrito'
    )
  ),
  'La reserva del hijo sale en el calendario del padre'
);

-- Lo del hijo NO se cuela en `mi_estado`: son cosas distintas y la tarjeta
-- las pinta en sitios distintos.
select is(
  (select mi_estado from public.listar_clases_semana(
     now(), now() + interval '7 day')
   where id = '00000000-0000-0000-0000-0000000000e1'),
  null,
  'Apuntar al hijo no marca al padre como inscrito'
);

-- ============================================================
-- El niño de otra familia no se ve
-- ============================================================

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000d2","role":"authenticated"}', true);

select public.reservar_clase(
  '00000000-0000-0000-0000-0000000000e1',
  '00000000-0000-0000-0000-0000000000f2'
);

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);

select is(
  (select jsonb_array_length(reservas_familia)
     from public.listar_clases_semana(now(), now() + interval '7 day')
   where id = '00000000-0000-0000-0000-0000000000e1'),
  1,
  'Un padre solo ve la reserva de SU hijo, no la del niño de otra familia'
);

select is(
  (select reservas_familia -> 0 ->> 'alumno_id'
     from public.listar_clases_semana(now(), now() + interval '7 day')
   where id = '00000000-0000-0000-0000-0000000000e1'),
  '00000000-0000-0000-0000-0000000000f1',
  'Y la que ve es la de su hijo, no la del otro'
);

-- ============================================================
-- Lista de espera: se distingue de la plaza confirmada
-- ============================================================

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000d2","role":"authenticated"}', true);
select public.reservar_clase(
  '00000000-0000-0000-0000-0000000000e2',
  '00000000-0000-0000-0000-0000000000f2'
);

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);

select is(
  public.reservar_clase(
    '00000000-0000-0000-0000-0000000000e2',
    '00000000-0000-0000-0000-0000000000f1'
  ),
  'espera',
  'Con el aforo lleno, el hijo entra en lista de espera'
);

select is(
  (select reservas_familia -> 0 ->> 'estado'
     from public.listar_clases_semana(now(), now() + interval '7 day')
   where id = '00000000-0000-0000-0000-0000000000e2'),
  'espera',
  'La lista de espera del hijo se distingue de la plaza confirmada'
);

-- ============================================================
-- Cancelar deja la columna vacía otra vez
-- ============================================================

select public.cancelar_reserva(
  '00000000-0000-0000-0000-0000000000e1',
  '00000000-0000-0000-0000-0000000000f1'
);

select is(
  (select reservas_familia from public.listar_clases_semana(
     now(), now() + interval '7 day')
   where id = '00000000-0000-0000-0000-0000000000e1'),
  '[]'::jsonb,
  'Tras cancelar, la clase vuelve a salir sin reservas de la familia'
);

select * from finish();
rollback;
