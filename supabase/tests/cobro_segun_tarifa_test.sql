-- Cobrar una tarifa respeta su precio y su duración, y reintentar no
-- duplica el cobro (auditoría externa del 09/10/2026, punto 2; ver
-- 20261009100000_cobro_segun_tarifa.sql).
begin;
select plan(16);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000ca001', 'dueno-ct@test.dev'),
  ('00000000-0000-0000-0000-0000000ca002', 'trimestral-ct@test.dev'),
  ('00000000-0000-0000-0000-0000000ca003', 'mensual-ct@test.dev'),
  ('00000000-0000-0000-0000-0000000ca004', 'suelta-ct@test.dev'),
  ('00000000-0000-0000-0000-0000000ca005', 'reintento-ct@test.dev'),
  ('00000000-0000-0000-0000-0000000ca006', 'otro-ct@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000ca0aa', 'Academia cobro', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000ca001', '00000000-0000-0000-0000-0000000ca0aa', 'dueño', 'Dueño', 'activo'),
  ('00000000-0000-0000-0000-0000000ca002', '00000000-0000-0000-0000-0000000ca0aa', 'alumno', 'Trimestral', 'activo'),
  ('00000000-0000-0000-0000-0000000ca003', '00000000-0000-0000-0000-0000000ca0aa', 'alumno', 'Mensual', 'activo'),
  ('00000000-0000-0000-0000-0000000ca004', '00000000-0000-0000-0000-0000000ca0aa', 'alumno', 'Suelta', 'activo'),
  ('00000000-0000-0000-0000-0000000ca005', '00000000-0000-0000-0000-0000000ca0aa', 'alumno', 'Reintento', 'activo'),
  ('00000000-0000-0000-0000-0000000ca006', '00000000-0000-0000-0000-0000000ca0aa', 'alumno', 'Otro', 'activo');

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, clases_incluidas) values
  ('00000000-0000-0000-0000-0000000ca0d1', '00000000-0000-0000-0000-0000000ca0aa', 'Bono 10 sesiones', 80, 'trimestral', 10),
  ('00000000-0000-0000-0000-0000000ca0d2', '00000000-0000-0000-0000-0000000ca0aa', 'White', 50, 'mensual', 8),
  ('00000000-0000-0000-0000-0000000ca0d3', '00000000-0000-0000-0000-0000000ca0aa', 'Anual', 500, 'anual', null),
  ('00000000-0000-0000-0000-0000000ca0d4', '00000000-0000-0000-0000-0000000ca0aa', 'Día suelto', 10, 'suelta', 1);

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ca001');

-- ------------------------------------------------------------
-- 1. Trimestral: por trimestres y a su precio
-- ------------------------------------------------------------
select throws_ok(
  $$ select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ca002', '00000000-0000-0000-0000-0000000ca0d1', p_meses => 1) $$,
  'Esta tarifa es trimestral: se cobra por periodos de 3 meses.',
  'Un bono trimestral no se cobra por un mes'
);

select lives_ok(
  $$ select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ca002', '00000000-0000-0000-0000-0000000ca0d1', p_meses => 3) $$,
  'Un bono trimestral se cobra por un trimestre'
);

reset role;
select is(
  (select importe_cobrado from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000ca002'),
  80.00::numeric,
  'Un trimestre del bono de 80 € propone 80 €, no 240 €'
);
select is(
  (select fecha_fin from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000ca002'),
  (select fecha_inicio + interval '3 months' from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000ca002'),
  'Dura tres meses de calendario'
);
select is(
  (public._saldo_clases('00000000-0000-0000-0000-0000000ca002') ->> 'incluidas')::int,
  10,
  'Con sus 10 sesiones para todo el trimestre'
);
select is(
  (public._saldo_clases('00000000-0000-0000-0000-0000000ca002') ->> 'ciclo_fin')::timestamptz,
  (select fecha_fin from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000ca002'),
  'El ciclo de las 10 sesiones acaba con la cuota'
);

-- ------------------------------------------------------------
-- 2. Anual y mensual
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ca001');
select throws_ok(
  $$ select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ca006', '00000000-0000-0000-0000-0000000ca0d3', p_meses => 6) $$,
  'Esta tarifa es anual: se cobra por periodos de 12 meses.',
  'Una anual no se cobra por seis meses'
);
select lives_ok(
  $$ select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ca003', '00000000-0000-0000-0000-0000000ca0d2', p_meses => 3) $$,
  'Una mensual se puede cobrar por tres meses'
);
reset role;
select is(
  (select importe_cobrado from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000ca003'),
  150.00::numeric,
  'Tres meses de 50 € proponen 150 €'
);

-- ------------------------------------------------------------
-- 3. Suelta: una clase que dura un mes
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ca001');
select throws_ok(
  $$ select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ca004', '00000000-0000-0000-0000-0000000ca0d4', p_meses => 3) $$,
  'Una clase suelta se cobra de una en una.',
  'Una suelta no se cobra por meses'
);
select lives_ok(
  $$ select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ca004', '00000000-0000-0000-0000-0000000ca0d4') $$,
  'Una suelta se cobra sin meses'
);
reset role;
select is(
  (select (importe_cobrado, fecha_fin = fecha_inicio + interval '1 month')::text
     from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000ca004'),
  '(10.00,t)',
  'La suelta cuesta su precio y se puede usar durante un mes'
);

-- ------------------------------------------------------------
-- 4. Reintentar el mismo cobro no lo duplica
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ca001');
select set_config('prueba.primera', public.activar_cuota_efectivo(
  '00000000-0000-0000-0000-0000000ca005', '00000000-0000-0000-0000-0000000ca0d2',
  p_meses => 1, p_importe => 50, p_clave => '00000000-0000-0000-0000-00000000c1a5')::text, true);
select is(
  public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ca005', '00000000-0000-0000-0000-0000000ca0d2',
    p_meses => 1, p_importe => 50, p_clave => '00000000-0000-0000-0000-00000000c1a5'),
  current_setting('prueba.primera')::uuid,
  'El reintento devuelve el cobro ya guardado'
);
reset role;
select is(
  (select count(*)::int from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000ca005'),
  1,
  'Y no hay una segunda cuota (antes era una renovación cobrada dos veces)'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ca001');
select throws_ok(
  $$ select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ca006', '00000000-0000-0000-0000-0000000ca0d2',
       p_meses => 1, p_clave => '00000000-0000-0000-0000-00000000c1a5') $$,
  'Ese cobro ya se registró para otro alumno.',
  'La clave de un cobro no vale para otro alumno'
);

-- Sin clave, como antes: un segundo cobro con la cuota en vigor es una
-- renovación. Es justo lo que la clave evita cuando es un reintento.
select lives_ok(
  $$ select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ca005', '00000000-0000-0000-0000-0000000ca0d2', p_meses => 1) $$,
  'Sin clave, un segundo cobro sigue siendo una renovación'
);

select * from finish();
rollback;
