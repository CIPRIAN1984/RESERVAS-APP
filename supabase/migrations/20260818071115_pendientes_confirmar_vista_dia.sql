-- Primera fase de mejoras tras el piloto, punto 2: «Confirmar todos» solo
-- vivía dentro del detalle de cada clase (ClaseDetalleScreen). Cipri lo
-- quiere también en la vista de día, sin tener que entrar en cada clase
-- una por una.
--
-- Para que la tarjeta de cada clase sepa si mostrar el botón (y cuántos
-- faltan) sin una consulta aparte por tarjeta, listar_clases_semana()
-- devuelve ahora cuántos inscritos tienen la asistencia sin validar.
--
-- Construida sobre 20260818063921_gestionar_clase_publicada.sql (añade el
-- estado de la clase a la misma RPC): este PR depende de ese, no es una
-- arista falsa — extiende la misma función.

drop function if exists public.listar_clases_semana(timestamptz, timestamptz);

create function public.listar_clases_semana(p_desde timestamptz, p_hasta timestamptz)
returns table (
  id uuid,
  titulo text,
  descripcion text,
  fecha_hora_inicio timestamptz,
  fecha_hora_fin timestamptz,
  aforo_maximo int,
  profesor_id uuid,
  profesor_nombre text,
  inscritos_count bigint,
  mi_estado text,
  estado text,
  pendientes_confirmar bigint
)
language sql
stable
set search_path = public, pg_temp
as $$
  select
    c.id,
    c.titulo,
    c.descripcion,
    c.fecha_hora_inicio,
    c.fecha_hora_fin,
    c.aforo_maximo,
    c.profesor_id,
    p.nombre as profesor_nombre,
    (select count(*) from public.inscripciones i
       where i.clase_id = c.id and i.estado = 'inscrito') as inscritos_count,
    (select i.estado from public.inscripciones i
       where i.clase_id = c.id and i.alumno_id = auth.uid()
       order by i.created_at desc limit 1) as mi_estado,
    c.estado,
    (select count(*) from public.inscripciones i
       where i.clase_id = c.id
         and i.estado = 'inscrito'
         and not exists (
           select 1 from public.asistencias a
           where a.clase_id = c.id and a.alumno_id = i.alumno_id
         )) as pendientes_confirmar
  from public.clases c
  join public.profiles p on p.id = c.profesor_id
  where c.fecha_hora_inicio >= p_desde and c.fecha_hora_inicio < p_hasta
  order by c.fecha_hora_inicio;
$$;

revoke all on function public.listar_clases_semana(timestamptz, timestamptz)
  from public, anon;
grant execute on function public.listar_clases_semana(timestamptz, timestamptz)
  to authenticated;
