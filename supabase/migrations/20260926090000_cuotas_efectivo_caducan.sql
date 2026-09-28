-- ITACA — Las cuotas en efectivo caducan de verdad, y una pausa congela el
-- tiempo que quedaba en vez de regalarlo.
--
-- Auditoría externa del 23/09/2026, punto 5. Dos fallos de la misma raíz:
--
-- 1. Una cuota en efectivo con la fecha de fin ya pasada seguía en
--    estado 'activa' para siempre: nada la pasaba a 'expirada' (solo se
--    cerraba al dar una cuota nueva). La reserva y Miembros miraban las
--    fechas y la trataban como caducada, pero Equipo solo miraba el estado
--    y la enseñaba «al día». En producción había 10 así a 26/09/2026.
--
-- 2. `reanudar_cuota_efectivo` —y el job, al reanudar una pausa con
--    fecha— dejaban `fecha_fin = null`: una cuota mensual pausada y
--    reanudada no caducaba nunca. Pausar dos días regalaba clases gratis
--    para siempre.
--
-- Arreglo:
--   * `resto_al_pausar`: al pausar se guarda cuánto le quedaba a la cuota
--     (null si no tenía fecha de fin). Al reanudar se devuelve ese resto
--     desde el momento de la reanudación.
--   * `expirar_pruebas_y_pausas()` (el job de cada 15 min) pasa además a
--     'expirada' las cuotas en efectivo 'activa' con la fecha de fin ya
--     pasada. Las de Stripe no se tocan: su estado lo manda el webhook.
--     No se borra nada: la fila y su fecha de fin se conservan.

-- ============================================================
-- 1. Lo que le quedaba a la cuota al pausarla
-- ============================================================

alter table public.suscripciones
  add column if not exists resto_al_pausar interval;

comment on column public.suscripciones.resto_al_pausar is
  'Tiempo que le quedaba a la cuota cuando se pausó; al reanudar, fecha_fin = reanudación + este resto. Null = sin fecha de fin.';

-- ============================================================
-- 2. Pausar: se guarda el resto
-- ============================================================

