-- Lista de espera FIFO, promociones y política de cancelación.
begin;
select plan(23);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000d01', 'owner-waitlist@test.dev'),
  ('00000000-0000-0000-0000-000000000d02', 'paid-one-waitlist@test.dev'),
  ('00000000-0000-0000-0000-000000000d03', 'paid-two-waitlist@test.dev');

insert into public.academias (id, nombre, estado) values
  (
    '00000000-0000-0000-0000-000000000dd1',
    'Academia Waitlist',
    'approved'
  );

insert into public.profiles (
  id,
  academia_id,
  rol,
  nombre,
  estado
) values
  (
    '00000000-0000-0000-0000-000000000d01',
    '00000000-0000-0000-0000-000000000dd1',
    'dueño',
    'Dueño Waitlist',
    'activo'
  ),
  (
    '00000000-0000-0000-0000-000000000d02',
    '00000000-0000-0000-0000-000000000dd1',
    'alumno',
    'Alumno Uno',
    'activo'
  ),
  (
    '00000000-0000-0000-0000-000000000d03',
    '00000000-0000-0000-0000-000000000dd1',
    'alumno',
    'Alumno Dos',
    'activo'
  );

insert into public.tarifas (
  id,
  academia_id,
  nombre,
  precio,
  periodicidad
) values (
  '00000000-0000-0000-0000-00000000f301',
  '00000000-0000-0000-0000-000000000dd1',
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
    '00000000-0000-0000-0000-00000000d301',
    '00000000-0000-0000-0000-000000000d02',
    '00000000-0000-0000-0000-00000000f301',
    '00000000-0000-0000-0000-000000000dd1',
    'sub_waitlist_one'
  ),
  (
    '00000000-0000-0000-0000-00000000d302',
    '00000000-0000-0000-0000-000000000d03',
    '00000000-0000-0000-0000-00000000f301',
    '00000000-0000-0000-0000-000000000dd1',
    'sub_waitlist_two'
  );

update public.suscripciones
  set estado = 'activa',
      payment_status = 'active'
  where id in (
    '00000000-0000-0000-0000-00000000d301',
    '00000000-0000-0000-0000-00000000d302'
  );

