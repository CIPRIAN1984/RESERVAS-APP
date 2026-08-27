-- Cinturones de niños (ver 20260820202054_cinturones_ninos.sql): trece
-- colores IBJJF nuevos, más los cinco de adulto que ya había. No toca
-- permisos ni RLS —solo amplía un CHECK—, pero merece regresión: que los
-- trece se acepten y que un valor inventado siga rechazándose.
begin;
select plan(15);

insert into public.academias (id, nombre, estado)
values ('00000000-0000-0000-0000-0000000cb0aa', 'Academia cinturones', 'approved');

insert into auth.users (id, email)
select
  ('00000000-0000-0000-0000-0000000cb' || lpad(n::text, 3, '0'))::uuid,
  'ninos-' || n || '@test.dev'
from generate_series(1, 14) as n;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000cb999', 'adulto-cinturon@test.dev'),
  ('00000000-0000-0000-0000-0000000cb998', 'inventado-cinturon@test.dev');

-- 1-13. Cada cinturón de niño se acepta.
do $$
declare
  v_colores text[] := array[
    'gris_blanco', 'gris', 'gris_negro',
    'amarillo_blanco', 'amarillo', 'amarillo_negro',
    'naranja_blanco', 'naranja', 'naranja_negro',
    'verde_blanco', 'verde', 'verde_negro',
    'blanco'
  ];
  v_color text;
  v_i int := 1;
begin
  foreach v_color in array v_colores loop
    insert into public.profiles (id, academia_id, rol, nombre, estado, cinturon)
    values (
      ('00000000-0000-0000-0000-0000000cb' || lpad(v_i::text, 3, '0'))::uuid,
      '00000000-0000-0000-0000-0000000cb0aa',
      'alumno',
      'Niño ' || v_i,
      'activo',
      v_color
    );
    v_i := v_i + 1;
  end loop;
end $$;

select is(
  (select count(*)::int from public.profiles
    where academia_id = '00000000-0000-0000-0000-0000000cb0aa'),
  13,
  'Los trece cinturones de niño se aceptan'
);

-- Repetimos el resto de comprobaciones como pruebas individuales, para que
-- un fallo señale exactamente qué color se rompió.
select ok(
  exists (select 1 from public.profiles where cinturon = 'gris_blanco'),
  'gris_blanco se acepta'
);
select ok(
  exists (select 1 from public.profiles where cinturon = 'gris'),
  'gris se acepta'
);
select ok(
  exists (select 1 from public.profiles where cinturon = 'gris_negro'),
  'gris_negro se acepta'
);
select ok(
  exists (select 1 from public.profiles where cinturon = 'amarillo_blanco'),
  'amarillo_blanco se acepta'
);
select ok(
  exists (select 1 from public.profiles where cinturon = 'amarillo'),
  'amarillo se acepta'
);
select ok(
  exists (select 1 from public.profiles where cinturon = 'amarillo_negro'),
  'amarillo_negro se acepta'
);
select ok(
  exists (select 1 from public.profiles where cinturon = 'naranja_blanco'),
  'naranja_blanco se acepta'
);
select ok(
  exists (select 1 from public.profiles where cinturon = 'naranja'),
  'naranja se acepta'
);
select ok(
  exists (select 1 from public.profiles where cinturon = 'naranja_negro'),
  'naranja_negro se acepta'
);
select ok(
  exists (select 1 from public.profiles where cinturon = 'verde_blanco'),
  'verde_blanco se acepta'
);
select ok(
  exists (select 1 from public.profiles where cinturon = 'verde'),
  'verde se acepta'
);
select ok(
  exists (select 1 from public.profiles where cinturon = 'verde_negro'),
  'verde_negro se acepta'
);

-- 14. Los cinco de adulto se siguen aceptando (no se ha estrechado el
-- conjunto, solo ampliado).
select lives_ok(
  $$ insert into public.profiles (id, academia_id, rol, nombre, estado, cinturon)
     values ('00000000-0000-0000-0000-0000000cb999', '00000000-0000-0000-0000-0000000cb0aa',
             'alumno', 'Adulto', 'activo', 'morado') $$,
  'Un cinturón de adulto (morado) se sigue aceptando'
);

-- 15. Un color inventado se sigue rechazando.
select throws_ok(
  $$ insert into public.profiles (id, academia_id, rol, nombre, estado, cinturon)
     values ('00000000-0000-0000-0000-0000000cb998', '00000000-0000-0000-0000-0000000cb0aa',
             'alumno', 'Inventado', 'activo', 'rosa_fosforito') $$,
  null,
  'Un color que no existe en ningún sistema sigue rechazándose'
);

select * from finish();
rollback;
