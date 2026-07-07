-- ITACA — Pagos, Fase 1: Stripe Connect (onboarding de la cuenta de cada academia).
--
-- Cada academia tiene su propia cuenta Stripe Connect (tipo Standard) — el
-- dinero va directo ahí, ITACA nunca lo retiene. Estas columnas solo las
-- puede escribir el service_role desde las Edge Functions (nunca el
-- cliente autenticado), por eso además del RLS habitual usamos un REVOKE de
-- privilegio a nivel de columna: RLS filtra filas, no columnas, así que un
-- Dueño con permiso normal de UPDATE sobre su propia academia (política ya
-- existente `academias_update`) no debe poder tocar estos campos de pago.

alter table public.academias
  add column if not exists stripe_account_id text,
  add column if not exists stripe_onboarding_status text not null default 'not_started',
  add column if not exists stripe_charges_enabled boolean not null default false;

alter table public.academias
  add constraint academias_stripe_onboarding_status_check
  check (stripe_onboarding_status in ('not_started', 'pending', 'complete'));

revoke update (stripe_account_id, stripe_onboarding_status, stripe_charges_enabled)
  on public.academias from authenticated;

-- ============================================================
-- Idempotencia de webhooks de Stripe (puede reenviar el mismo evento).
-- Solo la escribe el webhook (service_role); nadie más necesita acceso.
-- ============================================================

create table if not exists public.stripe_webhook_events (
  id text primary key,
  type text not null,
  processed_at timestamptz not null default now()
);

alter table public.stripe_webhook_events enable row level security;
-- Sin políticas: ni siquiera Administrador necesita verlas desde el cliente;
-- solo el service_role (que ignora RLS) las toca.
