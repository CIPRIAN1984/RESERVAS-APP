-- Horario a tres meses, fechas de inicio y fin de las clases semanales,
-- borrar la clase de un día y volver a crear las clases al quitar un cierre.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into public.gyms (id, name) values ('f0000000-0000-4000-f000-000000000001', 'Sede Z');
insert into public.disciplines (id, gym_id, slug, name, kind) values
  ('f1000000-0000-4000-f000-000000000001', 'f0000000-0000-4000-f000-000000000001', 'gi', 'Gi', 'gi');
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('00000000-0000-0000-0000-000000000000', 'f9000000-0000-4000-f000-000000000001', 'authenticated', 'authenticated', 'z-admin@z.test', '{"full_name":"Admin Z"}', now(), now());
insert into public.gym_members (gym_id, profile_id, role)
select 'f0000000-0000-4000-f000-000000000001', p.id, 'admin' from public.profiles p where p.user_id = 'f9000000-0000-4000-f000-000000000001';

-- Todos los días, sin fecha de fin
insert into public.class_templates (id, gym_id, discipline_id, name, weekdays, start_time, duration_min, capacity, valid_from)
values ('f2000000-0000-4000-f000-000000000001', 'f0000000-0000-4000-f000-000000000001', 'f1000000-0000-4000-f000-000000000001',
        'Diaria', '{1,2,3,4,5,6,7}', '23:59', 1 * 15, 50, current_date);
select ok((select max(starts_at) from public.class_sessions where template_id = 'f2000000-0000-4000-f000-000000000001') > now() + interval '80 days',
  'sin fecha de fin: hay clases con casi tres meses de antelación');

-- Con fecha de fin dentro de 10 días
insert into public.class_templates (id, gym_id, discipline_id, name, weekdays, start_time, duration_min, capacity, valid_from, valid_until)
values ('f2000000-0000-4000-f000-000000000002', 'f0000000-0000-4000-f000-000000000001', 'f1000000-0000-4000-f000-000000000001',
        'Hasta fecha', '{1,2,3,4,5,6,7}', '23:58', 15, 50, current_date, current_date + 10);
select is((select count(*)::int from public.class_sessions where template_id = 'f2000000-0000-4000-f000-000000000002'), 11, 'con fecha de fin: solo hasta ese día');

create function pg_temp.login() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', 'f9000000-0000-4000-f000-000000000001', 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- Acortar la fecha de fin borra las que sobran
select pg_temp.login();
update public.class_templates set valid_until = current_date + 3 where id = 'f2000000-0000-4000-f000-000000000002';
reset role;
select is((select count(*)::int from public.class_sessions where template_id = 'f2000000-0000-4000-f000-000000000002'), 4, 'acortar la fecha de fin quita las clases sobrantes');

-- Borrar la clase de un día
select pg_temp.login();
select is(public.delete_session((select id from public.class_sessions where template_id = 'f2000000-0000-4000-f000-000000000001' order by starts_at offset 2 limit 1)),
  'cancelled', 'el día de una clase semanal se anula (no se vuelve a generar)');
create temp table puntual as select public.create_one_off_session('f0000000-0000-4000-f000-000000000001', 'f1000000-0000-4000-f000-000000000001', 'Puntual', current_date + 5, '12:00', 60) as id;
select is(public.delete_session((select id from puntual)), 'deleted', 'una clase puntual sin reservas se borra');
reset role;
select is((select count(*)::int from public.class_sessions where name = 'Puntual'), 0, 'ya no está');
select pg_temp.login();
select public.generate_sessions('f0000000-0000-4000-f000-000000000001', 12);
reset role;
select is((select count(*)::int from public.class_sessions where template_id = 'f2000000-0000-4000-f000-000000000001' and status = 'cancelled'), 1,
  'regenerar no vuelve a crear el día anulado');

-- Un cierre y quitarlo
select pg_temp.login();
insert into public.closures (gym_id, date_from, date_to, reason) values ('f0000000-0000-4000-f000-000000000001', current_date + 20, current_date + 21, 'Puente');
reset role;
select is((select count(*)::int from public.class_sessions where template_id = 'f2000000-0000-4000-f000-000000000001' and status = 'cancelled'
  and (starts_at at time zone 'Europe/Madrid')::date between current_date + 20 and current_date + 21), 2, 'el cierre cancela esos días');
select pg_temp.login();
delete from public.closures where gym_id = 'f0000000-0000-4000-f000-000000000001';
reset role;
select is((select count(*)::int from public.class_sessions where template_id = 'f2000000-0000-4000-f000-000000000001' and status = 'scheduled'
  and (starts_at at time zone 'Europe/Madrid')::date between current_date + 20 and current_date + 21), 2, 'al quitar el cierre vuelven');

select * from finish();
rollback;
