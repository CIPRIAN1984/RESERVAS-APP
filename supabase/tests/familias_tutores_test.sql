-- Pruebas pgTAP para familias_tutores
-- Validaciones: tabla, columnas, restricciones, RLS

begin;

select plan(15);

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

select constraint_name_is(
  'public'::name, 'relaciones_familia'::name, 'relaciones_familia_child_id_key'::name,
  'Constraint unique(child_id) existe');

select constraint_name_is(
  'public'::name, 'relaciones_familia'::name, 'no_ciclos_familia'::name,
  'Constraint no_ciclos_familia existe');

-- ============================================================
-- Validar RLS
-- ============================================================

select ok(
  (select count(*) > 0 from pg_policies
   where tablename = 'relaciones_familia'
   and policyname = 'relaciones_familia_select'),
  'Policy relaciones_familia_select existe');

select ok(
  (select count(*) > 0 from pg_policies
   where tablename = 'relaciones_familia'
   and policyname = 'relaciones_familia_insert'),
  'Policy relaciones_familia_insert existe');

select ok(
  (select count(*) > 0 from pg_policies
   where tablename = 'relaciones_familia'
   and policyname = 'relaciones_familia_update'),
  'Policy relaciones_familia_update existe');

select ok(
  (select count(*) > 0 from pg_policies
   where tablename = 'relaciones_familia'
   and policyname = 'relaciones_familia_delete'),
  'Policy relaciones_familia_delete existe');

-- ============================================================
-- Validar function crear_perfil_hijo
-- ============================================================

select has_function('public'::name, 'crear_perfil_hijo'::name,
  array['uuid', 'uuid', 'text', 'text', 'text'],
  'Función crear_perfil_hijo existe con signatures correctas');

select finish();

rollback;
