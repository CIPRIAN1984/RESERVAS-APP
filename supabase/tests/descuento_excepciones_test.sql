-- Excepciones del descuento de clases (auditoría del 30/09/2026) y
-- perdonar una cancelación tardía (ver 20260930090000_descuento_excepciones.sql).
begin;
select plan(16);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000de001', 'dueno-de@test.dev'),
  ('00000000-0000-0000-0000-0000000de002', 'profe-de@test.dev'),
  ('00000000-0000-0000-0000-0000000de003', 'alumno-de@test.dev'),
  ('00000000-0000-0000-0000-0000000de004', 'profe-otra@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000de0aa', 'Academia descuento', 'approved'),
  ('00000000-0000-0000-0000-0000000de0bb', 'Otra academia', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000de001', '00000000-0000-0000-0000-0000000de0aa', 'dueño', 'Dueño', 'activo'),
  ('00000000-0000-0000-0000-0000000de002', '00000000-0000-0000-0000-0000000de0aa', 'profesor', 'Profe', 'activo'),
  ('00000000-0000-0000-0000-0000000de003', '00000000-0000-0000-0000-0000000de0aa', 'alumno', 'Alumno', 'activo'),
  ('00000000-0000-0000-0000-0000000de004', '00000000-0000-0000-0000-0000000de0bb', 'profesor', 'Profe ajeno', 'activo');

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, activo, clases_incluidas) values
  ('00000000-0000-0000-0000-0000000de0f1', '00000000-0000-0000-0000-0000000de0aa', 'Mensual 4', 40, 'mensual', true, 4);

insert into public.suscripciones (id, alumno_id, tarifa_id, academia_id, proveedor_pago) values
  ('00000000-0000-0000-0000-0000000de0e1', '00000000-0000-0000-0000-0000000de003',
   '00000000-0000-0000-0000-0000000de0f1', '00000000-0000-0000-0000-0000000de0aa', 'efectivo');
update public.suscripciones
   set estado = 'activa', payment_status = 'active',
       fecha_inicio = now() - interval '5 days', fecha_fin = now() + interval '25 days'
 where id = '00000000-0000-0000-0000-0000000de0e1';

-- Las tres empiezan dentro del margen de cancelación (240 min por defecto):
-- cancelarlas ahora es tardío.
insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-0000000de0c1', '00000000-0000-0000-0000-0000000de0aa', '00000000-0000-0000-0000-0000000de002',
   'Vuelve a reservar', now() + interval '1 hour', now() + interval '2 hours', 10),
  ('00000000-0000-0000-0000-0000000de0c2', '00000000-0000-0000-0000-0000000de0aa', '00000000-0000-0000-0000-0000000de002',
   'La cancela la academia', now() + interval '2 hours', now() + interval '3 hours', 10),
  ('00000000-0000-0000-0000-0000000de0c3', '00000000-0000-0000-0000-0000000de0aa', '00000000-0000-0000-0000-0000000de002',
   'La perdona el dueño', now() + interval '3 hours', now() + interval '4 hours', 10);

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

create or replace function pg_temp.saldo(p_campo text) returns int language sql as $$
  select (public._saldo_clases('00000000-0000-0000-0000-0000000de003') ->> p_campo)::int;
$$;

-- ------------------------------------------------------------
-- 1. Cancelar tarde y volver a reservar la misma clase: cuenta una vez
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000de003');
select public.reservar_clase('00000000-0000-0000-0000-0000000de0c1');
select public.cancelar_reserva('00000000-0000-0000-0000-0000000de0c1');
select public.reservar_clase('00000000-0000-0000-0000-0000000de0c1');
reset role;

select is(pg_temp.saldo('gastadas') + pg_temp.saldo('reservadas'), 1,
  'Cancelar tarde y volver a reservar la misma clase la cuenta una sola vez');
select is(pg_temp.saldo('disponibles'), 3, 'Le quedan 3 de 4');

