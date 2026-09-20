-- Tests pgTAP de que una prueba de 1 día respeta el límite de clases de su
-- tarifa, igual que una cuota activa normal.
--
-- Antes de esta migración, `_saldo_clases()` solo reconocía suscripciones
-- con estado 'activa': una prueba (estado 'prueba') siempre volvía
-- `tiene_cuota: false`, así que el bloqueo por número de clases nunca se
-- aplicaba durante una prueba, aunque su tarifa tuviera `clases_incluidas`.

begin;
select plan(3);

-- ── Semilla ──────────────────────────────────────────────────────────────
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000d1', 'duenoLP@test.dev'),
  ('00000000-0000-0000-0000-0000000000d2', 'alumnoLP@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-000000000ea1', 'Academia Límite Prueba', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-000000000ea1', 'dueño', 'Dueño LP', 'activo'),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-000000000ea1', 'alumno', 'Alumno LP', 'activo');

-- Tarifa de prueba con una sola clase incluida.
insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, clases_incluidas) values (
  '00000000-0000-0000-0000-000000000fa1',
  '00000000-0000-0000-0000-000000000ea1',
  'Prueba 1 clase',
  0,
  'mensual',
  1
);

-- Dos clases futuras de aforo amplio: lo que se pone a prueba es el saldo
-- de la tarifa, no el aforo de la clase.
insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-000000000ca1', '00000000-0000-0000-0000-000000000ea1', '00000000-0000-0000-0000-0000000000d1', 'Clase LP 1', now() + interval '1 day', now() + interval '1 day 1 hour', 10),
  ('00000000-0000-0000-0000-000000000ca2', '00000000-0000-0000-0000-000000000ea1', '00000000-0000-0000-0000-0000000000d1', 'Clase LP 2', now() + interval '2 days', now() + interval '2 days 1 hour', 10);

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- El Dueño da de alta la prueba.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000d1');
select public.activar_cuota_efectivo(
  '00000000-0000-0000-0000-0000000000d2',
  '00000000-0000-0000-0000-000000000fa1',
  null,
  true
);

-- ── El alumno de prueba reserva su única clase incluida ─────────────────
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000d2');
select is(
  public.reservar_clase('00000000-0000-0000-0000-000000000ca1'),
  'inscrito',
  'La primera clase, dentro del límite de la prueba, se reserva sin problema'
);

select is(
  public.clases_restantes('00000000-0000-0000-0000-0000000000d2')
    - 'ciclo_inicio' - 'ciclo_fin',
  jsonb_build_object(
    'tiene_cuota', true,
    'ilimitada', false,
    'tarifa', 'Prueba 1 clase',
    'incluidas', 1,
    'gastadas', 0,
    'reservadas', 1,
    'disponibles', 0
  ),
  'La prueba SÍ cuenta como cuota, con su saldo calculado (1 incluida, 1 reservada, 0 disponibles) — no un 0 por no tener cuota'
);

select throws_ok(
  $$ select public.reservar_clase('00000000-0000-0000-0000-000000000ca2') $$,
  'No te quedan clases en tu tarifa este mes. Renueva o compra una clase suelta.',
  'La segunda clase se rechaza: la prueba respeta el límite de su tarifa'
);

select * from finish();
rollback;
