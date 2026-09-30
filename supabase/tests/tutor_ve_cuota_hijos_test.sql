-- El tutor ve la cuota y el saldo de SUS hijos, y de nadie más (ver
-- 20260930120000_tutor_ve_cuota_hijos.sql).
begin;
select plan(7);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000ef001', 'duena-tv@test.dev'),
  ('00000000-0000-0000-0000-0000000ef002', 'madre-tv@test.dev'),
  ('00000000-0000-0000-0000-0000000ef003', 'otro-padre-tv@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000ef0aa', 'Academia tutores', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000ef001', '00000000-0000-0000-0000-0000000ef0aa', 'dueño', 'Dueña', 'activo'),
  ('00000000-0000-0000-0000-0000000ef002', '00000000-0000-0000-0000-0000000ef0aa', 'alumno', 'Madre', 'activo'),
  ('00000000-0000-0000-0000-0000000ef003', '00000000-0000-0000-0000-0000000ef0aa', 'alumno', 'Otro padre', 'activo');

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, activo, clases_incluidas) values
  ('00000000-0000-0000-0000-0000000ef0f1', '00000000-0000-0000-0000-0000000ef0aa', 'Infantil 2 días', 40, 'mensual', true, 8);

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- La madre da de alta a su hija; la dueña le cobra la cuota.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ef002');
select public.crear_hijo('Lucía', 'Ejemplo', 'blanco');
reset role;

create temp table hija as
  select child_id as id from public.relaciones_familia
   where parent_id = '00000000-0000-0000-0000-0000000ef002';
grant select on hija to authenticated;

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ef001');
select public.activar_cuota_efectivo(
  (select id from hija), '00000000-0000-0000-0000-0000000ef0f1', now() + interval '30 days');
reset role;

-- ------------------------------------------------------------
-- La madre
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ef002');
select is(
  (select count(*)::int from public.suscripciones where alumno_id = (select id from hija)),
  1,
  'La madre ve la cuota de su hija'
);
select lives_ok(
  $$ select public.clases_restantes((select id from hija)) $$,
  'Y puede consultar cuántas clases le quedan'
);
select is(
  (public.clases_restantes((select id from hija)) ->> 'incluidas')::int,
  8,
  'Con el saldo de verdad de su hija'
);
reset role;

-- ------------------------------------------------------------
-- Otro padre de la misma academia
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ef003');
select is(
  (select count(*)::int from public.suscripciones where alumno_id = (select id from hija)),
  0,
  'Otro padre no ve la cuota de una niña que no es suya'
);
select throws_ok(
  $$ select public.clases_restantes((select id from hija)) $$,
  'No autorizado.',
  'Ni su saldo'
);
select is(
  (select count(*)::int from public.suscripciones
    where alumno_id = '00000000-0000-0000-0000-0000000ef002'),
  0,
  'Ni la cuota de la madre'
);
reset role;

-- El staff sigue viéndolo todo en su academia.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000ef001');
select is(
  (public.clases_restantes((select id from hija)) ->> 'incluidas')::int,
  8,
  'La dueña sigue viendo el saldo de cualquier alumno de su academia'
);
reset role;

select * from finish();
rollback;
