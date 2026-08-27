-- Regresión de «listo para graduarse»: la columna que cuenta desde cuándo
-- lleva un alumno en su cinturón actual, y la RPC que lo promueve.
begin;
select plan(8);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000f101', 'dueno-cinturon-a@test.dev'),
  ('00000000-0000-0000-0000-00000000f102', 'alumno-cinturon-a@test.dev'),
  ('00000000-0000-0000-0000-00000000f103', 'alumno-cinturon-a-viejo@test.dev'),
  ('00000000-0000-0000-0000-00000000f201', 'dueno-cinturon-b@test.dev'),
  ('00000000-0000-0000-0000-00000000f202', 'alumno-cinturon-b@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-00000000f1aa', 'Cinturones A', 'approved'),
  ('00000000-0000-0000-0000-00000000f2bb', 'Cinturones B', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado, cinturon, created_at) values
  ('00000000-0000-0000-0000-00000000f101', '00000000-0000-0000-0000-00000000f1aa', 'dueño', 'Dueño A', 'activo', 'negro', now()),
  ('00000000-0000-0000-0000-00000000f102', '00000000-0000-0000-0000-00000000f1aa', 'alumno', 'Alumno A', 'activo', 'blanco', now()),
  ('00000000-0000-0000-0000-00000000f201', '00000000-0000-0000-0000-00000000f2bb', 'dueño', 'Dueño B', 'activo', 'negro', now()),
  ('00000000-0000-0000-0000-00000000f202', '00000000-0000-0000-0000-00000000f2bb', 'alumno', 'Alumno B', 'activo', 'blanco', now());

-- Simula un alumno importado con su fecha de alta real, como hará el futuro
-- importador de MAAT: fecha_inicio_cinturon se pasa explícita, no la del
-- momento de la migración.
insert into public.profiles
  (id, academia_id, rol, nombre, estado, cinturon, created_at, fecha_inicio_cinturon)
values (
  '00000000-0000-0000-0000-00000000f103', '00000000-0000-0000-0000-00000000f1aa',
  'alumno', 'Alumno Viejo A', 'activo', 'azul', '2020-01-01', '2020-01-01'
);

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

-- 1. La columna existe y ya no admite null (tiene default).
select ok(
  (select is_nullable = 'NO' from information_schema.columns
     where table_schema = 'public' and table_name = 'profiles'
     and column_name = 'fecha_inicio_cinturon'),
  'fecha_inicio_cinturon existe y no admite null'
);

-- 2. Una fecha de alta real, pasada a mano (como hará el importador de
-- MAAT), se respeta y no la pisa ningún valor por defecto.
select ok(
  (select fecha_inicio_cinturon::date = '2020-01-01'
     from public.profiles where id = '00000000-0000-0000-0000-00000000f103'),
  'Una fecha de alta histórica explícita se conserva tal cual'
);

-- 3. Authenticated puede alcanzar la RPC (ella valida el rol en servidor).
select ok(
  has_function_privilege(
    'authenticated',
    'public.promover_cinturon(uuid,text)',
    'EXECUTE'
  ),
  'Authenticated puede alcanzar promover_cinturon'
);

-- 4. Un alumno no puede promover a nadie.
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000f102');
select throws_ok(
  $$ select public.promover_cinturon(
       '00000000-0000-0000-0000-00000000f102', 'azul'
     ) $$,
  null,
  'Un alumno no puede promoverse a sí mismo ni a nadie'
);

-- 5. El Dueño no puede promover a un alumno de otra academia.
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000f101');
select throws_ok(
  $$ select public.promover_cinturon(
       '00000000-0000-0000-0000-00000000f202', 'azul'
     ) $$,
  null,
  'El aislamiento entre academias también aplica a promover_cinturon'
);

-- 6. Un color inventado se sigue rechazando (lo hace el CHECK, no la RPC).
select throws_ok(
  $$ select public.promover_cinturon(
       '00000000-0000-0000-0000-00000000f102', 'rosa_fosforito'
     ) $$,
  null,
  'Un color inventado se rechaza también al promover'
);

-- 7-8. El Dueño promueve a su propio alumno: cambia el cinturón y reinicia
-- el contador de entrenos (fecha_inicio_cinturon pasa a "ahora", no sigue
-- en la fecha de alta).
select public.promover_cinturon('00000000-0000-0000-0000-00000000f102', 'azul');
select is(
  (select cinturon from public.profiles where id = '00000000-0000-0000-0000-00000000f102'),
  'azul',
  'promover_cinturon cambia el cinturón del alumno'
);
select ok(
  (select fecha_inicio_cinturon > now() - interval '1 minute'
     from public.profiles where id = '00000000-0000-0000-0000-00000000f102'),
  'promover_cinturon reinicia el contador de entrenos del cinturón nuevo'
);

select * from finish();
rollback;
