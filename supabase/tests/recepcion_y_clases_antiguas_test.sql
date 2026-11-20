-- Dos casos de la auditoría del 13/11/2026, comprobados el 17/11 (eran
-- fallos reales). Ver 20261117100000_recepcion_y_clases_antiguas.sql.
--
-- 1. Cobrar en recepción con la clase ya empezada: la cuota recién cobrada
--    cubre esa clase y gasta una clase del bono, tanto si se cobra y luego se
--    apunta como si se apunta y luego se cobra.
-- 2. Una clase antigua sigue «cubierta» después de que caduque la cuota que
--    la cubría; y esa cuota no cubre fechas posteriores a su fin.

begin;
select plan(15);

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000b00aa', 'Academia RC', 'approved');
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000b0001', 'dueno-rc@test.dev'),
  ('00000000-0000-0000-0000-0000000b0003', 'alumno1-rc@test.dev'),
  ('00000000-0000-0000-0000-0000000b0004', 'alumno2-rc@test.dev'),
  ('00000000-0000-0000-0000-0000000b0005', 'alumno3-rc@test.dev');
insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000b0001', '00000000-0000-0000-0000-0000000b00aa', 'dueño', 'Dueño', 'activo'),
  ('00000000-0000-0000-0000-0000000b0003', '00000000-0000-0000-0000-0000000b00aa', 'alumno', 'Uno', 'activo'),
  ('00000000-0000-0000-0000-0000000b0004', '00000000-0000-0000-0000-0000000b00aa', 'alumno', 'Dos', 'activo'),
  ('00000000-0000-0000-0000-0000000b0005', '00000000-0000-0000-0000-0000000b00aa', 'alumno', 'Tres', 'activo');
insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, clases_incluidas) values
  ('00000000-0000-0000-0000-0000000b0d01', '00000000-0000-0000-0000-0000000b00aa', 'Ocho', 50, 'mensual', 8);

insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-0000000b0c01', '00000000-0000-0000-0000-0000000b00aa', '00000000-0000-0000-0000-0000000b0001',
   'En marcha A', now() - interval '10 minutes', now() + interval '50 minutes', 20),
  ('00000000-0000-0000-0000-0000000b0c02', '00000000-0000-0000-0000-0000000b00aa', '00000000-0000-0000-0000-0000000b0001',
   'En marcha B', now() - interval '10 minutes', now() + interval '50 minutes', 20),
  ('00000000-0000-0000-0000-0000000b0c03', '00000000-0000-0000-0000-0000000b00aa', '00000000-0000-0000-0000-0000000b0001',
   'Hace 40 días', now() - interval '40 days', now() - interval '40 days' + interval '1 hour', 20),
  ('00000000-0000-0000-0000-0000000b0c04', '00000000-0000-0000-0000-0000000b00aa', '00000000-0000-0000-0000-0000000b0001',
   'Hace 5 días', now() - interval '5 days', now() - interval '5 days' + interval '1 hour', 20);

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

-- ------------------------------------------------------------
-- Caso 1a: se cobra y DESPUÉS se apunta a la clase en marcha
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000b0001');
select lives_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000b0003',
       '00000000-0000-0000-0000-0000000b0d01', null, false, null, 1, gen_random_uuid()) $$,
  'Se cobra la cuota en recepción'
);
select lives_ok(
  $$ select public.apuntar_en_clase(
       '00000000-0000-0000-0000-0000000b0c01', '00000000-0000-0000-0000-0000000b0003') $$,
  'Se le apunta a la clase que ya ha empezado'
);
reset role;

select ok(
  public._cuota_cubre('00000000-0000-0000-0000-0000000b0003', '00000000-0000-0000-0000-0000000b00aa',
                      (select fecha_hora_inicio from public.clases where id = '00000000-0000-0000-0000-0000000b0c01')),
  'Cobrar y luego apuntar: la cuota cubre la clase que ya había empezado'
);
select is(
  (public._saldo_clases('00000000-0000-0000-0000-0000000b0003', now())->>'gastadas')::int,
  1,
  'Cobrar y luego apuntar: gasta exactamente una clase del bono'
);
select is(
  (public._saldo_clases('00000000-0000-0000-0000-0000000b0003', now())->>'disponibles')::int,
  7,
  'Cobrar y luego apuntar: quedan 7 de 8'
);

