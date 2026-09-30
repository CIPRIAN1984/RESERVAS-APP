-- ITACA — Excepciones del descuento de clases, y perdonar una cancelación
-- tardía.
--
-- Auditoría externa del 30/09/2026, punto 2:
--
-- 1. Cancelar tarde y volver a reservar la MISMA clase la contaba dos
--    veces: una por la cancelación tardía y otra por la reserva nueva (o
--    su asistencia). Ahora cada clase cuenta como mucho una vez.
--
-- 2. Si la academia cancelaba la clase entera, las cancelaciones tardías de
--    esa clase seguían descontando aunque la clase no se diera. Ahora una
--    clase cancelada no gasta nada.
--
-- 3. No había forma normal de perdonar una cancelación tardía ya
--    registrada (límite anotado en DECISIONS.md el 20/09). Nueva RPC
--    `perdonar_cancelacion_tardia`, para el Dueño y el Profesor de la
--    academia (decisión de Cipri, 30/09/2026). Queda rastro de quién
--    perdonó y cuándo.

-- ============================================================
-- 1. Rastro del perdón
-- ============================================================
-- Sin permisos para la app: solo las escribe la RPC (security definer) y la
-- app no las lee. `inscripciones` no tiene UPDATE para `authenticated` y el
-- SELECT está concedido columna a columna, así que las columnas nuevas nacen
-- cerradas.

alter table public.inscripciones
  add column if not exists tardia_perdonada_por uuid references public.profiles (id),
  add column if not exists tardia_perdonada_at timestamptz;

-- ============================================================
-- 2. _saldo_clases: cada clase una vez; las canceladas no cuentan
-- ============================================================

