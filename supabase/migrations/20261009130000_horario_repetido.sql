-- ITACA — Auditoría externa del 09/10/2026, punto 5: crear clases
-- repetidas de golpe, sin huecos ni duplicados y sin saltos de hora.
--
-- 1. «Clase periódica» se creaba desde la app con un bucle: una inserción
--    por semana. Si fallaba a mitad (la conexión, un permiso), quedaban
--    creadas las primeras; al repetir, salían duplicadas. Ahora es una sola
--    llamada al servidor (`crear_clases`), que crea todas o ninguna, y que
--    se salta la que ya exista (mismo título y misma hora): repetir no
--    duplica, tampoco si el reintento llega mientras la primera petición
--    aún trabaja (un candado por academia las pone en fila).
-- 2. La app sumaba 7 días exactos a la fecha y hora. Al cruzar el cambio
--    de hora (último domingo de marzo y de octubre), la clase de las 19:00
--    pasaba a las 18:00 o a las 20:00. Ahora el servidor pone cada semana
--    la fecha y la hora de la pared en la zona horaria de la academia, como
--    ya hacía el horario fijo (`generar_clases_recurrentes`).
-- 3. `generar_mis_clases_recurrentes` (el botón que genera ya las clases
--    del horario fijo) fallaba SIEMPRE por un error de fechas. Nadie lo vio
--    porque no hay horario fijo creado. De paso, su comprobación de rol pasa
--    a resistir una cuenta sin perfil.

create or replace function public.generar_mis_clases_recurrentes()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_academia uuid := public.current_academia_id();
  v_generadas int;
begin
  -- `coalesce`: sin perfil, `current_rol()` es NULL y un `if NULL` no
  -- lanza nada (ver 20261009090000_permisos_sin_perfil.sql).
  if not coalesce(public.current_rol() in ('profesor', 'dueño'), false) then
    raise exception 'Solo profesor o dueño pueden generar clases.';
  end if;

  with dias as (
    select d::date as dia
      from generate_series(
        current_date,
        -- Era `(current_date + interval '28 days') - 1`: fecha y hora menos
        -- un entero, que Postgres no sabe restar. La función fallaba
        -- siempre (09/10/2026).
        current_date + 27,
        interval '1 day'
      ) as d
  ),
  sesiones as (
    select
      cr.id as plantilla_id,
      cr.academia_id,
      cr.profesor_id,
      cr.titulo,
      cr.descripcion,
      ((dias.dia + cr.hora_inicio) at time zone a.zona_horaria) as inicio,
      (
        ((dias.dia + cr.hora_inicio) at time zone a.zona_horaria)
        + make_interval(mins => cr.duracion_min)
      ) as fin,
      cr.aforo_maximo
    from public.clases_recurrentes cr
    join public.academias a on a.id = cr.academia_id
    join dias
      on extract(dow from dias.dia)::int = cr.dia_semana
    where cr.activo
      and cr.academia_id = v_academia
      and dias.dia >= cr.fecha_inicio
      and (cr.fecha_fin is null or dias.dia <= cr.fecha_fin)
  ),
  insertadas as (
    insert into public.clases (
      academia_id,
      profesor_id,
      titulo,
      descripcion,
      fecha_hora_inicio,
      fecha_hora_fin,
      aforo_maximo,
      plantilla_id
    )
    select
      academia_id,
      profesor_id,
      titulo,
      descripcion,
      inicio,
      fin,
      aforo_maximo,
      plantilla_id
    from sesiones
    on conflict (
      plantilla_id,
      fecha_hora_inicio
    ) where plantilla_id is not null
    do nothing
    returning 1
  )
  select count(*)::int into v_generadas from insertadas;

  return v_generadas;
end;
$function$;


-- ============================================================
-- crear_clases: una clase o la misma durante varias semanas
-- ============================================================

create or replace function public.crear_clases(
  p_titulo text,
  p_descripcion text,
  p_fecha date,
  p_hora_inicio time,
  p_hora_fin time,
  p_aforo_maximo integer,
  p_semanas integer default 1
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_rol text;
  v_estado text;
  v_academia uuid;
  v_zona text;
  v_creadas int;
begin
  select rol, estado, academia_id
    into v_rol, v_estado, v_academia
    from public.profiles
   where id = v_actor_id;

  if not coalesce(v_rol in ('dueño', 'profesor') and v_estado = 'activo', false)
     or v_academia is null then
    raise exception 'Solo el Dueño o un Profesor pueden crear clases.';
  end if;

  if p_titulo is null or trim(p_titulo) = '' then
    raise exception 'El título no puede estar vacío.';
  end if;

  if p_hora_fin <= p_hora_inicio then
    raise exception 'La hora de fin debe ser posterior a la de inicio.';
  end if;

  if p_aforo_maximo is null or p_aforo_maximo <= 0 then
    raise exception 'El aforo debe ser mayor que cero.';
  end if;

  if p_semanas is null or p_semanas < 1 or p_semanas > 52 then
    raise exception 'Se pueden repetir entre 1 y 52 semanas.';
  end if;

  -- Una petición de crear clases a la vez por academia. Sin esto, un
  -- reintento mientras la primera aún trabaja no ve sus clases (no se han
  -- confirmado) y las duplica: comprobado con dos sesiones a la vez
  -- (09/10/2026). Con el candado, la segunda espera y se las salta.
  perform pg_advisory_xact_lock(7302, hashtext(v_academia::text));

  select zona_horaria into v_zona from public.academias where id = v_academia;

  with semanas as (
    select p_fecha + 7 * n as dia
      from generate_series(0, p_semanas - 1) as n
  ),
  sesiones as (
    -- Fecha y hora «de la pared» en la zona de la academia: las 19:00 son
    -- las 19:00 también después del cambio de hora.
    select (dia + p_hora_inicio) at time zone v_zona as inicio,
           (dia + p_hora_fin) at time zone v_zona as fin
      from semanas
  ),
  insertadas as (
    insert into public.clases (
      academia_id, profesor_id, titulo, descripcion,
      fecha_hora_inicio, fecha_hora_fin, aforo_maximo
    )
    select v_academia, v_actor_id, trim(p_titulo), nullif(trim(p_descripcion), ''),
           s.inicio, s.fin, p_aforo_maximo
      from sesiones s
     -- Repetir no duplica: se salta la que ya existe con el mismo título y
     -- la misma hora en la academia.
     where not exists (
       select 1 from public.clases c
        where c.academia_id = v_academia
          and c.titulo = trim(p_titulo)
          and c.fecha_hora_inicio = s.inicio
          and c.estado <> 'cancelada'
     )
    returning 1
  )
  select count(*)::int into v_creadas from insertadas;

  return v_creadas;
end;
$function$;

revoke all on function public.crear_clases(text, text, date, time, time, integer, integer)
  from public, anon;
grant execute on function public.crear_clases(text, text, date, time, time, integer, integer)
  to authenticated;