create or replace function public.pausar_cuota_efectivo(
  p_suscripcion_id uuid,
  -- NULL = pausa indefinida, hasta que el Dueño la reanude a mano. Con
  -- fecha, el job de reconciliación la reanuda solo.
  p_fecha_fin timestamptz default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_academia_id uuid;
  v_actor_rol text;
  v_actor_estado text;
  v_susc_academia_id uuid;
  v_susc_proveedor text;
  v_susc_estado text;
  v_susc_fecha_fin timestamptz;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select academia_id, rol, estado
    into v_actor_academia_id, v_actor_rol, v_actor_estado
    from public.profiles
    where id = v_actor_id;

  if not found
     or v_actor_rol <> 'dueño'
     or v_actor_estado <> 'activo'
     or v_actor_academia_id is null then
    raise exception 'Solo el Dueño activo puede pausar una cuota.';
  end if;

  if p_fecha_fin is not null and p_fecha_fin <= now() then
    raise exception 'La fecha de reanudación debe ser futura.';
  end if;

  select academia_id, proveedor_pago, estado, fecha_fin
    into v_susc_academia_id, v_susc_proveedor, v_susc_estado, v_susc_fecha_fin
    from public.suscripciones
    where id = p_suscripcion_id
    for update;

  if not found or v_susc_academia_id is distinct from v_actor_academia_id then
    raise exception 'Esa cuota no es de tu academia.';
  end if;

  if v_susc_proveedor <> 'efectivo' then
    raise exception 'Las cuotas de Stripe se pausan desde Stripe.';
  end if;

  if v_susc_estado <> 'activa' then
    raise exception 'Solo se puede pausar una cuota activa.';
  end if;

  if v_susc_fecha_fin is not null and v_susc_fecha_fin <= now() then
    raise exception 'Esa cuota ya ha caducado: no hay nada que pausar.';
  end if;

  -- Mientras está pausada, fecha_fin es cuándo se reanuda (la usa el job).
  -- Lo que quedaba de la cuota se guarda aparte.
  update public.suscripciones
     set estado = 'pausada',
         resto_al_pausar = v_susc_fecha_fin - now(),
         fecha_fin = p_fecha_fin
   where id = p_suscripcion_id;
end;
$$;

revoke all on function public.pausar_cuota_efectivo(uuid, timestamptz) from public, anon;
grant execute on function public.pausar_cuota_efectivo(uuid, timestamptz) to authenticated;

-- ============================================================
-- 3. Reanudar a mano: se devuelve el resto
-- ============================================================

create or replace function public.reanudar_cuota_efectivo(
  p_suscripcion_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_academia_id uuid;
  v_actor_rol text;
  v_actor_estado text;
  v_susc_academia_id uuid;
  v_susc_proveedor text;
  v_susc_estado text;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select academia_id, rol, estado
    into v_actor_academia_id, v_actor_rol, v_actor_estado
    from public.profiles
    where id = v_actor_id;

  if not found
     or v_actor_rol <> 'dueño'
     or v_actor_estado <> 'activo'
     or v_actor_academia_id is null then
    raise exception 'Solo el Dueño activo puede reanudar una cuota.';
  end if;

  select academia_id, proveedor_pago, estado
    into v_susc_academia_id, v_susc_proveedor, v_susc_estado
    from public.suscripciones
    where id = p_suscripcion_id
    for update;

  if not found or v_susc_academia_id is distinct from v_actor_academia_id then
    raise exception 'Esa cuota no es de tu academia.';
  end if;

  if v_susc_proveedor <> 'efectivo' then
    raise exception 'Las cuotas de Stripe se reanudan desde Stripe.';
  end if;

  if v_susc_estado <> 'pausada' then
    raise exception 'Solo se puede reanudar una cuota pausada.';
  end if;

  -- Vuelve con el tiempo que le quedaba al pausarla. Sin resto guardado
  -- (cuota sin fecha de fin) sigue sin fecha de fin.
  update public.suscripciones
     set estado = 'activa',
         fecha_fin = now() + resto_al_pausar,
         resto_al_pausar = null
   where id = p_suscripcion_id;
end;
$$;

revoke all on function public.reanudar_cuota_efectivo(uuid) from public, anon;
grant execute on function public.reanudar_cuota_efectivo(uuid) to authenticated;

-- ============================================================
-- 4. El job de cada 15 minutos
-- ============================================================
-- Cambia el tipo de retorno (columna nueva), así que hay que borrarla
-- antes. El cron guarda el texto `select public.expirar_pruebas_y_pausas()`,
-- no la función, y sigue funcionando sin reprogramarlo.

drop function if exists public.expirar_pruebas_y_pausas();

create function public.expirar_pruebas_y_pausas()
returns table (pruebas_expiradas int, pausas_reanudadas int, cuotas_caducadas int)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_pruebas int;
  v_pausas int;
  v_caducadas int;
begin
  with expiradas as (
    update public.suscripciones
      set estado = 'expirada', payment_status = 'canceled'
      where estado = 'prueba'
        and fecha_fin is not null
        and fecha_fin <= now()
      returning 1
  )
  select count(*)::int into v_pruebas from expiradas;

  -- Se reanuda en la fecha prevista (no cuando pasa el job), con el resto
  -- que le quedaba. Va antes de caducar: si el resto ya se hubiera agotado
  -- (job parado mucho tiempo), el paso siguiente la cierra.
  with reanudadas as (
    update public.suscripciones
      set estado = 'activa',
          fecha_fin = fecha_fin + resto_al_pausar,
          resto_al_pausar = null
      where estado = 'pausada'
        and fecha_fin is not null
        and fecha_fin <= now()
      returning 1
  )
  select count(*)::int into v_pausas from reanudadas;

  -- Solo efectivo: las de Stripe las lleva el webhook. payment_status no se
  -- toca: esa cuota sí se cobró, lo que ha pasado es que se acabó.
  with caducadas as (
    update public.suscripciones
      set estado = 'expirada'
      where estado = 'activa'
        and proveedor_pago = 'efectivo'
        and fecha_fin is not null
        and fecha_fin <= now()
      returning 1
  )
  select count(*)::int into v_caducadas from caducadas;

  return query select v_pruebas, v_pausas, v_caducadas;
end;
$$;

-- Nadie autenticado debe poder invocar esto como RPC: es un job de sistema.
revoke all on function public.expirar_pruebas_y_pausas() from public, authenticated, anon;
