-- Familias y tutores, segunda versión (03/09/2026).
--
-- La primera nunca pudo crear un hijo: `crear_perfil_hijo` insertaba un
-- perfil con un uuid nuevo, pero `profiles.id` tenía clave foránea contra
-- `auth.users`. Ahora los menores son perfiles sin cuenta.
--
-- Aquí se comprueba lo que de verdad importa: que un padre solo puede
-- crear y manejar a SUS hijos, que un extraño no, que el menor no tiene
-- cuenta con la que iniciar sesión, y que un tutor que no entrena no
-- ensucia las listas de alumnos.

begin;
select plan(18);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000b1', 'padre@test.dev'),
  ('00000000-0000-0000-0000-0000000000b2', 'extrano@test.dev'),
  ('00000000-0000-0000-0000-0000000000b3', 'duena@test.dev'),
  ('00000000-0000-0000-0000-0000000000b4', 'tutor-no-entrena@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000000bf', 'Academia Familias', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000000b3',
   '00000000-0000-0000-0000-0000000000bf', 'dueño', 'Dueña', 'activo'),
  ('00000000-0000-0000-0000-0000000000b1',
   '00000000-0000-0000-0000-0000000000bf', 'alumno', 'Padre', 'activo'),
  ('00000000-0000-0000-0000-0000000000b2',
   '00000000-0000-0000-0000-0000000000bf', 'alumno', 'Extraño', 'activo');

-- El tutor que solo trae al niño: existe, pero no entrena.
insert into public.profiles (id, academia_id, rol, nombre, estado, entrena) values
  ('00000000-0000-0000-0000-0000000000b4',
   '00000000-0000-0000-0000-0000000000bf', 'alumno', 'Tutor', 'activo', false);

insert into public.clases (
  id, academia_id, profesor_id, titulo,
  fecha_hora_inicio, fecha_hora_fin, aforo_maximo
) values (
  '00000000-0000-0000-0000-0000000000c1',
  '00000000-0000-0000-0000-0000000000bf',
  '00000000-0000-0000-0000-0000000000b3',
  'Infantil',
  now() + interval '1 day',
  now() + interval '1 day 1 hour',
  20
);

-- ============================================================
-- Alta de un hijo
-- ============================================================

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', true);

select lives_ok(
  $$select public.crear_hijo('Nico', 'Ejemplo', 'gris_blanco')$$,
  'Un padre puede dar de alta a un hijo'
);

reset role;

select is(
  (select count(*)::int from public.relaciones_familia
   where parent_id = '00000000-0000-0000-0000-0000000000b1'),
  1,
  'Queda registrada la relación padre-hijo'
);

select is(
  (select p.academia_id from public.profiles p
   join public.relaciones_familia rf on rf.child_id = p.id
   where rf.parent_id = '00000000-0000-0000-0000-0000000000b1'),
  '00000000-0000-0000-0000-0000000000bf'::uuid,
  'El hijo entra en la academia de su padre'
);

select is(
  (select p.rol from public.profiles p
   join public.relaciones_familia rf on rf.child_id = p.id
   where rf.parent_id = '00000000-0000-0000-0000-0000000000b1'),
  'alumno',
  'El hijo es un alumno normal: reserva, asiste y gradúa como los demás'
);

-- Lo que hacía fracasar a la primera versión, ahora al revés: el menor
-- existe como perfil y NO existe como cuenta.
select is(
  (select p.tiene_cuenta from public.profiles p
   join public.relaciones_familia rf on rf.child_id = p.id
   where rf.parent_id = '00000000-0000-0000-0000-0000000000b1'),
  false,
  'El hijo queda marcado como perfil sin cuenta'
);

select is(
  (select count(*)::int from auth.users u
   join public.relaciones_familia rf on rf.child_id = u.id
   where rf.parent_id = '00000000-0000-0000-0000-0000000000b1'),
  0,
  'El menor no tiene cuenta con la que iniciar sesión'
);

-- ============================================================
-- Validaciones del alta
-- ============================================================

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', true);

