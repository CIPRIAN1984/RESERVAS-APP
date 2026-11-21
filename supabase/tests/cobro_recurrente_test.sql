-- Cobro automático mensual con tarjeta (decisión de Cipri, 21/11/2026), lado
-- base de datos. Ver 20261121100000_cobro_recurrente.sql. No hay Stripe: se
-- prueba lo que el servidor hace cuando Stripe avisa.

begin;
select plan(25);

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000e00aa', 'Academia CR', 'approved');
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000e0001', 'dueno-cr@test.dev'),
  ('00000000-0000-0000-0000-0000000e0003', 'alumno1-cr@test.dev'),
  ('00000000-0000-0000-0000-0000000e0004', 'alumno2-cr@test.dev'),
  ('00000000-0000-0000-0000-0000000e0005', 'alumno3-cr@test.dev');
insert into public.profiles (id, academia_id, rol, nombre, estado, tiene_cuenta) values
  ('00000000-0000-0000-0000-0000000e0001', '00000000-0000-0000-0000-0000000e00aa', 'dueño', 'Dueño', 'activo', true),
  ('00000000-0000-0000-0000-0000000e0003', '00000000-0000-0000-0000-0000000e00aa', 'alumno', 'Uno', 'activo', true),
  ('00000000-0000-0000-0000-0000000e0004', '00000000-0000-0000-0000-0000000e00aa', 'alumno', 'Dos', 'activo', true),
  ('00000000-0000-0000-0000-0000000e0005', '00000000-0000-0000-0000-0000000e00aa', 'alumno', 'Tres', 'activo', true);
insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, clases_incluidas, activo) values
  ('00000000-0000-0000-0000-0000000e0d01', '00000000-0000-0000-0000-0000000e00aa', 'Mensual 8', 50, 'mensual', 8, true);

create or replace function pg_temp.actuar_como(p_uid uuid)
returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$f$;

-- 1. Nadie del cliente puede tocar estas funciones: son del servidor.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000e0003');
select throws_ok($$ select public.confirmar_suscripcion_stripe('cs_x','sub_x',5000,'eur') $$,
  '42501', null, 'Un alumno no puede darse por pagada una suscripción');
select throws_ok($$ select public.suscripcion_cancelada_en_stripe('sub_x') $$,
  '42501', null, 'Ni cancelar una suscripción por su cuenta');
select throws_ok($$ select public.reflejar_estado_suscripcion_stripe('sub_x','active') $$,
  '42501', null, 'Ni cambiar el estado del cobro');
reset role;

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;

-- 2. Primer cobro: la cuota queda activa, sin fecha de fin, ligada a la suscripción.
select public.guardar_sesion_stripe(
  (select pago_id from public.preparar_pago_stripe('00000000-0000-0000-0000-0000000e0003',
     '00000000-0000-0000-0000-0000000e0003', '00000000-0000-0000-0000-0000000e0d01')),
  'cs_sub1');
select isnt(public.confirmar_suscripcion_stripe('cs_sub1', 'sub_A1', 5000, 'eur'), null,
  'El primer cobro de una tarifa mensual activa la cuota');
