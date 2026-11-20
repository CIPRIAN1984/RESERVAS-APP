-- Límite de clases por tarifa: semana, mes natural, bono, no presentados,
-- lista de espera, excepción de recepción y asignación de tarifas.
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

-- ---------- Datos ----------
insert into public.gyms (id, name) values ('c0000000-0000-4000-c000-000000000001', 'Sede L');
insert into public.disciplines (id, gym_id, slug, name, kind) values
  ('c1000000-0000-4000-c000-000000000001', 'c0000000-0000-4000-c000-000000000001', 'gi', 'Gi', 'gi');

insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, jsonb_build_object('full_name', name), now(), now()
from (values
  ('c9000000-0000-4000-c000-000000000001'::uuid, 'l-luis@l.test',  'Luis'),
  ('c9000000-0000-4000-c000-000000000002'::uuid, 'l-eva@l.test',   'Eva'),
  ('c9000000-0000-4000-c000-000000000003'::uuid, 'l-ana@l.test',   'Ana'),
  ('c9000000-0000-4000-c000-000000000004'::uuid, 'l-pablo@l.test', 'Pablo'),
  ('c9000000-0000-4000-c000-000000000005'::uuid, 'l-desk@l.test',  'Recepción')
) as u (id, email, name);

create temp table pid as
select u.email, p.id from auth.users u join public.profiles p on p.user_id = u.id where u.email like 'l-%';
grant select on pid to authenticated;

insert into public.gym_members (gym_id, profile_id, role)
select 'c0000000-0000-4000-c000-000000000001', id, case when email = 'l-desk@l.test' then 'front_desk' else 'member' end::public.gym_role
from pid;

insert into public.plans (id, gym_id, slug, name, kind, price_cents, billing_period, sessions, sessions_per_month, weekly_sessions, validity_months) values
  ('c2000000-0000-4000-c000-000000000001', 'c0000000-0000-4000-c000-000000000001', 'semana', '1 Día por Semana', 'membership', 3000, 'month', null, true, 1, null),
  ('c2000000-0000-4000-c000-000000000002', 'c0000000-0000-4000-c000-000000000001', 'dos',    'Dos al mes',       'membership', 2000, 'month', 2, true, null, null),
  ('c2000000-0000-4000-c000-000000000003', 'c0000000-0000-4000-c000-000000000001', 'bono3',  'Bono 3',           'pack',       3000, 'quarter', 3, false, null, 3),
  ('c2000000-0000-4000-c000-000000000004', 'c0000000-0000-4000-c000-000000000001', 'libre',  'Ilimitada',        'membership', 9000, 'month', null, true, null, null);

insert into public.member_plans (gym_id, profile_id, plan_id, starts_on, ends_on)
select 'c0000000-0000-4000-c000-000000000001', (select id from pid where email = e), p::uuid, s, null
from (values
  ('l-luis@l.test', 'c2000000-0000-4000-c000-000000000001', current_date),
  ('l-eva@l.test',  'c2000000-0000-4000-c000-000000000002', current_date),
  ('l-ana@l.test',  'c2000000-0000-4000-c000-000000000003', current_date - 10)
) as x (e, p, s);
-- Pablo, sin tarifa: la sede no exige tarifa, reserva sin límite

-- Horas locales (Madrid) de referencia
create temp table t as select
  (date_trunc('week', now() at time zone 'Europe/Madrid') + interval '7 days') as next_monday,
  (date_trunc('month', now() at time zone 'Europe/Madrid') + interval '2 months') as month_m;
grant select on t to authenticated;

insert into public.class_sessions (id, gym_id, discipline_id, name, starts_at, ends_at, capacity)
select id::uuid, 'c0000000-0000-4000-c000-000000000001', 'c1000000-0000-4000-c000-000000000001', name,
       local_start at time zone 'Europe/Madrid', (local_start + interval '1 hour') at time zone 'Europe/Madrid', cap
