-- Datos de ejemplo para el entorno LOCAL (se cargan con `supabase db reset`).
-- Un usuario por rol. Se entra con enlace mágico; los correos llegan al
-- buzón local de Supabase (Mailpit): http://127.0.0.1:54324

insert into public.gyms (id, name)
values ('00000000-0000-4000-a000-000000000001', 'ITACA Jiu Jitsu');
update public.gyms set settings = settings || '{"contact": {"email": "contacto@tu-gimnasio.com", "phone": "+34600000000", "whatsapp": "34600000000", "address": "Calle Ejemplo, 1 · 00000 Tu ciudad", "instagram": "tu_gimnasio", "web": "https://www.tu-gimnasio.com"}}'::jsonb
where id = '00000000-0000-4000-a000-000000000001';

-- Usuarios de auth (el trigger on_auth_user_created crea su perfil)
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email, '', now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('full_name', u.name), now(), now(), '', '', '', ''
from (values
  ('10000000-0000-4000-a000-000000000001'::uuid, 'propietario@itaca.test', 'Propietario ITACA'),
  ('10000000-0000-4000-a000-000000000002'::uuid, 'admin@itaca.test',       'Admin ITACA'),
  ('10000000-0000-4000-a000-000000000003'::uuid, 'cipri@itaca.test',       'Cipri'),
  ('10000000-0000-4000-a000-000000000007'::uuid, 'boris@itaca.test',       'Boris'),
  ('10000000-0000-4000-a000-000000000008'::uuid, 'marta@itaca.test',       'Marta'),
  ('10000000-0000-4000-a000-000000000004'::uuid, 'recepcion@itaca.test',   'Recepción ITACA'),
  ('10000000-0000-4000-a000-000000000005'::uuid, 'elena@itaca.test',       'Elena Díaz'),
  ('10000000-0000-4000-a000-000000000006'::uuid, 'carlos@itaca.test',      'Carlos Vega')
) as u (id, email, name);

insert into auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at, last_sign_in_at)
select gen_random_uuid(), u.id, u.id::text,
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  'email', now(), now(), now()
from auth.users u
where u.email like '%@itaca.test';

-- Roles en la sede
insert into public.gym_members (gym_id, profile_id, role)
select '00000000-0000-4000-a000-000000000001', p.id, r.role::public.gym_role
from (values
  ('propietario@itaca.test', 'owner'),
  ('admin@itaca.test',       'admin'),
  ('cipri@itaca.test',       'coach'),
  ('boris@itaca.test',       'coach'),
  ('marta@itaca.test',       'coach'),
  ('recepcion@itaca.test',   'front_desk'),
  ('elena@itaca.test',       'member'),
  ('carlos@itaca.test',      'member')
) as r (email, role)
join auth.users u on u.email = r.email
join public.profiles p on p.user_id = u.id;

-- Elena tiene una hija de 8 años sin cuenta
with minor as (
  insert into public.profiles (full_name, birth_date)
  values ('Noa Díaz', (current_date - interval '8 years')::date)
  returning id
), m as (
  insert into public.gym_members (gym_id, profile_id, role)
  select '00000000-0000-4000-a000-000000000001', id, 'member' from minor
)
insert into public.guardianships (gym_id, guardian_profile_id, minor_profile_id)
select '00000000-0000-4000-a000-000000000001', g.id, minor.id
from minor, public.profiles g
join auth.users u on u.id = g.user_id and u.email = 'elena@itaca.test';

-- ---------- Horario (paso 2) ----------
-- Clases y horas tomadas de https://www.tu-gimnasio.com el 15/11/2026.
-- La web no indica profesor ni aforo por clase: profesor por asignar y aforo
-- provisional, a completar desde el editor de horario.
insert into public.disciplines (gym_id, slug, name, kind, sort) values
  ('00000000-0000-4000-a000-000000000001', 'gi',      'BJJ Gi',   'gi',      1),
  ('00000000-0000-4000-a000-000000000001', 'nogi',    'No Gi',    'nogi',    2),
  ('00000000-0000-4000-a000-000000000001', 'kids',    'Infantil', 'kids',    3),
  ('00000000-0000-4000-a000-000000000001', 'openmat', 'Open Mat', 'openmat', 4);

-- Cada plantilla genera sus sesiones de 4 semanas al insertarse (trigger)
insert into public.class_templates
  (gym_id, discipline_id, name, level, weekdays, start_time, duration_min, capacity, min_age, max_age, valid_from)
