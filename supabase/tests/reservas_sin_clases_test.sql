-- Reservas que se quedan sin clases después de confirmadas: se mantienen y
-- salen marcadas en la lista (auditoría externa del 09/10/2026, punto 4;
-- decisión de Cipri; ver 20261009120000_reservas_sin_clases.sql).
begin;
select plan(13);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000eb001', 'dueno-sc@test.dev'),
  ('00000000-0000-0000-0000-0000000eb002', 'alumno-sc@test.dev'),
  ('00000000-0000-0000-0000-0000000eb003', 'acaba-sc@test.dev'),
  ('00000000-0000-0000-0000-0000000eb004', 'profe-sc@test.dev'),
  ('00000000-0000-0000-0000-0000000eb005', 'profe-otra-sc@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000eb0aa', 'Academia sin clases', 'approved'),
  ('00000000-0000-0000-0000-0000000eb0bb', 'Otra academia', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000eb001', '00000000-0000-0000-0000-0000000eb0aa', 'dueño', 'Dueño', 'activo'),
  ('00000000-0000-0000-0000-0000000eb002', '00000000-0000-0000-0000-0000000eb0aa', 'alumno', 'Alumno', 'activo'),
  ('00000000-0000-0000-0000-0000000eb003', '00000000-0000-0000-0000-0000000eb0aa', 'alumno', 'Acaba pronto', 'activo'),
  ('00000000-0000-0000-0000-0000000eb004', '00000000-0000-0000-0000-0000000eb0aa', 'profesor', 'Profe', 'activo'),
  ('00000000-0000-0000-0000-0000000eb005', '00000000-0000-0000-0000-0000000eb0bb', 'profesor', 'Profe ajeno', 'activo');

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, clases_incluidas) values
  ('00000000-0000-0000-0000-0000000eb0d1', '00000000-0000-0000-0000-0000000eb0aa', 'Dos al mes', 30, 'mensual', 2);

insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-0000000eb0c1', '00000000-0000-0000-0000-0000000eb0aa', '00000000-0000-0000-0000-0000000eb001',
   'Mañana', now() + interval '1 day', now() + interval '1 day 1 hour', 10),
  ('00000000-0000-0000-0000-0000000eb0c2', '00000000-0000-0000-0000-0000000eb0aa', '00000000-0000-0000-0000-0000000eb001',
   'Pasado', now() + interval '2 days', now() + interval '2 days 1 hour', 10),
  ('00000000-0000-0000-0000-0000000eb0c3', '00000000-0000-0000-0000-0000000eb0aa', '00000000-0000-0000-0000-0000000eb001',
   'El mes que viene', now() + interval '35 days', now() + interval '35 days 1 hour', 10),
  ('00000000-0000-0000-0000-0000000eb0c4', '00000000-0000-0000-0000-0000000eb0aa', '00000000-0000-0000-0000-0000000eb001',
   'Dentro de 20 días', now() + interval '20 days', now() + interval '20 days 1 hour', 10);

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

create or replace function pg_temp.marca(p_clase uuid, p_alumno uuid) returns text language sql as $$
  select coalesce(
    (select case when sin_cuota then 'sin cuota' when sin_clases then 'sin clases' else 'bien' end
       from public.estado_cuota_participantes(p_clase) where alumno_id = p_alumno),
    'no está');
$$;

-- Cuota de un mes con 2 clases, y la renovación ya pagada para el siguiente.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb001');
select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000eb002', '00000000-0000-0000-0000-0000000eb0d1', p_meses => 1);
select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000eb002', '00000000-0000-0000-0000-0000000eb0d1', p_meses => 1);

-- Reserva sus dos clases de este mes y una del mes que viene (de la renovación).
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb002');
select public.reservar_clase('00000000-0000-0000-0000-0000000eb0c1');
select public.reservar_clase('00000000-0000-0000-0000-0000000eb0c2');
select public.reservar_clase('00000000-0000-0000-0000-0000000eb0c3');

-- ------------------------------------------------------------
-- 1. Con todo cubierto, nadie sale marcado
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb001');
select is(pg_temp.marca('00000000-0000-0000-0000-0000000eb0c1', '00000000-0000-0000-0000-0000000eb002'), 'bien', 'Su primera clase está cubierta');
select is(pg_temp.marca('00000000-0000-0000-0000-0000000eb0c3', '00000000-0000-0000-0000-0000000eb002'), 'bien', 'La del mes que viene la cubre la renovación');

