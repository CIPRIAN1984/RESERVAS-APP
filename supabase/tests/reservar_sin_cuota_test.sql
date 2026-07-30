-- Reservar sin cuota: interruptor por academia.
--
-- Aquí se protege dinero. Abrir la reserva a quien no paga es una decisión
-- de producto deliberada, pero tiene que seguir siendo del Dueño de CADA
-- academia y no debe abrir ninguna otra puerta: un alumno no puede tocar el
-- ajuste, ni cambiarlo en la academia de al lado, ni colarse en una clase que
-- no es suya.
begin;
select plan(12);

-- ------------------------------------------------------------
-- Escenario: dos academias con el ajuste puesto al revés
-- ------------------------------------------------------------

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000ac101', 'dueno-sincuota-a@test.dev'),
  ('00000000-0000-0000-0000-0000000ac102', 'alumno-sincuota-a@test.dev'),
  ('00000000-0000-0000-0000-0000000ac201', 'dueno-sincuota-b@test.dev'),
  ('00000000-0000-0000-0000-0000000ac202', 'alumno-sincuota-b@test.dev');

insert into public.academias (id, nombre, estado, exigir_cuota_para_reservar)
values
  ('00000000-0000-0000-0000-0000000ac0aa', 'Academia sin cuota', 'approved',
   false),
  ('00000000-0000-0000-0000-0000000ac0bb', 'Academia con cuota', 'approved',
   true);

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000ac101',
   '00000000-0000-0000-0000-0000000ac0aa', 'dueño',  'Dueño A',  'activo'),
  ('00000000-0000-0000-0000-0000000ac102',
   '00000000-0000-0000-0000-0000000ac0aa', 'alumno', 'Alumno A', 'activo'),
  ('00000000-0000-0000-0000-0000000ac201',
   '00000000-0000-0000-0000-0000000ac0bb', 'dueño',  'Dueño B',  'activo'),
  ('00000000-0000-0000-0000-0000000ac202',
   '00000000-0000-0000-0000-0000000ac0bb', 'alumno', 'Alumno B', 'activo');

insert into public.clases
  (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin,
   aforo_maximo)
values
  ('00000000-0000-0000-0000-0000000ac0c1',
   '00000000-0000-0000-0000-0000000ac0aa',
   '00000000-0000-0000-0000-0000000ac101', 'Clase A',
   now() + interval '2 days', now() + interval '2 days 1 hour', 20),
  ('00000000-0000-0000-0000-0000000ac0c2',
   '00000000-0000-0000-0000-0000000ac0bb',
   '00000000-0000-0000-0000-0000000ac201', 'Clase B',
   now() + interval '2 days', now() + interval '2 days 1 hour', 20);

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
-- El valor por defecto es el que ha pedido Cipri
-- ------------------------------------------------------------

reset role;
insert into public.academias (id, nombre, estado)
values ('00000000-0000-0000-0000-0000000ac0cc', 'Academia recién creada',
        'approved');

select is(
  (select exigir_cuota_para_reservar from public.academias
    where id = '00000000-0000-0000-0000-0000000ac0cc'),
  false,
  'Una academia nueva NO exige cuota para reservar'
);

-- ------------------------------------------------------------
-- Con el ajuste apagado: se reserva sin cuota
-- ------------------------------------------------------------

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ac102');

select is(
  (select public.reservar_clase('00000000-0000-0000-0000-0000000ac0c1')),
  'inscrito',
  'Un alumno sin cuota se apunta cuando la academia no la exige'
);

select throws_ok(
  $$ select public.reservar_clase('00000000-0000-0000-0000-0000000ac0c1') $$,
  null,
  'Sigue sin poder apuntarse dos veces a la misma clase'
);

select throws_ok(
  $$ select public.reservar_clase('00000000-0000-0000-0000-0000000ac0c2') $$,
  null,
  'No puede reservar en una clase de otra academia'
);

reset role;

select is(
  (select count(*)::int from public.inscripciones
    where clase_id = '00000000-0000-0000-0000-0000000ac0c1'
      and alumno_id = '00000000-0000-0000-0000-0000000ac102'
      and estado = 'inscrito'),
  1,
  'La inscripción queda guardada'
);

-- Y no por eso se le regala una cuota: sigue sin tenerla, que es justo lo
-- que el Dueño tiene que ver marcado en la lista de la clase.
select is(
  (select count(*)::int from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000ac102'),
  0,
  'Reservar sin cuota no le crea ninguna cuota'
);

-- ------------------------------------------------------------
-- Con el ajuste encendido: vuelve a hacer falta la cuota
-- ------------------------------------------------------------

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ac202');

select throws_ok(
  $$ select public.reservar_clase('00000000-0000-0000-0000-0000000ac0c2') $$,
  null,
  'Donde sí se exige, un alumno sin cuota sigue sin poder reservar'
);

reset role;

with nueva_tarifa as (
  insert into public.tarifas
    (academia_id, nombre, precio, periodicidad, activo)
  values ('00000000-0000-0000-0000-0000000ac0bb', 'Mensual B', 50, 'mensual',
          true)
  returning id
)
insert into public.suscripciones
  (alumno_id, academia_id, tarifa_id, proveedor_pago, referencia_externa)
select '00000000-0000-0000-0000-0000000ac202',
       '00000000-0000-0000-0000-0000000ac0bb',
       id, 'efectivo', null
  from nueva_tarifa;

-- El disparador de altas deja toda suscripción nueva en pendiente_pago: se
-- activa después, igual que hace `activar_cuota_efectivo`.
update public.suscripciones
   set estado = 'activa', payment_status = 'active'
 where alumno_id = '00000000-0000-0000-0000-0000000ac202';

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ac202');

select is(
  (select public.reservar_clase('00000000-0000-0000-0000-0000000ac0c2')),
  'inscrito',
  'Con la cuota activa sí reserva'
);

-- ------------------------------------------------------------
-- Quién puede cambiar el ajuste
-- ------------------------------------------------------------

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ac102');

-- Intenta ENCENDERLO en la suya (donde está apagado): no debe poder.
update public.academias
   set exigir_cuota_para_reservar = true
 where id = '00000000-0000-0000-0000-0000000ac0aa';

-- Y APAGARLO en la de al lado, que es lo que de verdad haría daño: entrar
-- gratis en una academia que sí cobra por adelantado.
update public.academias
   set exigir_cuota_para_reservar = false
 where id = '00000000-0000-0000-0000-0000000ac0bb';

reset role;

select is(
  (select exigir_cuota_para_reservar from public.academias
    where id = '00000000-0000-0000-0000-0000000ac0aa'),
  false,
  'Un alumno no puede encender el ajuste de su academia'
);

select is(
  (select exigir_cuota_para_reservar from public.academias
    where id = '00000000-0000-0000-0000-0000000ac0bb'),
  true,
  'Un alumno no puede quitar la exigencia de cuota de otra academia'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ac201');

update public.academias
   set exigir_cuota_para_reservar = false
 where id = '00000000-0000-0000-0000-0000000ac0bb';

-- Y no se le cuela nada más por la misma puerta.
select throws_ok(
  $$ update public.academias
        set estado = 'approved'
      where id = '00000000-0000-0000-0000-0000000ac0bb' $$,
  null,
  'El Dueño sigue sin poder tocar el estado de su academia'
);

reset role;

select is(
  (select exigir_cuota_para_reservar from public.academias
    where id = '00000000-0000-0000-0000-0000000ac0bb'),
  false,
  'El Dueño sí puede cambiar el ajuste de la suya'
);

rollback;
