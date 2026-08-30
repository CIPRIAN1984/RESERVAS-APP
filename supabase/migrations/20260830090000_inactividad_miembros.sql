-- Inactividad en Miembros: cuándo entrenó cada alumno por última vez.
--
-- Mismo motivo que llevó a Miembros a existir (mirando MAAT): el Dueño
-- necesita ver de un vistazo quién ha dejado de venir, no solo quién no ha
-- pagado — son dos señales distintas y las dos importan. Ver el comentario
-- de cabecera de miembros_screen.dart (0048): esto era justo lo que faltaba
-- por datos ("prueba/pausada, listo para graduarse, inactividad"). Prueba y
-- pausada ya están; esta migración cierra "inactividad".
--
-- Mismo patrón que ranking_periodo (0044): `language sql stable`, sin
-- security definer (no hace falta: RLS de asistencias ya limita a la propia
-- academia — esto solo evita traer todo el historial de asistencias al
-- cliente para calcularlo ahí, que con 166 alumnos y meses de clases sería
-- mucho tráfico para quedarse solo con una fecha por alumno).

create function public.ultima_asistencia_por_alumno()
returns table (
  alumno_id uuid,
  ultima_asistencia timestamptz
)
language sql
stable
as $$
  select a.alumno_id, max(a.fecha) as ultima_asistencia
    from public.asistencias a
    join public.profiles p on p.id = a.alumno_id
   where p.rol = 'alumno' and p.academia_id = public.current_academia_id()
   group by a.alumno_id;
$$;

revoke all on function public.ultima_asistencia_por_alumno() from public, anon;
grant execute on function public.ultima_asistencia_por_alumno() to authenticated;
alter function public.ultima_asistencia_por_alumno()
  set search_path = public, pg_temp;
