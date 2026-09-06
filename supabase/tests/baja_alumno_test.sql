-- Dar de baja a un alumno: se archiva, no se borra (06/09/2026).
--
-- El riesgo de esta tanda no es escribir la baja: es que **algún sitio se
-- olvide de mirarla**. Hoy se pregunta «¿quién es alumno activo?» en el
-- ranking, en los avisos de inactividad, en «listo para graduarse» y al
-- reservar. Si se escapa uno, un alumno dado de baja sigue contando ahí como
-- si nada, y Cipri se entera cuando le cuadran mal las listas.
--
-- Así que esta prueba los recorre **uno a uno**, en vez de fiarse de que se
-- repasaron. Y comprueba lo otro que importa: que la baja NO borra nada.

begin;
select plan(22);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000c0001', 'duena-baja2@test.dev'),
  ('00000000-0000-0000-0000-0000000c0002', 'profe-baja2@test.dev'),
  ('00000000-0000-0000-0000-0000000c0003', 'alumno-que-se-va@test.dev'),
  ('00000000-0000-0000-0000-0000000c0004', 'alumno-que-se-queda@test.dev'),
  ('00000000-0000-0000-0000-0000000c0005', 'alumno-en-espera@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000c00ff', 'Academia Bajas 2', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado, cinturon) values
  ('00000000-0000-0000-0000-0000000c0001',
   '00000000-0000-0000-0000-0000000c00ff', 'dueño', 'Dueña', 'activo', null),
  ('00000000-0000-0000-0000-0000000c0002',
   '00000000-0000-0000-0000-0000000c00ff', 'profesor', 'Profe', 'activo', null),
  ('00000000-0000-0000-0000-0000000c0003',
   '00000000-0000-0000-0000-0000000c00ff', 'alumno', 'SeVa', 'activo', 'azul'),
  ('00000000-0000-0000-0000-0000000c0004',
   '00000000-0000-0000-0000-0000000c00ff', 'alumno', 'SeQueda', 'activo', 'blanco'),
  ('00000000-0000-0000-0000-0000000c0005',
   '00000000-0000-0000-0000-0000000c00ff', 'alumno', 'EnEspera', 'activo', 'blanco');

-- Una clase futura con UNA sola plaza: la ocupa el que se va, y el tercero
-- espera. Al darle de baja, la plaza tiene que pasar al de la espera.
insert into public.clases (
  id, academia_id, profesor_id, titulo,
  fecha_hora_inicio, fecha_hora_fin, aforo_maximo
) values (
  '00000000-0000-0000-0000-0000000cc001',
  '00000000-0000-0000-0000-0000000c00ff',
  '00000000-0000-0000-0000-0000000c0002',
  'Clase futura', now() + interval '3 day', now() + interval '3 day 1 hour', 1
);

-- Y una clase pasada a la que sí fue: su historial.
insert into public.clases (
  id, academia_id, profesor_id, titulo,
  fecha_hora_inicio, fecha_hora_fin, aforo_maximo
) values (
  '00000000-0000-0000-0000-0000000cc002',
  '00000000-0000-0000-0000-0000000c00ff',
  '00000000-0000-0000-0000-0000000c0002',
  'Clase pasada', now() - interval '3 day', now() - interval '3 day' + interval '1 hour', 20
);

insert into public.inscripciones (clase_id, alumno_id, academia_id, estado) values
  ('00000000-0000-0000-0000-0000000cc001',
   '00000000-0000-0000-0000-0000000c0003',
   '00000000-0000-0000-0000-0000000c00ff', 'inscrito'),
  ('00000000-0000-0000-0000-0000000cc001',
   '00000000-0000-0000-0000-0000000c0005',
   '00000000-0000-0000-0000-0000000c00ff', 'espera'),
  ('00000000-0000-0000-0000-0000000cc002',
   '00000000-0000-0000-0000-0000000c0003',
   '00000000-0000-0000-0000-0000000c00ff', 'inscrito');

insert into public.asistencias (clase_id, alumno_id, validado_por) values
  ('00000000-0000-0000-0000-0000000cc002',
   '00000000-0000-0000-0000-0000000c0003',
   '00000000-0000-0000-0000-0000000c0002');

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad) values
  ('00000000-0000-0000-0000-0000000cd001',
   '00000000-0000-0000-0000-0000000c00ff', 'Mensual', 45, 'mensual');

insert into public.suscripciones (
  id, alumno_id, academia_id, tarifa_id, estado, payment_status, fecha_inicio
) values (
  '00000000-0000-0000-0000-0000000ce001',
  '00000000-0000-0000-0000-0000000c0003',
  '00000000-0000-0000-0000-0000000c00ff',
  '00000000-0000-0000-0000-0000000cd001',
  'activa', 'active', now() - interval '10 day'
);

-- ============================================================
-- Quién puede dar de baja
-- ============================================================

set local role authenticated;

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000c0003","role":"authenticated"}', true);
select throws_like(
  $$select public.dar_de_baja_alumno('00000000-0000-0000-0000-0000000c0003')$$,
  '%Solo el dueño%',
  'Un alumno no puede darse de baja a sí mismo — la regla de Cipri'
);

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000c0002","role":"authenticated"}', true);
select throws_like(
  $$select public.dar_de_baja_alumno('00000000-0000-0000-0000-0000000c0003')$$,
  '%Solo el dueño%',
  'Un profesor tampoco: pasa lista, pero las bajas son del dueño'
);

