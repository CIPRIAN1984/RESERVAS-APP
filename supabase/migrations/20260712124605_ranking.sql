-- ITACA — Fase 5: Estadísticas (módulo 2).
--
-- Ranking mensual por número de asistencias validadas. Sin tabla propia:
-- se agrega directamente sobre `asistencias` + `profiles`. Incluye a todos
-- los alumnos de la academia (también los de 0 asistencias), para que cada
-- uno vea su posición real.

create or replace function public.ranking_mensual(p_mes date default date_trunc('month', now())::date)
returns table (
  alumno_id uuid,
  nombre text,
  apellidos text,
  foto_url text,
  cinturon text,
  asistencias_count bigint
)
language sql
stable
as $$
  select
    p.id as alumno_id,
    p.nombre,
    p.apellidos,
    p.foto_url,
    p.cinturon,
    count(a.id) as asistencias_count
  from public.profiles p
  left join public.asistencias a
    on a.alumno_id = p.id
    and date_trunc('month', a.fecha) = date_trunc('month', p_mes::timestamptz)
  where p.rol = 'alumno' and p.academia_id = public.current_academia_id()
  group by p.id, p.nombre, p.apellidos, p.foto_url, p.cinturon
  order by asistencias_count desc, p.nombre asc;
$$;
