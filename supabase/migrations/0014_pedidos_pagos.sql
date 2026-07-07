-- ITACA — Pagos, Fase 2: cobro de la tienda (pago único con Stripe Connect).
--
-- Cambio de máquina de estados: antes 'reservado' significaba "quiero
-- comprar esto" sin dinero de por medio. Ahora nace en 'pendiente_pago' y
-- solo pasa a 'reservado' cuando el webhook confirma el pago — 'reservado'
-- pasa a significar "pagado, a la espera de que el Profesor lo prepare".
--
-- Lección aprendida en la Fase 1 (ver 0013): un REVOKE de columna no sirve
-- de nada si el rol ya tiene UPDATE de tabla completa. Aquí aplicamos el
-- mismo patrón correcto desde el principio: revocar todo y conceder solo lo
-- imprescindible.

alter table public.pedidos
  add column if not exists stripe_payment_intent_id text,
  add column if not exists payment_status text not null default 'pending',
  add column if not exists proveedor_pago text default 'stripe';

alter table public.pedidos
  add constraint pedidos_payment_status_check
  check (payment_status in ('pending', 'processing', 'succeeded', 'failed', 'canceled', 'refunded'));

alter table public.pedidos alter column estado set default 'pendiente_pago';

alter table public.pedidos drop constraint pedidos_estado_check;
alter table public.pedidos
  add constraint pedidos_estado_check
  check (estado in ('pendiente_pago', 'reservado', 'confirmado', 'entregado', 'cancelado'));

-- El alumno ya no actualiza su propio pedido directamente — la única vía de
-- pendiente_pago a reservado es el webhook de pago (service_role, que no
-- depende de estos privilegios de rol y por tanto no se ve afectado por
-- este cambio).
alter policy pedidos_update on public.pedidos
  using (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  )
  with check (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

-- El cliente (staff) solo puede tocar el estado de cumplimiento del pedido;
-- las columnas de pago son exclusivas de la Edge Function.
revoke update on public.pedidos from authenticated;
grant update (estado) on public.pedidos to authenticated;
