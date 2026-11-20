-- Ranking de asistencia: orden, empates, ocultos, menores y permisos.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into public.gyms (id, name) values ('d0000000-0000-4000-d000-000000000001', 'Sede K'), ('d0000000-0000-4000-d000-000000000002', 'Sede Otra');
insert into public.disciplines (id, gym_id, slug, name, kind) values
  ('d1000000-0000-4000-d000-000000000001', 'd0000000-0000-4000-d000-000000000001', 'gi', 'Gi', 'gi');

insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, jsonb_build_object('full_name', name), now(), now()
from (values
  ('d9000000-0000-4000-d000-000000000001'::uuid, 'k-ana@k.test',   'Ana'),
  ('d9000000-0000-4000-d000-000000000002'::uuid, 'k-bea@k.test',   'Bea'),
  ('d9000000-0000-4000-d000-000000000003'::uuid, 'k-cris@k.test',  'Cris'),
  ('d9000000-0000-4000-d000-000000000004'::uuid, 'k-dani@k.test',  'Dani'),
  ('d9000000-0000-4000-d000-000000000005'::uuid, 'k-nuevo@k.test', 'Nuevo'),
  ('d9000000-0000-4000-d000-000000000006'::uuid, 'k-fuera@k.test', 'Fuera')
) as u (id, email, name);
create temp table pid as select u.email, p.id from auth.users u join public.profiles p on p.user_id = u.id where u.email like 'k-%';
grant select on pid to authenticated;

insert into public.gym_members (gym_id, profile_id, status)
select 'd0000000-0000-4000-d000-000000000001', id, case when email = 'k-nuevo@k.test' then 'inactive' else 'active' end::public.member_status
from pid where email <> 'k-fuera@k.test';
insert into public.gym_members (gym_id, profile_id) select 'd0000000-0000-4000-d000-000000000002', id from pid where email = 'k-fuera@k.test';
-- Una menor de 12 años en la sede
insert into public.profiles (id, full_name, birth_date) values ('d2000000-0000-4000-d000-000000000001', 'Menor Kids', current_date - interval '12 years');
insert into public.gym_members (gym_id, profile_id) values ('d0000000-0000-4000-d000-000000000001', 'd2000000-0000-4000-d000-000000000001');

update public.profiles set hide_from_ranking = true where id = (select id from pid where email = 'k-dani@k.test');
insert into public.promotions (gym_id, profile_id, belt, stripes, promoted_at) values
  ('d0000000-0000-4000-d000-000000000001', (select id from pid where email = 'k-ana@k.test'), 'blanco', 2, current_date - 400),
  ('d0000000-0000-4000-d000-000000000001', (select id from pid where email = 'k-ana@k.test'), 'azul', 0, current_date - 30);

-- Una sesión al día los últimos 6 días
insert into public.class_sessions (id, gym_id, discipline_id, name, starts_at, ends_at, capacity)
select gen_random_uuid(), 'd0000000-0000-4000-d000-000000000001', 'd1000000-0000-4000-d000-000000000001', 'Gi ' || i,
       now() - make_interval(days => i), now() - make_interval(days => i) + interval '1 hour', 50
from generate_series(1, 6) i;

-- Asistencias: Ana 4, Bea 2, Cris 2, Dani 5 (oculto), Menor 6; y una anulada de Bea
create function pg_temp.attend(p_profile uuid, p_n int, p_void boolean default false) returns void language sql as $$
  insert into public.attendances (gym_id, session_id, profile_id, method, client_id, checked_in_at, voided_at)
  select 'd0000000-0000-4000-d000-000000000001', s.id, p_profile, 'coach', gen_random_uuid(), s.starts_at, case when p_void then now() end
  from (select id, starts_at from public.class_sessions where gym_id = 'd0000000-0000-4000-d000-000000000001' order by starts_at desc limit p_n) s
$$;
select pg_temp.attend((select id from pid where email = 'k-ana@k.test'), 4);
select pg_temp.attend((select id from pid where email = 'k-bea@k.test'), 2);
select pg_temp.attend((select id from pid where email = 'k-cris@k.test'), 2);
select pg_temp.attend((select id from pid where email = 'k-dani@k.test'), 5);
select pg_temp.attend('d2000000-0000-4000-d000-000000000001', 6);
-- La anulada de Bea es en una sesión distinta a sus dos válidas
insert into public.attendances (gym_id, session_id, profile_id, method, client_id, checked_in_at, voided_at)
select 'd0000000-0000-4000-d000-000000000001', id, (select id from pid where email = 'k-bea@k.test'), 'coach', gen_random_uuid(), starts_at, now()
from public.class_sessions where gym_id = 'd0000000-0000-4000-d000-000000000001' order by starts_at limit 1;

create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

select pg_temp.login('k-bea@k.test');
create temp table r as select * from public.gym_ranking('d0000000-0000-4000-d000-000000000001', current_date - 30, current_date);
select is((select display_name from r where rank_position = 1), 'Ana', 'primera: Ana con 4');
select is((select classes from r where display_name = 'Ana'), 4, 'cuenta las asistencias');
select is((select count(*)::int from r where rank_position = 2), 2, 'empate: Bea y Cris comparten el 2.º puesto');
select is((select classes from r where display_name = 'Bea'), 2, 'las anuladas no cuentan');
select is((select count(*)::int from r where display_name = 'Dani'), 0, 'quien se oculta no aparece');
select is((select count(*)::int from r where display_name = 'Menor Kids'), 0, 'los menores no aparecen');
select is((select is_me from r where display_name = 'Bea'), true, 'marca mi fila');
select is((select belt::text from r where display_name = 'Ana'), 'azul', 'Bea ve el cinturón actual de Ana');
-- Con límite 1, mi fila sigue apareciendo
select is((select count(*)::int from public.gym_ranking('d0000000-0000-4000-d000-000000000001', current_date - 30, current_date, 1) where is_me), 1, 'mi fila aparece aunque esté fuera del top');

select pg_temp.login('k-nuevo@k.test');
select throws_ok($$ select * from public.gym_ranking('d0000000-0000-4000-d000-000000000001', current_date - 30, current_date) $$, '42501', null, 'cuenta pendiente: no ve el ranking');
select pg_temp.login('k-fuera@k.test');
select throws_ok($$ select * from public.gym_ranking('d0000000-0000-4000-d000-000000000001', current_date - 30, current_date) $$, '42501', null, 'otra sede: no lo ve');

-- El alumno puede ocultarse
select pg_temp.login('k-ana@k.test');
select lives_ok($$ update public.profiles set hide_from_ranking = true where user_id = (select auth.uid()) $$, 'el alumno se oculta del ranking');

select * from finish();
rollback;
