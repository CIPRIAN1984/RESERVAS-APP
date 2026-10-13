-- ITACA — Auditoría externa del 09/10/2026, punto 4: reservas que se quedan
-- sin clases después de confirmadas.
--
-- Qué pasa: reservar comprueba el saldo en ese momento. Si después el Dueño
-- pausa o reanuda una cuota con una renovación pagada, o mueve una clase de
-- fecha, la reserva puede caer en otro ciclo o en otra cuota y pasarse de
-- las clases de la tarifa. Nadie lo volvía a mirar.
--
-- Decisión de Cipri (09/10/2026): esas reservas **se mantienen**, y en la
-- lista de la clase salen marcadas «sin clases» para cobrarlas en mano,
-- igual que ya se hace con «sin cuota».
--
-- Cómo: la marca se calcula al leer, no se guarda. Así no hay que acordarse
-- de recalcular nada en pausar, reanudar, mover una clase, perdonar una
-- cancelación… : siempre sale de lo que hay. Si en el ciclo de la clase el
-- alumno tiene contadas más clases de las que incluye su tarifa (con sus
-- extras), las que sobran son las ÚLTIMAS por fecha: las primeras estaban
-- cubiertas cuando se reservaron.
--
-- De paso, «sin cuota» también se calcula aquí, con la fecha de la clase.
-- La app lo miraba con la cuota de HOY, y desde el 25/09 el servidor exige
-- la cuota del día de la clase: una clase de después de que acabe la cuota
-- salía sin marcar.

-- ============================================================
-- 1. Qué clases cuentan en un ciclo, una a una
-- ============================================================
-- Las mismas que contaba `_consumo_ciclo` (20261009110000), pero con su
-- identificador y su fecha. `_consumo_ciclo` pasa a contar sobre esta, para
-- que el saldo y la marca no puedan dejar de coincidir.

create or replace function public._clases_contadas(
  p_alumno_id uuid,
  p_suscripcion_id uuid,
  p_inicio timestamptz,
  p_fin timestamptz
)
returns table (clase_id uuid, inicio timestamptz, gastada boolean)
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  with clases_del_ciclo as (
    -- Las del ciclo que no son de dentro de una pausa de esta cuota (a
    -- esas se va «sin cuota») ni canceladas por la academia.
    select c.id, c.fecha_hora_inicio, c.fecha_hora_fin
      from public.clases c
     where c.estado <> 'cancelada'
       and c.fecha_hora_inicio >= p_inicio
       and c.fecha_hora_inicio < p_fin
       and not exists (
         select 1 from public.pausas_suscripcion p
          where p.suscripcion_id = p_suscripcion_id
            and c.fecha_hora_inicio >= p.desde
            and c.fecha_hora_inicio < coalesce(p.hasta, 'infinity')
       )
  ),
  consumidas as (
    select a.clase_id
      from public.asistencias a
      join clases_del_ciclo c on c.id = a.clase_id
     where a.alumno_id = p_alumno_id
    union
    select i.clase_id
      from public.inscripciones i
      join clases_del_ciclo c on c.id = i.clase_id
     where i.alumno_id = p_alumno_id
       and i.estado = 'inscrito'
       and c.fecha_hora_fin <= now()
       and not exists (
         select 1 from public.asistencias a2
          where a2.clase_id = i.clase_id and a2.alumno_id = i.alumno_id
       )
    union
    select i.clase_id
      from public.inscripciones i
      join clases_del_ciclo c on c.id = i.clase_id
     where i.alumno_id = p_alumno_id
       and i.estado = 'cancelado'
       and i.cancelacion_tardia = true
  ),
  reservadas as (
    select i.clase_id
      from public.inscripciones i
      join clases_del_ciclo c on c.id = i.clase_id
     where i.alumno_id = p_alumno_id
       and i.estado = 'inscrito'
       and c.fecha_hora_fin > now()
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
       )
  )
  select c.id, c.fecha_hora_inicio, true
    from consumidas k join clases_del_ciclo c on c.id = k.clase_id
  union all
  select c.id, c.fecha_hora_inicio, false
    from reservadas r join clases_del_ciclo c on c.id = r.clase_id;
$function$;

revoke all on function public._clases_contadas(uuid, uuid, timestamptz, timestamptz)
  from public, anon, authenticated;