from t, lateral (values
  -- semana siguiente: lunes y martes; y el lunes de la otra
  ('c3000000-0000-4000-c000-000000000001', 'Lunes',        t.next_monday + interval '10 hours', 10),
  ('c3000000-0000-4000-c000-000000000002', 'Martes',       t.next_monday + interval '1 day 10 hours', 10),
  ('c3000000-0000-4000-c000-000000000003', 'Lunes otra',   t.next_monday + interval '7 days 10 hours', 10),
  -- mes M (dentro de dos meses): días 2, 3 y 4, y una de 1 plaza el día 5
  ('c3000000-0000-4000-c000-000000000011', 'M día 2',      t.month_m + interval '1 day 10 hours', 10),
  ('c3000000-0000-4000-c000-000000000012', 'M día 3',      t.month_m + interval '2 days 10 hours', 10),
  ('c3000000-0000-4000-c000-000000000013', 'M día 4',      t.month_m + interval '3 days 10 hours', 10),
  ('c3000000-0000-4000-c000-000000000014', 'M día 5 llena', t.month_m + interval '4 days 10 hours', 1),
  ('c3000000-0000-4000-c000-000000000015', 'M+1 día 2',    t.month_m + interval '1 month 1 day 10 hours', 10)
) as s (id, name, local_start, cap);

-- Pasado de Ana (bono desde hace 10 días): tres reservas sin asistir y una asistencia
insert into public.class_sessions (id, gym_id, discipline_id, name, starts_at, ends_at, capacity) values
  ('c3000000-0000-4000-c000-000000000021', 'c0000000-0000-4000-c000-000000000001', 'c1000000-0000-4000-c000-000000000001', 'Pasada tranquila', now() - interval '5 days', now() - interval '5 days' + interval '1 hour', 10),
  ('c3000000-0000-4000-c000-000000000022', 'c0000000-0000-4000-c000-000000000001', 'c1000000-0000-4000-c000-000000000001', 'Pasada con espera', now() - interval '4 days', now() - interval '4 days' + interval '1 hour', 1),
  ('c3000000-0000-4000-c000-000000000023', 'c0000000-0000-4000-c000-000000000001', 'c1000000-0000-4000-c000-000000000001', 'Pasada asistida', now() - interval '3 days', now() - interval '3 days' + interval '1 hour', 10);
insert into public.bookings (gym_id, session_id, profile_id, status) values
  ('c0000000-0000-4000-c000-000000000001', 'c3000000-0000-4000-c000-000000000021', (select id from pid where email = 'l-ana@l.test'), 'booked'),
  ('c0000000-0000-4000-c000-000000000001', 'c3000000-0000-4000-c000-000000000022', (select id from pid where email = 'l-ana@l.test'), 'booked'),
  ('c0000000-0000-4000-c000-000000000001', 'c3000000-0000-4000-c000-000000000022', (select id from pid where email = 'l-pablo@l.test'), 'waitlist'),
  ('c0000000-0000-4000-c000-000000000001', 'c3000000-0000-4000-c000-000000000023', (select id from pid where email = 'l-ana@l.test'), 'booked');
insert into public.attendances (gym_id, session_id, profile_id, method, client_id, checked_in_at)
values ('c0000000-0000-4000-c000-000000000001', 'c3000000-0000-4000-c000-000000000023', (select id from pid where email = 'l-ana@l.test'), 'coach', gen_random_uuid(), now() - interval '3 days');

create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims',
    json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- ================= Semanal: "1 Día por Semana" =================
select pg_temp.login('l-luis@l.test');
select is(public.book_session('c3000000-0000-4000-c000-000000000001') ->> 'status', 'booked', 'semanal: la primera clase de la semana entra');
select throws_like($$ select public.book_session('c3000000-0000-4000-c000-000000000002') $$,
  'Ya has usado tu clase de esta semana%', 'semanal: la segunda de la misma semana no');
select is(public.book_session('c3000000-0000-4000-c000-000000000003') ->> 'status', 'booked', 'semanal: la semana siguiente vuelve a tener su clase');
select is((public.my_plan_status() ->> 'period'), 'week', 'mi tarifa: periodo semanal');
select lives_ok($$ select public.cancel_booking((select id from public.bookings where session_id = 'c3000000-0000-4000-c000-000000000001' and status = 'booked')) $$, 'cancela la del lunes');
select is(public.book_session('c3000000-0000-4000-c000-000000000002') ->> 'status', 'booked', 'semanal: cancelar devuelve la clase');

