-- Cobro con tarjeta (Stripe en modo prueba), lado base de datos. Ver
-- 20261117120000 y 20261117121000. Aquí no hay Stripe: se prueba lo que el
-- servidor hace cuando Stripe confirma (o no) un pago.

begin;
select plan(41);

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000d00aa', 'Academia PS', 'approved');
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000d0001', 'dueno-ps@test.dev'),
  ('00000000-0000-0000-0000-0000000d0002', 'profe-ps@test.dev'),
  ('00000000-0000-0000-0000-0000000d0003', 'alumno1-ps@test.dev'),
  ('00000000-0000-0000-0000-0000000d0004', 'alumno2-ps@test.dev'),
  ('00000000-0000-0000-0000-0000000d0005', 'tutor-ps@test.dev'),
  ('00000000-0000-0000-0000-0000000d0007', 'extrano-ps@test.dev'),
  ('00000000-0000-0000-0000-0000000d0008', 'alumno3-ps@test.dev'),
  ('00000000-0000-0000-0000-0000000d0009', 'alumno4-ps@test.dev');
insert into public.profiles (id, academia_id, rol, nombre, estado, tiene_cuenta) values
  ('00000000-0000-0000-0000-0000000d0001', '00000000-0000-0000-0000-0000000d00aa', 'dueño', 'Dueño', 'activo', true),
  ('00000000-0000-0000-0000-0000000d0002', '00000000-0000-0000-0000-0000000d00aa', 'profesor', 'Profe', 'activo', true),
  ('00000000-0000-0000-0000-0000000d0003', '00000000-0000-0000-0000-0000000d00aa', 'alumno', 'Uno', 'activo', true),
  ('00000000-0000-0000-0000-0000000d0004', '00000000-0000-0000-0000-0000000d00aa', 'alumno', 'Dos', 'activo', true),
  ('00000000-0000-0000-0000-0000000d0005', '00000000-0000-0000-0000-0000000d00aa', 'alumno', 'Tutor', 'activo', true),
  ('00000000-0000-0000-0000-0000000d0006', '00000000-0000-0000-0000-0000000d00aa', 'alumno', 'Hijo', 'activo', false),
  ('00000000-0000-0000-0000-0000000d0007', '00000000-0000-0000-0000-0000000d00aa', 'alumno', 'Extraño', 'activo', true),
  ('00000000-0000-0000-0000-0000000d0008', '00000000-0000-0000-0000-0000000d00aa', 'alumno', 'Tres', 'activo', true),
  ('00000000-0000-0000-0000-0000000d0009', '00000000-0000-0000-0000-0000000d00aa', 'alumno', 'Cuatro', 'activo', true),
  ('00000000-0000-0000-0000-0000000d000a', '00000000-0000-0000-0000-0000000d00aa', 'alumno', 'Pendiente', 'pendiente_aprobacion', true);
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000d000a', 'pend-ps@test.dev');
insert into public.relaciones_familia (parent_id, child_id) values
  ('00000000-0000-0000-0000-0000000d0005', '00000000-0000-0000-0000-0000000d0006');

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, clases_incluidas, activo) values
  ('00000000-0000-0000-0000-0000000d0d01', '00000000-0000-0000-0000-0000000d00aa', 'Mensual 8', 50, 'mensual', 8, true),
  ('00000000-0000-0000-0000-0000000d0d02', '00000000-0000-0000-0000-0000000d00aa', 'Bono 10', 80, 'trimestral', 10, true),
  ('00000000-0000-0000-0000-0000000d0d03', '00000000-0000-0000-0000-0000000d00aa', 'Día suelto', 10, 'suelta', 1, true),
  ('00000000-0000-0000-0000-0000000d0d04', '00000000-0000-0000-0000-0000000d00aa', 'Retirada', 40, 'mensual', 8, false);

create or replace function pg_temp.actuar_como(p_uid uuid)
returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$f$;

-- ------------------------------------------------------------
-- 1. Quién puede iniciar un pago (la función es del servidor)
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000d0003');
select throws_ok(
  $$ select * from public.preparar_pago_stripe('00000000-0000-0000-0000-0000000d0003',
       '00000000-0000-0000-0000-0000000d0003', '00000000-0000-0000-0000-0000000d0d01') $$,
  '42501', null, 'Un alumno no puede llamar a las funciones del servidor de Stripe'
);
select throws_ok(
  $$ select public.confirmar_pago_stripe('cs_x', 'pi_x', 5000, 'eur') $$,
  '42501', null, 'Y no puede darse por pagada una cuota él mismo'
);
reset role;

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;

