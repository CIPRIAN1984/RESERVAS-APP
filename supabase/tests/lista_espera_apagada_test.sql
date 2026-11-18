-- La lista de espera no se puede encender desde la sesión de un usuario
-- (17/11/2026). Ver 20261117110000_lista_espera_apagada.sql.

begin;
select plan(4);

insert into public.academias (id, nombre, estado, lista_espera_activa) values
  ('00000000-0000-0000-0000-0000000c00aa', 'Academia LE', 'approved', false);
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000c0001', 'dueno-le@test.dev');
insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000c0001', '00000000-0000-0000-0000-0000000c00aa', 'dueño', 'Dueño', 'activo');

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-0000000c0001","role":"authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$ update public.academias set lista_espera_activa = true
      where id = '00000000-0000-0000-0000-0000000c00aa' $$,
  'La lista de espera no está disponible en esta versión: todavía no hay avisos verificados.',
  'El Dueño no puede encender la lista de espera'
);

select lives_ok(
  $$ update public.academias set cancelacion_limite_minutos = 90
      where id = '00000000-0000-0000-0000-0000000c00aa' $$,
  'Los demás ajustes de reservas se siguen pudiendo cambiar'
);

select lives_ok(
  $$ update public.academias set lista_espera_activa = false
      where id = '00000000-0000-0000-0000-0000000c00aa' $$,
  'Dejarla apagada no da error'
);
reset role;

select is(
  (select lista_espera_activa from public.academias where id = '00000000-0000-0000-0000-0000000c00aa'),
  false,
  'Sigue apagada'
);

select * from finish();
rollback;
