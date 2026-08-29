-- Prueba (1 día) y tarifa Pausada.
--
-- Dos estados nuevos de `suscripciones`, decididos con Cipri:
--
--   * 'prueba'  — el Dueño deja a un alumno probar un día sin cobrarle
--     todavía. Cuenta como cuota al reservar (igual que 'activa'), y expira
--     sola a las 24 horas: nadie tiene que acordarse de cerrarla.
--   * 'pausada' — el Dueño congela una cuota que ya existía (una baja
--     temporal, una lesión...). Mientras dure, NO cuenta para reservar —a
--     diferencia de 'prueba'. Puede ser indefinida (hasta que el Dueño la
--     reanude a mano) o con fecha de fin, y entonces se reanuda sola.
--
-- Ambas siguen contando para el índice de "una suscripción en curso por
-- alumno" (0015): no tiene sentido una prueba y una cuota pausada a la vez,
-- ni dos pruebas seguidas.

-- ============================================================
-- 1. Estados nuevos
-- ============================================================

alter table public.suscripciones drop constraint if exists suscripciones_estado_check;
alter table public.suscripciones
  add constraint suscripciones_estado_check
  check (estado in ('pendiente_pago', 'activa', 'prueba', 'pausada', 'cancelada', 'expirada'));

drop index if exists suscripciones_activa_unica_idx;
create unique index suscripciones_activa_unica_idx
  on public.suscripciones (alumno_id)
  where estado in ('activa', 'pendiente_pago', 'prueba', 'pausada');

-- ============================================================
-- 2. Iniciar prueba — se apoya en activar_cuota_efectivo
-- ============================================================
-- Cambia de firma (se añade p_prueba al final): hay que borrar la versión
-- vieja explícitamente, porque CREATE OR REPLACE con una lista de
-- parámetros distinta crea una función nueva en vez de sustituir la
-- anterior y dejaría las dos conviviendo.

drop function if exists public.activar_cuota_efectivo(uuid, uuid, timestamptz);

