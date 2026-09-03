-- Regresión del agujero de relaciones_familia (03/09/2026).
--
-- Un alumno con sesión iniciada podía declararse "padre" de cualquier otro
-- perfil (la política de INSERT solo miraba `parent_id`, nunca `child_id`)
-- y, encadenando con la política de UPDATE de `profiles`, cambiarle a esa
-- persona el nombre, los apellidos y la foto.
--
-- Esta suite comprueba lo que impide que vuelva a pasar: que ningún cliente
-- puede escribir en relaciones_familia, y que la lectura sí sigue viva
-- (cuando se retome familias, el padre tiene que poder ver a sus hijos).

begin;
select plan(9);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'padre-falso@test.dev'),
  ('00000000-0000-0000-0000-0000000000a2', 'victima@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000000af', 'Academia Familia', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, apellidos, estado) values
  ('00000000-0000-0000-0000-0000000000a1',
   '00000000-0000-0000-0000-0000000000af', 'alumno', 'Atacante', 'Uno', 'activo'),
  ('00000000-0000-0000-0000-0000000000a2',
   '00000000-0000-0000-0000-0000000000af', 'alumno', 'Victima', 'Dos', 'activo');

-- ============================================================
-- Permisos de tabla: los clientes no escriben en relaciones_familia
-- ============================================================

select ok(
  not has_table_privilege('authenticated', 'public.relaciones_familia', 'INSERT'),
  'authenticated no puede insertar en relaciones_familia'
);

select ok(
  not has_table_privilege('authenticated', 'public.relaciones_familia', 'UPDATE'),
  'authenticated no puede modificar relaciones_familia'
);

select ok(
  not has_table_privilege('authenticated', 'public.relaciones_familia', 'DELETE'),
  'authenticated no puede borrar de relaciones_familia'
);

select ok(
  has_table_privilege('authenticated', 'public.relaciones_familia', 'SELECT'),
  'authenticated sí puede leer relaciones_familia (un padre ve a sus hijos)'
);

select ok(
  not has_table_privilege('anon', 'public.relaciones_familia', 'SELECT'),
  'anon no tiene ningún acceso a relaciones_familia'
);

-- ============================================================
-- Permisos de tabla: anon no escribe en profiles
-- ============================================================

select ok(
  not has_table_privilege('anon', 'public.profiles', 'UPDATE'),
  'anon no puede modificar profiles'
);

select ok(
  not has_table_privilege('anon', 'public.profiles', 'INSERT'),
  'anon no puede insertar en profiles'
);

select ok(
  not has_table_privilege('anon', 'public.profiles', 'DELETE'),
  'anon no puede borrar de profiles'
);

-- ============================================================
-- El ataque completo, tal cual se reprodujo contra producción
-- ============================================================

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}',
  true
);

select throws_ok(
  $$insert into public.relaciones_familia (parent_id, child_id, tipo_relacion)
    values ('00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000a2', 'padre')$$,
  '42501',
  null,
  'Un alumno no puede declararse padre de otro perfil'
);

reset role;
select * from finish();
rollback;
