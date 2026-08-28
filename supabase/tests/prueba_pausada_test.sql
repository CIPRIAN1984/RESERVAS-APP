-- Prueba (1 día) y tarifa Pausada.
--
-- Lo que se protege aquí: una prueba tiene que caducar sola a las 24 horas
-- (si no, es una cuota gratis para siempre) y una cuota pausada NO puede
-- servir para reservar (si no, "pausar" no significa nada). Y como en toda
-- cuota, aislamiento por academia y solo el Dueño puede tocarlas.
begin;
select plan(23);

-- ------------------------------------------------------------
-- Escenario: dos academias
-- ------------------------------------------------------------

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000eb101', 'dueno-eb-a@test.dev'),
  ('00000000-0000-0000-0000-0000000eb102', 'alumno-eb-a@test.dev'),
  ('00000000-0000-0000-0000-0000000eb103', 'alumno-eb-a2@test.dev'),
  ('00000000-0000-0000-0000-0000000eb201', 'dueno-eb-b@test.dev'),
  ('00000000-0000-0000-0000-0000000eb202', 'alumno-eb-b@test.dev');

insert into public.academias (id, nombre, estado, exigir_cuota_para_reservar) values
  ('00000000-0000-0000-0000-0000000eb0aa', 'Academia EB A', 'approved', true),
  ('00000000-0000-0000-0000-0000000eb0bb', 'Academia EB B', 'approved', true);

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000eb101',
   '00000000-0000-0000-0000-0000000eb0aa', 'dueño',  'Dueño A',   'activo'),
  ('00000000-0000-0000-0000-0000000eb102',
   '00000000-0000-0000-0000-0000000eb0aa', 'alumno', 'Alumno A',  'activo'),
  ('00000000-0000-0000-0000-0000000eb103',
   '00000000-0000-0000-0000-0000000eb0aa', 'alumno', 'Alumno A2', 'activo'),
  ('00000000-0000-0000-0000-0000000eb201',
   '00000000-0000-0000-0000-0000000eb0bb', 'dueño',  'Dueño B',   'activo'),
  ('00000000-0000-0000-0000-0000000eb202',
   '00000000-0000-0000-0000-0000000eb0bb', 'alumno', 'Alumno B',  'activo');

insert into public.tarifas
  (id, academia_id, nombre, precio, periodicidad, activo) values
  ('00000000-0000-0000-0000-0000000eba01',
   '00000000-0000-0000-0000-0000000eb0aa', 'Mensual A', 50, 'mensual', true),
  ('00000000-0000-0000-0000-0000000eba02',
   '00000000-0000-0000-0000-0000000eb0bb', 'Mensual B', 60, 'mensual', true);

insert into public.clases
  (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin,
   aforo_maximo)
values
  ('00000000-0000-0000-0000-0000000ebc01',
   '00000000-0000-0000-0000-0000000eb0aa',
   '00000000-0000-0000-0000-0000000eb101', 'Clase A',
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
-- Iniciar prueba
-- ------------------------------------------------------------

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb101');

select throws_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000eb102',
       '00000000-0000-0000-0000-0000000eba01',
       now() + interval '30 days',
       true
     ) $$,
  null,
  'Una prueba no lleva fecha de fin propia: no se pueden dar las dos cosas'
);

select lives_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000eb102',
       '00000000-0000-0000-0000-0000000eba01',
       null,
       true
     ) $$,
  'El Dueño inicia una prueba de 1 día'
);

reset role;