select '00000000-0000-4000-a000-000000000001', d.id, c.name, c.level, c.weekdays, c.start_time::time, c.duration, c.capacity,
       c.min_age, c.max_age, current_date - 90
from (values
  ('gi',      'Fundamentos',          '',                '{1}'::smallint[], '07:00',  60, 50, null::smallint, null::smallint),
  ('gi',      'Fundamentos (Gi)',     '',                '{1}',             '17:00',  60, 50, null, null),
  ('nogi',    'Grappling No Gi',      '',                '{2}',             '10:00',  90, 50, null, null),
  ('kids',    'Kids',                 '7 a 10 años',       '{2}',             '16:45',  60, 50, 7, 10),
  ('nogi',    'Avanzados No Gi',      '',                '{2}',             '18:00', 120, 50, null, null),
  ('nogi',    'Iniciación No Gi',     '',                '{2}',             '20:00',  60, 50, null, null),
  ('nogi',    'Fundamentos No Gi',    '',                '{3}',             '07:00',  60, 50, null, null),
  ('nogi',    'No Gi Grappling',      '',                '{3}',             '17:00',  60, 50, null, null),
  ('gi',      'BJJ Gi',               '',                '{4}',             '10:00',  90, 50, null, null),
  ('kids',    'Kids',                 '4 a 6 años',        '{4}',             '16:45',  60, 50, 4, 6),
  ('gi',      'Avanzados Gi',         '',                '{4}',             '18:00', 120, 50, null, null),
  ('gi',      'Iniciación Gi',        '',                '{4}',             '20:00',  60, 50, null, null),
  ('gi',      'Específico Sparring',  '',                '{5}',             '07:00',  60, 50, null, null),
  ('kids',    'BJJ Kids Gi',          '7 a 10 años',       '{5}',             '16:45',  60, 50, 7, 10),
  ('gi',      'Avanzado Gi',          '',                '{5}',             '18:30',  90, 50, null, null),
  ('gi',      'BJJ Gi Libre',         '',                '{6}',             '10:00',  60, 50, null, null),
  ('openmat', 'Open Mat',             '',                '{6}',             '11:00',  90, 50, null, null)
) as c (slug, name, level, weekdays, start_time, duration, capacity, min_age, max_age)
join public.disciplines d on d.gym_id = '00000000-0000-4000-a000-000000000001' and d.slug = c.slug;

-- ---------- Alumnos y reservas de ejemplo (paso 3) ----------
-- Alumnos sin cuenta (nombres de ejemplo) para que la ocupación y la lista
-- del profesor tengan datos. Las reservas se insertan directamente: el
-- trigger mantiene los contadores de cada clase.
with nuevos as (
  insert into public.profiles (full_name)
  select n from unnest(array[
    'Ana Ruiz', 'Javier Soto', 'Lucía Marín', 'Marcos Gil', 'Paula Navarro', 'Luis Moreno',
    'Andrea Ramos', 'Jorge Serrano', 'Sara Ortega', 'Diego Castro', 'Nuria Prieto', 'Raúl Herrero',
    'Clara Molina', 'Pablo Iglesias', 'Irene Santos', 'Hugo Medina', 'Marta León', 'Álvaro Cano',
    'Eva Rubio', 'Adrián Vidal', 'Laura Pascual', 'Sergio Lozano', 'Alba Gallego', 'Iker Domínguez',
    'Daniel Ibáñez', 'Lola Vargas', 'Bruno Sanz'
  ]) as n
  returning id
)
insert into public.gym_members (gym_id, profile_id)
select '00000000-0000-4000-a000-000000000001', id from nuevos;

-- Cada clase de adultos futura con entre un 40 % y un 85 % de ocupación (determinista)
insert into public.bookings (gym_id, session_id, profile_id, status, created_at)
select s.gym_id, s.id, x.profile_id, 'booked', now() - interval '2 days' + x.rn * interval '1 minute'
from public.class_sessions s
join public.disciplines d on d.id = s.discipline_id and d.kind <> 'kids'
cross join lateral (
  select m.profile_id, row_number() over (order by md5(s.id::text || m.profile_id::text)) as rn
  from public.gym_members m
  join public.profiles p on p.id = m.profile_id
  where m.gym_id = s.gym_id and m.role = 'member' and p.user_id is null and p.birth_date is null
) x
where s.gym_id = '00000000-0000-4000-a000-000000000001'
  and s.starts_at > now()
  and x.rn <= least(s.capacity, greatest(3, (s.capacity * (40 + abs(hashtext(s.id::text)) % 46) / 100)));

