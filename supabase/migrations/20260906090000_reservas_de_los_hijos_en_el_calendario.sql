-- Reservar por un hijo desde el calendario, tercera y última tanda de
-- familias.
--
-- La base de datos ya aceptaba `reservar_clase(p_clase_id, p_alumno_id)`
-- desde la migración 20260903130000. Lo que faltaba era el camino de vuelta:
-- `listar_clases_semana` solo devolvía `mi_estado`, el estado del que
-- llama. Con eso un padre apuntaba al niño, la inscripción se creaba de
-- verdad… y la tarjeta de la clase seguía diciendo «Reservar plaza», como
-- si no hubiera pasado nada.
--
-- Se añade una columna `reservas_familia`: la reserva de cada hijo que
-- tenga plaza o esté en lista de espera en esa clase. Solo los hijos —lo
-- mío sigue en `mi_estado`, que ya funcionaba y no se toca.
--
-- Arista de verdad: esta migración va antes que la pantalla. Al revés, la
-- app pediría una columna que no existe y el calendario entero dejaría de
-- cargar.

-- La función no es `security definer`: se ejecuta como quien llama, así que
-- la RLS sigue mandando. Un padre puede leer estas filas porque
-- `relaciones_familia_select` le deja ver sus relaciones y
-- `inscripciones_select` le deja ver las inscripciones de su academia. No se
-- abre nada nuevo: solo se le ahorra una consulta por tarjeta.
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
  pendientes_confirmar bigint,
  reservas_familia jsonb
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
         )) as pendientes_confirmar,
    -- `coalesce` y no un null: la app trata la ausencia de hijos y la de
    -- reservas igual, como una lista vacía. Devolver null obligaría a
    -- comprobarlo en cada tarjeta.
    coalesce(
      (select jsonb_agg(
                jsonb_build_object('alumno_id', i.alumno_id, 'estado', i.estado)
                order by i.alumno_id
              )
         from public.inscripciones i
         where i.clase_id = c.id
           and i.estado in ('inscrito', 'espera')
           and i.alumno_id in (
             select rf.child_id from public.relaciones_familia rf
             where rf.parent_id = auth.uid()
           )),
      '[]'::jsonb
    ) as reservas_familia
  from public.clases c
  join public.profiles p on p.id = c.profesor_id
  where c.fecha_hora_inicio >= p_desde and c.fecha_hora_inicio < p_hasta
  order by c.fecha_hora_inicio;
$$;

revoke all on function public.listar_clases_semana(timestamptz, timestamptz)
  from public, anon;
grant execute on function public.listar_clases_semana(timestamptz, timestamptz)
  to authenticated;
