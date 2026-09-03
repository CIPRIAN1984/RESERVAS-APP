-- Pruebas pgTAP para familias_tutores
-- Validaciones: tabla, columnas, restricciones, RLS

begin;

select plan(27);

-- ============================================================
-- Validar tabla relaciones_familia
-- ============================================================

select has_table('public'::name, 'relaciones_familia'::name,
  'Tabla relaciones_familia existe');

select has_column('public'::name, 'relaciones_familia'::name, 'id'::name,
  'Columna id existe');

select has_column('public'::name, 'relaciones_familia'::name, 'parent_id'::name,
  'Columna parent_id existe');

select has_column('public'::name, 'relaciones_familia'::name, 'child_id'::name,
  'Columna child_id existe');

select has_column('public'::name, 'relaciones_familia'::name, 'tipo_relacion'::name,
  'Columna tipo_relacion existe');

select has_column('public'::name, 'relaciones_familia'::name, 'created_at'::name,
  'Columna created_at existe');

-- ============================================================
-- Validar índices
-- ============================================================

select has_index('public'::name, 'relaciones_familia'::name, 'relaciones_familia_parent_id_idx'::name,
  'Índice parent_id existe');

select has_index('public'::name, 'relaciones_familia'::name, 'relaciones_familia_child_id_idx'::name,
  'Índice child_id existe');

-- ============================================================
-- Validar restricciones
-- ============================================================

-- constraint_name_is() no existe en pgTAP (nunca existió: esta comprobación
-- llevaba desde que se escribió el fichero abortando el script entero con un
-- error de función desconocida, sin que ningún test posterior llegara a
-- correr). Se sustituye por una comprobación directa contra pg_constraint,
-- igual que las políticas RLS más abajo se comprueban contra pg_policies.
select ok(
  (select count(*) > 0 from pg_constraint
   where conrelid = 'public.relaciones_familia'::regclass
   and conname = 'relaciones_familia_child_id_key'),
  'Constraint unique(child_id) existe');

select ok(
  (select count(*) > 0 from pg_constraint
   where conrelid = 'public.relaciones_familia'::regclass
   and conname = 'no_ciclos_familia'),
  'Constraint no_ciclos_familia existe');

-- ============================================================
-- Validar RLS
-- ============================================================

select ok(
  (select count(*) > 0 from pg_policies
   where tablename = 'relaciones_familia'
   and policyname = 'relaciones_familia_select'),
  'Policy relaciones_familia_select existe');

-- Las políticas de INSERT/UPDATE/DELETE se retiraron el 03/09/2026: la de
-- inserción solo comprobaba `parent_id = auth.uid()` y no miraba de quién
-- se decía uno padre, así que cualquier alumno podía adueñarse del perfil
-- de otro. Ver `agujero_relaciones_familia_test.sql` y la migración
-- 20260903120000. Ahora la tabla es de solo lectura para los clientes.
select ok(
  (select count(*) = 0 from pg_policies
   where tablename = 'relaciones_familia'
   and policyname in ('relaciones_familia_insert',
                      'relaciones_familia_update',
                      'relaciones_familia_delete')),
  'Los clientes ya no tienen políticas de escritura en relaciones_familia');

-- ============================================================
-- Validar function crear_perfil_hijo
-- ============================================================

select has_function('public'::name, 'crear_perfil_hijo'::name,
  array['uuid', 'uuid', 'text', 'text', 'text'],
  'Función crear_perfil_hijo existe con signatures correctas');

-- La función es SECURITY DEFINER y no comprueba quién llama: solo la puerta
-- es segura si nadie externo puede invocarla directamente. La Edge Function
-- usa service_role, que no pasa por estos grants.
select ok(
  not has_function_privilege(
    'anon',
    'public.crear_perfil_hijo(uuid, uuid, text, text, text)',
    'EXECUTE'
  ),
  'Anon no puede crear perfiles de hijo directamente'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.crear_perfil_hijo(uuid, uuid, text, text, text)',
    'EXECUTE'
  ),
  'Authenticated tampoco: debe pasar por la Edge Function'
);

-- ============================================================
-- Regresión: la RLS de profiles y relaciones_familia no debe entrar en
-- recursión entre sí (ver migración 20260812112854_arreglar_recursion_rls_familias).
-- Antes de esa migración, profiles_select/profiles_update y
-- relaciones_familia_select se consultaban directamente entre sí dentro
-- de `using`, y Postgres devolvía "infinite recursion detected in policy
-- for relation profiles" al leer un padre con hijos.
-- ============================================================

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000fa01', 'padre_familia@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-00000000faaa', 'Academia Familia', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-00000000faaa', 'alumno', 'Padre Familia', 'activo');

