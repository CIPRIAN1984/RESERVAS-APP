-- Borra el esquema "stripe_mirror" (14 tablas) que apareció en producción
-- sin ninguna migración local que lo respalde: nadie en este repositorio
-- las creó, ninguna pantalla ni Edge Function las lee o escribe, y no
-- coinciden con las tablas de cobros propias de esta app (tarifas,
-- suscripciones, stripe_webhook_events — esas SÍ siguen intactas, ver
-- 20260712124653_stripe_connect.sql).
--
-- Por las columnas (bootstrap_academia_id, bootstrap_tarifa_id, html_target,
-- include_in_mrr, bucket_label...) no es un espejo genérico de Stripe: es
-- una capa de informes de ingresos, seguramente de otro proyecto de Cipri
-- que comparte esta misma base de datos de Supabase. Confirmado con Cipri
-- (2026-08-12): no sirve para la integración de pagos de esta app, que se
-- construirá desde cero cuando toque (Stripe y Pagos sigue congelado, ver
-- FREEZE.md). Se borra sin más porque no tiene ninguna dependencia desde
-- las tablas propias de esta app (comprobado: sin FKs entrantes, sin
-- funciones que las mencionen).

-- cascade: stripe_raw_events tenía una FK propia hacia stripe_sync_runs
-- (interna a este mismo grupo de 14 tablas, todas se borran igual).
drop table if exists public.stripe_sync_runs cascade;
drop table if exists public.stripe_raw_events cascade;
drop table if exists public.stripe_business_map cascade;
drop table if exists public.stripe_refunds cascade;
drop table if exists public.stripe_payouts cascade;
drop table if exists public.stripe_balance_transactions cascade;
drop table if exists public.stripe_charges cascade;
drop table if exists public.stripe_payment_intents cascade;
drop table if exists public.stripe_invoices cascade;
drop table if exists public.stripe_subscriptions cascade;
drop table if exists public.stripe_prices cascade;
drop table if exists public.stripe_products cascade;
drop table if exists public.stripe_customers cascade;
drop table if exists public.stripe_accounts cascade;
