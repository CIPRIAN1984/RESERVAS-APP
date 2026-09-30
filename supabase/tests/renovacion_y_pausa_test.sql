-- Renovar antes de tiempo no pierde días; la pausa conserva también las
-- clases (ver 20260930110000_renovacion_y_pausa.sql).
begin;
select plan(18);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000ab001', 'dueno-rp@test.dev'),
  ('00000000-0000-0000-0000-0000000ab002', 'renueva@test.dev'),
  ('00000000-0000-0000-0000-0000000ab003', 'baja@test.dev'),
  ('00000000-0000-0000-0000-0000000ab004', 'pausa@test.dev'),
  ('00000000-0000-0000-0000-0000000ab005', 'reanuda@test.dev'),
  ('00000000-0000-0000-0000-0000000ab006', 'reanuda-sola@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000ab0aa', 'Academia renovación', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado)
select u, '00000000-0000-0000-0000-0000000ab0aa',
       case when u = '00000000-0000-0000-0000-0000000ab001'::uuid then 'dueño' else 'alumno' end,
       'Persona', 'activo'
  from unnest(array[
    '00000000-0000-0000-0000-0000000ab001', '00000000-0000-0000-0000-0000000ab002',
    '00000000-0000-0000-0000-0000000ab003', '00000000-0000-0000-0000-0000000ab004',
    '00000000-0000-0000-0000-0000000ab005', '00000000-0000-0000-0000-0000000ab006'
  ]::uuid[]) as u;

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, activo, clases_incluidas) values
  ('00000000-0000-0000-0000-0000000ab0f1', '00000000-0000-0000-0000-0000000ab0aa', 'Mensual 8', 50, 'mensual', true, 8),
  ('00000000-0000-0000-0000-0000000ab0f2', '00000000-0000-0000-0000-0000000ab0aa', 'Mensual 4', 30, 'mensual', true, 4);

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- Para simular el paso del tiempo con el Dueño en el jwt (el disparador de
-- transiciones de estado lo exige) y privilegios de dueño de tabla.
create or replace function pg_temp.como_dueno_sin_rol() returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-0000-0000-0000000ab001', 'role', 'authenticated')::text, true);
$$;

create or replace function pg_temp.cobrar(p_alumno uuid, p_tarifa uuid) returns void language sql as $$
  select public.activar_cuota_efectivo(p_alumno, p_tarifa, null, false, null, 1);
$$;

-- ------------------------------------------------------------
-- 1. Renovar con la cuota en vigor: empieza cuando acaba la actual
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ab001');
select pg_temp.cobrar('00000000-0000-0000-0000-0000000ab002', '00000000-0000-0000-0000-0000000ab0f1');
select pg_temp.cobrar('00000000-0000-0000-0000-0000000ab002', '00000000-0000-0000-0000-0000000ab0f1');
reset role;