-- La próxima "Avanzados No Gi" llena y con 2 en lista de espera
with s as (
  select id, gym_id, capacity, booked_count from public.class_sessions
  where name = 'Avanzados No Gi' and starts_at > now() order by starts_at limit 1
), libres as (
  select m.profile_id, row_number() over (order by p.full_name) as rn
  from public.gym_members m join public.profiles p on p.id = m.profile_id, s
  where m.gym_id = s.gym_id and m.role = 'member' and p.user_id is null and p.birth_date is null
    and not exists (select 1 from public.bookings b where b.session_id = s.id and b.profile_id = m.profile_id)
)
insert into public.bookings (gym_id, session_id, profile_id, status, created_at)
select s.gym_id, s.id, l.profile_id,
  case when l.rn <= s.capacity - s.booked_count then 'booked'::public.booking_status else 'waitlist' end,
  now() - interval '1 day' + l.rn * interval '1 minute'
from s, libres l
where l.rn <= s.capacity - s.booked_count + 2;

-- Elena tiene reservada la próxima clase de tarde de adultos
insert into public.bookings (gym_id, session_id, profile_id, status)
select s.gym_id, s.id, p.id, 'booked'
from public.class_sessions s
join public.disciplines d on d.id = s.discipline_id and d.kind in ('gi', 'nogi')
join auth.users u on u.email = 'elena@itaca.test'
join public.profiles p on p.user_id = u.id
where s.starts_at > now() and extract(hour from s.starts_at at time zone 'Europe/Madrid') >= 17
  and s.booked_count < s.capacity
order by s.starts_at
limit 1;

-- ---------- Tarifas (adelanto del paso 6) ----------
-- Tarifas vigentes del gimnasio (capturas de la app actual, 15/11/2026).
insert into public.plans
  (gym_id, slug, name, description, kind, price_cents, billing_period, sessions, sessions_per_month, validity_months, auto_renew, audience, sort)
values
  ('00000000-0000-4000-a000-000000000001', '1-dia-semana', '1 Día por Semana', '',                                  'membership', 3000,  'month',   null,    true,  null, true,  'adults', 1),
  ('00000000-0000-4000-a000-000000000001', 'bjj-white',    'Bjj White',        '',                                  'membership', 5000,  'month',   8,    true,  null, true,  'adults', 2),
  ('00000000-0000-4000-a000-000000000001', 'blue',         'Blue',             '',                                  'membership', 6000,  'month',   12,   true,  null, true,  'adults', 3),
  ('00000000-0000-4000-a000-000000000001', 'black',        'Black',            '',                                  'membership', 7000,  'month',   16,   true,  null, true,  'adults', 4),
  ('00000000-0000-4000-a000-000000000001', 'corral',       'Corral',           '',                                  'membership', 8000,  'month',   32,   true,  null, true,  'adults', 5),
  ('00000000-0000-4000-a000-000000000001', 'fundador',     'Fundador',         '',                                  'membership', 5000,  'month',   null, true,  null, true,  'adults', 6),
  ('00000000-0000-4000-a000-000000000001', 'bono-10',      'Bono 10 Clases',   '10 clases durante máximo 3 meses',  'pack',       7000,  'quarter', 10,   false, 3,    false, 'adults', 7),
  ('00000000-0000-4000-a000-000000000001', 'bjj-kids',     'Bjj Kids',         'Bjj Kids martes y viernes',         'membership', 4000,  'month',   8,    true,  null, true,  'kids',   8),
  ('00000000-0000-4000-a000-000000000001', 'anual-kids',   'Anual BJJ Kids',   'Curso completo Bjj Kids',           'membership', 30000, 'year',    8,    true,  12,   false, 'kids',   9),
  ('00000000-0000-4000-a000-000000000001', 'pase-dia',     'Pase por un Día',  'Válido 1 día de entreno',           'drop_in',    1000,  'once',    1,    false, null, false, 'all',    10);
-- "1 Día por Semana": una clase por semana (ver …_plan_limits.sql)
update public.plans set weekly_sessions = 1 where slug = '1-dia-semana';

-- ITACA+: complemento de 5 €/mes (ver …_itaca_plus.sql)
insert into public.plans (gym_id, slug, name, description, kind, price_cents, billing_period, sessions, sessions_per_month, auto_renew, audience, sort, is_addon)
values ('00000000-0000-4000-a000-000000000001', 'itaca-plus', 'ITACA+', 'Vídeos de las clases, técnicas sueltas y currículos. Se suma a tu tarifa mensual.',
        'membership', 500, 'month', null, true, true, 'all', 50, true);

