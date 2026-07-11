-- Tests pgTAP del motor de clases recurrentes (migración 0020): generación
-- correcta desde plantillas e idempotencia.

begin;
select plan(3);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'profC@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000000CC', 'Academia C', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000CC', 'profesor', 'Prof C', 'activo');

-- Plantilla que cae en lunes (dow = 1) a las 19:00, 60 min, aforo 20.
insert into public.clases_recurrentes
  (id, academia_id, profesor_id, titulo, dia_semana, hora_inicio, duracion_min, aforo_maximo, fecha_inicio)
values
  ('00000000-0000-0000-0000-000000000e01', '00000000-0000-0000-0000-0000000000CC', '00000000-0000-0000-0000-0000000000c1', 'BJJ Fundamentals', 1, '19:00', 60, 20, current_date - 7);

-- Genera en una ventana fija de 28 días desde el lunes más próximo pasado, para
-- que el número de lunes sea determinista (4 semanas => 4 lunes).
-- Nos apoyamos en la RPC global (ejecutada aquí como superusuario).
select ok(
  (select public.generar_clases_recurrentes(
    date_trunc('week', current_date)::date,
    (date_trunc('week', current_date) + interval '28 days')::date
  )) = 4,
  'Genera exactamente 4 sesiones (4 lunes en 28 días)'
);

select is(
  (select count(*)::int from public.clases where plantilla_id = '00000000-0000-0000-0000-000000000e01'),
  4,
  'Las 4 sesiones quedan enlazadas a su plantilla'
);

-- Re-ejecutar no duplica (idempotencia por el índice único + ON CONFLICT).
select is(
  (select public.generar_clases_recurrentes(
    date_trunc('week', current_date)::date,
    (date_trunc('week', current_date) + interval '28 days')::date
  )),
  0,
  'Una segunda generación en la misma ventana no crea duplicados'
);

select * from finish();
rollback;
