-- Una clase suelta comprada con la cuota en vigor se puede usar ya y
-- caduca con la cuota (auditoría externa del 09/10/2026, punto 3; decisión
-- de Cipri; ver 20261009110000_clases_extra.sql).
begin;
select plan(19);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000ea001', 'dueno-ex@test.dev'),
  ('00000000-0000-0000-0000-0000000ea002', 'agotada-ex@test.dev'),
  ('00000000-0000-0000-0000-0000000ea003', 'ilimitada-ex@test.dev'),
  ('00000000-0000-0000-0000-0000000ea004', 'pausada-ex@test.dev'),
  ('00000000-0000-0000-0000-0000000ea005', 'sincuota-ex@test.dev'),
  ('00000000-0000-0000-0000-0000000ea006', 'dosmeses-ex@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000ea0aa', 'Academia extra', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000ea001', '00000000-0000-0000-0000-0000000ea0aa', 'dueño', 'Dueño', 'activo'),
  ('00000000-0000-0000-0000-0000000ea002', '00000000-0000-0000-0000-0000000ea0aa', 'alumno', 'Agotada', 'activo'),
  ('00000000-0000-0000-0000-0000000ea003', '00000000-0000-0000-0000-0000000ea0aa', 'alumno', 'Ilimitada', 'activo'),
  ('00000000-0000-0000-0000-0000000ea004', '00000000-0000-0000-0000-0000000ea0aa', 'alumno', 'Pausada', 'activo'),
  ('00000000-0000-0000-0000-0000000ea005', '00000000-0000-0000-0000-0000000ea0aa', 'alumno', 'Sin cuota', 'activo'),
  ('00000000-0000-0000-0000-0000000ea006', '00000000-0000-0000-0000-0000000ea0aa', 'alumno', 'Dos meses', 'activo');

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, clases_incluidas) values
  ('00000000-0000-0000-0000-0000000ea0d1', '00000000-0000-0000-0000-0000000ea0aa', 'Dos al mes', 30, 'mensual', 2),
  ('00000000-0000-0000-0000-0000000ea0d2', '00000000-0000-0000-0000-0000000ea0aa', 'Corral', 80, 'mensual', null),
  ('00000000-0000-0000-0000-0000000ea0d3', '00000000-0000-0000-0000-0000000ea0aa', 'Día suelto', 10, 'suelta', 1);

insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-0000000ea0c1', '00000000-0000-0000-0000-0000000ea0aa', '00000000-0000-0000-0000-0000000ea001',
   'Lunes', now() + interval '1 day', now() + interval '1 day 1 hour', 10),
  ('00000000-0000-0000-0000-0000000ea0c2', '00000000-0000-0000-0000-0000000ea0aa', '00000000-0000-0000-0000-0000000ea001',
   'Martes', now() + interval '2 days', now() + interval '2 days 1 hour', 10),
  ('00000000-0000-0000-0000-0000000ea0c3', '00000000-0000-0000-0000-0000000ea0aa', '00000000-0000-0000-0000-0000000ea001',
   'Miércoles', now() + interval '3 days', now() + interval '3 days 1 hour', 10),
  ('00000000-0000-0000-0000-0000000ea0c4', '00000000-0000-0000-0000-0000000ea0aa', '00000000-0000-0000-0000-0000000ea001',
   'Dentro de 40 días', now() + interval '40 days', now() + interval '40 days 1 hour', 10);

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

create or replace function pg_temp.saldo(p_alumno uuid, p_fecha timestamptz default now()) returns jsonb
language sql as $$ select public._saldo_clases(p_alumno, p_fecha); $$;

