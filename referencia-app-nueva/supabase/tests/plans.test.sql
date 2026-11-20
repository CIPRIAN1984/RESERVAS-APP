-- Catálogo de tarifas: lo ven los miembros, lo editan propietario y administración.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into public.gyms (id, name) values ('d5000000-0000-4000-a000-000000000001', 'Sede T'), ('d5000000-0000-4000-a000-000000000002', 'Sede U');
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, '{}', now(), now()
from (values
  ('d5900000-0000-4000-a000-000000000001'::uuid, 't-alumno@t.test'),
  ('d5900000-0000-4000-a000-000000000002'::uuid, 't-admin@t.test'),
  ('d5900000-0000-4000-a000-000000000003'::uuid, 't-otro@u.test')
) u (id, email);
insert into public.gym_members (gym_id, profile_id, role)
select g, p.id, r::public.gym_role from (values
  ('d5000000-0000-4000-a000-000000000001'::uuid, 'd5900000-0000-4000-a000-000000000001'::uuid, 'member'),
  ('d5000000-0000-4000-a000-000000000001'::uuid, 'd5900000-0000-4000-a000-000000000002'::uuid, 'admin'),
  ('d5000000-0000-4000-a000-000000000002'::uuid, 'd5900000-0000-4000-a000-000000000003'::uuid, 'member')
) x (g, u, r) join public.profiles p on p.user_id = x.u;
insert into public.plans (gym_id, slug, name, kind, price_cents, billing_period, sessions)
values ('d5000000-0000-4000-a000-000000000001', 'blue', 'Blue', 'membership', 6000, 'month', 12);

create function pg_temp.login(p_user uuid) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

select pg_temp.login('d5900000-0000-4000-a000-000000000001');
select is((select count(*)::int from public.plans), 1, 'alumno: ve las tarifas de su sede');
update public.plans set price_cents = 1;
select throws_ok($$ insert into public.plans (gym_id, slug, name, kind, price_cents, billing_period) values ('d5000000-0000-4000-a000-000000000001', 'x', 'X', 'drop_in', 0, 'once') $$,
  '42501', null, 'alumno: no crea tarifas');

select pg_temp.login('d5900000-0000-4000-a000-000000000003');
select is((select count(*)::int from public.plans), 0, 'alumno de otra sede: no ve estas tarifas');

select pg_temp.login('d5900000-0000-4000-a000-000000000002');
select is((select price_cents from public.plans where slug = 'blue'), 6000, 'el intento del alumno no cambió el precio');
update public.plans set price_cents = 6500 where slug = 'blue';
select is((select price_cents from public.plans where slug = 'blue'), 6500, 'administración: cambia el precio');

reset role;
set local role anon;
select throws_ok('select count(*) from public.plans', '42501', null, 'anónimo: no ve tarifas');

select * from finish();
rollback;