-- Tarifas asignadas a los alumnos de prueba (desde el día 1 del mes)
insert into public.member_plans (gym_id, profile_id, plan_id, starts_on)
select '00000000-0000-4000-a000-000000000001', p.id, pl.id, date_trunc('month', current_date)::date
from (values ('elena@itaca.test', 'blue'), ('carlos@itaca.test', '1-dia-semana')) as v(email, slug)
join auth.users u on u.email = v.email
join public.profiles p on p.user_id = u.id
join public.plans pl on pl.slug = v.slug;


-- ---------- Cinturones de ejemplo ----------
insert into public.promotions (gym_id, profile_id, belt, stripes, promoted_at, self_declared)
select '00000000-0000-4000-a000-000000000001', p.id, r.belt::public.belt, r.stripes, r.since::date, false
from (values
  ('elena@itaca.test', 'azul', 2, '2026-03-10'),
  ('carlos@itaca.test', 'azul', 1, '2025-11-02'),
  ('cipri@itaca.test', 'negro', 1, '2023-06-01'),
  ('boris@itaca.test', 'morado', 2, '2024-09-15'),
  ('marta@itaca.test', 'morado', 1, '2025-01-20')
) r (email, belt, stripes, since)
join auth.users u on u.email = r.email
join public.profiles p on p.user_id = u.id;

insert into public.promotions (gym_id, profile_id, belt, stripes, promoted_at, self_declared)
select '00000000-0000-4000-a000-000000000001', p.id,
  (array['blanco','blanco','blanco','azul','azul','morado','marron'])[1 + abs(hashtext(p.full_name)) % 7]::public.belt,
  (abs(hashtext(p.full_name || 'g')) % 5)::smallint, current_date - (abs(hashtext(p.full_name)) % 700), false
from public.profiles p
where p.user_id is null and p.birth_date is null;

-- ---------- Historial de asistencia de ejemplo (Elena, últimas 10 semanas) ----------
select public.generate_sessions('00000000-0000-4000-a000-000000000001', 10, current_date - 70);
insert into public.attendances (gym_id, session_id, profile_id, method, client_id, checked_in_at)
select s.gym_id, s.id, p.id, 'coach', gen_random_uuid(), s.starts_at + interval '5 minutes'
from public.class_sessions s
join public.disciplines d on d.id = s.discipline_id and d.kind in ('gi', 'nogi')
join auth.users u on u.email = 'elena@itaca.test'
join public.profiles p on p.user_id = u.id
where s.starts_at < now() and abs(hashtext(s.id::text)) % 5 < 2;

-- ---------- Asistencia de ejemplo del resto de alumnos (para el ranking) ----------
-- Cada alumno sin cuenta va a una fracción distinta de las clases pasadas (determinista)
insert into public.attendances (gym_id, session_id, profile_id, method, client_id, checked_in_at)
select s.gym_id, s.id, p.id, 'coach', gen_random_uuid(), s.starts_at + interval '5 minutes'
from public.class_sessions s
join public.disciplines d on d.id = s.discipline_id and d.kind in ('gi', 'nogi')
join public.gym_members m on m.gym_id = s.gym_id and m.role = 'member'
join public.profiles p on p.id = m.profile_id and p.user_id is null and p.birth_date is null
where s.gym_id = '00000000-0000-4000-a000-000000000001' and s.starts_at < now()
  and abs(hashtext(s.id::text || p.id::text)) % 100 < 10 + abs(hashtext(p.full_name)) % 35;

-- ---------- Novedades de ejemplo ----------
insert into public.announcements (gym_id, title, body, pinned, author_profile_id, published_at, created_at, updated_at)
select '00000000-0000-4000-a000-000000000001', a.title, a.body, a.pinned, p.id, now() - a.ago, now() - a.ago, now() - a.ago
from (values
  ('Normas del tatami', E'Llega 5 minutos antes, uñas cortas y kimono limpio.\nSi estás malo, descansa: el tatami te espera.', true, interval '20 days'),
  ('Seminario de guardia el sábado', 'Sábado a las 11:00 con Cipri. Abierto a todos los niveles. Apúntate en recepción.', false, interval '2 days'),
  ('Cerrado el 8 de diciembre', 'Por el festivo de la Inmaculada no habrá clases ese día.', false, interval '5 hours')
) as a (title, body, pinned, ago)
join auth.users u on u.email = 'admin@itaca.test'
join public.profiles p on p.user_id = u.id;
