-- Ranking por periodo: mes actual, año actual o desde siempre.
--
-- Sustituye a `ranking_mensual`, que solo admitía un mes concreto. Cipri
-- pidió poder filtrar como en MAAT: mes, año o histórico completo. En vez
-- de mantener dos funciones (una quedaría muerta y sin usar desde Flutter),
-- se sustituye por una sola con rango abierto: `p_desde`/`p_hasta` nulos
-- significa sin límite por ese lado, así que los tres casos (mes, año,
-- siempre) son el mismo código con distintas fechas calculadas en el
-- cliente.
drop function if exists public.ranking_mensual(date);

create function public.ranking_periodo(
  p_desde date default null,
  p_hasta date default null
)
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
    and (p_desde is null or a.fecha >= p_desde::timestamptz)
    and (p_hasta is null or a.fecha < (p_hasta + 1)::timestamptz)
  where p.rol = 'alumno' and p.academia_id = public.current_academia_id()
  group by p.id, p.nombre, p.apellidos, p.foto_url, p.cinturon
  order by asistencias_count desc, p.nombre asc;
$$;

revoke all on function public.ranking_periodo(date, date) from public, anon;
grant execute on function public.ranking_periodo(date, date) to authenticated;
alter function public.ranking_periodo(date, date)
  set search_path = public, pg_temp;