-- Cuotas de partida, cobradas como en la app.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ea001');
select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ea002', '00000000-0000-0000-0000-0000000ea0d1', p_meses => 1);
select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ea003', '00000000-0000-0000-0000-0000000ea0d2', p_meses => 1);
select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ea004', '00000000-0000-0000-0000-0000000ea0d1', p_meses => 1);
select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ea006', '00000000-0000-0000-0000-0000000ea0d1', p_meses => 2);
select public.pausar_cuota_efectivo(
  (select id from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000ea004' and estado = 'activa'),
  null
);
reset role;

-- ------------------------------------------------------------
-- 1. Cuota en vigor y sin clases: la extra sirve hoy
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ea002');
select public.reservar_clase('00000000-0000-0000-0000-0000000ea0c1');
select public.reservar_clase('00000000-0000-0000-0000-0000000ea0c2');
select throws_ok(
  $$ select public.reservar_clase('00000000-0000-0000-0000-0000000ea0c3') $$,
  'No te quedan clases en tu tarifa para esa fecha. Renueva o compra una clase suelta.',
  'Sin clases, no puede reservar la tercera'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ea001');
select lives_ok(
  $$ select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ea002', '00000000-0000-0000-0000-0000000ea0d3') $$,
  'Se le cobra un día suelto'
);
reset role;

select is(
  (select estado || '/' || (extra_de = (select id from public.suscripciones b
                                         where b.alumno_id = e.alumno_id and b.estado = 'activa'))::text
     from public.suscripciones e
    where alumno_id = '00000000-0000-0000-0000-0000000ea002' and tarifa_id = '00000000-0000-0000-0000-0000000ea0d3'),
  'extra/true',
  'Queda como clase extra de su cuota, no como renovación'
);
select is(
  (select count(*)::int from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000ea002' and estado = 'programada'),
  0,
  'No se ha creado ninguna renovación para cuando acabe'
);
select is(
  (select (importe_cobrado, fecha_fin = (select fecha_fin from public.suscripciones b
                                          where b.alumno_id = e.alumno_id and b.estado = 'activa'))::text
     from public.suscripciones e
    where alumno_id = '00000000-0000-0000-0000-0000000ea002' and estado = 'extra'),
  '(10.00,t)',
  'Cobrada a su precio, y vale hasta que acaba la cuota'
);
select is(
  pg_temp.saldo('00000000-0000-0000-0000-0000000ea002') - 'ciclo_inicio' - 'ciclo_fin',
  '{"tiene_cuota": true, "ilimitada": false, "tarifa": "Dos al mes", "incluidas": 3, "extras": 1, "gastadas": 0, "reservadas": 2, "disponibles": 1}'::jsonb,
  'El saldo suma la extra: le queda 1'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ea002');
select is(
  public.reservar_clase('00000000-0000-0000-0000-0000000ea0c3'),
  'inscrito',
  'Y con ella reserva la tercera'
);
reset role;
select is(
  (pg_temp.saldo('00000000-0000-0000-0000-0000000ea002') ->> 'disponibles')::int,
  0,
  'Gastada la extra, vuelve a 0'
);

-- ------------------------------------------------------------
-- 2. Caduca con la cuota: no pasa a la renovación
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ea001');
select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ea002', '00000000-0000-0000-0000-0000000ea0d1', p_meses => 1);
reset role;
select is(
  (pg_temp.saldo('00000000-0000-0000-0000-0000000ea002', now() + interval '40 days') ->> 'incluidas')::int,
  2,
  'La renovación tiene sus 2 clases, sin la extra de la cuota anterior'
);
select ok(
  not (pg_temp.saldo('00000000-0000-0000-0000-0000000ea002', now() + interval '40 days') ? 'extras'),
  'Y no arrastra extras'
);

-- ------------------------------------------------------------
-- 3. Cuota de dos meses: la extra es una bolsa, no una por ciclo
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ea006');
select public.reservar_clase('00000000-0000-0000-0000-0000000ea0c1');
select public.reservar_clase('00000000-0000-0000-0000-0000000ea0c2');
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ea001');
select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ea006', '00000000-0000-0000-0000-0000000ea0d3');
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ea006');
select is(
  public.reservar_clase('00000000-0000-0000-0000-0000000ea0c3'),
  'inscrito',
  'En el primer mes gasta sus 2 y la extra'
);
reset role;
select is(
  pg_temp.saldo('00000000-0000-0000-0000-0000000ea006', now() + interval '40 days') ->> 'disponibles',
  '2',
  'El segundo mes tiene sus 2, no 3: la extra ya se gastó en el primero'
);
select is(
  (pg_temp.saldo('00000000-0000-0000-0000-0000000ea006') ->> 'disponibles')::int,
  0,
  'Y en el primer mes no queda nada'
);

-- ------------------------------------------------------------
-- 4. Casos en los que no es una extra
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ea001');
select throws_ok(
  $$ select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ea003', '00000000-0000-0000-0000-0000000ea0d3') $$,
  'Su cuota ya tiene clases ilimitadas: no le hace falta una clase extra.',
  'Con clases ilimitadas no se vende una extra'
);
select throws_ok(
  $$ select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ea004', '00000000-0000-0000-0000-0000000ea0d3') $$,
  'Tiene la cuota pausada: mientras lo esté puede venir sin cuota. Reanúdala antes de cobrarle una clase extra.',
  'Con la cuota pausada no se vende una extra'
);
reset role;
select is(
  (select estado from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000ea004' and estado <> 'extra'),
  'pausada',
  'Y su cuota pausada sigue intacta'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ea001');
select lives_ok(
  $$ select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ea005', '00000000-0000-0000-0000-0000000ea0d3') $$,
  'Sin cuota, la suelta se cobra como siempre'
);
reset role;
select is(
  (select estado from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000ea005'),
  'activa',
  'Y es su cuota (una clase para un mes), no una extra'
);

-- Las extras no son cuotas: no las ve el job ni la app como «cuota en curso».
select is(
  (select count(*)::int from public.suscripciones where estado = 'extra' and extra_de is null),
  0,
  'Toda extra apunta a su cuota'
);

select * from finish();
rollback;