select throws_ok(
  $$select public.crear_hijo('   ')$$,
  'El nombre del hijo es obligatorio.',
  'Un hijo sin nombre no se crea'
);

reset role;

-- Un menor no da de alta a nadie: cortaría la cadena de responsabilidad.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  (select json_build_object('sub', rf.child_id, 'role', 'authenticated')::text
     from public.relaciones_familia rf
    where rf.parent_id = '00000000-0000-0000-0000-0000000000b1'),
  true
);

select throws_ok(
  $$select public.crear_hijo('Nieto')$$,
  'Un menor no puede dar de alta a otras personas.',
  'Un menor no puede crear hijos'
);

reset role;

-- ============================================================
-- Reservar y cancelar por un hijo
-- ============================================================

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', true);

select is(
  (select public.reservar_clase(
     '00000000-0000-0000-0000-0000000000c1',
     (select child_id from public.relaciones_familia
       where parent_id = '00000000-0000-0000-0000-0000000000b1'))),
  'inscrito',
  'Un padre reserva la clase para su hijo'
);

reset role;

select is(
  (select i.alumno_id from public.inscripciones i
   where i.clase_id = '00000000-0000-0000-0000-0000000000c1'
     and i.estado = 'inscrito'),
  (select child_id from public.relaciones_familia
    where parent_id = '00000000-0000-0000-0000-0000000000b1'),
  'La plaza queda a nombre del hijo, no del padre'
);

-- Un extraño no puede tocar al niño de otro.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);

select throws_ok(
  format(
    $$select public.reservar_clase('00000000-0000-0000-0000-0000000000c1'::uuid, %L::uuid)$$,
    (select child_id from public.relaciones_familia
      where parent_id = '00000000-0000-0000-0000-0000000000b1')
  ),
  'Solo puedes reservar para ti o para tus hijos.',
  'Un extraño no puede reservar en nombre del hijo de otro'
);

select throws_ok(
  format(
    $$select public.cancelar_reserva('00000000-0000-0000-0000-0000000000c1'::uuid, %L::uuid)$$,
    (select child_id from public.relaciones_familia
      where parent_id = '00000000-0000-0000-0000-0000000000b1')
  ),
  'Solo puedes cancelar por ti o por tus hijos.',
  'Un extraño tampoco puede cancelarle la plaza al hijo de otro'
);

reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', true);

select lives_ok(
  format(
    $$select public.cancelar_reserva('00000000-0000-0000-0000-0000000000c1'::uuid, %L::uuid)$$,
    (select child_id from public.relaciones_familia
      where parent_id = '00000000-0000-0000-0000-0000000000b1')
  ),
  'Un padre sí puede cancelarle la plaza a su hijo'
);

reset role;

-- ============================================================
-- Quien no entrena, no reserva ni cuenta como alumno
-- ============================================================

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000b4","role":"authenticated"}', true);

select throws_ok(
  $$select public.reservar_clase('00000000-0000-0000-0000-0000000000c1'::uuid)$$,
  'Tienes marcado que no entrenas. Cámbialo en tu perfil para reservar.',
  'Un tutor que no entrena no ocupa plaza en una clase'
);

select is(
  (select count(*)::int from public.progreso_graduacion_alumnos()
    where alumno_id = '00000000-0000-0000-0000-0000000000b4'),
  0,
  'Un tutor que no entrena no sale en la lista de graduación'
);

reset role;

-- ============================================================
-- Permisos y firmas
-- ============================================================

select ok(
  not has_function_privilege('anon', 'public.crear_hijo(text, text, text)', 'EXECUTE'),
  'Quien no ha iniciado sesión no puede crear hijos'
);

-- Si quedara la firma de un argumento junto a la de dos, PostgREST no
-- sabría a cuál llamar y reservar dejaría de funcionar para todos.
select is(
  (select count(*)::int from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'reservar_clase'),
  1,
  'Solo existe una versión de reservar_clase (sin sobrecargas ambiguas)'
);

select ok(
  not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_id_fkey'
  ),
  'Un perfil ya no obliga a tener cuenta: los menores no la tienen'
);

select * from finish();
rollback;
