-- Cambiar la hora o los días de una clase semanal con reservas: las reservas
-- pasan a la nueva hora y no quedan sesiones sueltas con la hora antigua.
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into public.gyms (id, name) values ('aa000000-0000-4000-a000-000000000001', 'Sede M');
insert into public.disciplines (id, gym_id, slug, name, kind) values
  ('aa100000-0000-4000-a000-000000000001', 'aa000000-0000-4000-a000-000000000001', 'gi', 'Gi', 'gi');
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('00000000-0000-0000-0000-000000000000', 'aa900000-0000-4000-a000-000000000001', 'authenticated', 'authenticated', 'm-admin@m.test', '{"full_name":"Admin M"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'aa900000-0000-4000-a000-000000000002', 'authenticated', 'authenticated', 'm-alumna@m.test', '{"full_name":"Alumna M"}', now(), now());
insert into public.gym_members (gym_id, profile_id, role)
select 'aa000000-0000-4000-a000-000000000001', p.id, case when p.user_id = 'aa900000-0000-4000-a000-000000000001' then 'admin' else 'member' end::public.gym_role
from public.profiles p where p.user_id in ('aa900000-0000-4000-a000-000000000001', 'aa900000-0000-4000-a000-000000000002');

-- Clase diaria a las 18:30
insert into public.class_templates (id, gym_id, discipline_id, name, weekdays, start_time, duration_min, capacity, valid_from)
values ('aa200000-0000-4000-a000-000000000001', 'aa000000-0000-4000-a000-000000000001', 'aa100000-0000-4000-a000-000000000001',
        'Avanzado', '{1,2,3,4,5,6,7}', '18:30', 60, 50, current_date);
-- La alumna reserva la de dentro de 3 días
create temp table day as select (current_date + 3) as d;
grant select on day to authenticated;
insert into public.bookings (gym_id, session_id, profile_id, status)
select 'aa000000-0000-4000-a000-000000000001', s.id, p.id, 'booked'
from public.class_sessions s, public.profiles p
where s.template_id = 'aa200000-0000-4000-a000-000000000001' and (s.starts_at at time zone 'Europe/Madrid')::date = (select d from day)
  and p.user_id = 'aa900000-0000-4000-a000-000000000002';

create function pg_temp.login() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', 'aa900000-0000-4000-a000-000000000001', 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- Pasa a las 18:00
select pg_temp.login();
update public.class_templates set start_time = '18:00' where id = 'aa200000-0000-4000-a000-000000000001';
reset role;
select is((select count(*)::int from public.class_sessions where template_id = 'aa200000-0000-4000-a000-000000000001'
  and (starts_at at time zone 'Europe/Madrid')::date = (select d from day)), 1, 'ese día queda una sola clase');
select is((select to_char(starts_at at time zone 'Europe/Madrid', 'HH24:MI') from public.class_sessions where template_id = 'aa200000-0000-4000-a000-000000000001'
  and (starts_at at time zone 'Europe/Madrid')::date = (select d from day)), '18:00', 'a la hora nueva');
select is((select to_char(s.starts_at at time zone 'Europe/Madrid', 'HH24:MI') from public.bookings b join public.class_sessions s on s.id = b.session_id where b.status = 'booked' and b.gym_id = 'aa000000-0000-4000-a000-000000000001'),
  '18:00', 'la reserva de la alumna pasa a las 18:00');
select is((select booked_count from public.class_sessions where template_id = 'aa200000-0000-4000-a000-000000000001'
  and (starts_at at time zone 'Europe/Madrid')::date = (select d from day)), 1, 'y cuenta en la ocupación');
select is((select count(*)::int from public.class_sessions where template_id = 'aa200000-0000-4000-a000-000000000001'
  and to_char(starts_at at time zone 'Europe/Madrid', 'HH24:MI') = '18:30' and starts_at > now()), 0, 'no queda ninguna a las 18:30');

-- Quitar ese día de la semana: la sesión con reserva se cancela (los alumnos lo ven)
select pg_temp.login();
update public.class_templates set weekdays = array(select x::smallint from generate_series(1, 7) x where x <> extract(isodow from (select d from day))::int)
where id = 'aa200000-0000-4000-a000-000000000001';
reset role;
select is((select status::text from public.class_sessions where template_id = 'aa200000-0000-4000-a000-000000000001'
  and (starts_at at time zone 'Europe/Madrid')::date = (select d from day)), 'cancelled', 'si ese día ya no hay clase, la reservada queda cancelada');
select is((select count(*)::int from public.class_sessions where template_id = 'aa200000-0000-4000-a000-000000000001'
  and extract(isodow from starts_at at time zone 'Europe/Madrid') = extract(isodow from (select d from day)) and status = 'scheduled' and starts_at > now()), 0,
  'y no quedan clases programadas ese día de la semana');

select * from finish();
rollback;
