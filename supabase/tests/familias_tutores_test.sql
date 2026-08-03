-- Tests para familias y tutores: RLS, creación de menores, visibilidad
-- Los menores NO tienen auth.users: solo profiles vinculados por relaciones_familia

begin;

select plan(25);

-- ============================================================
-- Setup: usuarios, academias y perfiles
-- ============================================================

-- Crear academia
insert into public.academias (id, nombre, estado, created_by)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'Test Academia',
  'approved',
  'dueño0000-0000-0000-0000-000000000000'::uuid
);

-- Crear usuario padre en auth
insert into auth.users (id, email, encrypted_password, email_confirmed_at, aud, role)
values (
  'padre00-0000-0000-0000-000000000000'::uuid,
  'padre@test.local',
  crypt('password', gen_salt('bf')),
  now(),
  'authenticated',
  'authenticated'
);

-- Crear otros usuarios para tests
insert into auth.users (id, email, encrypted_password, email_confirmed_at, aud, role)
values (
  'ciclo00-0000-0000-0000-000000000000'::uuid,
  'ciclo@test.local',
  crypt('password', gen_salt('bf')),
  now(),
  'authenticated',
  'authenticated'
);

-- Crear perfiles: padre
insert into public.profiles (id, academia_id, rol, nombre, estado)
values (
  'padre00-0000-0000-0000-000000000000'::uuid,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'alumno',
  'Padre Testigo',
  'activo'
);

-- Crear otro usuario para test de ciclos
insert into public.profiles (id, academia_id, rol, nombre, estado)
values (
  'ciclo00-0000-0000-0000-000000000000'::uuid,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'alumno',
  'Ciclo Test',
  'activo'
);

-- Crear perfil hijo (SOLO PROFILE, sin auth.users)
-- Usamos UUID conocida para poder referenciarla en tests
insert into public.profiles (id, academia_id, rol, nombre, estado)
values (
  'hijo00-0000-0000-0000-000000000001'::uuid,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'alumno',
  'Hijo Testigo',
  'activo'
);

-- ============================================================
-- Test 1: relaciones_familia creada correctamente
-- ============================================================

select is(
  (select count(*) from public.relaciones_familia),
  0::bigint,
  'relaciones_familia inicia vacía'
);

-- ============================================================
-- Test 2-5: Crear relación familia y verificar campos
-- ============================================================

insert into public.relaciones_familia (
  parent_id,
  child_id,
  tipo_relacion
) values (
  'padre00-0000-0000-0000-000000000000'::uuid,
  'hijo00-0000-0000-0000-000000000001'::uuid,
  'padre'
);

select is(
  (select count(*) from public.relaciones_familia),
  1::bigint,
  'se inserta una relación familia'
);

select is(
  (select parent_id from public.relaciones_familia limit 1),
  'padre00-0000-0000-0000-000000000000'::uuid,
  'parent_id es correcto'
);

select is(
  (select child_id from public.relaciones_familia limit 1),
  'hijo00-0000-0000-0000-000000000001'::uuid,
  'child_id es correcto'
);

select is(
  (select tipo_relacion from public.relaciones_familia limit 1),
  'padre',
  'tipo_relacion es correcto'
);

-- ============================================================
-- Test 6: Un menor solo puede tener un padre/tutor (unique constraint)
-- ============================================================

select throws_ok(
  $$
    insert into public.relaciones_familia (
      parent_id,
      child_id,
      tipo_relacion
    ) values (
      'padre00-0000-0000-0000-000000000000'::uuid,
      'hijo00-0000-0000-0000-000000000001'::uuid,
      'madre'
    );
  $$,
  'duplicate key value',
  'no permite dos padres para el mismo hijo (unique)'
);

-- ============================================================
-- Test 7: No se permite ciclos (padre = hijo)
-- ============================================================

select throws_ok(
  $$
    insert into public.relaciones_familia (
      parent_id,
      child_id,
      tipo_relacion
    ) values (
      'ciclo00-0000-0000-0000-000000000000'::uuid,
      'ciclo00-0000-0000-0000-000000000000'::uuid,
      'padre'
    );
  $$,
  'new row for relation',
  'no permite que un usuario sea su propio padre (no_ciclos_familia)'
);

-- ============================================================
-- Test 8-11: RLS — padre ve sus hijos
-- ============================================================

-- Cambiar a sesión del padre
select set_config('request.jwt.claims', json_build_object(
  'sub', 'padre00-0000-0000-0000-000000000000',
  'role', 'authenticated'
)::text, true);

