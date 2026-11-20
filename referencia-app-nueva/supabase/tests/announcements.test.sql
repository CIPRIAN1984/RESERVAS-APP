-- Novedades: quién publica, quién edita y borra, quién lee; orden con fijados.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into public.gyms (id, name) values ('ab000000-0000-4000-a000-000000000001', 'Sede N'), ('ab000000-0000-4000-a000-000000000002', 'Sede Otra');
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, jsonb_build_object('full_name', name), now(), now()
from (values
  ('ab900000-0000-4000-a000-000000000001'::uuid, 'n-admin@n.test', 'Ana Admin'),
  ('ab900000-0000-4000-a000-000000000002'::uuid, 'n-coach@n.test', 'Carlos Coach'),
  ('ab900000-0000-4000-a000-000000000003'::uuid, 'n-coach2@n.test', 'Clara Coach'),
  ('ab900000-0000-4000-a000-000000000004'::uuid, 'n-alumno@n.test', 'Alumno N'),
  ('ab900000-0000-4000-a000-000000000005'::uuid, 'n-fuera@n.test', 'De Fuera')
) as u (id, email, name);
create temp table pid as select u.email, p.id from auth.users u join public.profiles p on p.user_id = u.id where u.email like 'n-%';
grant select on pid to authenticated;
insert into public.gym_members (gym_id, profile_id, role)
select case when email = 'n-fuera@n.test' then 'ab000000-0000-4000-a000-000000000002'::uuid else 'ab000000-0000-4000-a000-000000000001'::uuid end, id,
  case email when 'n-admin@n.test' then 'admin' when 'n-coach@n.test' then 'coach' when 'n-coach2@n.test' then 'coach' else 'member' end::public.gym_role
from pid;

create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- Publicar
select pg_temp.login('n-alumno@n.test');
select throws_ok($$ insert into public.announcements (gym_id, title, author_profile_id) values ('ab000000-0000-4000-a000-000000000001', 'Hola', public.current_profile_id()) $$,
  '42501', null, 'un alumno no publica');
select pg_temp.login('n-coach@n.test');
select lives_ok($$ insert into public.announcements (gym_id, title, body, author_profile_id, published_at) values ('ab000000-0000-4000-a000-000000000001', 'Seminario el sábado', 'A las 11', public.current_profile_id(), now() - interval '1 hour') $$,
  'un profesor publica');
select throws_ok($$ insert into public.announcements (gym_id, title, author_profile_id) values ('ab000000-0000-4000-a000-000000000001', 'Suplantado', (select id from pid where email = 'n-admin@n.test')) $$,
  '42501', null, 'no se publica en nombre de otro');
select pg_temp.login('n-admin@n.test');
select lives_ok($$ insert into public.announcements (gym_id, title, pinned, author_profile_id, published_at) values ('ab000000-0000-4000-a000-000000000001', 'Normas del tatami', true, public.current_profile_id(), now() - interval '5 days') $$,
  'administración publica un aviso fijado');
select lives_ok($$ insert into public.announcements (gym_id, title, author_profile_id) values ('ab000000-0000-4000-a000-000000000001', 'Cerrado el lunes', public.current_profile_id()) $$,
  'y otro normal');

-- Leer y orden
select pg_temp.login('n-alumno@n.test');
select is((select string_agg(title, ' | ' order by ord) from (select title, row_number() over () as ord from public.gym_announcements('ab000000-0000-4000-a000-000000000001')) x),
  'Normas del tatami | Cerrado el lunes | Seminario el sábado', 'el alumno ve los avisos: fijados primero y luego los más recientes');
select is((select author_name from public.gym_announcements('ab000000-0000-4000-a000-000000000001') where title = 'Seminario el sábado'), 'Carlos', 'con el nombre del autor');
select is((select bool_or(can_edit) from public.gym_announcements('ab000000-0000-4000-a000-000000000001')), false, 'el alumno no puede editar ninguno');
select pg_temp.login('n-fuera@n.test');
select is((select count(*)::int from public.gym_announcements('ab000000-0000-4000-a000-000000000001')), 0, 'otra sede no los ve');

-- Editar y borrar
select pg_temp.login('n-coach2@n.test');
update public.announcements set title = 'Cambiado' where title = 'Seminario el sábado';
reset role;
select is((select count(*)::int from public.announcements where title = 'Seminario el sábado'), 1, 'otro profesor no edita un aviso ajeno');
select pg_temp.login('n-coach@n.test');
update public.announcements set title = 'Seminario el sábado a las 11' where title = 'Seminario el sábado';
reset role;
select is((select count(*)::int from public.announcements where title = 'Seminario el sábado a las 11'), 1, 'el autor edita el suyo');
select pg_temp.login('n-admin@n.test');
delete from public.announcements where title like 'Seminario%';
reset role;
select is((select count(*)::int from public.announcements where title like 'Seminario%' and gym_id = 'ab000000-0000-4000-a000-000000000001'), 0, 'administración borra cualquiera');

select * from finish();
rollback;