-- ------------------------------------------------------------
-- 2. La academia cancela la clase: la cancelación tardía deja de contar
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000de003');
select public.reservar_clase('00000000-0000-0000-0000-0000000de0c2');
select public.cancelar_reserva('00000000-0000-0000-0000-0000000de0c2');
reset role;
select is(pg_temp.saldo('disponibles'), 2, 'Cancelar tarde la segunda clase gasta otra');

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000de001');
select public.cancelar_clase('00000000-0000-0000-0000-0000000de0c2');
reset role;
select is(pg_temp.saldo('disponibles'), 3,
  'Si la academia cancela la clase, la cancelación tardía de antes ya no descuenta');

-- ------------------------------------------------------------
-- 3. Perdonar
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000de003');
select throws_ok(
  $$ select public.perdonar_cancelacion_tardia('00000000-0000-0000-0000-0000000de0c1', '00000000-0000-0000-0000-0000000de003') $$,
  'Solo el Dueño o un Profesor pueden perdonar una cancelación.',
  'El alumno no se puede perdonar a sí mismo'
);
reset role;

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000de004');
select throws_ok(
  $$ select public.perdonar_cancelacion_tardia('00000000-0000-0000-0000-0000000de0c1', '00000000-0000-0000-0000-0000000de003') $$,
  'Clase no encontrada.',
  'Un profesor de otra academia no puede'
);
reset role;

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000de002');
select lives_ok(
  $$ select public.perdonar_cancelacion_tardia('00000000-0000-0000-0000-0000000de0c1', '00000000-0000-0000-0000-0000000de003') $$,
  'El profesor de la academia perdona la cancelación tardía'
);
select throws_ok(
  $$ select public.perdonar_cancelacion_tardia('00000000-0000-0000-0000-0000000de0c1', '00000000-0000-0000-0000-0000000de003') $$,
  'Esa cancelación no cuenta como tardía: no hay nada que perdonar.',
  'Perdonar dos veces avisa de que no queda nada'
);
reset role;

select ok(
  (select bool_and(not cancelacion_tardia
                   and tardia_perdonada_por = '00000000-0000-0000-0000-0000000de002'
                   and tardia_perdonada_at is not null)
     from public.inscripciones
    where clase_id = '00000000-0000-0000-0000-0000000de0c1'
      and alumno_id = '00000000-0000-0000-0000-0000000de003'
      and estado = 'cancelado'),
  'Queda rastro de quién perdonó y cuándo'
);
select is(pg_temp.saldo('gastadas'), 0, 'Perdonada, ya no cuenta como gastada');
select is(pg_temp.saldo('reservadas'), 1, 'La reserva nueva de esa clase sí cuenta');

-- El Dueño también puede (decisión de Cipri, 30/09/2026).
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000de003');
select public.reservar_clase('00000000-0000-0000-0000-0000000de0c3');
select public.cancelar_reserva('00000000-0000-0000-0000-0000000de0c3');
reset role;
select is(pg_temp.saldo('disponibles'), 2, 'Otra cancelación tardía gasta una');

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000de001');
select lives_ok(
  $$ select public.perdonar_cancelacion_tardia('00000000-0000-0000-0000-0000000de0c3', '00000000-0000-0000-0000-0000000de003') $$,
  'El dueño también perdona'
);
reset role;
select is(pg_temp.saldo('disponibles'), 3, 'Y se le devuelve la clase');

-- ------------------------------------------------------------
-- 4. Permisos
-- ------------------------------------------------------------
select ok(
  not has_function_privilege('anon', 'public.perdonar_cancelacion_tardia(uuid, uuid)', 'EXECUTE'),
  'Sin sesión no se puede perdonar nada'
);
select ok(
  not has_column_privilege('authenticated', 'public.inscripciones', 'tardia_perdonada_por', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.inscripciones', 'cancelacion_tardia', 'UPDATE'),
  'Nadie puede quitarse una cancelación tardía escribiendo directamente en la tabla'
);

select * from finish();
rollback;
