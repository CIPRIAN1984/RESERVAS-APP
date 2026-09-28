-- Las cuotas en efectivo caducan de verdad y una pausa congela el tiempo
-- que quedaba (ver 20260926090000_cuotas_efectivo_caducan.sql).
begin;
select plan(14);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000cad01', 'dueno-cad@test.dev'),
  ('00000000-0000-0000-0000-0000000cad02', 'caducada@test.dev'),
  ('00000000-0000-0000-0000-0000000cad03', 'vigente@test.dev'),
  ('00000000-0000-0000-0000-0000000cad04', 'sin-fin@test.dev'),
  ('00000000-0000-0000-0000-0000000cad05', 'stripe@test.dev'),
  ('00000000-0000-0000-0000-0000000cad06', 'pausa-fecha@test.dev'),
  ('00000000-0000-0000-0000-0000000cad07', 'pausa-sin-fin@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000cadaa', 'Academia caducidad', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado)
select u, '00000000-0000-0000-0000-0000000cadaa',
       case when u = '00000000-0000-0000-0000-0000000cad01'::uuid then 'dueño' else 'alumno' end,
       'Persona', 'activo'
  from unnest(array[
    '00000000-0000-0000-0000-0000000cad01', '00000000-0000-0000-0000-0000000cad02',
    '00000000-0000-0000-0000-0000000cad03', '00000000-0000-0000-0000-0000000cad04',
    '00000000-0000-0000-0000-0000000cad05', '00000000-0000-0000-0000-0000000cad06',
    '00000000-0000-0000-0000-0000000cad07'
  ]::uuid[]) as u;

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, activo) values
  ('00000000-0000-0000-0000-0000000cadf1', '00000000-0000-0000-0000-0000000cadaa', 'Mensual', 50, 'mensual', true);

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- El Dueño da cuota a todos en efectivo (la de cad04, sin fecha de fin).
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000cad01');
select public.activar_cuota_efectivo(a, '00000000-0000-0000-0000-0000000cadf1', f)
  from (values
    ('00000000-0000-0000-0000-0000000cad02'::uuid, now() + interval '10 days'),
    ('00000000-0000-0000-0000-0000000cad03'::uuid, now() + interval '10 days'),
    ('00000000-0000-0000-0000-0000000cad04'::uuid, null::timestamptz),
    ('00000000-0000-0000-0000-0000000cad06'::uuid, now() + interval '20 days'),
    ('00000000-0000-0000-0000-0000000cad07'::uuid, null::timestamptz)
  ) as v(a, f);

-- Pausar una cuota ya caducada no tiene sentido (y regalaría el tiempo).
reset role;
update public.suscripciones set fecha_fin = now() - interval '1 day'
 where alumno_id = '00000000-0000-0000-0000-0000000cad02';
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000cad01');
select throws_ok(
  $$ select public.pausar_cuota_efectivo(
       (select id from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000cad02')) $$,
  'Esa cuota ya ha caducado: no hay nada que pausar.',
  'No se puede pausar una cuota ya caducada'
);

-- Pausas: una hasta ayer (el job la reanuda) y otra indefinida.
select public.pausar_cuota_efectivo(
  (select id from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000cad06'),
  now() + interval '1 hour');
select public.pausar_cuota_efectivo(
  (select id from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000cad07'),
  now() + interval '1 hour');
reset role;

select ok(
  (select resto_al_pausar between interval '19 days 23 hours' and interval '20 days'
     from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000cad06'),
  'Al pausar se guarda lo que le quedaba (20 días)'
);

-- Simular que ha llegado la fecha de reanudación de las dos pausas.
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-0000-0000-0000000cad01', 'role', 'authenticated')::text, true);
update public.suscripciones set fecha_fin = now() - interval '1 hour'
 where alumno_id in ('00000000-0000-0000-0000-0000000cad06', '00000000-0000-0000-0000-0000000cad07');

-- Y una de Stripe caducada: esa la lleva el webhook, el job no la toca.
insert into public.suscripciones
  (alumno_id, tarifa_id, academia_id, estado, proveedor_pago, referencia_externa, payment_status)
values
  ('00000000-0000-0000-0000-0000000cad05', '00000000-0000-0000-0000-0000000cadf1',
   '00000000-0000-0000-0000-0000000cadaa', 'activa', 'stripe', 'sub_cad', 'active');
update public.suscripciones set estado = 'activa', payment_status = 'active',
       fecha_fin = now() - interval '1 day'
 where alumno_id = '00000000-0000-0000-0000-0000000cad05';

select results_eq(
  $$ select pruebas_expiradas, pausas_reanudadas, cuotas_caducadas
       from public.expirar_pruebas_y_pausas() $$,
  $$ values (0, 2, 1) $$,
  'El job reanuda las 2 pausas y caduca 1 cuota en efectivo'
);

select is(
  (select estado from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000cad02'),
  'expirada',
  'La cuota en efectivo con la fecha pasada queda expirada'
);
select ok(
  (select fecha_fin < now() and payment_status = 'active'
     from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000cad02'),
  'Conserva su fecha de fin y que se cobró: no se borra ni se reescribe nada'
);
select is(
  (select estado from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000cad03'),
  'activa',
  'La que sigue en fecha sigue activa'
);
select is(
  (select estado from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000cad04'),
  'activa',
  'La que no tiene fecha de fin sigue activa'
);
select is(
  (select estado from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000cad05'),
  'activa',
  'La de Stripe no la toca el job'
);
select ok(
  (select estado = 'activa'
          and fecha_fin between now() + interval '19 days 21 hours'
                            and now() + interval '19 days 23 hours'
     from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000cad06'),
  'La pausa con fecha vuelve con sus 20 días, contados desde el día que tocaba reanudar'
);
select ok(
  (select estado = 'activa' and fecha_fin is null and resto_al_pausar is null
     from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000cad07'),
  'La que no tenía fecha de fin vuelve igual, sin fecha de fin'
);

-- Pasar el job dos veces no cambia nada más.
select results_eq(
  $$ select pruebas_expiradas, pausas_reanudadas, cuotas_caducadas
       from public.expirar_pruebas_y_pausas() $$,
  $$ values (0, 0, 0) $$,
  'Una segunda pasada del job no hace nada'
);

select ok(
  not has_function_privilege('authenticated', 'public.expirar_pruebas_y_pausas()', 'EXECUTE')
  and not has_function_privilege('anon', 'public.expirar_pruebas_y_pausas()', 'EXECUTE'),
  'Nadie desde la app puede disparar el job'
);

select ok(
  not has_column_privilege('authenticated', 'public.suscripciones', 'resto_al_pausar', 'UPDATE'),
  'Nadie desde la app puede tocarse el resto guardado'
);

select is(
  (select count(*)::int from public.suscripciones where academia_id = '00000000-0000-0000-0000-0000000cadaa'),
  6,
  'No desaparece ninguna cuota'
);

select * from finish();
rollback;
