-- Quién va a la clase y permisos de las fotos de perfil.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into public.gyms (id, name) values
  ('a7000000-0000-4000-a000-000000000001', 'Sede Fotos'),
  ('a7000000-0000-4000-a000-000000000002', 'Otra sede');
insert into public.disciplines (id, gym_id, slug, name, kind)
values ('a7100000-0000-4000-a000-000000000001', 'a7000000-0000-4000-a000-000000000001', 'gi', 'Gi', 'gi');
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, jsonb_build_object('full_name', name), now(), now()
from (values
  ('a7900000-0000-4000-a000-000000000001'::uuid, 'f-ana@f.test',  'Ana Ruiz'),
  ('a7900000-0000-4000-a000-000000000002'::uuid, 'f-luis@f.test', 'Luis Mora'),
  ('a7900000-0000-4000-a000-000000000003'::uuid, 'f-otro@o.test', 'Otro Lejos')
) as u (id, email, name);
insert into public.gym_members (gym_id, profile_id)
select g, p.id from (values
  ('a7000000-0000-4000-a000-000000000001'::uuid, 'a7900000-0000-4000-a000-000000000001'::uuid),
  ('a7000000-0000-4000-a000-000000000001'::uuid, 'a7900000-0000-4000-a000-000000000002'::uuid),
  ('a7000000-0000-4000-a000-000000000002'::uuid, 'a7900000-0000-4000-a000-000000000003'::uuid)
) x (g, u) join public.profiles p on p.user_id = x.u;

-- Menor sin cuenta
insert into public.profiles (id, full_name, birth_date) values ('a7200000-0000-4000-a000-000000000001', 'Nico Ruiz Pérez', current_date - 3000);
insert into public.gym_members (gym_id, profile_id) values ('a7000000-0000-4000-a000-000000000001', 'a7200000-0000-4000-a000-000000000001');

insert into public.class_sessions (id, gym_id, discipline_id, name, starts_at, ends_at, capacity)
values ('a7300000-0000-4000-a000-000000000001', 'a7000000-0000-4000-a000-000000000001', 'a7100000-0000-4000-a000-000000000001', 'Gi', now() + interval '1 day', now() + interval '1 day 1 hour', 10);
insert into public.bookings (gym_id, session_id, profile_id, status)
select 'a7000000-0000-4000-a000-000000000001', 'a7300000-0000-4000-a000-000000000001', id, 'booked'
from public.profiles where user_id = 'a7900000-0000-4000-a000-000000000001' or id = 'a7200000-0000-4000-a000-000000000001';

create function pg_temp.login(p_user uuid) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- ---------- Quién va ----------
select pg_temp.login('a7900000-0000-4000-a000-000000000002'); -- Luis, no apuntado
select is((select count(*)::int from public.session_attendees('a7300000-0000-4000-a000-000000000001')), 2,
  'un alumno de la sede ve quién va a la clase');
select is((select count(*)::int from public.session_attendees('a7300000-0000-4000-a000-000000000001') where display_name = 'Ana Ruiz'), 1,
  've el nombre completo de un adulto');
select is((select count(*)::int from public.session_attendees('a7300000-0000-4000-a000-000000000001') where display_name = 'Nico'), 1,
  'de un menor solo ve el nombre de pila');
select is((select count(*)::int from public.profiles where full_name = 'Ana Ruiz'), 0,
  'sigue sin poder leer el perfil completo de otra alumna');

select pg_temp.login('a7900000-0000-4000-a000-000000000001'); -- Ana, apuntada
select is((select is_me from public.session_attendees('a7300000-0000-4000-a000-000000000001') limit 1), true,
  'quien está apuntado sale el primero, marcado como "yo"');

select pg_temp.login('a7900000-0000-4000-a000-000000000003'); -- otra sede
select is((select count(*)::int from public.session_attendees('a7300000-0000-4000-a000-000000000001')), 0,
  'alguien de otra sede no ve quién va');

-- ---------- Fotos ----------
select pg_temp.login('a7900000-0000-4000-a000-000000000001');
select lives_ok($$ insert into storage.objects (bucket_id, name) values ('avatars', 'a7900000-0000-4000-a000-000000000001/foto.jpg') $$,
  'subir una foto a tu carpeta');
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('avatars', 'a7900000-0000-4000-a000-000000000002/foto.jpg') $$,
  '42501', null, 'no puedes subir a la carpeta de otro');
select lives_ok($$ update public.profiles set avatar_path = 'a7900000-0000-4000-a000-000000000001/foto.jpg' where user_id = auth.uid() $$,
  'poner tu foto en tu perfil');
select throws_ok($$ update public.profiles set avatar_path = 'a7900000-0000-4000-a000-000000000002/foto.jpg' where user_id = auth.uid() $$,
  '42501', null, 'no puedes usar como foto un fichero de otro');

select pg_temp.login('a7900000-0000-4000-a000-000000000002');
select is((select count(*)::int from storage.objects where bucket_id = 'avatars' and name like 'a7900000-0000-4000-a000-000000000001/%'), 1,
  'un compañero de sede puede ver tu foto');
-- Storage bloquea el borrado por SQL salvo con este ajuste; así se prueba la política, no el bloqueo
select set_config('storage.allow_delete_query', 'true', true);
delete from storage.objects where bucket_id = 'avatars' and name like 'a7900000-0000-4000-a000-000000000001/%';
select is((select count(*)::int from storage.objects where bucket_id = 'avatars' and name like 'a7900000-0000-4000-a000-000000000001/%'), 1,
  'pero no puede borrarla');

select pg_temp.login('a7900000-0000-4000-a000-000000000003');
select is((select count(*)::int from storage.objects where bucket_id = 'avatars' and name like 'a7900000-0000-4000-a000-000000000001/%'), 0,
  'alguien de otra sede no ve tu foto');

reset role;
set local role anon;
select is((select count(*)::int from storage.objects where bucket_id = 'avatars'), 0, 'anónimo: no ve ninguna foto');

select * from finish();
rollback;