select is(
  (select proveedor_pago || '/' || referencia_externa || '/' || estado || '/' || payment_status
     from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000e0003'),
  'stripe/sub_A1/activa/active', 'Queda ligada a la suscripción de Stripe y activa');
select is((select fecha_fin from public.suscripciones
            where alumno_id = '00000000-0000-0000-0000-0000000e0003'), null,
  'No tiene fecha de fin: dura mientras Stripe siga cobrando');
select is((select estado from public.pagos_stripe where checkout_session_id = 'cs_sub1'),
  'pagado', 'El pago queda como pagado');

-- 3. Un aviso repetido no duplica nada.
select lives_ok($$ select public.confirmar_suscripcion_stripe('cs_sub1', 'sub_A1', 5000, 'eur') $$,
  'El mismo aviso otra vez no falla');
select is((select count(*)::int from public.suscripciones
            where alumno_id = '00000000-0000-0000-0000-0000000e0003'), 1,
  'Y no duplica la cuota');

-- 4. Importe que no cuadra, o suscripción sin identificar: no se activa.
select public.guardar_sesion_stripe(
  (select pago_id from public.preparar_pago_stripe('00000000-0000-0000-0000-0000000e0004',
     '00000000-0000-0000-0000-0000000e0004', '00000000-0000-0000-0000-0000000e0d01')),
  'cs_sub2');
select is(public.confirmar_suscripcion_stripe('cs_sub2', 'sub_A2', 100, 'eur'), null,
  'Un importe que no cuadra con la tarifa no activa la cuota');
select is((select estado from public.pagos_stripe where checkout_session_id = 'cs_sub2'),
  'revisar', 'Queda a la vista del Dueño para revisar');
select is(public.confirmar_suscripcion_stripe('cs_sub2', null, 5000, 'eur'), null,
  'Sin identificador de suscripción tampoco se activa');
select is((select count(*)::int from public.suscripciones
            where alumno_id = '00000000-0000-0000-0000-0000000e0004'), 0,
  'No hay cuota para quien no ha pagado bien');

-- 5. Lo que diga Stripe se refleja tal cual (sin reglas propias).
select public.reflejar_estado_suscripcion_stripe('sub_A1', 'past_due');
select is((select payment_status from public.suscripciones where referencia_externa = 'sub_A1'),
  'past_due', 'Stripe dice «impagada»: la cuota deja de contar como pagada');
select public.reflejar_estado_suscripcion_stripe('sub_A1', 'active');
select is((select payment_status from public.suscripciones where referencia_externa = 'sub_A1'),
  'active', 'Stripe vuelve a cobrar: la cuota vuelve a estar al día');
select public.reflejar_estado_suscripcion_stripe('sub_A1', 'unpaid');
select is((select payment_status from public.suscripciones where referencia_externa = 'sub_A1'),
  'unpaid', 'Stripe corta el cobro: «sin pagar»');
select public.reflejar_estado_suscripcion_stripe('sub_A1', 'active');

-- 6. Cancelada en Stripe → el alumno pasa a baja en la app.
select public.guardar_sesion_stripe(
  (select pago_id from public.preparar_pago_stripe('00000000-0000-0000-0000-0000000e0005',
     '00000000-0000-0000-0000-0000000e0005', '00000000-0000-0000-0000-0000000e0d01')),
  'cs_sub3');
select public.confirmar_suscripcion_stripe('cs_sub3', 'sub_A3', 5000, 'eur');

select public.suscripcion_cancelada_en_stripe('sub_A1');
select is((select estado || '/' || payment_status from public.suscripciones where referencia_externa = 'sub_A1'),
  'cancelada/canceled', 'La cuota se cierra al cancelarla en Stripe');
select is((select estado from public.profiles where id = '00000000-0000-0000-0000-0000000e0003'),
  'baja', 'El alumno pasa a baja en la app');
select is((select fecha_fin is not null from public.suscripciones where referencia_externa = 'sub_A1'),
  true, 'La cuota no se borra: se cierra con fecha');
select is((select estado from public.profiles where id = '00000000-0000-0000-0000-0000000e0005'),
  'activo', 'Los demás alumnos no se tocan');
select is(current_setting('request.jwt.claims', true), '{"role":"service_role"}',
  'El servidor vuelve a ser el servidor (no se queda con la identidad del Dueño)');

-- 7. Un segundo aviso de la misma cancelación no hace nada ni falla.
select lives_ok($$ select public.suscripcion_cancelada_en_stripe('sub_A1') $$,
  'Otro aviso de cancelación no falla');

-- 8. La baja la dio antes la propia app (el Dueño): el aviso de Stripe que
-- llega después no repite nada.
reset role;
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000e0001');
select public.dar_de_baja_alumno('00000000-0000-0000-0000-0000000e0005');
reset role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
select lives_ok($$ select public.suscripcion_cancelada_en_stripe('sub_A3') $$,
  'Si la baja ya la dio el Dueño, el aviso de Stripe no falla');
select is((select estado from public.profiles where id = '00000000-0000-0000-0000-0000000e0005'),
  'baja', 'Y el alumno sigue de baja una sola vez');

-- 9. Una referencia desconocida se ignora.
select lives_ok($$ select public.suscripcion_cancelada_en_stripe('sub_no_existe') $$,
  'Una suscripción que no es de la app se ignora');

select * from finish();
rollback;
