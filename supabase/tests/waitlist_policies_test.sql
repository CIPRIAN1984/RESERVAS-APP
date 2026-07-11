-- Lista de espera FIFO, promociones y política de cancelación.
begin;
select plan(12);

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

select * from finish();
rollback;