create or replace function public._saldo_clases(
  p_alumno_id uuid,
  p_referencia timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_suscripcion record;
  v_ciclo record;
  v_gastadas int;
  v_reservadas int;
begin
  select s.*, t.clases_incluidas, t.periodicidad, t.nombre as tarifa_nombre
    into v_suscripcion
    from public.suscripciones s
    join public.tarifas t on t.id = s.tarifa_id
   where s.alumno_id = p_alumno_id
     and s.estado in ('activa', 'prueba')
     and s.payment_status = 'active'
     and s.fecha_inicio <= p_referencia
     and (s.fecha_fin is null or s.fecha_fin > p_referencia)
   order by s.fecha_inicio desc
   limit 1;

  if not found then
    return jsonb_build_object(
      'tiene_cuota', false,
      'ilimitada', false,
      'incluidas', 0,
      'gastadas', 0,
      'reservadas', 0,
      'disponibles', 0
    );
  end if;

  select * into v_ciclo
    from public.ciclo_en(
      v_suscripcion.fecha_inicio,
      v_suscripcion.fecha_fin,
      v_suscripcion.periodicidad,
      p_referencia
    );

  if v_suscripcion.clases_incluidas is null then
    return jsonb_build_object(
      'tiene_cuota', true,
      'ilimitada', true,
      'tarifa', v_suscripcion.tarifa_nombre,
      'ciclo_inicio', v_ciclo.inicio,
      'ciclo_fin', v_ciclo.fin
    );
  end if;

  -- Gastadas: clases distintas del ciclo, no canceladas por la academia,
  -- con asistencia, no presentado o cancelación tardía. `union` (sin `all`)
  -- deja cada clase una sola vez aunque venga de dos orígenes: cancelar
  -- tarde y volver a reservar la misma clase ya no la cuenta dos veces.
  with consumidas as (
    select a.clase_id
      from public.asistencias a
      join public.clases c on c.id = a.clase_id
     where a.alumno_id = p_alumno_id
       and c.estado <> 'cancelada'
       and c.fecha_hora_inicio >= v_ciclo.inicio
       and c.fecha_hora_inicio < v_ciclo.fin
    union
    select i.clase_id
      from public.inscripciones i
      join public.clases c on c.id = i.clase_id
     where i.alumno_id = p_alumno_id
       and i.estado = 'inscrito'
       and c.estado <> 'cancelada'
       and c.fecha_hora_fin <= now()
       and c.fecha_hora_inicio >= v_ciclo.inicio
       and c.fecha_hora_inicio < v_ciclo.fin
       and not exists (
         select 1 from public.asistencias a2
          where a2.clase_id = i.clase_id and a2.alumno_id = i.alumno_id
       )
    union
    select i.clase_id
      from public.inscripciones i
      join public.clases c on c.id = i.clase_id
     where i.alumno_id = p_alumno_id
       and i.estado = 'cancelado'
       and i.cancelacion_tardia = true
       and c.estado <> 'cancelada'
       and c.fecha_hora_inicio >= v_ciclo.inicio
       and c.fecha_hora_inicio < v_ciclo.fin
  )
  select count(*)::int into v_gastadas from consumidas;

  -- Reservadas: inscrito, la clase aún no ha terminado, sin asistencia… y
  -- que no esté ya contada como gastada por una cancelación tardía de esa
  -- misma clase.
  select count(*)::int into v_reservadas
    from public.inscripciones i
    join public.clases c on c.id = i.clase_id
   where i.alumno_id = p_alumno_id
     and i.estado = 'inscrito'
     and c.estado <> 'cancelada'
     and c.fecha_hora_fin > now()
     and c.fecha_hora_inicio >= v_ciclo.inicio
     and c.fecha_hora_inicio < v_ciclo.fin
     and not exists (
       select 1 from public.asistencias a
        where a.clase_id = i.clase_id and a.alumno_id = i.alumno_id
     )
     and not exists (
       select 1 from public.inscripciones t
        where t.clase_id = i.clase_id
          and t.alumno_id = i.alumno_id
          and t.estado = 'cancelado'
          and t.cancelacion_tardia = true
     );

  return jsonb_build_object(
    'tiene_cuota', true,
    'ilimitada', false,
    'tarifa', v_suscripcion.tarifa_nombre,
    'incluidas', v_suscripcion.clases_incluidas,
    'gastadas', v_gastadas,
    'reservadas', v_reservadas,
    'disponibles', greatest(
      0, v_suscripcion.clases_incluidas - v_gastadas - v_reservadas
    ),
    'ciclo_inicio', v_ciclo.inicio,
    'ciclo_fin', v_ciclo.fin
  );
end;
$function$;

revoke all on function public._saldo_clases(uuid, timestamptz)
  from public, anon, authenticated;

-- ============================================================
-- 3. perdonar_cancelacion_tardia
-- ============================================================

create or replace function public.perdonar_cancelacion_tardia(
  p_clase_id uuid,
  p_alumno_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_academia uuid;
  v_actor_rol text;
  v_actor_estado text;
  v_clase_academia uuid;
  v_inscripcion_id uuid;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select academia_id, rol, estado
    into v_actor_academia, v_actor_rol, v_actor_estado
    from public.profiles
   where id = v_actor_id;

  if not found
     or v_actor_rol not in ('dueño', 'profesor')
     or v_actor_estado <> 'activo' then
    raise exception 'Solo el Dueño o un Profesor pueden perdonar una cancelación.';
  end if;

  select academia_id into v_clase_academia
    from public.clases
   where id = p_clase_id;

  if not found or v_clase_academia is distinct from v_actor_academia then
    raise exception 'Clase no encontrada.';
  end if;

  -- Puede haber más de una fila cancelada del mismo alumno en la clase
  -- (canceló, volvió a reservar, volvió a cancelar): se perdonan todas las
  -- tardías, que es lo que el staff quiere decir con «perdónale esta clase».
  select id into v_inscripcion_id
    from public.inscripciones
   where clase_id = p_clase_id
     and alumno_id = p_alumno_id
     and estado = 'cancelado'
     and cancelacion_tardia = true
   limit 1
   for update;

  if not found then
    raise exception 'Esa cancelación no cuenta como tardía: no hay nada que perdonar.';
  end if;

  update public.inscripciones
     set cancelacion_tardia = false,
         tardia_perdonada_por = v_actor_id,
         tardia_perdonada_at = now()
   where clase_id = p_clase_id
     and alumno_id = p_alumno_id
     and estado = 'cancelado'
     and cancelacion_tardia = true;
end;
$function$;

revoke all on function public.perdonar_cancelacion_tardia(uuid, uuid) from public, anon;
grant execute on function public.perdonar_cancelacion_tardia(uuid, uuid) to authenticated;
