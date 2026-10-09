-- Apuntar a quien llega a clase sin reserva, respetando aforo, cuota y
-- clases de la tarifa (auditoría externa del 09/10/2026, punto 6; decisión
-- de Cipri; ver 20261009140000_apuntar_sin_reserva.sql).
begin;
select plan(18);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000ed001', 'dueno-as@test.dev'),
  ('00000000-0000-0000-0000-0000000ed002', 'profe-as@test.dev'),
  ('00000000-0000-0000-0000-0000000ed003', 'con-clases-as@test.dev'),
  ('00000000-0000-0000-0000-0000000ed004', 'sin-clases-as@test.dev'),
  ('00000000-0000-0000-0000-0000000ed005', 'sin-cuota-as@test.dev'),
  ('00000000-0000-0000-0000-0000000ed006', 'en-espera-as@test.dev'),
  ('00000000-0000-0000-0000-0000000ed007', 'ajeno-as@test.dev'),
  ('00000000-0000-0000-0000-0000000ed008', 'otro-as@test.dev'),
  ('00000000-0000-0000-0000-0000000ed009', 'sin-perfil-as@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000ed0aa', 'Academia apuntar', 'approved'),
  ('00000000-0000-0000-0000-0000000ed0bb', 'Otra academia', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000ed001', '00000000-0000-0000-0000-0000000ed0aa', 'dueño', 'Dueño', 'activo'),
  ('00000000-0000-0000-0000-0000000ed002', '00000000-0000-0000-0000-0000000ed0aa', 'profesor', 'Profe', 'activo'),
  ('00000000-0000-0000-0000-0000000ed003', '00000000-0000-0000-0000-0000000ed0aa', 'alumno', 'Con clases', 'activo'),
  ('00000000-0000-0000-0000-0000000ed004', '00000000-0000-0000-0000-0000000ed0aa', 'alumno', 'Sin clases', 'activo'),
  ('00000000-0000-0000-0000-0000000ed005', '00000000-0000-0000-0000-0000000ed0aa', 'alumno', 'Sin cuota', 'activo'),
  ('00000000-0000-0000-0000-0000000ed006', '00000000-0000-0000-0000-0000000ed0aa', 'alumno', 'En espera', 'activo'),
  ('00000000-0000-0000-0000-0000000ed007', '00000000-0000-0000-0000-0000000ed0bb', 'alumno', 'Ajeno', 'activo'),
  ('00000000-0000-0000-0000-0000000ed008', '00000000-0000-0000-0000-0000000ed0aa', 'alumno', 'Otro', 'activo');

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, clases_incluidas) values
  ('00000000-0000-0000-0000-0000000ed0d1', '00000000-0000-0000-0000-0000000ed0aa', 'Dos al mes', 30, 'mensual', 2),
  ('00000000-0000-0000-0000-0000000ed0d2', '00000000-0000-0000-0000-0000000ed0aa', 'Una al mes', 15, 'mensual', 1);

insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-0000000ed0c1', '00000000-0000-0000-0000-0000000ed0aa', '00000000-0000-0000-0000-0000000ed002',
   'Empezada', now() - interval '10 minutes', now() + interval '50 minutes', 3),
  ('00000000-0000-0000-0000-0000000ed0c2', '00000000-0000-0000-0000-0000000ed0aa', '00000000-0000-0000-0000-0000000ed002',
   'Pasado mañana', now() + interval '2 days', now() + interval '2 days 1 hour', 10),
  ('00000000-0000-0000-0000-0000000ed0c3', '00000000-0000-0000-0000-0000000ed0aa', '00000000-0000-0000-0000-0000000ed002',
   'Ayer', now() - interval '1 day', now() - interval '1 day' + interval '1 hour', 10);

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- Cuotas: «Con clases» tiene 2; «Sin clases» tiene 1 y ya la gastó ayer.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ed001');
select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ed003', '00000000-0000-0000-0000-0000000ed0d1', p_meses => 1);
select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000ed004', '00000000-0000-0000-0000-0000000ed0d2', p_meses => 1);
reset role;
-- Las cuotas empiezan hace unos días: la clase empezada (hace 10 minutos)
-- y la de ayer caen dentro.
update public.suscripciones set fecha_inicio = now() - interval '3 days'
 where alumno_id in ('00000000-0000-0000-0000-0000000ed003', '00000000-0000-0000-0000-0000000ed004');
insert into public.inscripciones (clase_id, alumno_id, estado) values
  ('00000000-0000-0000-0000-0000000ed0c3', '00000000-0000-0000-0000-0000000ed004', 'inscrito');
insert into public.asistencias (clase_id, alumno_id, validado_por) values
  ('00000000-0000-0000-0000-0000000ed0c3', '00000000-0000-0000-0000-0000000ed004', '00000000-0000-0000-0000-0000000ed002');
-- «En espera» está en la cola de la clase empezada.
insert into public.inscripciones (clase_id, alumno_id, estado) values
  ('00000000-0000-0000-0000-0000000ed0c1', '00000000-0000-0000-0000-0000000ed006', 'espera');