create or replace function public.activar_cuota_efectivo(
  p_alumno_id uuid,
  p_tarifa_id uuid,
  p_fecha_fin timestamptz default null,
  p_prueba boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_academia_id uuid;
  v_actor_rol text;
  v_actor_estado text;
  v_alumno_academia_id uuid;
  v_alumno_rol text;
  v_alumno_estado text;
  v_tarifa_academia_id uuid;
  v_tarifa_activa boolean;
  v_suscripcion_id uuid;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select academia_id, rol, estado
    into v_actor_academia_id, v_actor_rol, v_actor_estado
    from public.profiles
    where id = v_actor_id;

  -- Solo el Dueño: quien cobra en mano (o regala la prueba) es quien
  -- responde de ese dinero.
  if not found
     or v_actor_rol <> 'dueño'
     or v_actor_estado <> 'activo'
     or v_actor_academia_id is null then
    raise exception 'Solo el Dueño activo puede registrar cuotas en efectivo.';
  end if;

  if p_prueba and p_fecha_fin is not null then
    raise exception 'La prueba dura siempre 1 día: no lleva fecha de fin propia.';
  end if;

  if not p_prueba and p_fecha_fin is not null and p_fecha_fin <= now() then
    raise exception 'La fecha de fin debe ser futura.';
  end if;

  -- Se bloquea la fila del alumno para que dos altas simultáneas no dejen
  -- dos cuotas activas a la vez.
  select academia_id, rol, estado
    into v_alumno_academia_id, v_alumno_rol, v_alumno_estado
    from public.profiles
    where id = p_alumno_id
    for update;

  if not found or v_alumno_academia_id is distinct from v_actor_academia_id then
    raise exception 'Ese miembro no es de tu academia.';
  end if;

  if v_alumno_estado <> 'activo' then
    raise exception 'Ese miembro todavía no está activo.';
  end if;

  -- Profesores y Dueños ya reservan sin cuota; darles una sería un cobro
  -- fantasma en las cuentas de la academia.
  if v_alumno_rol <> 'alumno' then
    raise exception 'Solo los Alumnos necesitan cuota para reservar.';
  end if;

  select academia_id, activo
    into v_tarifa_academia_id, v_tarifa_activa
    from public.tarifas
    where id = p_tarifa_id;

  if not found or v_tarifa_academia_id is distinct from v_actor_academia_id then
    raise exception 'Esa tarifa no es de tu academia.';
  end if;

  if not v_tarifa_activa then
    raise exception 'Esa tarifa está desactivada.';
  end if;

  -- Cerrar la cuota en efectivo anterior (incluida una prueba o una pausa
  -- previas): un alumno tiene una cuota, no una pila de ellas. Hay un
  -- índice único por alumno sobre los estados en curso, así que además es
  -- obligatorio dejar sitio.
  update public.suscripciones
     set estado = 'expirada',
         fecha_fin = least(coalesce(fecha_fin, now()), now())
   where alumno_id = p_alumno_id
     and academia_id = v_actor_academia_id
     and proveedor_pago = 'efectivo'
     and estado in ('activa', 'pendiente_pago', 'prueba', 'pausada');

  -- Una de Stripe no se toca desde aquí, pero tampoco puede convivir con
  -- esta por el índice único. Mejor decirlo claro que reventar con un error
  -- de clave duplicada que no significa nada para quien lo lee.
  if exists (
    select 1
      from public.suscripciones
     where alumno_id = p_alumno_id
       and proveedor_pago = 'stripe'
       and estado in ('activa', 'pendiente_pago', 'prueba', 'pausada')
  ) then
    raise exception 'Ese alumno ya tiene una cuota domiciliada por tarjeta. '
                    'Cancélala primero desde Stripe.';
  end if;

  -- OJO: el disparador `set_suscripcion_defaults` pisa estado,
  -- payment_status, fecha_inicio y fecha_fin en cada alta — es la protección
  -- que impide que nadie se auto-active la cuota. Por eso hay que insertar
  -- primero y activar después con un UPDATE; hacerlo en el INSERT no tiene
  -- ningún efecto y la cuota se queda en 'pendiente_pago' sin que se note.
  insert into public.suscripciones (
    alumno_id, tarifa_id, academia_id, proveedor_pago, referencia_externa
  )
  values (
    p_alumno_id, p_tarifa_id, v_actor_academia_id, 'efectivo', null
  )
  returning id into v_suscripcion_id;

  -- El disparador `check_suscripcion_estado_transicion` deja pasar este
  -- cambio porque quien llama es el Dueño, comprobado más arriba.
  update public.suscripciones
     set estado = case when p_prueba then 'prueba' else 'activa' end,
         payment_status = 'active',
         fecha_fin = case
           when p_prueba then now() + interval '1 day'
           else p_fecha_fin
         end
   where id = v_suscripcion_id;

  return v_suscripcion_id;
end;
$$;

revoke all on function public.activar_cuota_efectivo(uuid, uuid, timestamptz, boolean)
  from public, anon;
grant execute on function public.activar_cuota_efectivo(uuid, uuid, timestamptz, boolean)
  to authenticated;

-- ============================================================
-- 3. Pausar y reanudar una cuota en efectivo
-- ============================================================
-- Solo para cuotas en efectivo, igual que desactivar_cuota_efectivo: una de
-- Stripe se gestiona desde Stripe, no desde aquí.

create or replace function public.pausar_cuota_efectivo(
  p_suscripcion_id uuid,
  -- NULL = pausa indefinida, hasta que el Dueño la reanude a mano. Con
  -- fecha, el job de reconciliación la reanuda solo (ver más abajo).
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

  select academia_id, proveedor_pago, estado
    into v_susc_academia_id, v_susc_proveedor, v_susc_estado
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

  update public.suscripciones
     set estado = 'pausada',
         fecha_fin = p_fecha_fin
   where id = p_suscripcion_id;
end;
$$;

revoke all on function public.pausar_cuota_efectivo(uuid, timestamptz) from public, anon;
grant execute on function public.pausar_cuota_efectivo(uuid, timestamptz) to authenticated;

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

  -- Vuelve sin fecha de caducidad propia: si el Dueño quiere ponerle una,
  -- es la misma acción que dar/renovar cuota.
  update public.suscripciones
     set estado = 'activa',
         fecha_fin = null
   where id = p_suscripcion_id;
end;
$$;

revoke all on function public.reanudar_cuota_efectivo(uuid) from public, anon;
grant execute on function public.reanudar_cuota_efectivo(uuid) to authenticated;

-- ============================================================
-- 4. Job de reconciliación: expira pruebas y reanuda pausas con fecha
-- ============================================================
-- Mismo patrón que expirar_pagos_pendientes (0018): security definer para
-- que lo pueda ejecutar el scheduler (rol cron, sin sesión de usuario), y
-- programación condicional para no romper entornos sin pg_cron (Supabase
-- local de CI).

create or replace function public.expirar_pruebas_y_pausas()
returns table (pruebas_expiradas int, pausas_reanudadas int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pruebas int;
  v_pausas int;
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

  with reanudadas as (
    update public.suscripciones
      set estado = 'activa', fecha_fin = null
      where estado = 'pausada'
        and fecha_fin is not null
        and fecha_fin <= now()
      returning 1
  )
  select count(*)::int into v_pausas from reanudadas;

  return query select v_pruebas, v_pausas;
end;
$$;

-- Nadie autenticado debe poder invocar esto como RPC: es un job de sistema.
revoke all on function public.expirar_pruebas_y_pausas() from public, authenticated, anon;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.unschedule('itaca_expirar_pruebas_y_pausas')
      where exists (select 1 from cron.job where jobname = 'itaca_expirar_pruebas_y_pausas');
    perform cron.schedule(
      'itaca_expirar_pruebas_y_pausas',
      '*/15 * * * *',
      $cron$ select public.expirar_pruebas_y_pausas(); $cron$
    );
  else
    raise notice 'pg_cron no disponible: expirar_pruebas_y_pausas debe programarse manualmente (Edge Function + cron externo).';
  end if;
end;
$$;

-- ============================================================
-- 5. reservar_clase: una prueba cuenta como cuota, una pausa no
-- ============================================================

create or replace function public.reservar_clase(p_clase_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_usuario_id uuid := auth.uid();
  v_academia_id uuid;
  v_rol text;
  v_estado text;
  v_clase_academia_id uuid;
  v_clase_estado text;
  v_inicio timestamptz;
  v_aforo_maximo int;
  v_lista_espera_activa boolean;
  v_exigir_cuota boolean;
  v_inscritos int;
  v_resultado text;
  v_saldo jsonb;
begin
  if v_usuario_id is null then
    raise exception 'No autorizado.';
  end if;

  select academia_id, rol, estado
    into v_academia_id, v_rol, v_estado
    from public.profiles
    where id = v_usuario_id;

  if not found or v_estado <> 'activo' then
    raise exception 'Tu cuenta no está activa.';
  end if;

  if v_rol not in ('alumno', 'profesor', 'dueño') or v_academia_id is null then
    raise exception 'Tu cuenta no puede reservar clases.';
  end if;

  select c.academia_id,
         c.estado,
         c.fecha_hora_inicio,
         c.aforo_maximo,
         a.lista_espera_activa,
         a.exigir_cuota_para_reservar
    into v_clase_academia_id,
         v_clase_estado,
         v_inicio,
         v_aforo_maximo,
         v_lista_espera_activa,
         v_exigir_cuota
    from public.clases c
    join public.academias a on a.id = c.academia_id
    where c.id = p_clase_id
    for update of c;

  if not found or v_clase_academia_id is distinct from v_academia_id then
    raise exception 'Clase no encontrada.';
  end if;

  if v_clase_estado <> 'activa' then
    raise exception 'Esta clase no admite nuevas reservas.';
  end if;

  if v_inicio <= now() then
    raise exception 'Solo puedes reservar clases futuras.';
  end if;

  if exists (
    select 1
      from public.inscripciones
      where clase_id = p_clase_id
        and alumno_id = v_usuario_id
        and estado in ('inscrito', 'espera')
  ) then
    raise exception 'Ya tienes una reserva o plaza de espera en esta clase.';
  end if;

  -- Solo si la academia lo exige. Con el ajuste por defecto, quien no tiene
  -- cuota reserva igual y sale marcado en la lista de la clase. Una prueba
  -- cuenta como cuota (es justo lo que permite probar antes de pagar); una
  -- cuota pausada NO cuenta (es justo lo que significa pausarla).
  if v_exigir_cuota and v_rol = 'alumno' and not exists (
    select 1
      from public.suscripciones
      where alumno_id = v_usuario_id
        and academia_id = v_academia_id
        and estado in ('activa', 'prueba')
        and payment_status = 'active'
        and fecha_inicio <= now()
        and (fecha_fin is null or fecha_fin > now())
  ) then
    raise exception 'Debes tener una cuota activa para reservar esta clase.';
  end if;

  -- Caso distinto del de arriba: aquí SÍ hay una cuota activa con número de
  -- clases, y ya no le queda ninguna este ciclo. No aplica a quien no tiene
  -- cuota (ese caso ya lo decide el bloque de arriba) ni a las ilimitadas.
  if v_rol = 'alumno' then
    v_saldo := public.clases_restantes(v_usuario_id);
    if (v_saldo->>'tiene_cuota')::boolean
       and not (v_saldo->>'ilimitada')::boolean
       and (v_saldo->>'disponibles')::int <= 0
    then
      raise exception
        'No te quedan clases en tu tarifa este mes. Renueva o compra una clase suelta.';
    end if;
  end if;

  select count(*)::int
    into v_inscritos
    from public.inscripciones
    where clase_id = p_clase_id and estado = 'inscrito';

  if v_inscritos < v_aforo_maximo then
    v_resultado := 'inscrito';
  elsif v_lista_espera_activa then
    v_resultado := 'espera';
  else
    raise exception 'Aforo completo para esta clase.';
  end if;

  insert into public.inscripciones (
    clase_id,
    alumno_id,
    academia_id,
    estado
  ) values (
    p_clase_id,
    v_usuario_id,
    v_academia_id,
    v_resultado
  );

  return v_resultado;
end;
$function$;

revoke all on function public.reservar_clase(uuid) from public, anon;
grant execute on function public.reservar_clase(uuid) to authenticated;
