-- ITACA+: complemento de 5 €/mes que necesita una tarifa de pago recurrente activa.
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into public.gyms (id, name) values ('ad000000-0000-4000-a000-000000000001', 'Sede V');
insert into public.plans (id, gym_id, slug, name, kind, price_cents, billing_period, sessions, sessions_per_month, auto_renew, validity_months, is_addon) values
  ('ad200000-0000-4000-a000-000000000001', 'ad000000-0000-4000-a000-000000000001', 'blue', 'Blue', 'membership', 6000, 'month', 12, true, true, null, false),
  ('ad200000-0000-4000-a000-000000000002', 'ad000000-0000-4000-a000-000000000001', 'bono', 'Bono', 'pack', 7000, 'quarter', 10, false, false, 3, false),
  ('ad200000-0000-4000-a000-000000000003', 'ad000000-0000-4000-a000-000000000001', 'itaca-plus', 'ITACA+', 'membership', 500, 'month', null, true, true, null, true);
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, jsonb_build_object('full_name', name), now(), now()
from (values
  ('ad900000-0000-4000-a000-000000000001'::uuid, 'v-desk@v.test', 'Recepción V'),
  ('ad900000-0000-4000-a000-000000000002'::uuid, 'v-ana@v.test', 'Ana V')
) as u (id, email, name);
create temp table pid as select u.email, p.id from auth.users u join public.profiles p on p.user_id = u.id where u.email like 'v-%';
grant select on pid to authenticated;
insert into public.gym_members (gym_id, profile_id, role)
select 'ad000000-0000-4000-a000-000000000001', id, case when email = 'v-desk@v.test' then 'front_desk' else 'member' end::public.gym_role from pid;

create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- Sin tarifa: no puede pedir ITACA+
select pg_temp.login('v-ana@v.test');
select throws_like($$ select public.request_plan('ad200000-0000-4000-a000-000000000003') $$, 'ITACA+ necesita una tarifa de pago mensual activa%', 'sin tarifa no se pide ITACA+');

-- Con un bono (no recurrente) tampoco
select pg_temp.login('v-desk@v.test');
select public.assign_plan((select id from pid where email = 'v-ana@v.test'), 'ad200000-0000-4000-a000-000000000002');
select throws_like($$ select public.assign_plan((select id from pid where email = 'v-ana@v.test'), 'ad200000-0000-4000-a000-000000000003') $$,
  'ITACA+ necesita una tarifa de pago mensual activa%', 'con un bono no se puede asignar ITACA+');

-- Con Blue (mensual de pago) sí
select public.assign_plan((select id from pid where email = 'v-ana@v.test'), 'ad200000-0000-4000-a000-000000000001');
select pg_temp.login('v-ana@v.test');
select lives_ok($$ select public.request_plan('ad200000-0000-4000-a000-000000000003') $$, 'con Blue pide ITACA+');
select lives_ok($$ select public.request_plan('ad200000-0000-4000-a000-000000000001') $$, 'y a la vez puede tener pedida otra tarifa principal');
select is(public.has_itaca_plus(), false, 'pedido, pero aún no activo');

select pg_temp.login('v-desk@v.test');
select lives_ok($$ select public.assign_plan((select id from pid where email = 'v-ana@v.test'), 'ad200000-0000-4000-a000-000000000003') $$, 'recepción asigna ITACA+');
select pg_temp.login('v-ana@v.test');
select is(public.has_itaca_plus(), true, 'ITACA+ activo');
select is(public.my_plan_status() ->> 'plan', 'Blue', 'su tarifa principal sigue siendo Blue (ITACA+ no la sustituye)');
reset role;
select is((select count(*)::int from public.plan_requests where profile_id = (select id from pid where email = 'v-ana@v.test') and status = 'pending'), 1,
  'al asignar ITACA+ solo se cierra su solicitud; la de la tarifa principal sigue pendiente');

-- Si la tarifa principal termina, ITACA+ deja de funcionar
select pg_temp.login('v-desk@v.test');
select public.end_plan((select mp.id from public.member_plans mp join public.plans pl on pl.id = mp.plan_id where pl.slug = 'blue' and mp.gym_id = 'ad000000-0000-4000-a000-000000000001'), current_date - 1);
select pg_temp.login('v-ana@v.test');
select is(public.has_itaca_plus(), false, 'sin tarifa principal, ITACA+ no funciona');

select * from finish();
rollback;