-- profiles.id exige una fila en auth.users (profiles_id_fkey). Un menor no
-- inicia sesión nunca, pero para esta prueba de RLS se necesita la fila
-- igualmente: sin ella, este insert ya falla antes de llegar a la RLS.
-- (Ver aparte: crear_perfil_hijo() no crea esta fila, así que hoy no puede
-- crear un hijo real — es un fallo distinto al que arregla esta migración.)
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000fa02', 'hijo_familia@test.dev');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-00000000fa02', '00000000-0000-0000-0000-00000000faaa', 'alumno', 'Hijo Familia', 'activo');

insert into public.relaciones_familia (parent_id, child_id, tipo_relacion) values
  ('00000000-0000-0000-0000-00000000fa01', '00000000-0000-0000-0000-00000000fa02', 'padre');

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

select pg_temp.actuar_como('00000000-0000-0000-0000-00000000fa01');

select lives_ok(
  $$ select * from public.profiles where id = '00000000-0000-0000-0000-00000000fa01' $$,
  'Un padre puede leer su propio perfil sin que la RLS entre en recursión'
);

select lives_ok(
  $$ select * from public.profiles where id = '00000000-0000-0000-0000-00000000fa02' $$,
  'Un padre puede leer el perfil de su hijo sin recursión de RLS'
);

select is(
  (select count(*)::int from public.profiles),
  2,
  'El padre ve exactamente a sí mismo y a su hijo'
);

select lives_ok(
  $$ select * from public.relaciones_familia where parent_id = '00000000-0000-0000-0000-00000000fa01' $$,
  'Un padre puede leer sus relaciones de familia sin recursión de RLS'
);

-- ============================================================
-- Regresión: permisos que faltaban en relaciones_familia y en las
-- funciones auxiliares nuevas (ver 20260812112854_arreglar_recursion_rls_familias).
-- ============================================================

-- Sin el GRANT de tabla, el select de arriba fallaría con "permission
-- denied for table relaciones_familia" aunque la política RLS sea correcta.
select ok(
  has_table_privilege('authenticated', 'public.relaciones_familia', 'SELECT'),
  'authenticated tiene SELECT en relaciones_familia'
);

select ok(
  not has_function_privilege('anon', 'public.mi_padre_id()', 'EXECUTE'),
  'Anon no puede ejecutar mi_padre_id'
);

select ok(
  not has_function_privilege('anon', 'public.es_padre_de(uuid)', 'EXECUTE'),
  'Anon no puede ejecutar es_padre_de'
);

select ok(
  not has_function_privilege('anon', 'public.academia_id_de(uuid)', 'EXECUTE'),
  'Anon no puede ejecutar academia_id_de'
);

-- ============================================================
-- Regresión: academia_id_de() ya no devuelve la academia de cualquier
-- perfil sin comprobar nada (ver 20260813133000_endurecer_academia_id_de).
-- Antes, cualquier autenticado podía llamar
-- /rest/v1/rpc/academia_id_de con el id de cualquier otro perfil, de
-- cualquier academia, y le devolvía su academia sin ninguna comprobación.
-- ============================================================

reset role;

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-00000000fbbb', 'Academia Ajena', 'approved');

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000fa03', 'ajeno_familia@test.dev'),
  ('00000000-0000-0000-0000-00000000fa04', 'companero_familia@test.dev');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-00000000fa03', '00000000-0000-0000-0000-00000000fbbb', 'alumno', 'Ajeno', 'activo'),
  ('00000000-0000-0000-0000-00000000fa04', '00000000-0000-0000-0000-00000000faaa', 'alumno', 'Compañero', 'activo');

select pg_temp.actuar_como('00000000-0000-0000-0000-00000000fa01');

select is(
  public.academia_id_de('00000000-0000-0000-0000-00000000fa01'),
  '00000000-0000-0000-0000-00000000faaa'::uuid,
  'academia_id_de de uno mismo sigue funcionando'
);

select is(
  public.academia_id_de('00000000-0000-0000-0000-00000000fa02'),
  '00000000-0000-0000-0000-00000000faaa'::uuid,
  'academia_id_de del propio hijo sigue funcionando'
);

select is(
  public.academia_id_de('00000000-0000-0000-0000-00000000fa04'),
  '00000000-0000-0000-0000-00000000faaa'::uuid,
  'academia_id_de de un compañero de la misma academia sigue funcionando'
);

select is(
  public.academia_id_de('00000000-0000-0000-0000-00000000fa03'),
  null,
  'academia_id_de de alguien ajeno, de otra academia y sin relación, ya no se filtra'
);

select finish();

rollback;
