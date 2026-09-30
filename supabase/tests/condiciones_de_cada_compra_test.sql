-- Cada cuota guarda las condiciones con las que se compró, y el cobro en
-- efectivo apunta cuánto y quién (ver 20260930100000_condiciones_de_cada_compra.sql).
begin;
select plan(14);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000cc001', 'dueno-cc@test.dev'),
  ('00000000-0000-0000-0000-0000000cc002', 'alumno1-cc@test.dev'),
  ('00000000-0000-0000-0000-0000000cc003', 'alumno2-cc@test.dev'),
  ('00000000-0000-0000-0000-0000000cc004', 'alumno3-cc@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000cc0aa', 'Academia condiciones', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000cc001', '00000000-0000-0000-0000-0000000cc0aa', 'dueño', 'Dueño', 'activo'),
  ('00000000-0000-0000-0000-0000000cc002', '00000000-0000-0000-0000-0000000cc0aa', 'alumno', 'Uno', 'activo'),
  ('00000000-0000-0000-0000-0000000cc003', '00000000-0000-0000-0000-0000000cc0aa', 'alumno', 'Dos', 'activo'),
  ('00000000-0000-0000-0000-0000000cc004', '00000000-0000-0000-0000-0000000cc0aa', 'alumno', 'Tres', 'activo');

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, activo, clases_incluidas) values
  ('00000000-0000-0000-0000-0000000cc0f1', '00000000-0000-0000-0000-0000000cc0aa', '2 días', 50, 'mensual', true, 8),
  ('00000000-0000-0000-0000-0000000cc0f2', '00000000-0000-0000-0000-0000000cc0aa', 'Ilimitada', 80, 'mensual', true, null);

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- ------------------------------------------------------------
-- Cobro en efectivo: importe y quién
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000cc001');

select lives_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cc002', '00000000-0000-0000-0000-0000000cc0f1',
       now() + interval '30 days', false, 45) $$,
  'El dueño cobra 45 € (con descuento) por una tarifa de 50 €'
);
select public.activar_cuota_efectivo(
  '00000000-0000-0000-0000-0000000cc003', '00000000-0000-0000-0000-0000000cc0f1',
  now() + interval '30 days');
select public.activar_cuota_efectivo(
  '00000000-0000-0000-0000-0000000cc004', '00000000-0000-0000-0000-0000000cc0f1',
  null, true);
select throws_ok(
  $$ select public.activar_cuota_efectivo(
       '00000000-0000-0000-0000-0000000cc002', '00000000-0000-0000-0000-0000000cc0f1',
       now() + interval '30 days', false, -5) $$,
  'El importe cobrado no puede ser negativo.',
  'No se puede apuntar un importe negativo'
);
reset role;

select ok(
  (select importe_cobrado = 45
          and cobrado_por = '00000000-0000-0000-0000-0000000cc001'
          and cobrado_at is not null
     from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000cc002' and estado = 'activa'),
  'Queda apuntado lo que se recibió de verdad, quién lo cobró y cuándo'
);
select is(
  (select importe_cobrado from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000cc003' and estado = 'activa'),
  50.00::numeric,
  'Sin importe, se apunta el precio de la tarifa'
);
select is(
  (select importe_cobrado from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000cc004' and estado = 'prueba'),
  0.00::numeric,
  'Una prueba de 1 día se apunta con 0 €'
);

-- ------------------------------------------------------------
-- Las condiciones de la compra no cambian al editar la tarifa
-- ------------------------------------------------------------
select ok(
  (select tarifa_nombre = '2 días' and precio = 50 and periodicidad = 'mensual'
          and clases_incluidas = 8
     from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000cc002' and estado = 'activa'),
  'La cuota guarda nombre, precio, periodicidad y clases de la tarifa'
);

update public.tarifas
   set nombre = '3 días', precio = 70, clases_incluidas = 12, periodicidad = 'trimestral'
 where id = '00000000-0000-0000-0000-0000000cc0f1';

select ok(
  (select tarifa_nombre = '2 días' and precio = 50 and periodicidad = 'mensual'
          and clases_incluidas = 8
     from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000cc002' and estado = 'activa'),
  'Editar la tarifa no cambia la cuota ya comprada'
);
select is(
  (public._saldo_clases('00000000-0000-0000-0000-0000000cc002') ->> 'incluidas')::int,
  8,
  'El saldo sigue siendo de 8 clases, no de las 12 de la tarifa editada'
);
select is(
  (public._saldo_clases('00000000-0000-0000-0000-0000000cc002') ->> 'tarifa'),
  '2 días',
  'Y con el nombre con el que se compró'
);
select ok(
  (select (public._saldo_clases(s.alumno_id) ->> 'ciclo_fin')::timestamptz
          = s.fecha_inicio + interval '1 month'
     from public.suscripciones s
    where s.alumno_id = '00000000-0000-0000-0000-0000000cc002' and s.estado = 'activa'),
  'El ciclo sigue siendo mensual aunque la tarifa pase a trimestral'
);

-- Una cuota nueva sí se vende con las condiciones nuevas.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000cc001');
select public.activar_cuota_efectivo(
  '00000000-0000-0000-0000-0000000cc003', '00000000-0000-0000-0000-0000000cc0f1',
  now() + interval '90 days');
reset role;
select ok(
  (select clases_incluidas = 12 and periodicidad = 'trimestral' and precio = 70
     from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000cc003' and estado = 'activa'),
  'La siguiente compra sale con las condiciones nuevas'
);

-- Cambiar de tarifa en una cuota (lo que haría un cambio de plan en Stripe)
-- copia las condiciones de la nueva.
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-0000-0000-0000000cc001', 'role', 'authenticated')::text, true);
update public.suscripciones set tarifa_id = '00000000-0000-0000-0000-0000000cc0f2'
 where alumno_id = '00000000-0000-0000-0000-0000000cc003' and estado = 'activa';
select ok(
  (select clases_incluidas is null and tarifa_nombre = 'Ilimitada' and precio = 80
     from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000cc003' and estado = 'activa'),
  'Al cambiar de tarifa se copian las condiciones de la nueva'
);

-- ------------------------------------------------------------
-- Permisos
-- ------------------------------------------------------------
select ok(
  not has_column_privilege('authenticated', 'public.suscripciones', 'importe_cobrado', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.suscripciones', 'clases_incluidas', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.suscripciones', 'precio', 'UPDATE'),
  'Nadie puede cambiarse desde la app el importe ni las condiciones'
);
select ok(
  not has_function_privilege('authenticated', 'public.copiar_condiciones_tarifa()', 'EXECUTE'),
  'El disparador no se puede llamar como función'
);

select * from finish();
rollback;