select is(
  (select importe_centimos from public.preparar_pago_stripe('00000000-0000-0000-0000-0000000d0003',
     '00000000-0000-0000-0000-0000000d0003', '00000000-0000-0000-0000-0000000d0d02')),
  8000, 'El importe sale de la tarifa: bono trimestral = 8000 céntimos'
);
select throws_ok(
  $$ select * from public.preparar_pago_stripe('00000000-0000-0000-0000-0000000d0007',
       '00000000-0000-0000-0000-0000000d0003', '00000000-0000-0000-0000-0000000d0d01') $$,
  'Solo puedes pagar tu cuota o la de tus hijos.', 'Un extraño no puede pagar la cuota de otro'
);
select lives_ok(
  $$ select * from public.preparar_pago_stripe('00000000-0000-0000-0000-0000000d0005',
       '00000000-0000-0000-0000-0000000d0006', '00000000-0000-0000-0000-0000000d0d01') $$,
  'Un tutor sí puede pagar la cuota de su hijo'
);
select throws_ok(
  $$ select * from public.preparar_pago_stripe('00000000-0000-0000-0000-0000000d000a',
       '00000000-0000-0000-0000-0000000d000a', '00000000-0000-0000-0000-0000000d0d01') $$,
  'Esa persona no puede pagar una cuota.', 'Una alta pendiente de aprobar no puede pagar'
);
select throws_ok(
  $$ select * from public.preparar_pago_stripe('00000000-0000-0000-0000-0000000d0003',
       '00000000-0000-0000-0000-0000000d0003', '00000000-0000-0000-0000-0000000d0d04') $$,
  'Esa tarifa no está disponible.', 'Una tarifa retirada no se puede pagar'
);

-- Pulsar dos veces no abre dos pagos.
select is(
  (select reutilizado from public.preparar_pago_stripe('00000000-0000-0000-0000-0000000d0003',
     '00000000-0000-0000-0000-0000000d0003', '00000000-0000-0000-0000-0000000d0d02')),
  true, 'Un pago abierto del mismo alumno y tarifa se reutiliza'
);
select is(
  (select count(*)::int from public.pagos_stripe
    where alumno_id = '00000000-0000-0000-0000-0000000d0003' and tarifa_id = '00000000-0000-0000-0000-0000000d0d02'),
  1, 'Solo hay un pago abierto'
);
select public.guardar_sesion_stripe(
  (select id from public.pagos_stripe where alumno_id = '00000000-0000-0000-0000-0000000d0003'), 'cs_bono_1');

