-- ITACA — Pagos, Fase 3: cobro de tarifas (suscripciones recurrentes con
-- Stripe Connect / Billing).
--
-- Mismo cambio de máquina de estados que en pedidos (ver 0014): antes
-- 'activa' se ponía directamente sin pago de por medio (RPC suscribirse);
-- ahora la fila nace en 'pendiente_pago' y solo pasa a 'activa' cuando el
-- webhook confirma el cobro de la primera factura de Stripe Billing.
-- proveedor_pago/referencia_externa/payment_status ya existían sin usar
-- (ver 0009) — aquí se activan. referencia_externa pasa a guardar el id de
-- la Subscription de Stripe; se añade stripe_customer_id porque el Customer
-- del alumno vive dentro de la cuenta conectada de su academia (no hay
-- Customer global, igual que el resto del modelo Connect).

alter table public.suscripciones
  add column if not exists stripe_customer_id text;

alter table public.suscripciones alter column proveedor_pago set default 'stripe';
alter table public.suscripciones alter column payment_status set default 'pending';

-- Normaliza las filas existentes (creadas con el antiguo default 'n/a', sin
-- pago real de por medio) antes de imponer el nuevo check constraint.
update public.suscripciones
  set payment_status = case
    when estado = 'activa' then 'active'
    when estado in ('cancelada', 'expirada') then 'canceled'
    else 'pending'
  end
  where payment_status not in ('pending', 'active', 'past_due', 'canceled', 'unpaid');

alter table public.suscripciones drop constraint if exists suscripciones_payment_status_check;
alter table public.suscripciones
  add constraint suscripciones_payment_status_check
  check (payment_status in ('pending', 'active', 'past_due', 'canceled', 'unpaid'));

alter table public.suscripciones drop constraint if exists suscripciones_estado_check;
alter table public.suscripciones
  add constraint suscripciones_estado_check
  check (estado in ('pendiente_pago', 'activa', 'cancelada', 'expirada'));

alter table public.suscripciones alter column estado set default 'pendiente_pago';

-- ============================================================
-- La fila nace siempre en pendiente_pago, pase lo que pase en el insert del
-- cliente (mismo patrón que set_pedido_defaults fuerza precio_snapshot).
-- ============================================================

create or replace function public.set_suscripcion_defaults()
returns trigger
language plpgsql
as $$
begin
  select academia_id into new.academia_id from public.profiles where id = new.alumno_id;
  new.estado := 'pendiente_pago';
  new.payment_status := 'pending';
  new.fecha_inicio := now();
  new.fecha_fin := null;
  return new;
end;
$$;

drop trigger if exists suscripciones_set_academia on public.suscripciones;
create trigger suscripciones_set_defaults
  before insert on public.suscripciones
  for each row execute function public.set_suscripcion_defaults();

-- ============================================================
-- Solo una suscripción activa o en curso de pago por alumno a la vez (antes
-- el índice único solo cubría 'activa').
-- ============================================================

drop index if exists suscripciones_activa_unica_idx;
create unique index suscripciones_activa_unica_idx
  on public.suscripciones (alumno_id)
  where estado in ('activa', 'pendiente_pago');

-- ============================================================
-- El alumno ya no puede activar su propia suscripción ni tocar los campos
-- de pago directamente (columnas de pago exclusivas de la Edge Function,
-- vía service_role, que no está sujeta a estos GRANT). Se permite que el
-- alumno cancele la suya (activa -> cancelada) y que el staff gestione
-- cualquiera de su academia sin restricción.
-- ============================================================

revoke update on public.suscripciones from authenticated;
grant update (estado) on public.suscripciones to authenticated;

create or replace function public.check_suscripcion_estado_transicion()
returns trigger
language plpgsql
as $$
begin
  if new.estado is distinct from old.estado
     and public.current_rol() not in ('profesor', 'dueño', 'administrador') then
    if not (old.estado = 'activa' and new.estado = 'cancelada' and old.alumno_id = auth.uid()) then
      raise exception 'No autorizado para cambiar el estado de esta suscripción.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists suscripciones_check_transicion on public.suscripciones;
create trigger suscripciones_check_transicion
  before update on public.suscripciones
  for each row execute function public.check_suscripcion_estado_transicion();

-- La RPC suscribirse activaba la suscripción sin pago de por medio y,
-- además, ahora sería un agujero: al ser security invoker, un alumno podría
-- llamarla directamente para auto-activarse sin pagar. Se retira — el punto
-- de entrada del cliente pasa a ser la Edge Function
-- stripe-create-tarifa-subscription, y la activación real solo la hace el
-- webhook con service_role.
drop function if exists public.suscribirse(uuid);