select ok(
  (select fecha_fin = now() + interval '1 month'
     from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000ab002' and estado = 'activa'),
  'Renovar no cierra la cuota actual: sigue activa hasta su fecha'
);
select ok(
  (select fecha_inicio = now() + interval '1 month'
          and fecha_fin = now() + interval '1 month' + interval '1 month'
          and payment_status = 'active' and importe_cobrado = 50
     from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000ab002' and estado = 'programada'),
  'La renovación empieza el día que acaba la actual y dura su mes entero'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ab001');
select throws_ok(
  $$ select pg_temp.cobrar('00000000-0000-0000-0000-0000000ab002', '00000000-0000-0000-0000-0000000ab0f1') $$,
  'Ese alumno ya tiene una renovación pendiente de empezar.',
  'Una sola renovación esperando'
);
reset role;

select is(
  (public._saldo_clases('00000000-0000-0000-0000-0000000ab002', now()) ->> 'ciclo_inicio')::timestamptz,
  (select fecha_inicio from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000ab002' and estado = 'activa'),
  'Hoy cuenta la cuota actual'
);
select is(
  (public._saldo_clases('00000000-0000-0000-0000-0000000ab002', now() + interval '1 month 2 days') ->> 'ciclo_inicio')::timestamptz,
  now() + interval '1 month',
  'Una clase de después del fin de la actual cuenta contra la renovación'
);
select ok(
  public._cuota_cubre('00000000-0000-0000-0000-0000000ab002', '00000000-0000-0000-0000-0000000ab0aa', now() + interval '1 month 2 days'),
  'Y con la renovación se tiene cuota para esa fecha'
);

-- El día que acaba la actual, el job activa la renovación.
select pg_temp.como_dueno_sin_rol();
update public.suscripciones set fecha_fin = now() - interval '1 minute'
 where alumno_id = '00000000-0000-0000-0000-0000000ab002' and estado = 'activa';
update public.suscripciones set fecha_inicio = now() - interval '1 minute'
 where alumno_id = '00000000-0000-0000-0000-0000000ab002' and estado = 'programada';

select results_eq(
  $$ select cuotas_caducadas, renovaciones_activadas from public.expirar_pruebas_y_pausas() $$,
  $$ values (1, 1) $$,
  'El job caduca la anterior y activa la renovación en la misma pasada'
);
select is(
  (select count(*)::int from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000ab002'
      and estado = 'activa' and importe_cobrado = 50),
  1,
  'Queda una sola cuota activa: la renovación'
);

-- ------------------------------------------------------------
-- 2. Dar de baja cancela también la renovación pendiente
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ab001');
select pg_temp.cobrar('00000000-0000-0000-0000-0000000ab003', '00000000-0000-0000-0000-0000000ab0f1');
select pg_temp.cobrar('00000000-0000-0000-0000-0000000ab003', '00000000-0000-0000-0000-0000000ab0f1');
select public.dar_de_baja_alumno('00000000-0000-0000-0000-0000000ab003');
reset role;

select is(
  (select count(*)::int from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000ab003' and estado <> 'cancelada'),
  0,
  'Al dar de baja, ni la cuota ni su renovación siguen en pie'
);

-- ------------------------------------------------------------
-- 3. La pausa conserva las clases: el ciclo se alarga lo que duró
-- ------------------------------------------------------------
-- Cuota de 4 clases que empezó hace 20 días, con una pausa de 5 días (de
-- hace 10 a hace 5). Así es como la deja reanudar_cuota_efectivo.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ab001');
select pg_temp.cobrar('00000000-0000-0000-0000-0000000ab004', '00000000-0000-0000-0000-0000000ab0f2');
reset role;
update public.suscripciones
   set fecha_inicio = now() - interval '20 days',
       fecha_fin = now() - interval '20 days' + interval '1 month' + interval '5 days'
 where alumno_id = '00000000-0000-0000-0000-0000000ab004' and estado = 'activa';
insert into public.pausas_suscripcion (suscripcion_id, desde, hasta)
select id, now() - interval '10 days', now() - interval '5 days'
  from public.suscripciones
 where alumno_id = '00000000-0000-0000-0000-0000000ab004' and estado = 'activa';

insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-0000000ab0c1', '00000000-0000-0000-0000-0000000ab0aa', '00000000-0000-0000-0000-0000000ab001',
   'Antes de la pausa', now() - interval '15 days', now() - interval '15 days' + interval '1 hour', 10),
  ('00000000-0000-0000-0000-0000000ab0c2', '00000000-0000-0000-0000-0000000ab0aa', '00000000-0000-0000-0000-0000000ab001',
   'Durante la pausa', now() - interval '7 days', now() - interval '7 days' + interval '1 hour', 10),
  ('00000000-0000-0000-0000-0000000ab0c3', '00000000-0000-0000-0000-0000000ab0aa', '00000000-0000-0000-0000-0000000ab001',
   'Pasado el mes original', now() - interval '20 days' + interval '1 month' + interval '2 days',
   now() - interval '20 days' + interval '1 month' + interval '2 days 1 hour', 10);

insert into public.inscripciones (clase_id, alumno_id, academia_id, estado) values
  ('00000000-0000-0000-0000-0000000ab0c1', '00000000-0000-0000-0000-0000000ab004', '00000000-0000-0000-0000-0000000ab0aa', 'inscrito'),
  ('00000000-0000-0000-0000-0000000ab0c2', '00000000-0000-0000-0000-0000000ab004', '00000000-0000-0000-0000-0000000ab0aa', 'inscrito'),
  ('00000000-0000-0000-0000-0000000ab0c3', '00000000-0000-0000-0000-0000000ab004', '00000000-0000-0000-0000-0000000ab0aa', 'inscrito');
insert into public.asistencias (clase_id, alumno_id, validado_por) values
  ('00000000-0000-0000-0000-0000000ab0c1', '00000000-0000-0000-0000-0000000ab004', '00000000-0000-0000-0000-0000000ab001'),
  ('00000000-0000-0000-0000-0000000ab0c2', '00000000-0000-0000-0000-0000000ab004', '00000000-0000-0000-0000-0000000ab001');

select is(
  (public._saldo_clases('00000000-0000-0000-0000-0000000ab004') ->> 'ciclo_fin')::timestamptz,
  now() - interval '20 days' + interval '1 month' + interval '5 days',
  'El ciclo que cruza la pausa se alarga los 5 días que duró'
);
select is(
  (public._saldo_clases('00000000-0000-0000-0000-0000000ab004') ->> 'gastadas')::int,
  1,
  'La clase a la que fue durante la pausa no gasta de la cuota'
);
select is(
  (public._saldo_clases('00000000-0000-0000-0000-0000000ab004') ->> 'reservadas')::int,
  1,
  'Una clase pasado el mes original sigue en el mismo ciclo: no salen clases nuevas'
);

-- ------------------------------------------------------------
-- 4. Reanudar mueve la renovación detrás
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ab001');
select pg_temp.cobrar('00000000-0000-0000-0000-0000000ab005', '00000000-0000-0000-0000-0000000ab0f1');
select pg_temp.cobrar('00000000-0000-0000-0000-0000000ab005', '00000000-0000-0000-0000-0000000ab0f1');
select public.pausar_cuota_efectivo(
  (select id from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000ab005' and estado = 'activa'));
reset role;

-- Como si la pausa hubiera empezado hace 10 días.
update public.suscripciones set resto_al_pausar = resto_al_pausar + interval '10 days'
 where alumno_id = '00000000-0000-0000-0000-0000000ab005' and estado = 'pausada';
update public.pausas_suscripcion set desde = now() - interval '10 days'
 where suscripcion_id = (select id from public.suscripciones
                          where alumno_id = '00000000-0000-0000-0000-0000000ab005' and estado = 'pausada');

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ab001');
select public.reanudar_cuota_efectivo(
  (select id from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000ab005' and estado = 'pausada'));
reset role;

select ok(
  (select fecha_fin = now() + interval '1 month' + interval '10 days'
     from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000ab005' and estado = 'activa'),
  'Reanudada, la cuota acaba 10 días más tarde'
);
select ok(
  (select p.fecha_inicio = a.fecha_fin
          -- La misma duración que tenía: de fin de la cuota a un mes después.
          and p.fecha_fin - p.fecha_inicio
              = (now() + interval '2 months') - (now() + interval '1 month')
     from public.suscripciones p, public.suscripciones a
    where p.alumno_id = '00000000-0000-0000-0000-0000000ab005' and p.estado = 'programada'
      and a.alumno_id = p.alumno_id and a.estado = 'activa'),
  'Y la renovación se mueve para empezar justo entonces, con la misma duración'
);

-- El job, al reanudar una pausa con fecha, hace lo mismo.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ab001');
select pg_temp.cobrar('00000000-0000-0000-0000-0000000ab006', '00000000-0000-0000-0000-0000000ab0f1');
select pg_temp.cobrar('00000000-0000-0000-0000-0000000ab006', '00000000-0000-0000-0000-0000000ab0f1');
select public.pausar_cuota_efectivo(
  (select id from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000ab006' and estado = 'activa'),
  now() + interval '1 day');
reset role;

select pg_temp.como_dueno_sin_rol();
update public.pausas_suscripcion set desde = now() - interval '3 days'
 where suscripcion_id = (select id from public.suscripciones
                          where alumno_id = '00000000-0000-0000-0000-0000000ab006' and estado = 'pausada');
update public.suscripciones
   set fecha_fin = now() - interval '1 minute',
       resto_al_pausar = resto_al_pausar + interval '3 days'
 where alumno_id = '00000000-0000-0000-0000-0000000ab006' and estado = 'pausada';

select results_eq(
  $$ select pausas_reanudadas, renovaciones_activadas from public.expirar_pruebas_y_pausas() $$,
  $$ values (1, 0) $$,
  'El job reanuda la pausa y no activa la renovación antes de tiempo'
);
select ok(
  (select p.fecha_inicio = a.fecha_fin
          and a.fecha_fin = now() - interval '1 minute' + interval '1 month' + interval '3 days'
     from public.suscripciones p, public.suscripciones a
    where p.alumno_id = '00000000-0000-0000-0000-0000000ab006' and p.estado = 'programada'
      and a.alumno_id = p.alumno_id and a.estado = 'activa'),
  'Tras reanudarse sola, la renovación empieza cuando acaba la cuota'
);

-- ------------------------------------------------------------
-- 5. Permisos
-- ------------------------------------------------------------
select ok(
  not has_table_privilege('authenticated', 'public.pausas_suscripcion', 'SELECT')
  and not has_table_privilege('authenticated', 'public.pausas_suscripcion', 'INSERT')
  and not has_table_privilege('authenticated', 'public.suscripciones', 'INSERT'),
  'La app no puede tocar las pausas ni crear cuotas a mano'
);
select ok(
  not has_function_privilege('authenticated', 'public._tiempo_real(uuid, timestamptz)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public._encadenar_programada(uuid, timestamptz)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.ciclo_de_suscripcion(uuid, timestamptz, timestamptz, text, timestamptz)', 'EXECUTE'),
  'Las funciones internas no se pueden llamar desde la app'
);

select * from finish();
rollback;