-- ------------------------------------------------------------
-- 2. Un pago correcto activa la cuota, una sola vez
-- ------------------------------------------------------------
select isnt(
  public.confirmar_pago_stripe('cs_bono_1', 'pi_bono_1', 8000, 'eur'), null,
  'Un pago confirmado devuelve la cuota activada'
);
select is(
  (select tarifa_nombre || '/' || clases_incluidas || '/' || periodicidad || '/' || estado || '/' || proveedor_pago || '/' || importe_cobrado
     from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000d0003'),
  'Bono 10/10/trimestral/activa/stripe/80.00', 'La cuota es la correcta: bono, 10 clases, trimestral, 80 €, por tarjeta'
);
select is(
  (select extract(month from age(fecha_fin, fecha_inicio))::int from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000d0003'),
  3, 'Dura 3 meses'
);
select is(
  (select estado from public.pagos_stripe where checkout_session_id = 'cs_bono_1'),
  'pagado', 'El pago queda como pagado'
);

-- Notificación repetida: no activa dos veces.
select is(
  public.confirmar_pago_stripe('cs_bono_1', 'pi_bono_1', 8000, 'eur'),
  (select id from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000d0003'),
  'Una notificación repetida devuelve la misma cuota'
);
select is(
  (select count(*)::int from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000d0003'),
  1, 'Y no crea una segunda'
);

-- ------------------------------------------------------------
-- 3. Importe distinto, fallos, abandono y reintento
-- ------------------------------------------------------------
select public.preparar_pago_stripe('00000000-0000-0000-0000-0000000d0004',
  '00000000-0000-0000-0000-0000000d0004', '00000000-0000-0000-0000-0000000d0d01');
select public.guardar_sesion_stripe(
  (select id from public.pagos_stripe where alumno_id = '00000000-0000-0000-0000-0000000d0004'), 'cs_mensual_2');

select is(
  public.confirmar_pago_stripe('cs_mensual_2', 'pi_m2', 100, 'eur'), null,
  'Si Stripe dice que se cobraron 1 € de una cuota de 50 €, no se activa'
);
select is(
  (select estado from public.pagos_stripe where checkout_session_id = 'cs_mensual_2'),
  'revisar', 'Queda en «revisar»'
);
select is(
  (select count(*)::int from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000d0004'),
  0, 'Sin cuota'
);
select matches(
  (select error from public.pagos_stripe where checkout_session_id = 'cs_mensual_2'),
  'no coincide', 'Con el motivo escrito para el Dueño'
);

-- Un intento rechazado y luego otro que sale bien (reintento dentro de la sesión).
select public.preparar_pago_stripe('00000000-0000-0000-0000-0000000d0008',
  '00000000-0000-0000-0000-0000000d0008', '00000000-0000-0000-0000-0000000d0d01');
select public.guardar_sesion_stripe(
  (select id from public.pagos_stripe where alumno_id = '00000000-0000-0000-0000-0000000d0008'), 'cs_reintento');
select public.anotar_intento_fallido_stripe(
  (select id from public.pagos_stripe where checkout_session_id = 'cs_reintento'), 'Tu tarjeta ha sido rechazada.');
select is(
  (select estado || '/' || intentos_fallidos from public.pagos_stripe where checkout_session_id = 'cs_reintento'),
  'creado/1', 'Un intento rechazado se anota pero el pago sigue abierto para reintentar'
);
select isnt(
  public.confirmar_pago_stripe('cs_reintento', 'pi_re', 5000, 'eur'), null,
  'El reintento que sale bien activa la cuota'
);
select is(
  (select estado || '/' || coalesce(error, 'sin error') from public.pagos_stripe where checkout_session_id = 'cs_reintento'),
  'pagado/sin error', 'Y el pago queda limpio'
);

-- Abandonado: la sesión caduca sin pagar.
select public.preparar_pago_stripe('00000000-0000-0000-0000-0000000d0009',
  '00000000-0000-0000-0000-0000000d0009', '00000000-0000-0000-0000-0000000d0d01');
select public.guardar_sesion_stripe(
  (select id from public.pagos_stripe where alumno_id = '00000000-0000-0000-0000-0000000d0009'), 'cs_abandonado');
select public.cerrar_pago_stripe('cs_abandonado', 'expirado', 'La sesión de pago caducó sin pagar.');
select is(
  (select estado from public.pagos_stripe where checkout_session_id = 'cs_abandonado'),
  'expirado', 'Un pago abandonado queda como expirado'
);
select is(
  (select count(*)::int from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000d0009'),
  0, 'Sin cuota'
);
-- Un pago tardío sobre una sesión ya cerrada NO se pierde: se activa.
select isnt(
  public.confirmar_pago_stripe('cs_abandonado', 'pi_tarde', 5000, 'eur'), null,
  'Si Stripe confirma un pago de una sesión ya marcada como expirada, se activa (no se pierde un cobro)'
);
reset role;

-- ------------------------------------------------------------
-- 4. Mismas condiciones que el cobro en mano
-- ------------------------------------------------------------
-- El Dueño cobra en mano el mismo bono a un cuarto alumno y se compara.
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000d000b', 'alumno5-ps@test.dev');
insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000d000b', '00000000-0000-0000-0000-0000000d00aa', 'alumno', 'Cinco', 'activo');
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000d0001');
select lives_ok(
  $$ select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000d000b',
       '00000000-0000-0000-0000-0000000d0d02', null, false, null, 3, gen_random_uuid()) $$,
  'El Dueño cobra el mismo bono en mano'
);
reset role;
select is(
  (select tarifa_nombre || '/' || clases_incluidas || '/' || periodicidad || '/' || importe_cobrado || '/' || (fecha_fin - fecha_inicio)::text
     from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000d000b'),
  (select tarifa_nombre || '/' || clases_incluidas || '/' || periodicidad || '/' || importe_cobrado || '/' || (fecha_fin - fecha_inicio)::text
     from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000d0003'),
  'Tarjeta y en mano dan exactamente la misma cuota: mismas clases, periodo, importe y duración'
);

-- Con la cuota en vigor, otro pago es una renovación (no duplica derechos).
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
select public.preparar_pago_stripe('00000000-0000-0000-0000-0000000d0003',
  '00000000-0000-0000-0000-0000000d0003', '00000000-0000-0000-0000-0000000d0d02');
select public.guardar_sesion_stripe(
  (select id from public.pagos_stripe where alumno_id = '00000000-0000-0000-0000-0000000d0003' and checkout_session_id is null), 'cs_renov');
select isnt(public.confirmar_pago_stripe('cs_renov', 'pi_renov', 8000, 'eur'), null, 'Pagar otro bono con la cuota en vigor es una renovación');
select is(
  (select count(*)::int from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000d0003' and estado = 'programada'),
  1, 'Queda programada para cuando acabe la actual'
);
select is(
  (select count(*)::int from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000d0003' and estado = 'activa'),
  1, 'La actual sigue siendo la única activa'
);
-- Ya con una renovación pendiente no se deja pagar otra.
select throws_ok(
  $$ select * from public.preparar_pago_stripe('00000000-0000-0000-0000-0000000d0003',
       '00000000-0000-0000-0000-0000000d0003', '00000000-0000-0000-0000-0000000d0d02') $$,
  'Ya tiene una renovación pagada pendiente de empezar.', 'No se deja pagar una segunda renovación'
);

-- Pago que ya no se puede aplicar (dos sesiones abiertas a la vez): no se pierde.
insert into public.pagos_stripe (academia_id, alumno_id, tarifa_id, pagado_por, importe_esperado, checkout_session_id)
values ('00000000-0000-0000-0000-0000000d00aa', '00000000-0000-0000-0000-0000000d0003',
        '00000000-0000-0000-0000-0000000d0d02', '00000000-0000-0000-0000-0000000d0003', 80, 'cs_doble');
select is(public.confirmar_pago_stripe('cs_doble', 'pi_doble', 8000, 'eur'), null,
  'Un pago que ya no cabe (renovación pendiente ya existente) no se activa');
select is(
  (select estado from public.pagos_stripe where checkout_session_id = 'cs_doble'),
  'revisar', 'Queda en «revisar», con el dinero cobrado a la vista'
);
select matches(
  (select error from public.pagos_stripe where checkout_session_id = 'cs_doble'),
  'Cobrado, pero no se ha podido activar', 'Con el motivo'
);

-- ------------------------------------------------------------
-- 5. Devoluciones
-- ------------------------------------------------------------
select public.registrar_devolucion_stripe('pi_bono_1', 2000);
select is(
  (select estado from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000d0003' and estado = 'activa' limit 1),
  'activa', 'Una devolución parcial no cierra la cuota'
);
select is(
  (select importe_devuelto from public.pagos_stripe where checkout_session_id = 'cs_bono_1'),
  20.00, 'Pero queda anotada'
);
select public.registrar_devolucion_stripe('pi_bono_1', 8000);
select is(
  (select estado from public.pagos_stripe where checkout_session_id = 'cs_bono_1'),
  'reembolsado', 'Una devolución total marca el pago como reembolsado'
);
select is(
  (select estado from public.suscripciones where id = (select suscripcion_id from public.pagos_stripe where checkout_session_id = 'cs_bono_1')),
  'cancelada', 'Y cancela la cuota que dio'
);
reset role;

-- ------------------------------------------------------------
-- 6. Quién ve los pagos
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000d0003');
select ok(
  (select count(*) from public.pagos_stripe) > 0
  and (select count(*) from public.pagos_stripe where alumno_id <> '00000000-0000-0000-0000-0000000d0003') = 0,
  'El alumno ve solo sus pagos'
);
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000d0002');
select is((select count(*)::int from public.pagos_stripe), 0, 'El Profesor no ve los pagos (llevan importes)');
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000d0001');
select ok(
  (select count(*) from public.pagos_stripe where estado = 'revisar') = 2,
  'El Dueño ve los pagos con problema (2 en «revisar»)'
);
reset role;

select * from finish();
rollback;
