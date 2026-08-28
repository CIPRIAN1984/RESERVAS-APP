-- Cuotas cobradas en efectivo por el Dueño.
--
-- Lo que se protege aquí es dinero y acceso: una cuota activa es lo que
-- permite a un Alumno reservar plaza. Si esta puerta se abre de más, cualquier
-- alumno podría darse cuota a sí mismo y entrenar gratis.
begin;
select plan(18);

-- ------------------------------------------------------------
-- Escenario: dos academias, para comprobar el aislamiento
-- ------------------------------------------------------------

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000cf101', 'dueno-cuota-a@test.dev'),
  ('00000000-0000-0000-0000-0000000cf102', 'alumno-cuota-a@test.dev'),
  ('00000000-0000-0000-0000-0000000cf103', 'profesor-cuota-a@test.dev'),
  ('00000000-0000-0000-0000-0000000cf104', 'alumno-pendiente@test.dev'),
  ('00000000-0000-0000-0000-0000000cf201', 'dueno-cuota-b@test.dev'),
  ('00000000-0000-0000-0000-0000000cf202', 'alumno-cuota-b@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000cf0aa', 'Academia A', 'approved'),
  ('00000000-0000-0000-0000-0000000cf0bb', 'Academia B', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000cf101',
   '00000000-0000-0000-0000-0000000cf0aa', 'dueño',    'Dueño A',     'activo'),
  ('00000000-0000-0000-0000-0000000cf102',
   '00000000-0000-0000-0000-0000000cf0aa', 'alumno',   'Alumno A',    'activo'),
  ('00000000-0000-0000-0000-0000000cf103',
   '00000000-0000-0000-0000-0000000cf0aa', 'profesor', 'Profesor A',  'activo'),
  ('00000000-0000-0000-0000-0000000cf104',
   '00000000-0000-0000-0000-0000000cf0aa', 'alumno',   'Alumno nuevo',
   'pendiente_aprobacion'),
  ('00000000-0000-0000-0000-0000000cf201',
   '00000000-0000-0000-0000-0000000cf0bb', 'dueño',    'Dueño B',     'activo'),
  ('00000000-0000-0000-0000-0000000cf202',
   '00000000-0000-0000-0000-0000000cf0bb', 'alumno',   'Alumno B',    'activo');

insert into public.tarifas
  (id, academia_id, nombre, precio, periodicidad, activo) values
  ('00000000-0000-0000-0000-0000000cfa01',
   '00000000-0000-0000-0000-0000000cf0aa', 'Mensual A', 50, 'mensual', true),
  ('00000000-0000-0000-0000-0000000cfa02',
   '00000000-0000-0000-0000-0000000cf0aa', 'Retirada',  40, 'mensual', false),
  ('00000000-0000-0000-0000-0000000cfa03',
   '00000000-0000-0000-0000-0000000cf0bb', 'Mensual B', 60, 'mensual', true);

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

-- ------------------------------------------------------------
-- Permisos de la propia función
-- ------------------------------------------------------------

select ok(
  not has_function_privilege(
    'anon',
    'public.activar_cuota_efectivo(uuid,uuid,timestamptz,boolean)',
    'EXECUTE'
  ),
  'Sin iniciar sesión no se puede alcanzar la función'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.activar_cuota_efectivo(uuid,uuid,timestamptz,boolean)',
    'EXECUTE'
  ),
  'Quien ha iniciado sesión la alcanza; el rol se valida en el servidor'
);

-- ------------------------------------------------------------
-- Quién NO puede dar cuotas
-- ------------------------------------------------------------

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000cf102');
select throws_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cf102',
       '00000000-0000-0000-0000-0000000cfa01'
     ) $$,
  null,
  'Un Alumno no puede darse cuota a sí mismo'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000cf103');
select throws_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cf102',
       '00000000-0000-0000-0000-0000000cfa01'
     ) $$,
  null,
  'Un Profesor tampoco: el dinero es cosa del Dueño'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000cf201');
select throws_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cf102',
       '00000000-0000-0000-0000-0000000cfa03'
     ) $$,
  null,
  'El Dueño de otra academia no puede dar cuota a un alumno ajeno'
);