insert into public.clases (
  id,
  academia_id,
  profesor_id,
  titulo,
  fecha_hora_inicio,
  fecha_hora_fin,
  aforo_maximo
) values
  (
    '00000000-0000-0000-0000-00000000c301',
    '00000000-0000-0000-0000-000000000dd1',
    '00000000-0000-0000-0000-000000000d01',
    'Clase con espera',
    now() + interval '1 day',
    now() + interval '1 day 1 hour',
    1
  ),
  (
    '00000000-0000-0000-0000-00000000c302',
    '00000000-0000-0000-0000-000000000dd1',
    '00000000-0000-0000-0000-000000000d01',
    'Clase cancelación tardía',
    now() + interval '2 hours',
    now() + interval '3 hours',
    1
  ),
  (
    '00000000-0000-0000-0000-00000000c303',
    '00000000-0000-0000-0000-000000000dd1',
    '00000000-0000-0000-0000-000000000d01',
    'Clase sin espera',
    now() + interval '1 day',
    now() + interval '1 day 1 hour',
    1
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

-- 1. La primera reserva obtiene plaza.
select pg_temp.actuar_como('00000000-0000-0000-0000-000000000d02');
select is(
  public.reservar_clase('00000000-0000-0000-0000-00000000c301'),
  'inscrito',
  'La primera reserva queda confirmada'
);

-- 2. La segunda entra automáticamente en la cola.
select pg_temp.actuar_como('00000000-0000-0000-0000-000000000d03');
select is(
  public.reservar_clase('00000000-0000-0000-0000-00000000c301'),
  'espera',
  'La segunda reserva entra en lista de espera'
);

-- 3-4. Nunca se supera el aforo y la cola queda separada.
select is(
  (
    select count(*)::int
      from public.inscripciones
      where clase_id = '00000000-0000-0000-0000-00000000c301'
        and estado = 'inscrito'
  ),
  1,
  'Solo hay una plaza confirmada'
);
select is(
  (
    select count(*)::int
      from public.inscripciones
      where clase_id = '00000000-0000-0000-0000-00000000c301'
        and estado = 'espera'
  ),
  1,
  'Hay una persona esperando'
);

-- 5-6. Al cancelar con tiempo, la primera persona de la cola sube sola.
select pg_temp.actuar_como('00000000-0000-0000-0000-000000000d02');
select is(
  public.cancelar_reserva(
    '00000000-0000-0000-0000-00000000c301'
  ) ->> 'cancelacion_tardia',
  'false',
  'La cancelación hecha con tiempo no queda marcada como tardía'
);
select is(
  (
    select estado
      from public.inscripciones
      where clase_id = '00000000-0000-0000-0000-00000000c301'
        and alumno_id = '00000000-0000-0000-0000-000000000d03'
  ),
  'inscrito',
  'La primera persona de la cola es promocionada'
);

-- 7. La promoción genera una notificación sin intervención manual.
reset role;
select is(
  (
    select count(*)::int
      from public.notificaciones_outbox
      where user_id = '00000000-0000-0000-0000-000000000d03'
        and data ->> 'type' = 'waitlist_promoted'
  ),
  1,
  'La promoción encola una notificación push'
);

-- 8-9. Dentro de la ventana configurada, la baja queda marcada como tardía.
select pg_temp.actuar_como('00000000-0000-0000-0000-000000000d02');
select is(
  public.reservar_clase('00000000-0000-0000-0000-00000000c302'),
  'inscrito',
  'El alumno reserva la clase cercana'
);
select is(
  public.cancelar_reserva(
    '00000000-0000-0000-0000-00000000c302'
  ) ->> 'cancelacion_tardia',
  'true',
  'La cancelación dentro de cuatro horas queda marcada como tardía'
);

-- 10-12. Si el dueño desactiva la cola, la clase llena rechaza la reserva.
reset role;
update public.academias
  set lista_espera_activa = false
  where id = '00000000-0000-0000-0000-000000000dd1';

select pg_temp.actuar_como('00000000-0000-0000-0000-000000000d02');
select is(
  public.reservar_clase('00000000-0000-0000-0000-00000000c303'),
  'inscrito',
  'La primera plaza se confirma con la cola desactivada'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-000000000d03');
select throws_ok(
  $booking$
    select public.reservar_clase(
      '00000000-0000-0000-0000-00000000c303'
    )
  $booking$,
  null,
  'Una clase llena rechaza altas cuando la cola está desactivada'
);
select is(
  (
    select count(*)::int
      from public.inscripciones
      where clase_id = '00000000-0000-0000-0000-00000000c303'
        and estado = 'espera'
  ),
  0,
  'No se crea ninguna entrada de espera si la cola está desactivada'
);

-- ============================================================
-- La promoción también comprueba clases_restantes, no solo que la
-- cuota siga activa (20260813120000_promocion_lista_espera_con_creditos).
-- ============================================================

reset role;
select set_config('request.jwt.claims', '{}', true);

-- El escenario "cola desactivada" de más arriba dejó lista_espera_activa
-- en false para esta academia: hay que devolverla a true para los
-- escenarios de abajo, que sí necesitan cola.
update public.academias
  set lista_espera_activa = true
  where id = '00000000-0000-0000-0000-000000000dd1';

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000d04', 'agotado-waitlist@test.dev'),
  ('00000000-0000-0000-0000-000000000d05', 'con-credito-waitlist@test.dev'),
  ('00000000-0000-0000-0000-000000000d06', 'caducada-waitlist@test.dev'),
  ('00000000-0000-0000-0000-000000000d07', 'segundo-credito-waitlist@test.dev');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-000000000d04', '00000000-0000-0000-0000-000000000dd1', 'alumno', 'Agotado', 'activo'),
  ('00000000-0000-0000-0000-000000000d05', '00000000-0000-0000-0000-000000000dd1', 'alumno', 'Con crédito', 'activo'),
  ('00000000-0000-0000-0000-000000000d06', '00000000-0000-0000-0000-000000000dd1', 'alumno', 'Cuota caducada', 'activo'),
  ('00000000-0000-0000-0000-000000000d07', '00000000-0000-0000-0000-000000000dd1', 'alumno', 'Segundo con crédito', 'activo');

-- Tarifa de una sola clase al mes: fácil de agotar.
insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, clases_incluidas) values
  ('00000000-0000-0000-0000-00000000f302', '00000000-0000-0000-0000-000000000dd1', 'Suelta única', 15, 'mensual', 1);

insert into public.suscripciones (id, alumno_id, tarifa_id, academia_id, proveedor_pago) values
  ('00000000-0000-0000-0000-00000000d303', '00000000-0000-0000-0000-000000000d04', '00000000-0000-0000-0000-00000000f302', '00000000-0000-0000-0000-000000000dd1', 'efectivo'),
  ('00000000-0000-0000-0000-00000000d304', '00000000-0000-0000-0000-000000000d05', '00000000-0000-0000-0000-00000000f302', '00000000-0000-0000-0000-000000000dd1', 'efectivo'),
  ('00000000-0000-0000-0000-00000000d305', '00000000-0000-0000-0000-000000000d06', '00000000-0000-0000-0000-00000000f301', '00000000-0000-0000-0000-000000000dd1', 'efectivo'),
  ('00000000-0000-0000-0000-00000000d306', '00000000-0000-0000-0000-000000000d07', '00000000-0000-0000-0000-00000000f302', '00000000-0000-0000-0000-000000000dd1', 'efectivo');

update public.suscripciones
  set estado = 'activa', payment_status = 'active',
      fecha_inicio = now() - interval '3 days', fecha_fin = now() + interval '27 days'
  where id in (
    '00000000-0000-0000-0000-00000000d303',
    '00000000-0000-0000-0000-00000000d304',
    '00000000-0000-0000-0000-00000000d306'
  );

-- La de "Cuota caducada" empieza activa: tiene que poder reservar/esperar
-- primero (si ya estuviera caducada, reservar_clase la rechazaría antes de
-- llegar a la cola). Se caduca más abajo, ya con la plaza de espera hecha,
-- para simular que pasa el tiempo mientras espera.
update public.suscripciones
  set estado = 'activa', payment_status = 'active',
      fecha_inicio = now() - interval '5 days', fecha_fin = now() + interval '2 days'
  where id = '00000000-0000-0000-0000-00000000d305';

-- Clase con aforo 1: la ocupa el Dueño (no consume cuota de alumno) y se
-- llenan de cola, en orden, Agotado → Con crédito. «Agotado» todavía tiene
-- su clase disponible al entrar en la cola — unirse a la espera no gasta
-- saldo (solo cuentan como «reservadas» las plazas ya confirmadas, ver
-- _saldo_clases) — y la gasta después, ya esperando, en otra clase. Es la
-- única forma real de que esto pase: reservar_clase ya impide unirse a la
-- cola sin saldo desde el principio.
insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-00000000c305', '00000000-0000-0000-0000-000000000dd1', '00000000-0000-0000-0000-000000000d01', 'Clase con cola mixta', now() + interval '1 day', now() + interval '1 day 1 hour', 1);

select pg_temp.actuar_como('00000000-0000-0000-0000-000000000d01');
select is(
  public.reservar_clase('00000000-0000-0000-0000-00000000c305'),
  'inscrito',
  'El dueño ocupa la única plaza'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-000000000d04');
select is(
  public.reservar_clase('00000000-0000-0000-0000-00000000c305'),
  'espera',
  'Agotado entra en la cola con su clase todavía disponible'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-000000000d05');
select is(
  public.reservar_clase('00000000-0000-0000-0000-00000000c305'),
  'espera',
  'Con crédito entra detrás, segundo en la cola'
);

-- Ahora, ya esperando, Agotado se gasta su única clase del ciclo en otra
-- clase distinta.
reset role;
select set_config('request.jwt.claims', '{}', true);
insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-00000000c304', '00000000-0000-0000-0000-000000000dd1', '00000000-0000-0000-0000-000000000d01', 'Ayer', now() - interval '1 day', now() - interval '23 hours', 20);
insert into public.asistencias (clase_id, alumno_id, academia_id, validado_por) values
  ('00000000-0000-0000-0000-00000000c304', '00000000-0000-0000-0000-000000000d04', '00000000-0000-0000-0000-000000000dd1', '00000000-0000-0000-0000-000000000d01');

-- El dueño libera la plaza: Agotado es el primero de la cola pero no le
-- quedan clases, así que se le retira y se salta a Con crédito sin romper
-- el orden entre quienes sí son elegibles.
select pg_temp.actuar_como('00000000-0000-0000-0000-000000000d01');
select is(
  public.cancelar_reserva('00000000-0000-0000-0000-00000000c305') ->> 'alumno_promovido_id',
  '00000000-0000-0000-0000-000000000d05',
  'Se salta al primero de la cola (sin crédito) y promueve al siguiente elegible'
);
select is(
  (select estado from public.inscripciones
    where clase_id = '00000000-0000-0000-0000-00000000c305'
      and alumno_id = '00000000-0000-0000-0000-000000000d04'),
  'cancelado',
  'Agotado queda retirado de la cola, no promovido'
);
select is(
  (select estado from public.inscripciones
    where clase_id = '00000000-0000-0000-0000-00000000c305'
      and alumno_id = '00000000-0000-0000-0000-000000000d05'),
  'inscrito',
  'Con crédito sí queda promovido'
);

-- Cuota caducada: mismo filtro, con una clase propia para no mezclar con
-- la cola anterior. ITACA no exige cuota por defecto para reservar
-- (exigir_cuota_para_reservar = false): con ese ajuste, alguien con la
-- cuota caducada es tratado igual que alguien sin cuota — puede reservar
-- igual, queda marcado «sin cuota» para que el dueño lo cobre en mano. El
-- filtro de cuota caducada solo aplica cuando la academia SÍ la exige, así
-- que se activa aquí para probar ese camino de verdad.
reset role;
update public.academias
  set exigir_cuota_para_reservar = true
  where id = '00000000-0000-0000-0000-000000000dd1';

insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-00000000c306', '00000000-0000-0000-0000-000000000dd1', '00000000-0000-0000-0000-000000000d01', 'Clase con cuota caducada en cola', now() + interval '1 day', now() + interval '1 day 1 hour', 1);

select pg_temp.actuar_como('00000000-0000-0000-0000-000000000d01');
select is(
  public.reservar_clase('00000000-0000-0000-0000-00000000c306'),
  'inscrito',
  'El dueño ocupa la plaza de la segunda clase'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-000000000d06');
select is(
  public.reservar_clase('00000000-0000-0000-0000-00000000c306'),
  'espera',
  'Con la cuota todavía activa, entra en la cola sin problema'
);

-- Pasa el tiempo: su cuota caduca mientras sigue esperando.
reset role;
select set_config('request.jwt.claims', '{}', true);
update public.suscripciones
  set fecha_fin = now() - interval '1 hour'
  where id = '00000000-0000-0000-0000-00000000d305';

select pg_temp.actuar_como('00000000-0000-0000-0000-000000000d07');
select is(
  public.reservar_clase('00000000-0000-0000-0000-00000000c306'),
  'espera',
  'Segundo con crédito entra detrás'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-000000000d01');
select is(
  public.cancelar_reserva('00000000-0000-0000-0000-00000000c306') ->> 'alumno_promovido_id',
  '00000000-0000-0000-0000-000000000d07',
  'La cuota caducada no se promueve; se salta a quien sí puede reservar'
);

-- La cerradura de la fila de la clase (`for update of c` en
-- cancelar_reserva) es lo que hace atómica la promoción cuando dos
-- cancelaciones de la misma clase llegan a la vez: la segunda transacción
-- espera a que la primera termine antes de leer la cola, así que nunca
-- promueven a la misma persona dos veces ni se saltan a alguien. No se
-- puede reproducir con dos conexiones reales dentro de pgTAP (todo corre
-- en una sola transacción); queda verificado por inspección del código,
-- no ejecutado aquí. Esta prueba solo confirma que el bloqueo sigue en la
-- definición de la función, para que nadie lo quite sin darse cuenta.
select ok(
  pg_get_functiondef('public.cancelar_reserva(uuid)'::regprocedure)
    like '%for update of i, c%',
  'cancelar_reserva sigue bloqueando la fila de la clase (base de la seguridad ante concurrencia)'
);

select * from finish();
rollback;