-- ------------------------------------------------------------
-- 2. El Dueño mueve la del mes que viene a este mes
-- ------------------------------------------------------------
select public.editar_clase('00000000-0000-0000-0000-0000000eb0c3', 'Adelantada', null,
  now() + interval '3 days', now() + interval '3 days 1 hour', 10);

select is(pg_temp.marca('00000000-0000-0000-0000-0000000eb0c3', '00000000-0000-0000-0000-0000000eb002'), 'sin clases',
  'La reserva movida a este mes se pasa de sus 2 clases: sale «sin clases»');
select is(pg_temp.marca('00000000-0000-0000-0000-0000000eb0c1', '00000000-0000-0000-0000-0000000eb002'), 'bien',
  'Las que ya tenía siguen bien: sobra la última por fecha');
select is(pg_temp.marca('00000000-0000-0000-0000-0000000eb0c2', '00000000-0000-0000-0000-0000000eb002'), 'bien',
  'Y la segunda también');
select is(
  (select estado from public.inscripciones
    where clase_id = '00000000-0000-0000-0000-0000000eb0c3' and alumno_id = '00000000-0000-0000-0000-0000000eb002'),
  'inscrito',
  'La reserva se mantiene (decisión de Cipri): no se cancela sola'
);

-- Le cobra una clase extra: deja de estar marcada.
reset role;
insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, clases_incluidas) values
  ('00000000-0000-0000-0000-0000000eb0d2', '00000000-0000-0000-0000-0000000eb0aa', 'Día suelto', 10, 'suelta', 1);
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb001');
select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000eb002', '00000000-0000-0000-0000-0000000eb0d2');
select is(pg_temp.marca('00000000-0000-0000-0000-0000000eb0c3', '00000000-0000-0000-0000-0000000eb002'), 'bien',
  'Cobrada una clase extra, ya está cubierta');

-- ------------------------------------------------------------
-- 3. «Sin cuota» mira la fecha de la clase, no la de hoy
-- ------------------------------------------------------------
reset role;
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb001');
select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000eb003', '00000000-0000-0000-0000-0000000eb0d1', p_meses => 1);
reset role;
update public.suscripciones set fecha_fin = now() + interval '10 days'
 where alumno_id = '00000000-0000-0000-0000-0000000eb003';
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb003');
select public.reservar_clase('00000000-0000-0000-0000-0000000eb0c1');
select public.reservar_clase('00000000-0000-0000-0000-0000000eb0c4');
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb001');
select is(pg_temp.marca('00000000-0000-0000-0000-0000000eb0c1', '00000000-0000-0000-0000-0000000eb003'), 'bien',
  'Mañana tiene cuota');
select is(pg_temp.marca('00000000-0000-0000-0000-0000000eb0c4', '00000000-0000-0000-0000-0000000eb003'), 'sin cuota',
  'Dentro de 20 días su cuota ya habrá acabado: «sin cuota», aunque hoy la tenga');

-- ------------------------------------------------------------
-- 4. Solo lo ve el staff de la academia
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb004');
select is(pg_temp.marca('00000000-0000-0000-0000-0000000eb0c3', '00000000-0000-0000-0000-0000000eb002'), 'bien',
  'Un profesor de la academia también lo ve');

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb002');
select throws_ok($$ select * from public.estado_cuota_participantes('00000000-0000-0000-0000-0000000eb0c1') $$,
  'Solo el Dueño o un Profesor ven el estado de cuota de la clase.', 'Un alumno no ve las cuotas de sus compañeros');

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb005');
select throws_ok($$ select * from public.estado_cuota_participantes('00000000-0000-0000-0000-0000000eb0c1') $$,
  'Clase no encontrada.', 'Un profesor de otra academia tampoco');

reset role;
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000eb009', 'sin-perfil-sc@test.dev');
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000eb009');
select throws_ok($$ select * from public.estado_cuota_participantes('00000000-0000-0000-0000-0000000eb0c1') $$,
  'Solo el Dueño o un Profesor ven el estado de cuota de la clase.', 'Ni una cuenta sin perfil');

select * from finish();
rollback;