-- ============================================================
-- La baja
-- ============================================================

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000c0001","role":"authenticated"}', true);

select lives_ok(
  $$select public.dar_de_baja_alumno('00000000-0000-0000-0000-0000000c0003')$$,
  'El dueño sí puede dar de baja'
);

select throws_like(
  $$select public.dar_de_baja_alumno('00000000-0000-0000-0000-0000000c0003')$$,
  '%ya estaba dado de baja%',
  'Dar de baja dos veces avisa en vez de hacer cosas raras'
);

reset role;

select is(
  (select estado from public.profiles
   where id = '00000000-0000-0000-0000-0000000c0003'),
  'baja',
  'Queda marcado como baja'
);

select isnt(
  (select fecha_baja from public.profiles
   where id = '00000000-0000-0000-0000-0000000c0003'),
  null,
  'Y con la fecha en que se fue'
);

-- ============================================================
-- Lo que NO se borra — que es la decisión de Cipri
-- ============================================================

select is(
  (select count(*)::int from public.profiles
   where id = '00000000-0000-0000-0000-0000000c0003'),
  1,
  'El perfil sigue ahí: dar de baja no borra a nadie'
);

select is(
  (select cinturon from public.profiles
   where id = '00000000-0000-0000-0000-0000000c0003'),
  'azul',
  'Conserva su cinturón, para cuando vuelva'
);

select is(
  (select count(*)::int from public.asistencias
   where alumno_id = '00000000-0000-0000-0000-0000000c0003'),
  1,
  'Sus asistencias se quedan'
);

select is(
  (select count(*)::int from public.suscripciones
   where alumno_id = '00000000-0000-0000-0000-0000000c0003'),
  1,
  'Y el registro de la cuota cobrada NO se borra'
);

-- ============================================================
-- Lo que sí cambia: la cuota se cierra
-- ============================================================

select is(
  (select estado from public.suscripciones
   where id = '00000000-0000-0000-0000-0000000ce001'),
  'cancelada',
  'La cuota deja de estar activa'
);

select ok(
  (select fecha_fin from public.suscripciones
   where id = '00000000-0000-0000-0000-0000000ce001') <= now(),
  'Y se cierra con fecha de hoy, no en el futuro'
);

-- ============================================================
-- Sus reservas futuras se liberan, y la lista de espera asciende
-- ============================================================

select is(
  (select estado from public.inscripciones
   where clase_id = '00000000-0000-0000-0000-0000000cc001'
     and alumno_id = '00000000-0000-0000-0000-0000000c0003'),
  'cancelado',
  'Su reserva futura se cancela: no sale en la lista de una clase a la que no irá'
);

-- Esto es lo que se ganaba reutilizando `cancelar_reserva` en vez de copiar
-- su lógica: la promoción de la lista de espera sale gratis y sigue siendo
-- la de verdad, no una copia que se desincroniza.
select is(
  (select estado from public.inscripciones
   where clase_id = '00000000-0000-0000-0000-0000000cc001'
     and alumno_id = '00000000-0000-0000-0000-0000000c0005'),
  'inscrito',
  'Y el que esperaba plaza asciende: la plaza no se pierde'
);

select is(
  (select estado from public.inscripciones
   where clase_id = '00000000-0000-0000-0000-0000000cc002'
     and alumno_id = '00000000-0000-0000-0000-0000000c0003'),
  'inscrito',
  'La clase a la que YA fue no se toca: es historial'
);

-- ============================================================
-- Los sitios que tenían que dejar de contarlo — uno a uno
-- ============================================================

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000c0001","role":"authenticated"}', true);

select is(
  (select count(*)::int from public.ranking_periodo(
     (now() - interval '30 day')::date, (now() + interval '1 day')::date)
   where alumno_id = '00000000-0000-0000-0000-0000000c0003'),
  0,
  'No sale en el ranking: el ranking es de quien entrena ahora'
);

select is(
  (select count(*)::int from public.ultima_asistencia_por_alumno()
   where alumno_id = '00000000-0000-0000-0000-0000000c0003'),
  0,
  'No sale como «inactivo»: no es un despistado, es alguien que se fue'
);

select is(
  (select count(*)::int from public.progreso_graduacion_alumnos()
   where alumno_id = '00000000-0000-0000-0000-0000000c0003'),
  0,
  'No sale como «listo para graduarse»'
);

-- Y los que siguen activos no se han visto afectados por nada de esto.
select is(
  (select count(*)::int from public.ultima_asistencia_por_alumno()
   where alumno_id = '00000000-0000-0000-0000-0000000c0005'),
  0,
  'El que sigue activo pero sin asistencias tampoco aparece — como antes'
);

-- ============================================================
-- Reservar estando de baja
-- ============================================================

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000c0003","role":"authenticated"}', true);

select throws_like(
  $$select public.reservar_clase('00000000-0000-0000-0000-0000000cc001')$$,
  '%no está activa%',
  'Un alumno de baja no puede reservar'
);

-- ============================================================
-- Volver
-- ============================================================

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000c0001","role":"authenticated"}', true);

select lives_ok(
  $$select public.reactivar_alumno('00000000-0000-0000-0000-0000000c0003')$$,
  'El dueño puede reactivar a quien vuelve'
);

reset role;

select is(
  (select estado || '/' || cinturon from public.profiles
   where id = '00000000-0000-0000-0000-0000000c0003'),
  'activo/azul',
  'Vuelve activo y con su cinturón: sigue donde lo dejó'
);

select * from finish();
rollback;
