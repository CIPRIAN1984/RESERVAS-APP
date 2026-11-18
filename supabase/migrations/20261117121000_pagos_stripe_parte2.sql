-- ITACA — Cobro con tarjeta (Stripe en modo prueba), parte 2: registro de
-- pagos y funciones del servidor. Ver la parte 1 (20261117120000).
--
-- Reglas que se garantizan aquí, no en el navegador ni en la función de
-- Stripe:
-- - La cuota la activa `confirmar_pago_stripe`, y solo la llama el servidor
--   con la confirmación firmada de Stripe.
-- - Un mismo pago no activa dos veces (la clave del cobro sale de la sesión de
--   Stripe), aunque Stripe repita la notificación o lleguen dos a la vez.
-- - Si el importe cobrado no coincide con la tarifa, o la cuota ya no se
--   puede dar (p. ej. ya tenía una renovación pendiente), NO se activa ni se
--   pierde: queda en estado «revisar» y se ve en la lista de pagos con
--   problema, con el motivo.
-- - Una devolución total cancela la cuota que ese pago dio.

create table public.pagos_stripe (
  id uuid primary key default gen_random_uuid(),
  academia_id uuid not null references public.academias (id),
  alumno_id uuid not null references public.profiles (id),
  tarifa_id uuid not null references public.tarifas (id),
  -- Quién lo pidió (el propio alumno o su tutor).
  pagado_por uuid references public.profiles (id),
  checkout_session_id text unique,
  payment_intent_id text,
  estado text not null default 'creado'
    check (estado in ('creado', 'pagado', 'fallido', 'expirado', 'reembolsado', 'revisar')),
  -- Lo que debe cobrarse según la tarifa, calculado en el servidor.
  importe_esperado numeric(10, 2) not null check (importe_esperado >= 0),
  importe_pagado numeric(10, 2),
  importe_devuelto numeric(10, 2) not null default 0,
  suscripcion_id uuid references public.suscripciones (id),
  -- Último motivo de fallo o de «revisar», en castellano.
  error text,
  intentos_fallidos integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index pagos_stripe_alumno_idx on public.pagos_stripe (alumno_id);
create index pagos_stripe_academia_estado_idx on public.pagos_stripe (academia_id, estado);
create index pagos_stripe_payment_intent_idx on public.pagos_stripe (payment_intent_id)
  where payment_intent_id is not null;

alter table public.pagos_stripe enable row level security;

-- Lo ve el propio alumno, su tutor y el Dueño. El Profesor no (importes).
create policy pagos_stripe_select on public.pagos_stripe
  for select
  using (
    alumno_id = auth.uid()
    or public.es_padre_de(alumno_id)
    or (academia_id = public.current_academia_id() and public.current_rol() = 'dueño')
    or public.current_rol() = 'administrador'
  );

-- Nadie escribe desde la app: solo el servidor con el rol de servicio.
revoke all on public.pagos_stripe from anon, authenticated;
grant select on public.pagos_stripe to authenticated;

-- ============================================================
-- Preparar el pago: validar y fijar el importe en el servidor
-- ============================================================
-- Lo llama la función de Stripe con el usuario ya verificado (`p_quien`).
-- El importe sale de la tarifa; el navegador no manda ninguna cifra.

create or replace function public.preparar_pago_stripe(
  p_quien uuid,
  p_alumno_id uuid,
  p_tarifa_id uuid
)
returns table (pago_id uuid, importe_centimos integer, tarifa_nombre text, reutilizado boolean)
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_alumno record;
  v_tarifa record;
  v_pago uuid;
  v_importe numeric;
begin
  select academia_id, rol, estado, entrena
    into v_alumno
    from public.profiles
   where id = p_alumno_id;

  if not found or v_alumno.estado <> 'activo' or v_alumno.rol <> 'alumno' then
    raise exception 'Esa persona no puede pagar una cuota.';
  end if;

  -- El propio alumno, o su tutor.
  if p_quien <> p_alumno_id
     and not exists (select 1 from public.relaciones_familia
                      where parent_id = p_quien and child_id = p_alumno_id) then
    raise exception 'Solo puedes pagar tu cuota o la de tus hijos.';
  end if;

  select id, academia_id, nombre, precio, periodicidad, activo
    into v_tarifa
    from public.tarifas
   where id = p_tarifa_id;

  if not found or not v_tarifa.activo or v_tarifa.academia_id <> v_alumno.academia_id then
    raise exception 'Esa tarifa no está disponible.';
  end if;

  if exists (select 1 from public.suscripciones
              where alumno_id = p_alumno_id and estado = 'programada') then
    raise exception 'Ya tiene una renovación pagada pendiente de empezar.';
  end if;

  v_importe := v_tarifa.precio;

  -- Un pago abierto del mismo alumno y tarifa (recién creado, aún sin
  -- resolver) se reutiliza: pulsar dos veces o volver atrás no abre otro.
  select id into v_pago
    from public.pagos_stripe
   where alumno_id = p_alumno_id
     and tarifa_id = p_tarifa_id
     and estado = 'creado'
     and created_at > now() - interval '30 minutes'
   order by created_at desc
   limit 1;

  if v_pago is not null then
    return query select v_pago, round(v_importe * 100)::int, v_tarifa.nombre, true;
    return;
  end if;

  insert into public.pagos_stripe (academia_id, alumno_id, tarifa_id, pagado_por, importe_esperado)
  values (v_alumno.academia_id, p_alumno_id, p_tarifa_id, p_quien, v_importe)
  returning id into v_pago;

  return query select v_pago, round(v_importe * 100)::int, v_tarifa.nombre, false;
end;
$function$;

-- Guarda la sesión de Stripe una vez creada.
create or replace function public.guardar_sesion_stripe(p_pago_id uuid, p_session_id text)
returns void
language sql
security definer
set search_path = public, pg_temp
as $function$
  update public.pagos_stripe
     set checkout_session_id = p_session_id, updated_at = now()
   where id = p_pago_id and checkout_session_id is null;
$function$;

-- ============================================================
-- Confirmar el pago: aquí se activa la cuota
-- ============================================================

create or replace function public.confirmar_pago_stripe(
  p_session_id text,
  p_payment_intent text,
  p_importe_centimos bigint,
  p_moneda text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_pago public.pagos_stripe%rowtype;
  v_tarifa record;
  v_meses integer;
  v_suscripcion uuid;
begin
  -- La fila del pago se bloquea: dos notificaciones a la vez esperan una a la
  -- otra y la segunda ve el resultado de la primera.
  select * into v_pago
    from public.pagos_stripe
   where checkout_session_id = p_session_id
   for update;

  if not found then
    raise exception 'Pago desconocido.';
  end if;

  if v_pago.estado in ('pagado', 'reembolsado') then
    return v_pago.suscripcion_id;
  end if;

  update public.pagos_stripe
     set payment_intent_id = coalesce(p_payment_intent, payment_intent_id)
   where id = v_pago.id;

  if lower(coalesce(p_moneda, '')) <> 'eur'
     or p_importe_centimos is distinct from round(v_pago.importe_esperado * 100)::bigint then
    update public.pagos_stripe
       set estado = 'revisar',
           importe_pagado = p_importe_centimos / 100.0,
           error = format('El importe cobrado (%s %s) no coincide con el de la tarifa (%s EUR). No se ha activado la cuota.',
                          p_importe_centimos / 100.0, upper(coalesce(p_moneda, '?')), v_pago.importe_esperado),
           updated_at = now()
     where id = v_pago.id;
    return null;
  end if;

  select periodicidad into v_tarifa from public.tarifas where id = v_pago.tarifa_id;
  -- Un pago es un periodo de la tarifa; la clase suelta es una clase.
  v_meses := case v_tarifa.periodicidad
    when 'mensual' then 1
    when 'trimestral' then 3
    when 'anual' then 12
    else null
  end;

  begin
    v_suscripcion := public._alta_cuota(
      v_pago.alumno_id, v_pago.tarifa_id, null, false,
      p_importe_centimos / 100.0, v_meses,
      -- La misma sesión siempre da la misma clave: un cobro no se duplica.
      md5('stripe:' || p_session_id)::uuid,
      'stripe', p_session_id, null, v_pago.academia_id
    );
  exception when others then
    -- El dinero ya está cobrado pero la cuota no se puede dar: no se pierde
    -- ni se reintenta en bucle; queda a la vista para el Dueño.
    update public.pagos_stripe
       set estado = 'revisar',
           importe_pagado = p_importe_centimos / 100.0,
           error = 'Cobrado, pero no se ha podido activar la cuota: ' || sqlerrm,
           updated_at = now()
     where id = v_pago.id;
    return null;
  end;

  update public.pagos_stripe
     set estado = 'pagado',
         importe_pagado = p_importe_centimos / 100.0,
         suscripcion_id = v_suscripcion,
         error = null,
         updated_at = now()
   where id = v_pago.id;

  return v_suscripcion;
end;
$function$;

-- ============================================================
-- Fallos, abandonos y devoluciones
-- ============================================================

-- Un intento de pago rechazado (tarjeta sin fondos…): el alumno puede
-- reintentar dentro de la misma sesión, así que el pago sigue «creado» pero
-- queda anotado el motivo.
create or replace function public.anotar_intento_fallido_stripe(p_pago_id uuid, p_motivo text)
returns void
language sql
security definer
set search_path = public, pg_temp
as $function$
  update public.pagos_stripe
     set intentos_fallidos = intentos_fallidos + 1,
         error = coalesce(nullif(p_motivo, ''), 'El pago fue rechazado.'),
         updated_at = now()
   where id = p_pago_id and estado = 'creado';
$function$;

-- La sesión caducó sin pagar (abandonado) o el pago asíncrono falló.
create or replace function public.cerrar_pago_stripe(p_session_id text, p_estado text, p_motivo text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if p_estado not in ('expirado', 'fallido') then
    raise exception 'Estado no válido.';
  end if;
  update public.pagos_stripe
     set estado = p_estado,
         error = coalesce(nullif(p_motivo, ''), error),
         updated_at = now()
   where checkout_session_id = p_session_id and estado = 'creado';
end;
$function$;

-- Devolución en Stripe. Total: se cancela la cuota que dio ese pago.
-- Parcial: solo se anota, y el Dueño decide.
create or replace function public.registrar_devolucion_stripe(
  p_payment_intent text,
  p_devuelto_centimos bigint
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_pago public.pagos_stripe%rowtype;
  v_total boolean;
begin
  select * into v_pago
    from public.pagos_stripe
   where payment_intent_id = p_payment_intent
   for update;

  if not found then
    return;
  end if;

  v_total := p_devuelto_centimos >= round(coalesce(v_pago.importe_pagado, v_pago.importe_esperado) * 100);

  update public.pagos_stripe
     set importe_devuelto = p_devuelto_centimos / 100.0,
         estado = case when v_total then 'reembolsado' else estado end,
         error = case when v_total then 'Devuelto en Stripe.'
                      else format('Devolución parcial de %s EUR: revisa si hay que cerrar la cuota.', p_devuelto_centimos / 100.0) end,
         updated_at = now()
   where id = v_pago.id;

  if v_total and v_pago.suscripcion_id is not null then
    update public.suscripciones
       set estado = 'cancelada',
           -- Una clase extra deja de serlo al cancelarse (restricción de coherencia).
           extra_de = null,
           fecha_fin = least(coalesce(fecha_fin, now()), now())
     where id = v_pago.suscripcion_id
       and estado in ('activa', 'prueba', 'pausada', 'programada', 'extra');
  end if;
end;
$function$;

-- ============================================================
-- Solo el servidor las puede llamar
-- ============================================================

revoke all on function public.preparar_pago_stripe(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.guardar_sesion_stripe(uuid, text) from public, anon, authenticated;
revoke all on function public.confirmar_pago_stripe(text, text, bigint, text) from public, anon, authenticated;
revoke all on function public.anotar_intento_fallido_stripe(uuid, text) from public, anon, authenticated;
revoke all on function public.cerrar_pago_stripe(text, text, text) from public, anon, authenticated;
revoke all on function public.registrar_devolucion_stripe(text, bigint) from public, anon, authenticated;

grant execute on function public.preparar_pago_stripe(uuid, uuid, uuid) to service_role;
grant execute on function public.guardar_sesion_stripe(uuid, text) to service_role;
grant execute on function public.confirmar_pago_stripe(text, text, bigint, text) to service_role;
grant execute on function public.anotar_intento_fallido_stripe(uuid, text) to service_role;
grant execute on function public.cerrar_pago_stripe(text, text, text) to service_role;
grant execute on function public.registrar_devolucion_stripe(text, bigint) to service_role;