-- ------------------------------------------------------------
-- Validaciones del Dueño legítimo
-- ------------------------------------------------------------

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000cf101');

select throws_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cf202',
       '00000000-0000-0000-0000-0000000cfa01'
     ) $$,
  null,
  'No se puede dar cuota a un alumno de otra academia'
);

select throws_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cf102',
       '00000000-0000-0000-0000-0000000cfa03'
     ) $$,
  null,
  'No se puede usar una tarifa de otra academia'
);

select throws_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cf102',
       '00000000-0000-0000-0000-0000000cfa02'
     ) $$,
  null,
  'No se puede usar una tarifa desactivada'
);

select throws_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cf104',
       '00000000-0000-0000-0000-0000000cfa01'
     ) $$,
  null,
  'No se puede dar cuota a quien aún no está aprobado'
);

select throws_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cf103',
       '00000000-0000-0000-0000-0000000cfa01'
     ) $$,
  null,
  'No se da cuota a un Profesor: ya reserva sin ella'
);

select throws_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cf102',
       '00000000-0000-0000-0000-0000000cfa01',
       now() - interval '1 day'
     ) $$,
  null,
  'La fecha de fin no puede estar en el pasado'
);

-- ------------------------------------------------------------
-- El camino bueno
-- ------------------------------------------------------------

select lives_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cf102',
       '00000000-0000-0000-0000-0000000cfa01',
       now() + interval '30 days'
     ) $$,
  'El Dueño da cuota en efectivo a un Alumno de su academia'
);

-- Se vuelve al rol privilegiado: como Dueño, los permisos de fila filtran
-- lo que se ve, y estas comprobaciones son sobre lo que hizo la función, no
-- sobre quién puede leerlo.
reset role;

select is(
  (select count(*)::int
     from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000cf102'
      and estado = 'activa'
      and payment_status = 'active'
      and proveedor_pago = 'efectivo'
      and referencia_externa is null),
  1,
  'Queda una cuota activa, en efectivo y sin referencia de Stripe'
);

-- Esto es lo que de verdad importa: que con esa cuota ya pueda reservar.
select is(
  (select count(*)::int
     from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000cf102'
      and academia_id = '00000000-0000-0000-0000-0000000cf0aa'
      and estado = 'activa'
      and payment_status = 'active'
      and fecha_inicio <= now()
      and (fecha_fin is null or fecha_fin > now())),
  1,
  'Cumple exactamente la condición que exige reservar_clase'
);

-- ------------------------------------------------------------
-- Renovar no acumula cuotas
-- ------------------------------------------------------------

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000cf101');
select lives_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cf102',
       '00000000-0000-0000-0000-0000000cfa01',
       now() + interval '60 days'
     ) $$,
  'Se puede renovar la cuota del mismo alumno'
);
reset role;

select is(
  (select count(*)::int
     from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000cf102'
      and proveedor_pago = 'efectivo'
      and estado = 'activa'),
  1,
  'Renovar cierra la anterior en vez de apilar cuotas activas'
);

-- ------------------------------------------------------------
-- Retirar la cuota
-- ------------------------------------------------------------

-- Una suscripción de Stripe no se toca desde aquí. Se inserta con el rol
-- privilegiado porque la tabla no admite escrituras desde el cliente.
reset role;
insert into public.suscripciones
  (id, alumno_id, tarifa_id, academia_id, estado,
   proveedor_pago, referencia_externa, payment_status)
values
  ('00000000-0000-0000-0000-0000000cfb99',
   '00000000-0000-0000-0000-0000000cf104',
   '00000000-0000-0000-0000-0000000cfa01',
   '00000000-0000-0000-0000-0000000cf0aa',
   'activa', 'stripe', 'sub_test_123', 'active');

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000cf101');
select throws_ok(
  $$ select public.desactivar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cfb99'
     ) $$,
  null,
  'Una cuota de Stripe no se retira desde la app'
);

-- Y tampoco se le encima una en efectivo: el indice unico no lo permite, y
-- es mejor decirlo que reventar con un error de clave duplicada.
select throws_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cf104',
       '00000000-0000-0000-0000-0000000cfa01',
       now() + interval '30 days'
     ) $$,
  null,
  'No se encima una cuota en efectivo a quien ya paga por tarjeta'
);

rollback;