-- ------------------------------------------------------------
-- Caso 1b: se apunta primero y DESPUÉS se cobra
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000b0001');
select lives_ok(
  $$ select public.apuntar_en_clase(
       '00000000-0000-0000-0000-0000000b0c02', '00000000-0000-0000-0000-0000000b0004') $$,
  'Apuntar primero (sin cuota todavía)'
);
select lives_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000b0004',
       '00000000-0000-0000-0000-0000000b0d01', null, false, null, 1, gen_random_uuid()) $$,
  'Y cobrar después'
);
reset role;

select ok(
  public._cuota_cubre('00000000-0000-0000-0000-0000000b0004', '00000000-0000-0000-0000-0000000b00aa',
                      (select fecha_hora_inicio from public.clases where id = '00000000-0000-0000-0000-0000000b0c02')),
  'Apuntar y luego cobrar: la cuota cubre la clase que ya había empezado'
);
select is(
  (public._saldo_clases('00000000-0000-0000-0000-0000000b0004', now())->>'gastadas')::int,
  1,
  'Apuntar y luego cobrar: gasta exactamente una clase del bono'
);

-- Una cuota cobrada sin ninguna clase en marcha sigue empezando ahora.
select is(
  (select count(*)::int from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000b0003'
      and fecha_inicio <= (select fecha_hora_inicio from public.clases where id = '00000000-0000-0000-0000-0000000b0c01')),
  1,
  'La cuota solo se retrasa hasta el inicio de la clase en marcha, no más'
);

-- ------------------------------------------------------------
-- Caso 2: una clase antigua tras caducar la cuota que la cubría
-- ------------------------------------------------------------
-- Cuota mensual de hace 50 días a hace 20 que ya caducó (el trabajo de
-- caducidad la dejó en 'expirada').
insert into public.suscripciones (id, alumno_id, tarifa_id, academia_id, proveedor_pago)
values ('00000000-0000-0000-0000-0000000b0e09', '00000000-0000-0000-0000-0000000b0005',
        '00000000-0000-0000-0000-0000000b0d01', '00000000-0000-0000-0000-0000000b00aa', 'efectivo');
update public.suscripciones
   set estado = 'expirada', payment_status = 'active', importe_cobrado = 50,
       fecha_inicio = now() - interval '50 days', fecha_fin = now() - interval '20 days'
 where id = '00000000-0000-0000-0000-0000000b0e09';

select ok(
  public._cuota_cubre('00000000-0000-0000-0000-0000000b0005', '00000000-0000-0000-0000-0000000b00aa', now() - interval '40 days'),
  'Una cuota expirada sigue cubriendo una clase de las fechas que cubrió'
);
select ok(
  not public._cuota_cubre('00000000-0000-0000-0000-0000000b0005', '00000000-0000-0000-0000-0000000b00aa', now() - interval '5 days'),
  'Y no cubre una clase posterior a su fin'
);
select ok(
  (public._saldo_clases('00000000-0000-0000-0000-0000000b0005', now() - interval '40 days')->>'tiene_cuota')::boolean,
  'La consulta de saldo de esa fecha encuentra la cuota expirada'
);

insert into public.inscripciones (clase_id, alumno_id, estado) values
  ('00000000-0000-0000-0000-0000000b0c03', '00000000-0000-0000-0000-0000000b0005', 'inscrito'),
  ('00000000-0000-0000-0000-0000000b0c04', '00000000-0000-0000-0000-0000000b0005', 'inscrito');

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000b0001');
select is(
  (select sin_cuota from public.estado_cuota_participantes('00000000-0000-0000-0000-0000000b0c03')
    where alumno_id = '00000000-0000-0000-0000-0000000b0005'),
  false,
  'La lista de una clase antigua no marca «sin cuota» a quien la tenía'
);
select is(
  (select sin_cuota from public.estado_cuota_participantes('00000000-0000-0000-0000-0000000b0c04')
    where alumno_id = '00000000-0000-0000-0000-0000000b0005'),
  true,
  'Pero sí a quien no tenía cuota en la fecha de esa clase'
);
reset role;

select * from finish();
rollback;
