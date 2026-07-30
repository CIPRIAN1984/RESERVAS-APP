-- Regresiones de seguridad y consistencia del flujo de reservas/pagos.
begin;
select plan(10);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000c01', 'owner-hardening@test.dev'),
  ('00000000-0000-0000-0000-000000000c02', 'paid-one@test.dev'),
  ('00000000-0000-0000-0000-000000000c03', 'paid-two@test.dev'),
  ('00000000-0000-0000-0000-000000000c04', 'unpaid@test.dev');

-- Esta suite comprueba la regla estricta: sin cuota no se reserva. Desde
-- julio de 2026 eso es un ajuste de cada academia y viene apagado por
-- defecto, así que aquí se enciende a propósito. El comportamiento por
-- defecto lo cubre `reservar_sin_cuota_test.sql`.
insert into public.academias
  (id, nombre, estado, exigir_cuota_para_reservar) values
  ('00000000-0000-0000-0000-0000000000CC', 'Academia Hardening', 'approved',
   true);

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-0000000000CC', 'dueño', 'Dueño', 'activo'),
  ('00000000-0000-0000-0000-000000000c02', '00000000-0000-0000-0000-0000000000CC', 'alumno', 'Alumno Pago 1', 'activo'),
  ('00000000-0000-0000-0000-000000000c03', '00000000-0000-0000-0000-0000000000CC', 'alumno', 'Alumno Pago 2', 'activo'),
  ('00000000-0000-0000-0000-000000000c04', '00000000-0000-0000-0000-0000000000CC', 'alumno', 'Alumno Sin Pago', 'activo');

insert into public.clases (
  id,
  academia_id,
  profesor_id,
  titulo,
  fecha_hora_inicio,
  fecha_hora_fin,
  aforo_maximo
) values (
  '00000000-0000-0000-0000-00000000c201',
  '00000000-0000-0000-0000-0000000000CC',
  '00000000-0000-0000-0000-000000000c01',
  'Clase de aforo uno',
  now() + interval '1 day',
  now() + interval '1 day 1 hour',
  1
);

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad)
values (
  '00000000-0000-0000-0000-00000000f201',
  '00000000-0000-0000-0000-0000000000CC',
  'Mensual',
  50,
  'mensual'
);

insert into public.suscripciones (
  id,
  alumno_id,
  tarifa_id,
  academia_id,
  referencia_externa
) values
  (
    '00000000-0000-0000-0000-00000000d201',
    '00000000-0000-0000-0000-000000000c02',
    '00000000-0000-0000-0000-00000000f201',
    '00000000-0000-0000-0000-0000000000CC',
    'sub_paid_one'
  ),
  (
    '00000000-0000-0000-0000-00000000d202',
    '00000000-0000-0000-0000-000000000c03',
    '00000000-0000-0000-0000-00000000f201',
    '00000000-0000-0000-0000-0000000000CC',
    'sub_paid_two'
  );

update public.suscripciones
  set estado = 'activa', payment_status = 'active'
  where id in (
    '00000000-0000-0000-0000-00000000d201',
    '00000000-0000-0000-0000-00000000d202'
  );

create or replace function pg_temp.actuar_como(p_uid uuid)
returns void
language plpgsql
as $function$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text,
    true
  );
  perform set_config('role', 'authenticated', true);
end;
$function$;

-- 1. Un alumno no puede ascenderse ni mover campos administrativos.
select pg_temp.actuar_como('00000000-0000-0000-0000-000000000c02');
select throws_ok(
  $$ update public.profiles
       set rol = 'administrador'
       where id = '00000000-0000-0000-0000-000000000c02' $$,
  null,
  'Un alumno no puede cambiar su rol'
);

-- 2-3. El dueño tampoco puede autoaprobar/rechazar su academia.
select pg_temp.actuar_como('00000000-0000-0000-0000-000000000c01');
select throws_ok(
  $$ update public.academias
       set estado = 'rejected'
       where id = '00000000-0000-0000-0000-0000000000CC' $$,
  null,
  'El dueño no puede editar directamente el estado de la academia'
);
select throws_ok(
  $$ select public.rechazar_academia('00000000-0000-0000-0000-0000000000CC') $$,
  null,
  'La RPC de rechazo exige rol administrador'
);

-- 4. Sin cuota cobrada no se puede reservar.
select pg_temp.actuar_como('00000000-0000-0000-0000-000000000c04');
select throws_ok(
  $$ select public.reservar_clase('00000000-0000-0000-0000-00000000c201') $$,
  null,
  'Un alumno sin cuota activa no puede reservar'
);

-- 5. Con cuota activa sí se confirma la plaza.
select pg_temp.actuar_como('00000000-0000-0000-0000-000000000c02');
select lives_ok(
  $$ select public.reservar_clase('00000000-0000-0000-0000-00000000c201') $$,
  'Un alumno con cuota activa puede reservar'
);

-- 6. La segunda reserva no rebasa el aforo: entra en espera.
select pg_temp.actuar_como('00000000-0000-0000-0000-000000000c03');
select is(
  public.reservar_clase('00000000-0000-0000-0000-00000000c201'),
  'espera',
  'La segunda reserva entra en espera sin superar el aforo'
);

-- 7. Solo queda una plaza activa.
select is(
  (
    select count(*)::int
      from public.inscripciones
      where clase_id = '00000000-0000-0000-0000-00000000c201'
        and estado = 'inscrito'
  ),
  1,
  'El aforo activo queda exactamente en uno'
);

-- 8. El cliente no puede cancelar solo en Postgres y dejar Stripe cobrando.
select pg_temp.actuar_como('00000000-0000-0000-0000-000000000c02');
select throws_ok(
  $$ update public.suscripciones
       set estado = 'cancelada'
       where id = '00000000-0000-0000-0000-00000000d201' $$,
  null,
  'La cancelación directa de una suscripción está revocada'
);

-- 9-10. La baja de la clase pasa por RPC y libera la plaza.
select lives_ok(
  $$ select public.cancelar_reserva('00000000-0000-0000-0000-00000000c201') $$,
  'El alumno puede cancelar su propia reserva'
);
select is(
  (
    select estado
      from public.inscripciones
      where clase_id = '00000000-0000-0000-0000-00000000c201'
        and alumno_id = '00000000-0000-0000-0000-000000000c03'
  ),
  'inscrito',
  'Cancelar libera la plaza y promociona a la lista de espera'
);

select * from finish();
rollback;
