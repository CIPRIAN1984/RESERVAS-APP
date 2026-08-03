-- Tests para familias y tutores: verifica tabla relaciones_familia existe
-- Los menores NO tienen auth.users: solo profiles vinculados por relaciones_familia

begin;

select plan(6);

-- Test 1: tabla relaciones_familia existe
select has_table(
  'public',
  'relaciones_familia',
  'Tabla relaciones_familia existe'
);

-- Test 2-6: columnas principales existen
select has_column('public', 'relaciones_familia', 'id', 'Columna id');
select has_column('public', 'relaciones_familia', 'parent_id', 'Columna parent_id');
select has_column('public', 'relaciones_familia', 'child_id', 'Columna child_id');
select has_column('public', 'relaciones_familia', 'tipo_relacion', 'Columna tipo_relacion');
select has_column('public', 'relaciones_familia', 'created_at', 'Columna created_at');

select finish();
rollback;