select is(
  (select estado from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000eb102'),
  'prueba',
  'La prueba queda en estado prueba'
);

select ok(
  (select fecha_fin from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000eb102')
    between now() + interval '23 hours' and now() + interval '25 hours',
  'Y caduca sola alrededor de 1 día después'
);

-- Cuenta como cuota para reservar, igual que una activa.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb102');
select is(
  (select public.reservar_clase('00000000-0000-0000-0000-0000000ebc01')),
  'inscrito',
  'Con la prueba en marcha sí se puede reservar, aunque la academia exija cuota'
);
reset role;

-- ------------------------------------------------------------
-- Pausar una cuota
-- ------------------------------------------------------------

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb101');

select public.activar_cuota_efectivo(
  '00000000-0000-0000-0000-0000000eb103',
  '00000000-0000-0000-0000-0000000eba01',
  now() + interval '30 days'
);

select throws_ok(
  $$ select public.pausar_cuota_efectivo(
       (select id from public.suscripciones
         where alumno_id = '00000000-0000-0000-0000-0000000eb102')
     ) $$,
  null,
  'No se puede pausar una prueba: solo se pausa una cuota activa'
);

select lives_ok(
  $$ select public.pausar_cuota_efectivo(
       (select id from public.suscripciones
         where alumno_id = '00000000-0000-0000-0000-0000000eb103'),
       null
     ) $$,
  'El Dueño pausa la cuota de un alumno, sin fecha de fin (indefinida)'
);

reset role;

select is(
  (select estado from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000eb103'),
  'pausada',
  'Queda pausada'
);

-- Lo que de verdad importa: pausada NO cuenta para reservar.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb103');
select throws_ok(
  $$ select public.reservar_clase('00000000-0000-0000-0000-0000000ebc01') $$,
  null,
  'Con la cuota pausada no se puede reservar donde se exige cuota'
);
reset role;

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb201');
select throws_ok(
  $$ select public.pausar_cuota_efectivo(
       (select id from public.suscripciones
         where alumno_id = '00000000-0000-0000-0000-0000000eb103')
     ) $$,
  null,
  'El Dueño de otra academia no puede pausar una cuota ajena'
);
reset role;

-- ------------------------------------------------------------
-- Reanudar
-- ------------------------------------------------------------

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb201');
select throws_ok(
  $$ select public.reanudar_cuota_efectivo(
       (select id from public.suscripciones
         where alumno_id = '00000000-0000-0000-0000-0000000eb103')
     ) $$,
  null,
  'El Dueño de otra academia tampoco puede reanudarla'
);
reset role;

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb101');

select throws_ok(
  $$ select public.reanudar_cuota_efectivo(
       (select id from public.suscripciones
         where alumno_id = '00000000-0000-0000-0000-0000000eb102')
     ) $$,
  null,
  'No se puede reanudar una prueba: no está pausada'
);

select lives_ok(
  $$ select public.reanudar_cuota_efectivo(
       (select id from public.suscripciones
         where alumno_id = '00000000-0000-0000-0000-0000000eb103')
     ) $$,
  'El Dueño reanuda la cuota pausada'
);

reset role;

select is(
  (select estado from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000eb103'),
  'activa',
  'Vuelve a activa'
);

select ok(
  (select fecha_fin from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000eb103') is null,
  'Sin fecha de caducidad propia al reanudar'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb103');
select is(
  (select public.reservar_clase('00000000-0000-0000-0000-0000000ebc01')),
  'inscrito',
  'Reanudada, vuelve a poder reservar'
);
reset role;

-- ------------------------------------------------------------
-- Pausa con fecha: el job de reconciliación la reanuda sola
-- ------------------------------------------------------------

-- Fijar el estado a mano (para simular el paso del tiempo) toca la columna
-- fecha_fin, que no está concedida a `authenticated` — hace falta el rol
-- con privilegios de `reset role`. Pero el disparador
-- check_suscripcion_estado_transicion exige un current_rol() de staff, y
-- ese se calcula a partir de auth.uid() (el jwt), no del rol de Postgres:
-- se deja el rol en el de tabla-owner y solo se cambia el jwt al Dueño.
select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', '00000000-0000-0000-0000-0000000eb101', 'role', 'authenticated'
  )::text,
  true
);

update public.suscripciones
   set estado = 'pausada', fecha_fin = now() - interval '1 minute'
 where alumno_id = '00000000-0000-0000-0000-0000000eb103';

-- Y una prueba ya caducada, para comprobar las dos cosas con un solo job.
update public.suscripciones
   set fecha_fin = now() - interval '1 minute'
 where alumno_id = '00000000-0000-0000-0000-0000000eb102';

select results_eq(
  $$ select pausas_reanudadas, pruebas_expiradas
       from public.expirar_pruebas_y_pausas() $$,
  $$ values (1, 1) $$,
  'El job reanuda 1 pausa vencida y expira 1 prueba vencida'
);

select is(
  (select estado from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000eb103'),
  'activa',
  'La pausa con fecha pasada vuelve sola a activa'
);

select is(
  (select estado from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000eb102'),
  'expirada',
  'La prueba caducada pasa a expirada'
);

-- Nadie de fuera puede disparar el job a mano.
select ok(
  not has_function_privilege(
    'authenticated',
    'public.expirar_pruebas_y_pausas()',
    'EXECUTE'
  ),
  'Ni siquiera un usuario autenticado puede llamar al job de reconciliación'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.expirar_pruebas_y_pausas()',
    'EXECUTE'
  ),
  'Tampoco sin iniciar sesión'
);

-- ------------------------------------------------------------
-- Solo cuotas en efectivo se pausan/reanudan desde aquí
-- ------------------------------------------------------------

reset role;
insert into public.suscripciones
  (id, alumno_id, tarifa_id, academia_id, estado,
   proveedor_pago, referencia_externa, payment_status)
values
  ('00000000-0000-0000-0000-0000000ebb99',
   '00000000-0000-0000-0000-0000000eb202',
   '00000000-0000-0000-0000-0000000eba02',
   '00000000-0000-0000-0000-0000000eb0bb',
   'activa', 'stripe', 'sub_test_pp', 'active');

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb201');
select throws_ok(
  $$ select public.pausar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000ebb99'
     ) $$,
  null,
  'Una cuota de Stripe no se pausa desde la app'
);
reset role;

-- ------------------------------------------------------------
-- El índice único cubre también prueba y pausada
-- ------------------------------------------------------------

-- Alumno A (eb102) sigue con la prueba activa (aún no ha caducado en la
-- base de datos real, solo se le tocó fecha_fin para el job anterior a
-- propósito: ya quedó 'expirada' arriba). Se comprueba con uno limpio.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb101');
select public.activar_cuota_efectivo(
  '00000000-0000-0000-0000-0000000eb102',
  '00000000-0000-0000-0000-0000000eba01',
  null,
  true
);
reset role;

select is(
  (select count(*)::int from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000eb102'
      and estado in ('activa', 'pendiente_pago', 'prueba', 'pausada')),
  1,
  'Sigue habiendo como mucho una cuota en curso por alumno, prueba incluida'
);

rollback;
