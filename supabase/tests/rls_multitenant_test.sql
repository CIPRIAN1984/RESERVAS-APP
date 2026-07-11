-- Tests pgTAP del aislamiento multi-tenant y de las reglas de rol más
-- críticas. Se ejecutan con `supabase test db` (Supabase levanta la base
-- local, aplica las migraciones y corre este fichero dentro de una
-- transacción que se revierte al terminar).
--
-- Estrategia: sembramos dos academias con sus usuarios, y comprobamos que,
-- suplantando el JWT de cada usuario (set request.jwt.claims + set role
-- authenticated), la RLS deja ver/escribir solo lo que debe.

begin;
select plan(10);

-- ── Semilla ────────────────────────────────────────────────────────────────
-- Insertamos como superusuario (bypassa RLS) el estado de partida.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'duenoA@test.dev'),
  ('00000000-0000-0000-0000-0000000000a2', 'alumnoA@test.dev'),
  ('00000000-0000-0000-0000-0000000000b1', 'duenoB@test.dev'),
  ('00000000-0000-0000-0000-0000000000b2', 'alumnoB@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000000AA', 'Academia A', 'approved'),
  ('00000000-0000-0000-0000-0000000000BB', 'Academia B', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000AA', 'dueño', 'Dueño A', 'activo'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000AA', 'alumno', 'Alumno A', 'activo'),
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000BB', 'dueño', 'Dueño B', 'activo'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000BB', 'alumno', 'Alumno B', 'activo');

-- Una clase en cada academia.
insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-00000000c1a1', '00000000-0000-0000-0000-0000000000AA', '00000000-0000-0000-0000-0000000000a1', 'Clase A', now() + interval '1 day', now() + interval '1 day 1 hour', 2),
  ('00000000-0000-0000-0000-00000000c1b1', '00000000-0000-0000-0000-0000000000BB', '00000000-0000-0000-0000-0000000000b1', 'Clase B', now() + interval '1 day', now() + interval '1 day 1 hour', 2);

-- Cuota cobrada para el alumno A: las reservas de alumnos exigen una
-- suscripción activa, no solo una cuenta registrada.
insert into public.tarifas (id, academia_id, nombre, precio, periodicidad)
values (
  '00000000-0000-0000-0000-00000000f001',
  '00000000-0000-0000-0000-0000000000AA',
  'Mensual A',
  50,
  'mensual'
);

insert into public.suscripciones (
  id,
  alumno_id,
  tarifa_id,
  academia_id,
  proveedor_pago,
  referencia_externa
) values (
  '00000000-0000-0000-0000-00000000d001',
  '00000000-0000-0000-0000-0000000000a2',
  '00000000-0000-0000-0000-00000000f001',
  '00000000-0000-0000-0000-0000000000AA',
  'stripe',
  'sub_test_alumno_a'
);
update public.suscripciones
  set estado = 'activa', payment_status = 'active'
  where id = '00000000-0000-0000-0000-00000000d001';

-- Helper: adopta la identidad de un usuario autenticado concreto.
create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- ── 1-2. Aislamiento de lectura de clases ───────────────────────────────────
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000a2');
select is(
  (select count(*)::int from public.clases),
  1,
  'El alumno A solo ve las clases de su propia academia'
);
select is(
  (select count(*)::int from public.clases where academia_id = '00000000-0000-0000-0000-0000000000BB'),
  0,
  'El alumno A no ve ninguna clase de la academia B'
);

-- ── 3. Un alumno no puede inscribirse en una clase de OTRA academia ─────────
select throws_ok(
  $$ insert into public.inscripciones (clase_id, alumno_id, academia_id)
     values ('00000000-0000-0000-0000-00000000c1b1', '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000AA') $$,
  null,
  'La RLS bloquea que el alumno A se inscriba en una clase de la academia B'
);

-- ── 4. Un alumno con cuota activa sí puede reservar en la SUYA ──────────────
select lives_ok(
  $ select public.reservar_clase('00000000-0000-0000-0000-00000000c1a1') $,
  'El alumno A con cuota activa puede reservar una clase de su academia'
);

-- ── 5. Un alumno no puede inscribir a OTRO usuario ──────────────────────────
select throws_ok(
  $$ insert into public.inscripciones (clase_id, alumno_id, academia_id)
     values ('00000000-0000-0000-0000-00000000c1a1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000AA') $$,
  null,
  'El alumno A no puede inscribir a un tercero (alumno_id debe ser auth.uid())'
);

-- ── 6. Un alumno no puede crear clases ──────────────────────────────────────
select throws_ok(
  $$ insert into public.clases (academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo)
     values ('00000000-0000-0000-0000-0000000000AA', '00000000-0000-0000-0000-0000000000a2', 'Pirata', now(), now() + interval '1 hour', 5) $$,
  null,
  'Un alumno no puede crear clases (solo profesor/dueño)'
);

-- ── 7. El Dueño A no puede sembrar técnicas en la academia B (RPC definer) ───
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000a1');
select throws_ok(
  $$ select public.sembrar_tecnicas_default('00000000-0000-0000-0000-0000000000BB') $$,
  null,
  'sembrar_tecnicas_default rechaza a quien no es administrador'
);

-- ── 8. El Dueño A no puede aprobar su propia academia ───────────────────────
select throws_ok(
  $$ select public.aprobar_academia('00000000-0000-0000-0000-0000000000AA') $$,
  null,
  'aprobar_academia rechaza a quien no es administrador'
);

-- ── 9. El Dueño A no puede escribir columnas de Stripe directamente ──────────
-- El UPDATE de una columna con el privilegio revocado falla con "permission
-- denied for column", no con una violación de RLS — pero igualmente lanza.
select throws_ok(
  $$ update public.academias set stripe_charges_enabled = true
     where id = '00000000-0000-0000-0000-0000000000AA' $$,
  null,
  'El Dueño no puede activar stripe_charges_enabled (columna revocada)'
);

-- ── 10. El Dueño B no ve los perfiles de la academia A ──────────────────────
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000b1');
select is(
  (select count(*)::int from public.profiles where academia_id = '00000000-0000-0000-0000-0000000000AA'),
  0,
  'El Dueño B no ve ningún perfil de la academia A'
);

select * from finish();
rollback;