select is(
  (select count(*) from public.profiles where id = 'hijo00-0000-0000-0000-000000000001'::uuid),
  1::bigint,
  'padre ve el perfil del hijo'
);

select is(
  (select nombre from public.profiles where id = 'hijo00-0000-0000-0000-000000000001'::uuid),
  'Hijo Testigo',
  'padre puede leer datos del hijo'
);

-- ============================================================
-- Test 12-14: RLS — padre puede ver sus hijos vía relaciones_familia
-- ============================================================

select is(
  (select count(*) from public.relaciones_familia where parent_id = 'padre00-0000-0000-0000-000000000000'::uuid),
  1::bigint,
  'padre ve sus propias relaciones familia'
);

select is(
  (select child_id from public.relaciones_familia where parent_id = 'padre00-0000-0000-0000-000000000000'::uuid limit 1),
  'hijo00-0000-0000-0000-000000000001'::uuid,
  'relación familia enlaza correctamente'
);

-- ============================================================
-- Test 15-18: RLS — padre puede editar datos del hijo
-- ============================================================

select set_config('request.jwt.claims', json_build_object(
  'sub', 'padre00-0000-0000-0000-000000000000',
  'role', 'authenticated'
)::text, true);

update public.profiles
set nombre = 'Hijo Editado'
where id = 'hijo00-0000-0000-0000-000000000001'::uuid;

select is(
  (select nombre from public.profiles where id = 'hijo00-0000-0000-0000-000000000001'::uuid),
  'Hijo Editado',
  'padre puede editar nombre del hijo'
);

update public.profiles
set cinturon = 'azul'
where id = 'hijo00-0000-0000-0000-000000000001'::uuid;

select is(
  (select cinturon from public.profiles where id = 'hijo00-0000-0000-0000-000000000001'::uuid),
  'azul',
  'padre puede editar cinturón del hijo'
);

-- ============================================================
-- Test 19-21: RLS — otro padre NO puede editar hijo ajeno
-- ============================================================

-- Crear otro padre
insert into auth.users (id, email, encrypted_password, email_confirmed_at, aud, role)
values (
  'otro00-0000-0000-0000-000000000002'::uuid,
  'otro@test.local',
  crypt('password', gen_salt('bf')),
  now(),
  'authenticated',
  'authenticated'
);

insert into public.profiles (id, academia_id, rol, nombre, estado)
values (
  'otro00-0000-0000-0000-000000000002'::uuid,
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'alumno',
  'Otro Padre',
  'activo'
);

-- Cambiar a sesión del otro padre
select set_config('request.jwt.claims', json_build_object(
  'sub', 'otro00-0000-0000-0000-000000000002',
  'role', 'authenticated'
)::text, true);

select throws_ok(
  $$
    update public.profiles
    set nombre = 'Ataataca'
    where id = 'hijo00-0000-0000-0000-000000000001'::uuid;
  $$,
  'new row violates row-level security policy',
  'otro padre NO puede editar hijo ajeno'
);

-- ============================================================
-- Test 22-24: Función crear_perfil_hijo (sin auth.users)
-- ============================================================

-- Llamar la función como service_role (lo hace la Edge Function)
select lives_ok(
  $$
    select public.crear_perfil_hijo(
      'padre00-0000-0000-0000-000000000000'::uuid,
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
      'Hijo Nuevo',
      'Apellido Nuevo',
      'blanco'
    );
  $$,
  'crear_perfil_hijo ejecuta sin error'
);

select is(
  (select count(*) from public.relaciones_familia where parent_id = 'padre00-0000-0000-0000-000000000000'::uuid),
  2::bigint,
  'padre tiene 2 hijos después de crear_perfil_hijo'
);

select is(
  (select count(*) from public.profiles where nombre = 'Hijo Nuevo'),
  1::bigint,
  'se creó el perfil del hijo nuevo'
);

-- ============================================================
-- Test 25-27: crear_perfil_hijo establece relación automáticamente
-- ============================================================

select is(
  (select tipo_relacion from public.relaciones_familia where child_id = (select id from public.profiles where nombre = 'Hijo Nuevo')),
  'padre',
  'relación familia tiene tipo_relacion correcto'
);

select is(
  (select cinturon from public.profiles where nombre = 'Hijo Nuevo'),
  'blanco',
  'hijo nuevo tiene cinturón correcto'
);

select is(
  (select estado from public.profiles where nombre = 'Hijo Nuevo'),
  'activo',
  'hijo nuevo está activo'
);

-- Reset role
select reset_role();
select set_config('request.jwt.claims', '{}', true);

select finish();
rollback;
