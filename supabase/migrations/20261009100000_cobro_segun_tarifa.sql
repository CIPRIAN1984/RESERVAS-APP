-- ITACA — Auditoría externa del 09/10/2026, punto 2: cobrar una tarifa
-- respeta su precio y su duración, y reintentar no duplica el cobro.
--
-- 1. La hoja de cobro trataba todas las tarifas como mensuales («1 mes»,
--    «3 meses»…) y el servidor aceptaba cualquier número de meses. El bono
--    trimestral de 80 € (10 sesiones) cobrado «3 meses» proponía 240 €, y
--    cobrado «1 mes» duraba un mes con las 10 sesiones de un trimestre.
--    Ahora los meses tienen que ser periodos enteros de la tarifa
--    (trimestral: 3, 6…; anual: 12…), el importe propuesto es precio ×
--    periodos, y la suelta es una clase que dura un mes.
-- 2. Si la conexión se cortaba después de guardar, el Dueño volvía a
--    pulsar «Registrar cobro» y el servidor, que ya veía una cuota en vigor,
--    creaba una renovación: el mismo dinero apuntado dos veces. Ahora la app
--    manda una clave por cobro (`p_clave`) y el segundo intento devuelve el
--    primero.

alter table public.suscripciones add column if not exists clave_cobro uuid;

create unique index if not exists suscripciones_clave_cobro_key
  on public.suscripciones (clave_cobro)
  where clave_cobro is not null;

comment on column public.suscripciones.clave_cobro is
  'Identificador del cobro que manda la app: un reintento con la misma '
  'clave devuelve el cobro ya guardado en vez de crear otro.';

drop function if exists public.activar_cuota_efectivo(uuid, uuid, timestamptz, boolean, numeric, integer);

