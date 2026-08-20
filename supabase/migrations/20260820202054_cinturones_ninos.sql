-- Cinturones de niños (sistema IBJJF), para el filtro de Miembros.
--
-- Antes solo existían los cinco de adulto. Un menor (`profiles.parent_id`
-- no nulo — ver familias_tutores) sigue la progresión infantil: blanco,
-- gris-blanca, gris, gris-negra, amarilla-blanca, amarilla, amarilla-negra,
-- naranja-blanca, naranja, naranja-negra, verde-blanca, verde, verde-negra
-- — trece en total, el blanco compartido con adultos porque es el mismo
-- color de salida.
alter table public.profiles drop constraint if exists profiles_cinturon_check;
alter table public.profiles add constraint profiles_cinturon_check
  check (cinturon in (
    'blanco', 'azul', 'morado', 'marron', 'negro',
    'gris_blanco', 'gris', 'gris_negro',
    'amarillo_blanco', 'amarillo', 'amarillo_negro',
    'naranja_blanco', 'naranja', 'naranja_negro',
    'verde_blanco', 'verde', 'verde_negro'
  ));