-- ================= Mes natural: 2 al mes =================
select pg_temp.login('l-eva@l.test');
select is(public.book_session('c3000000-0000-4000-c000-000000000011') ->> 'status', 'booked', 'mensual: 1 de 2');
-- La de 1 plaza ya la tiene Pablo: Eva queda en espera (la espera no gasta clase)
reset role;
select pg_temp.login('l-pablo@l.test');
select is(public.book_session('c3000000-0000-4000-c000-000000000014') ->> 'status', 'booked', 'sin tarifa: reserva sin límite');
select pg_temp.login('l-eva@l.test');
select is(public.book_session('c3000000-0000-4000-c000-000000000014') ->> 'status', 'waitlist', 'mensual: puede ponerse en espera');
select is(public.book_session('c3000000-0000-4000-c000-000000000012') ->> 'status', 'booked', 'mensual: 2 de 2 (la espera no contaba)');
select throws_like($$ select public.book_session('c3000000-0000-4000-c000-000000000013') $$,
  'Ya has usado tus 2 clases de este mes%', 'mensual: la tercera del mes no');
select is(public.book_session('c3000000-0000-4000-c000-000000000015') ->> 'status', 'booked', 'mensual: el mes siguiente empieza de cero');
select is((select (public.my_plan_status(null, (select (month_m + interval '9 days')::date from t)) ->> 'used')::int), 2, 'mi tarifa: 2 usadas ese mes');

-- ================= Bono y no presentados =================
select pg_temp.login('l-ana@l.test');
-- Pasado: la no presentada sin nadie fuera NO cuenta; la de lista de espera SÍ; la asistida SÍ → 2 de 3
select is((public.my_plan_status() ->> 'used')::int, 2, 'bono: el no presentado solo gasta si alguien se quedó fuera');
-- Ana se pone en espera en la de 1 plaza, detrás de Eva
select is(public.book_session('c3000000-0000-4000-c000-000000000014') ->> 'status', 'waitlist', 'bono: Ana en espera detrás de Eva');

-- ================= La espera salta a quien ya no tiene clases =================
select pg_temp.login('l-pablo@l.test');
select is(
  (public.cancel_booking((select id from public.bookings where session_id = 'c3000000-0000-4000-c000-000000000014' and status = 'booked')) ->> 'promoted_profile_id')::uuid,
  (select id from pid where email = 'l-ana@l.test'),
  'al liberarse la plaza sube Ana: Eva ya gastó sus 2 clases de ese mes');
reset role;
select is((select status::text from public.bookings where session_id = 'c3000000-0000-4000-c000-000000000014' and profile_id = (select id from pid where email = 'l-eva@l.test') and status <> 'cancelled'), 'waitlist', 'Eva sigue en espera');

select pg_temp.login('l-ana@l.test');
select throws_like($$ select public.book_session('c3000000-0000-4000-c000-000000000011') $$,
  'Ya has usado tus 3 clases del bono%', 'bono: agotado');

-- ================= Recepción puede pasar el límite =================
select pg_temp.login('l-desk@l.test');
select is(public.book_session('c3000000-0000-4000-c000-000000000013', (select id from pid where email = 'l-eva@l.test')) ->> 'plan_override', 'true',
  'recepción apunta a Eva por encima del límite');
reset role;
select is((select count(*)::int from public.audit_log where action = 'plan_limit_override' and gym_id = 'c0000000-0000-4000-c000-000000000001'), 1, 'y queda en auditoría');

-- ================= Asignar tarifas =================
select pg_temp.login('l-luis@l.test');
select throws_ok($$ select public.assign_plan((select id from pid where email = 'l-luis@l.test'), 'c2000000-0000-4000-c000-000000000004') $$,
  '42501', null, 'un alumno no se asigna tarifas');
select pg_temp.login('l-desk@l.test');
select lives_ok($$ select public.assign_plan((select id from pid where email = 'l-luis@l.test'), 'c2000000-0000-4000-c000-000000000004', current_date + 1) $$,
  'recepción cambia la tarifa de Luis desde mañana');
reset role;
select is((select ends_on from public.member_plans where profile_id = (select id from pid where email = 'l-luis@l.test') and plan_id = 'c2000000-0000-4000-c000-000000000001'),
  current_date, 'la tarifa anterior termina hoy');
select is((select count(*)::int from public.member_plans where profile_id = (select id from pid where email = 'l-luis@l.test')), 2, 'Luis conserva el historial: la anterior y la nueva');

select * from finish();
rollback;
