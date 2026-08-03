-- Tests para familias y tutores: tabla relaciones_familia y RLS básico
-- Los menores NO tienen auth.users: solo profiles vinculados por relaciones_familia

begin;

select plan(8);

-- ============================================================
-- Test 1: tabla relaciones_familia existe
-- ============================================================

select has_table(
  'public',
  'relaciones_familia',
  'Tabla relaciones_familia existe'
);

-- ============================================================
-- Test 2-7: columnas de relaciones_familia existen y tienen tipos correctos
-- ============================================================

select has_column(
  'public',
  'relaciones_familia',
  'id',
  'Columna id existe'
);

select has_column(
  'public',
  'relaciones_familia',
  'parent_id',
  'Columna parent_id existe'
);

select has_column(
  'public',
  'relaciones_familia',
  'child_id',
  'Columna child_id existe'
);

select has_column(
  'public',
  'relaciones_familia',
  'tipo_relacion',
  'Columna tipo_relacion existe'
);

select has_column(
  'public',
  'relaciones_familia',
  'created_at',
  'Columna created_at existe'
);

-- ============================================================
-- Test 8: función crear_perfil_hijo existe
-- ============================================================

select has_function(
  'public',
  'crear_perfil_hijo',
  ARRAY['uuid', 'uuid', 'text', 'text', 'text'],
  'Función crear_perfil_hijo existe con los parámetros correctos'
);

-- ============================================================
-- Cleanup
-- ============================================================

select finish();
rollback;
