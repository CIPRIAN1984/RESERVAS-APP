-- Listo para graduarse en Miembros: quién ya cumple los entrenos que hacen
-- falta para el siguiente cinturón.
--
-- El cálculo en sí (cuántos entrenos hacen falta, dónde arranca el reloj,
-- niños vs adultos) ya vive en Dart (`progreso_cinturon.dart`) y ya se
-- consulta uno a uno desde la ficha del alumno (`contarAsistenciasDesde` +
-- `esMenor`). Esta función no repite esas reglas: solo trae, en un único
-- viaje, los dos datos en bruto que hacen falta para aplicarlas a TODA la
-- academia de golpe (166 alumnos uno a uno serían 332 consultas, la lista
-- de rodillas) — cuántos entrenos lleva cada alumno desde que empezó su
-- cinturón actual, y si es menor de edad (para saber qué escala usar).
--
-- Mismo patrón que ranking_periodo y ultima_asistencia_por_alumno:
-- `language sql stable`, sin security definer (RLS ya limita todo esto a
-- la propia academia).

create function public.progreso_graduacion_alumnos()
returns table (
  alumno_id uuid,
  asistencias bigint,
  es_menor boolean
)
language sql
stable
as $$
  select
    p.id as alumno_id,
    count(a.id) as asistencias,
    exists (
      select 1 from public.relaciones_familia rf where rf.child_id = p.id
    ) as es_menor
  from public.profiles p
  left join public.asistencias a
    on a.alumno_id = p.id
    and a.fecha >= coalesce(p.fecha_inicio_cinturon, now())
  where p.rol = 'alumno' and p.academia_id = public.current_academia_id()
  group by p.id;
$$;

revoke all on function public.progreso_graduacion_alumnos() from public, anon;
grant execute on function public.progreso_graduacion_alumnos() to authenticated;
alter function public.progreso_graduacion_alumnos()
  set search_path = public, pg_temp;