create or replace function public._consumo_ciclo(
  p_alumno_id uuid,
  p_suscripcion_id uuid,
  p_inicio timestamptz,
  p_fin timestamptz,
  out gastadas int,
  out reservadas int
)
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select (count(*) filter (where gastada))::int,
         (count(*) filter (where not gastada))::int
    from public._clases_contadas(p_alumno_id, p_suscripcion_id, p_inicio, p_fin);
$function$;

revoke all on function public._consumo_ciclo(uuid, uuid, timestamptz, timestamptz)
  from public, anon, authenticated;

-- ============================================================
-- 2. ¿Esta reserva se pasa de las clases de su tarifa?
-- ============================================================

create or replace function public._reserva_sin_clases(
  p_alumno_id uuid,
  p_clase_id uuid,
  p_inicio timestamptz
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_saldo jsonb;
  v_exceso int;
  v_suscripcion record;
  v_ciclo record;
  v_posicion int;
begin
  v_saldo := public._saldo_clases(p_alumno_id, p_inicio);

  if not (v_saldo->>'tiene_cuota')::boolean
     or (v_saldo->>'ilimitada')::boolean then
    return false;
  end if;

  v_exceso := (v_saldo->>'gastadas')::int + (v_saldo->>'reservadas')::int
              - (v_saldo->>'incluidas')::int;
  if v_exceso <= 0 then
    return false;
  end if;

  -- La misma cuota y el mismo ciclo que ha usado `_saldo_clases`.
  select s.*
    into v_suscripcion
    from public.suscripciones s
   where s.alumno_id = p_alumno_id
     and s.estado in ('activa', 'prueba', 'programada')
     and s.payment_status = 'active'
     and s.fecha_inicio <= p_inicio
     and (s.fecha_fin is null or s.fecha_fin > p_inicio)
   order by s.fecha_inicio desc
   limit 1;

  select * into v_ciclo
    from public.ciclo_de_suscripcion(
      v_suscripcion.id,
      v_suscripcion.fecha_inicio,
      v_suscripcion.fecha_fin,
      v_suscripcion.periodicidad,
      p_inicio
    );

  -- Sobran las últimas por fecha.
  select x.posicion into v_posicion
    from (
      select k.clase_id,
             row_number() over (order by k.inicio desc, k.clase_id desc) as posicion
        from public._clases_contadas(
          p_alumno_id, v_suscripcion.id, v_ciclo.inicio, v_ciclo.fin
        ) k
    ) x
   where x.clase_id = p_clase_id;

  return v_posicion is not null and v_posicion <= v_exceso;
end;
$function$;

revoke all on function public._reserva_sin_clases(uuid, uuid, timestamptz)
  from public, anon, authenticated;

-- ============================================================
-- 3. Lo que ve el staff en la lista de la clase
-- ============================================================

create or replace function public.estado_cuota_participantes(p_clase_id uuid)
returns table (alumno_id uuid, sin_cuota boolean, sin_clases boolean)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_rol text;
  v_actor_academia uuid;
  v_actor_estado text;
  v_clase_academia uuid;
  v_inicio timestamptz;
begin
  select rol, academia_id, estado
    into v_actor_rol, v_actor_academia, v_actor_estado
    from public.profiles
   where id = auth.uid();

  -- `coalesce`: sin perfil todo es NULL y un `if NULL` no lanza nada
  -- (ver 20261009090000_permisos_sin_perfil.sql).
  if not coalesce(
    v_actor_rol in ('dueño', 'profesor') and v_actor_estado = 'activo',
    false
  ) then
    raise exception 'Solo el Dueño o un Profesor ven el estado de cuota de la clase.';
  end if;

  select c.academia_id, c.fecha_hora_inicio
    into v_clase_academia, v_inicio
    from public.clases c
   where c.id = p_clase_id;

  if not found or v_clase_academia is distinct from v_actor_academia then
    raise exception 'Clase no encontrada.';
  end if;

  return query
    select i.alumno_id,
           p.rol = 'alumno'
             and not public._cuota_cubre(i.alumno_id, v_clase_academia, v_inicio),
           p.rol = 'alumno'
             and i.estado = 'inscrito'
             and public._reserva_sin_clases(i.alumno_id, p_clase_id, v_inicio)
      from public.inscripciones i
      join public.profiles p on p.id = i.alumno_id
     where i.clase_id = p_clase_id
       and i.estado in ('inscrito', 'espera');
end;
$function$;

revoke all on function public.estado_cuota_participantes(uuid) from public, anon;
grant execute on function public.estado_cuota_participantes(uuid) to authenticated;
