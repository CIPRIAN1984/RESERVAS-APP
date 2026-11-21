-- ITACA — Decisión de Cipri del 21/11/2026: las tarifas MENSUALES se cobran
-- solas cada mes con tarjeta (suscripción de Stripe); bono trimestral y día
-- suelto siguen siendo un pago. Stripe lleva los reintentos y los avisos de
-- fallo. La baja funciona en los dos sentidos: la del Dueño en la app corta la
-- suscripción en Stripe, y una cancelación hecha en Stripe da de baja al alumno
-- en la app. Solo el Dueño da de baja: el alumno no tiene botón de cancelar.
--
-- Modelo: una suscripción de Stripe = UNA fila de `suscripciones`
-- (proveedor_pago 'stripe', referencia_externa 'sub_…', sin fecha de fin). Los
-- ciclos mensuales y el saldo de clases salen de `ciclo_de_suscripcion`, como
-- siempre. `payment_status` refleja lo que diga Stripe (active / past_due /
-- unpaid / canceled): si Stripe no cobra, la cuota deja de cubrir.
--
-- Solo para el rol de servicio (el webhook). Sin ningún `drop`.

-- 1) Primer cobro de una suscripción: activa la cuota (sin fecha de fin).
create or replace function public.confirmar_suscripcion_stripe(
  p_session_id text,
  p_subscription_id text,
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
  v_suscripcion uuid;
begin
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

  if p_subscription_id is null or p_subscription_id not like 'sub\_%' then
    update public.pagos_stripe
       set estado = 'revisar',
           error = 'Stripe no ha devuelto la suscripción. No se ha activado la cuota.',
           updated_at = now()
     where id = v_pago.id;
    return null;
  end if;

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

  begin
    -- Sin meses ni fecha de fin: la cuota dura mientras Stripe siga cobrando.
    v_suscripcion := public._alta_cuota(
      v_pago.alumno_id, v_pago.tarifa_id, null, false,
      p_importe_centimos / 100.0, null,
      md5('stripe:' || p_session_id)::uuid,
      'stripe', p_subscription_id, null, v_pago.academia_id
    );
  exception when others then
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

-- 2) Una suscripción se cancela en Stripe (la cancela el Dueño desde Stripe, o
-- Stripe la corta tras agotar los reintentos): la cuota se cierra y el alumno
-- pasa a baja en la app, con la misma función que usa el Dueño
-- (`dar_de_baja_alumno`: libera reservas, cierra la cuota, no borra nada).
--
-- Si la cuota YA estaba cerrada, no se hace nada: es el caso en que la cancela
-- la propia app (el Dueño da de baja) o en que llega un segundo aviso.
create or replace function public.suscripcion_cancelada_en_stripe(p_subscription_id text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_s record;
  v_estado text;
  v_rol text;
  v_dueno uuid;
begin
  select id, alumno_id, academia_id, estado into v_s
    from public.suscripciones
   where referencia_externa = p_subscription_id
     and proveedor_pago = 'stripe'
   for update;

  if not found or v_s.estado = 'cancelada' then
    return;
  end if;

  update public.suscripciones
     set estado = 'cancelada',
         payment_status = 'canceled',
         fecha_fin = least(coalesce(fecha_fin, now()), now())
   where id = v_s.id;

  select estado, rol into v_estado, v_rol
    from public.profiles where id = v_s.alumno_id;

  if v_rol = 'alumno' and v_estado = 'activo' then
    select id into v_dueno
      from public.profiles
     where academia_id = v_s.academia_id and rol = 'dueño' and estado = 'activo'
     limit 1;

    if v_dueno is not null then
      -- La baja es cosa del Dueño: se hace con su identidad, solo dentro de esta
      -- función (que solo puede llamar el servidor) y solo en esta transacción.
      perform set_config('request.jwt.claims',
        json_build_object('sub', v_dueno, 'role', 'authenticated')::text, true);
      perform public.dar_de_baja_alumno(v_s.alumno_id);
      perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
    end if;
  end if;
end;
$function$;

-- 3) Estado del cobro que dice Stripe (active / past_due / unpaid): refleja
-- lo que Stripe diga sin inventar reglas propias. Una cancelación NO pasa por
-- aquí: va por `suscripcion_cancelada_en_stripe`.
create or replace function public.reflejar_estado_suscripcion_stripe(
  p_subscription_id text,
  p_estado_stripe text
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $function$
  update public.suscripciones
     set payment_status = case
           when p_estado_stripe in ('active', 'trialing') then 'active'
           when p_estado_stripe = 'past_due' then 'past_due'
           else 'unpaid'
         end
   where referencia_externa = p_subscription_id
     and proveedor_pago = 'stripe'
     and estado in ('pendiente_pago', 'activa', 'pausada');
$function$;

revoke all on function public.confirmar_suscripcion_stripe(text, text, bigint, text) from public, anon, authenticated;
revoke all on function public.suscripcion_cancelada_en_stripe(text) from public, anon, authenticated;
revoke all on function public.reflejar_estado_suscripcion_stripe(text, text) from public, anon, authenticated;
grant execute on function public.confirmar_suscripcion_stripe(text, text, bigint, text) to service_role;
grant execute on function public.suscripcion_cancelada_en_stripe(text) to service_role;
grant execute on function public.reflejar_estado_suscripcion_stripe(text, text) to service_role;