create or replace function public.activar_cuota_efectivo(
  p_alumno_id uuid,
  p_tarifa_id uuid,
  p_fecha_fin timestamptz default null,
  p_prueba boolean default false,
  p_importe numeric default null,
  -- Meses de calendario desde que empieza la cuota (que en una renovación
  -- es el fin de la actual). Si llega, manda sobre p_fecha_fin.
  p_meses integer default null,
  -- 09/10/2026: identificador del cobro, lo genera la app al abrir la hoja.
  -- Si la conexión se corta después de guardar y el Dueño pulsa otra vez,
  -- llega la misma clave y se devuelve el cobro ya hecho, sin duplicarlo.
  p_clave uuid default null
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
  v_tarifa_precio numeric;
  v_tarifa_periodicidad text;
  v_meses_periodo int;
  v_meses int := p_meses;
  v_existente_id uuid;
  v_existente_alumno uuid;
  v_actual_fin timestamptz;
  v_renovacion boolean := false;
  v_inicio timestamptz := now();
  v_fin timestamptz;
  v_suscripcion_id uuid;
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
    raise exception 'Solo el Dueño activo puede registrar cuotas en efectivo.';
  end if;

  if p_prueba and (p_fecha_fin is not null or p_meses is not null) then
    raise exception 'La prueba dura siempre 1 día: no lleva fecha de fin propia.';
  end if;

  if not p_prueba and p_meses is null and p_fecha_fin is not null
     and p_fecha_fin <= now() then
    raise exception 'La fecha de fin debe ser futura.';
  end if;

  if p_meses is not null and p_meses <= 0 then
    raise exception 'Los meses tienen que ser al menos 1.';
  end if;

  if p_importe is not null and p_importe < 0 then
    raise exception 'El importe cobrado no puede ser negativo.';
  end if;

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

  if v_alumno_rol <> 'alumno' then
    raise exception 'Solo los Alumnos necesitan cuota para reservar.';
  end if;

  -- ¿Es un reintento de un cobro ya guardado? Se mira con el alumno ya
  -- bloqueado: dos llamadas a la vez con la misma clave esperan una a la
  -- otra, y la segunda encuentra el cobro de la primera.
  if p_clave is not null then
    select id, alumno_id into v_existente_id, v_existente_alumno
      from public.suscripciones
     where clave_cobro = p_clave;
    if found then
      if v_existente_alumno is distinct from p_alumno_id then
        raise exception 'Ese cobro ya se registró para otro alumno.';
      end if;
      return v_existente_id;
    end if;
  end if;

  select academia_id, activo, precio, periodicidad
    into v_tarifa_academia_id, v_tarifa_activa, v_tarifa_precio,
         v_tarifa_periodicidad
    from public.tarifas
    where id = p_tarifa_id;

  if not found or v_tarifa_academia_id is distinct from v_actor_academia_id then
    raise exception 'Esa tarifa no es de tu academia.';
  end if;

  if not v_tarifa_activa then
    raise exception 'Esa tarifa está desactivada.';
  end if;

  -- 09/10/2026 (auditoría, punto 2): la duración sale de la tarifa. Antes
  -- todas se trataban como mensuales: el bono trimestral de 80 € cobrado
  -- «1 mes» duraba un mes, y «3 meses» proponía 240 €.
  v_meses_periodo := case v_tarifa_periodicidad
    when 'mensual' then 1
    when 'trimestral' then 3
    when 'anual' then 12
  end;

  if not p_prueba then
    if v_tarifa_periodicidad = 'suelta' then
      -- Una clase, que se puede usar durante un mes.
      if p_meses is not null and p_meses <> 1 then
        raise exception 'Una clase suelta se cobra de una en una.';
      end if;
      if p_fecha_fin is null then
        v_meses := 1;
      end if;
    elsif p_meses is not null and p_meses % v_meses_periodo <> 0 then
      raise exception 'Esta tarifa es %: se cobra por periodos de % meses.',
        v_tarifa_periodicidad, v_meses_periodo;
    end if;
  end if;

  -- ¿Es una renovación de una cuota en efectivo todavía en vigor? Entonces
  -- la nueva empieza cuando acabe esa (decisión de Cipri, 30/09/2026).
  if not p_prueba then
    select fecha_fin into v_actual_fin
      from public.suscripciones
     where alumno_id = p_alumno_id
       and academia_id = v_actor_academia_id
       and proveedor_pago = 'efectivo'
       and estado = 'activa'
       and fecha_fin > now()
     for update;
    v_renovacion := found;
  end if;

  if v_renovacion then
    if exists (
      select 1 from public.suscripciones
       where alumno_id = p_alumno_id and estado = 'programada'
    ) then
      raise exception 'Ese alumno ya tiene una renovación pendiente de empezar.';
    end if;
    v_inicio := v_actual_fin;
  else
    -- Sin cuota en vigor que respetar: se cierra la anterior en efectivo
    -- (una prueba, una pausada, una caducada que el job no ha cerrado aún).
    update public.suscripciones
       set estado = 'expirada',
           fecha_fin = least(coalesce(fecha_fin, now()), now())
     where alumno_id = p_alumno_id
       and academia_id = v_actor_academia_id
       and proveedor_pago = 'efectivo'
       and estado in ('activa', 'pendiente_pago', 'prueba', 'pausada');
  end if;

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

  v_fin := case
    when p_prueba then now() + interval '1 day'
    when v_meses is not null then v_inicio + make_interval(months => v_meses)
    when p_fecha_fin is not null then v_inicio + (p_fecha_fin - now())
    else null
  end;

  perform set_config('itaca.alta_programada', case when v_renovacion then 'on' else 'off' end, true);

  insert into public.suscripciones (
    alumno_id, tarifa_id, academia_id, proveedor_pago, referencia_externa,
    clave_cobro
  )
  values (
    p_alumno_id, p_tarifa_id, v_actor_academia_id, 'efectivo', null,
    p_clave
  )
  returning id into v_suscripcion_id;

  perform set_config('itaca.alta_programada', 'off', true);

  update public.suscripciones
     set estado = case
           when p_prueba then 'prueba'
           when v_renovacion then 'programada'
           else 'activa'
         end,
         payment_status = 'active',
         fecha_inicio = v_inicio,
         fecha_fin = v_fin,
         importe_cobrado = case
           when p_prueba then 0
           -- Precio de la tarifa por cada periodo pagado (la suelta, una).
           else coalesce(
             p_importe,
             v_tarifa_precio * coalesce(v_meses / v_meses_periodo, 1)
           )
         end,
         cobrado_por = v_actor_id,
         cobrado_at = now()
   where id = v_suscripcion_id;

  return v_suscripcion_id;
end;
$$;

revoke all on function public.activar_cuota_efectivo(uuid, uuid, timestamptz, boolean, numeric, integer, uuid)
  from public, anon;
grant execute on function public.activar_cuota_efectivo(uuid, uuid, timestamptz, boolean, numeric, integer, uuid)
  to authenticated;
