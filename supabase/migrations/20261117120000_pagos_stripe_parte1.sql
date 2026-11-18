-- ITACA — Encargo de Cipri del 17/11/2026, bloque 3: cobro con tarjeta
-- (Stripe en modo prueba) con las MISMAS condiciones que el cobro en mano.
--
-- 1. El alta de una cuota (periodos, importe, renovación, clase extra, cuota
--    que cubre la clase en marcha…) se saca de `activar_cuota_efectivo` a una
--    función interna, `_alta_cuota`. Cobrar en mano y cobrar con tarjeta
--    llaman a la misma: no pueden dar derechos distintos. `activar_cuota_efectivo`
--    queda igual para quien la llama (mismas comprobaciones de Dueño).
--    Una cuota de tarjeta cuenta como cualquier otra para renovar y para la
--    clase extra; solo una suscripción recurrente de verdad (sub_…) bloquea
--    el cobro en mano.
-- 2. `pagos_stripe`: cada intento de pago con tarjeta, con su estado. Sirve
--    para (a) no activar dos veces el mismo pago, (b) no activar si el
--    importe no coincide, y (c) que el Dueño vea los pagos con problema
--    sin esperar a que un alumno avise.
-- 3. Las funciones que usa el servidor al hablar con Stripe, solo para el
--    rol de servicio: la cuota se activa por la confirmación firmada de
--    Stripe (webhook), nunca porque el navegador diga «pago correcto».
--
-- No hay cobros recurrentes: cada pago es de un periodo de la tarifa.
-- Sin ningún `drop`.

create or replace function public._alta_cuota(
  p_alumno_id uuid,
  p_tarifa_id uuid,
  p_fecha_fin timestamptz,
  p_prueba boolean,
  p_importe numeric,
  p_meses integer,
  p_clave uuid,
  p_proveedor text,
  p_referencia text,
  p_actor uuid,
  p_academia_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
AS $function$
declare
  v_actor_id uuid := p_actor;
  v_actor_academia_id uuid := p_academia_id;
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
  v_base_id uuid;
  v_base_estado text;
  v_base_fin timestamptz;
  v_base_incluidas int;
  v_actual_fin timestamptz;
  v_renovacion boolean := false;
  v_inicio timestamptz := now();
  v_fin timestamptz;
  v_suscripcion_id uuid;
begin
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

  -- 09/10/2026 (auditoría, punto 3; decisión de Cipri): una suelta con la
  -- cuota en vigor es una clase EXTRA de esa cuota. Se puede usar ya y
  -- caduca con ella. Antes era una renovación para cuando acabara.
  if not p_prueba and v_tarifa_periodicidad = 'suelta' then
    select id, estado, fecha_fin, clases_incluidas
      into v_base_id, v_base_estado, v_base_fin, v_base_incluidas
      from public.suscripciones
     where alumno_id = p_alumno_id
       and estado in ('activa', 'pausada')
       and payment_status = 'active'
       and (fecha_fin is null or fecha_fin > now())
     order by fecha_inicio desc
     limit 1
     for update;

    if found then
      if v_base_estado = 'pausada' then
        raise exception 'Tiene la cuota pausada: mientras lo esté puede venir '
                        'sin cuota. Reanúdala antes de cobrarle una clase extra.';
      end if;

      if v_base_incluidas is null then
        raise exception 'Su cuota ya tiene clases ilimitadas: no le hace falta '
                        'una clase extra.';
      end if;

      perform set_config('itaca.alta_extra', 'on', true);

      insert into public.suscripciones (
        alumno_id, tarifa_id, academia_id, proveedor_pago, referencia_externa,
        clave_cobro, extra_de
      )
      values (
        p_alumno_id, p_tarifa_id, v_actor_academia_id, p_proveedor, p_referencia,
        p_clave, v_base_id
      )
      returning id into v_suscripcion_id;

      perform set_config('itaca.alta_extra', 'off', true);

      -- La fecha de fin es la de la cuota hoy, para enseñarla. La que
      -- manda es la de la cuota en cada momento: si se pausa y se alarga,
      -- la extra dura lo mismo (`_saldo_clases` la lee desde la cuota).
      update public.suscripciones
         set payment_status = 'active',
             fecha_inicio = now(),
             fecha_fin = v_base_fin,
             importe_cobrado = coalesce(p_importe, v_tarifa_precio),
             cobrado_por = v_actor_id,
             cobrado_at = now()
       where id = v_suscripcion_id;

      return v_suscripcion_id;
    end if;
  end if;

  -- ¿Es una renovación de una cuota en efectivo todavía en vigor? Entonces
  -- la nueva empieza cuando acabe esa (decisión de Cipri, 30/09/2026).
  if not p_prueba then
    select fecha_fin into v_actual_fin
      from public.suscripciones
     where alumno_id = p_alumno_id
       and academia_id = v_actor_academia_id
       and proveedor_pago in ('efectivo', 'stripe')
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
       and proveedor_pago in ('efectivo', 'stripe')
       and estado in ('activa', 'pendiente_pago', 'prueba', 'pausada');
  end if;

  if exists (
    select 1
      from public.suscripciones
     where alumno_id = p_alumno_id
       and proveedor_pago = 'stripe'
       -- Solo una suscripción recurrente de verdad (sub_…): un pago único
       -- con tarjeta (cs_…) es una cuota como la de en mano.
       and referencia_externa like 'sub\_%'
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
    p_alumno_id, p_tarifa_id, v_actor_academia_id, p_proveedor, p_referencia,
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

  -- 17/11/2026: si la persona ya está en una clase que ha empezado, la cuota
  -- recién cobrada la cubre (cobro en recepción con la clase en marcha).
  perform public._cubrir_clase_en_curso(p_alumno_id);

  return v_suscripcion_id;
end;
$function$;

revoke all on function public._alta_cuota(uuid, uuid, timestamptz, boolean, numeric, integer, uuid, text, text, uuid, uuid)
  from public, anon, authenticated;

create or replace function public.activar_cuota_efectivo(
  p_alumno_id uuid,
  p_tarifa_id uuid,
  p_fecha_fin timestamptz default null,
  p_prueba boolean default false,
  p_importe numeric default null,
  p_meses integer default null,
  p_clave uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_academia_id uuid;
  v_actor_rol text;
  v_actor_estado text;
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

  return public._alta_cuota(
    p_alumno_id, p_tarifa_id, p_fecha_fin, p_prueba, p_importe, p_meses,
    p_clave, 'efectivo', null, v_actor_id, v_actor_academia_id
  );
end;
$function$;
