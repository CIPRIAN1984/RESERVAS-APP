-- Perfil editable y cinturones.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

insert into public.gyms (id, name) values ('c7000000-0000-4000-a000-000000000001', 'Sede R'), ('c7000000-0000-4000-a000-000000000002', 'Sede S');
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, jsonb_build_object('full_name', n), now(), now()
from (values
  ('c7900000-0000-4000-a000-000000000001'::uuid, 'pr-ana@r.test', 'Ana'),
  ('c7900000-0000-4000-a000-000000000002'::uuid, 'pr-luis@r.test', 'Luis'),
  ('c7900000-0000-4000-a000-000000000003'::uuid, 'pr-coach@r.test', 'Coach'),
  ('c7900000-0000-4000-a000-000000000004'::uuid, 'pr-desk@r.test', 'Recepción'),
  ('c7900000-0000-4000-a000-000000000005'::uuid, 'pr-otro@s.test', 'Otro')
) u (id, email, n);
create temp table pid as select u.email, p.id from auth.users u join public.profiles p on p.user_id = u.id where u.email like 'pr-%';
grant select on pid to authenticated;
insert into public.gym_members (gym_id, profile_id, role)
select g, (select id from pid where email = e), r::public.gym_role from (values
  ('c7000000-0000-4000-a000-000000000001'::uuid, 'pr-ana@r.test', 'member'),
  ('c7000000-0000-4000-a000-000000000001'::uuid, 'pr-luis@r.test', 'member'),
  ('c7000000-0000-4000-a000-000000000001'::uuid, 'pr-coach@r.test', 'coach'),
  ('c7000000-0000-4000-a000-000000000001'::uuid, 'pr-desk@r.test', 'front_desk'),
  ('c7000000-0000-4000-a000-000000000002'::uuid, 'pr-otro@s.test', 'coach')
) x (g, e, r);

create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- ================= Editar el perfil =================
select pg_temp.login('pr-ana@r.test');
update public.profiles set full_name = 'Ana Ruiz', phone = '600111222', birth_date = '1995-04-02',
  emergency_contact_name = 'Pedro', emergency_contact_phone = '600333444' where user_id = auth.uid();
select is((select full_name || ' ' || phone from public.profiles where user_id = auth.uid()), 'Ana Ruiz 600111222', 'alumna: cambia su nombre y su teléfono');
select throws_ok($$ update public.profiles set full_name = '   ' where user_id = auth.uid() $$, '23514', null, 'el nombre no puede quedar vacío');
select throws_ok($$ update public.profiles set full_name = repeat('a', 81) where user_id = auth.uid() $$, '23514', null, 'el nombre tiene un máximo de 80 caracteres');
update public.profiles set full_name = 'Hackeado' where id = (select id from pid where email = 'pr-luis@r.test');
reset role;
select is((select full_name from public.profiles where id = (select id from pid where email = 'pr-luis@r.test')), 'Luis', 'alumna: no cambia el nombre de otro');

-- ================= Declarar el propio cinturón =================
select pg_temp.login('pr-ana@r.test');
select lives_ok($$ select public.set_my_rank('c7000000-0000-4000-a000-000000000001', 'azul', 2::smallint, '2025-03-01') $$, 'alumna: indica su cinturón la primera vez');
select is((select belt::text || ' ' || stripes from public.current_rank(public.current_profile_id(), 'c7000000-0000-4000-a000-000000000001')), 'azul 2', 'su cinturón actual es azul con 2 grados');
select lives_ok($$ select public.set_my_rank('c7000000-0000-4000-a000-000000000001', 'azul', 3::smallint) $$, 'puede corregirlo mientras ningún profesor lo haya registrado');
select throws_ok($$ select public.set_my_rank('c7000000-0000-4000-a000-000000000001', 'negro', 0::smallint, current_date + 1) $$, '22023', null, 'la fecha no puede ser futura');
select throws_ok($$ select public.set_my_rank('c7000000-0000-4000-a000-000000000001', 'azul', 9::smallint) $$, '22023', null, 'grados entre 0 y 6');
select throws_ok($$ select public.set_my_rank('c7000000-0000-4000-a000-000000000001', 'negro', 0::smallint, null, (select id from pid where email = 'pr-luis@r.test')) $$,
  '42501', null, 'alumna: no indica el cinturón de otro');
select throws_ok($$ select public.promote('c7000000-0000-4000-a000-000000000001', public.current_profile_id(), 'negro', 0::smallint) $$,
  '42501', null, 'alumna: no puede graduarse a sí misma');

-- ================= El profesor gradúa =================
select pg_temp.login('pr-coach@r.test');
select isnt(public.promote('c7000000-0000-4000-a000-000000000001', (select id from pid where email = 'pr-ana@r.test'), 'morado', 0::smallint, null, 'Gran progresión'), null,
  'profesor: gradúa a Ana a morado');
select is((select belt::text from public.current_rank((select id from pid where email = 'pr-ana@r.test'), 'c7000000-0000-4000-a000-000000000001')), 'morado', 'Ana es morado');
select is((select count(*)::int from public.gym_roster('c7000000-0000-4000-a000-000000000001')), 4, 'profesor: ve la lista de miembros con su cinturón');
select is((select belt::text from public.gym_roster('c7000000-0000-4000-a000-000000000001') where full_name = 'Ana Ruiz'), 'morado', 'la lista muestra el cinturón actual');

select pg_temp.login('pr-ana@r.test');
select throws_ok($$ select public.set_my_rank('c7000000-0000-4000-a000-000000000001', 'negro', 0::smallint) $$,
  'P0001', 'Tu cinturón ya lo ha registrado tu profesor: pídele a él el cambio', 'tras la graduación del profesor, la alumna ya no puede cambiarlo');
select is((select count(*)::int from public.gym_roster('c7000000-0000-4000-a000-000000000001')), 0, 'alumna: no ve la lista de miembros');
select is((select count(*)::int from public.promotions), 3, 'alumna: ve su historial de cinturones');

select pg_temp.login('pr-desk@r.test');
select throws_ok($$ select public.promote('c7000000-0000-4000-a000-000000000001', (select id from pid where email = 'pr-luis@r.test'), 'azul', 0::smallint) $$,
  '42501', null, 'recepción: no gradúa');

select pg_temp.login('pr-otro@s.test');
select throws_ok($$ select public.promote('c7000000-0000-4000-a000-000000000001', (select id from pid where email = 'pr-luis@r.test'), 'azul', 0::smallint) $$,
  '42501', null, 'profesor de otra sede: no gradúa aquí');

select * from finish();
rollback;
