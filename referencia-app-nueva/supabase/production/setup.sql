-- Datos iniciales de PRODUCCIÓN (proyecto en la nube).
-- A diferencia de supabase/seed.sql (solo local), aquí no hay usuarios,
-- alumnos ni reservas de prueba: solo la sede, el horario y las tarifas.
-- Idempotente: si la sede ya existe, no hace nada.
--
-- Uso: npm run db:setup-production

do $$
begin
  if exists (select 1 from public.gyms where id = '00000000-0000-4000-a000-000000000001') then
    raise notice 'La sede ya existe: no se cambia nada';
    return;
  end if;

  insert into public.gyms (id, name) values ('00000000-0000-4000-a000-000000000001', 'ITACA Jiu Jitsu');
  update public.gyms set settings = settings || '{"contact": {"email": "contacto@tu-gimnasio.com", "phone": "+34600000000", "whatsapp": "34600000000", "address": "Calle Ejemplo, 1 · 00000 Tu ciudad", "instagram": "tu_gimnasio", "web": "https://www.tu-gimnasio.com"}}'::jsonb
  where id = '00000000-0000-4000-a000-000000000001';

  -- Horario tomado de https://www.tu-gimnasio.com (15/11/2026). Profesor y aforo, por confirmar.
  insert into public.disciplines (gym_id, slug, name, kind, sort) values
    ('00000000-0000-4000-a000-000000000001', 'gi',      'BJJ Gi',   'gi',      1),
    ('00000000-0000-4000-a000-000000000001', 'nogi',    'No Gi',    'nogi',    2),
    ('00000000-0000-4000-a000-000000000001', 'kids',    'Infantil', 'kids',    3),
    ('00000000-0000-4000-a000-000000000001', 'openmat', 'Open Mat', 'openmat', 4);
  
  -- Cada plantilla genera sus sesiones de 4 semanas al insertarse (trigger)
  insert into public.class_templates
    (gym_id, discipline_id, name, level, weekdays, start_time, duration_min, capacity, min_age, max_age, valid_from)
  select '00000000-0000-4000-a000-000000000001', d.id, c.name, c.level, c.weekdays, c.start_time::time, c.duration, c.capacity,
         c.min_age, c.max_age, current_date - 7
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

  -- Tarifas vigentes (capturas de la app actual, 15/11/2026)
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
  update public.plans set weekly_sessions = 1 where slug = '1-dia-semana';
end $$;

select 'sede: ' || (select name from public.gyms) || ' · clases: ' || (select count(*) from public.class_templates)
  || ' · sesiones generadas: ' || (select count(*) from public.class_sessions) || ' · tarifas: ' || (select count(*) from public.plans);