-- ------------------------------------------------------------
-- 1. Llega sin reserva y tiene clases: queda apuntado y presente
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ed002');
select lives_ok(
  $$ select public.apuntar_en_clase('00000000-0000-0000-0000-0000000ed0c1', '00000000-0000-0000-0000-0000000ed003') $$,
  'El profesor apunta a quien ha venido sin reserva'
);
reset role;
select is(
  (select estado from public.inscripciones
    where clase_id = '00000000-0000-0000-0000-0000000ed0c1' and alumno_id = '00000000-0000-0000-0000-0000000ed003'),
  'inscrito', 'Queda con plaza'
);
select is(
  (select validado_por from public.asistencias
    where clase_id = '00000000-0000-0000-0000-0000000ed0c1' and alumno_id = '00000000-0000-0000-0000-0000000ed003'),
  '00000000-0000-0000-0000-0000000ed002'::uuid, 'Y con la asistencia confirmada por el profesor'
);
select is(
  (public._saldo_clases('00000000-0000-0000-0000-0000000ed003') ->> 'gastadas')::int,
  1, 'Le cuenta como clase gastada'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ed002');
select throws_ok(
  $$ select public.apuntar_en_clase('00000000-0000-0000-0000-0000000ed0c1', '00000000-0000-0000-0000-0000000ed003') $$,
  'Ya tiene la asistencia confirmada en esta clase.', 'No se le apunta dos veces'
);

-- ------------------------------------------------------------
-- 2. Las reglas de reservar
-- ------------------------------------------------------------
select throws_ok(
  $$ select public.apuntar_en_clase('00000000-0000-0000-0000-0000000ed0c1', '00000000-0000-0000-0000-0000000ed004') $$,
  'No le quedan clases en su tarifa. Cóbrale una clase extra antes de apuntarlo.',
  'Sin clases en su tarifa, no'
);
select lives_ok(
  $$ select public.apuntar_en_clase('00000000-0000-0000-0000-0000000ed0c1', '00000000-0000-0000-0000-0000000ed005') $$,
  'Sin cuota, sí: la academia no la exige (saldrá «sin cuota» para cobrarle)'
);
select throws_ok(
  $$ select public.apuntar_en_clase('00000000-0000-0000-0000-0000000ed0c2', '00000000-0000-0000-0000-0000000ed008') $$,
  'Se puede apuntar a quien ha venido desde media hora antes de la clase.',
  'Una clase de pasado mañana todavía no'
);

reset role;
update public.academias set exigir_cuota_para_reservar = true where id = '00000000-0000-0000-0000-0000000ed0aa';
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ed002');
select throws_ok(
  $$ select public.apuntar_en_clase('00000000-0000-0000-0000-0000000ed0c1', '00000000-0000-0000-0000-0000000ed008') $$,
  'No tiene cuota para esta clase. Cóbrasela antes de apuntarlo.',
  'Si la academia exige cuota, sin cuota no'
);
reset role;
update public.academias set exigir_cuota_para_reservar = false where id = '00000000-0000-0000-0000-0000000ed0aa';

-- ------------------------------------------------------------
-- 3. Aforo y lista de espera
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ed001');
select lives_ok(
  $$ select public.apuntar_en_clase('00000000-0000-0000-0000-0000000ed0c1', '00000000-0000-0000-0000-0000000ed006') $$,
  'Quien estaba en la lista de espera pasa a tener plaza'
);
reset role;
select is(
  (select count(*)::int from public.inscripciones
    where clase_id = '00000000-0000-0000-0000-0000000ed0c1' and alumno_id = '00000000-0000-0000-0000-0000000ed006'),
  1, 'Sin duplicar su fila'
);
select is(
  (select count(*)::int from public.inscripciones
    where clase_id = '00000000-0000-0000-0000-0000000ed0c1' and estado = 'inscrito'),
  3, 'La clase queda llena (3 de 3)'
);
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ed001');
select throws_ok(
  $$ select public.apuntar_en_clase('00000000-0000-0000-0000-0000000ed0c1', '00000000-0000-0000-0000-0000000ed008') $$,
  'Aforo completo para esta clase.', 'Con la clase llena, no'
);

-- ------------------------------------------------------------
-- 4. Quién puede y a quién
-- ------------------------------------------------------------
select throws_ok(
  $$ select public.apuntar_en_clase('00000000-0000-0000-0000-0000000ed0c3', '00000000-0000-0000-0000-0000000ed007') $$,
  'Esa persona no es de tu academia.', 'A alguien de otra academia, no'
);
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ed003');
select throws_ok(
  $$ select public.apuntar_en_clase('00000000-0000-0000-0000-0000000ed0c3', '00000000-0000-0000-0000-0000000ed008') $$,
  'Solo el Dueño o un Profesor pueden apuntar a alguien en la clase.', 'Un alumno no puede'
);
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ed009');
select throws_ok(
  $$ select public.apuntar_en_clase('00000000-0000-0000-0000-0000000ed0c3', '00000000-0000-0000-0000-0000000ed008') $$,
  'Solo el Dueño o un Profesor pueden apuntar a alguien en la clase.', 'Ni una cuenta sin perfil'
);

-- Una clase de ayer: se puede apuntar a quien vino y no se registró.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ed002');
select lives_ok(
  $$ select public.apuntar_en_clase('00000000-0000-0000-0000-0000000ed0c3', '00000000-0000-0000-0000-0000000ed008') $$,
  'En una clase ya pasada también (igual que pasar lista)'
);
reset role;
select is(
  (select count(*)::int from public.asistencias where alumno_id = '00000000-0000-0000-0000-0000000ed008'),
  1, 'Con su asistencia'
);

select * from finish();
rollback;
