-- ITACA — Fiabilidad, Fase 2: reconciliación del ciclo de vida de pagos.
--
-- Cierra tres cabos sueltos operativos de la integración de Stripe:
--
-- 1. Pagos abandonados: si el alumno inicia un pedido/suscripción (nace en
--    'pendiente_pago') y cierra la app sin pagar, o si un webhook se pierde,
--    la fila se queda en 'pendiente_pago' para siempre. Peor: el índice único
--    "una suscripción activa/pendiente por alumno" (0015) y el de "una
--    inscripción/pedido en curso" dejan al usuario bloqueado sin poder
--    reintentar. Se añade un job que expira lo obsoleto.
--
-- 2. Reembolsos: no había ninguna vía para revertir un pedido pagado. Se
--    añade la reposición de stock cuando un pedido pasa de 'reservado' a
--    'cancelado' (lo dispara el webhook al recibir charge.refunded), como
--    complemento simétrico de descontar_stock_al_reservar (0016).

-- ============================================================
-- 1. Expiración de pagos pendientes obsoletos
-- ============================================================

-- security definer: la ejecuta el scheduler (rol cron), que no es un usuario
-- autenticado; necesita saltarse las RLS/GRANT de cliente. search_path fijo,
-- igual que el resto de funciones definer del proyecto.
create or replace function public.expirar_pagos_pendientes(p_antiguedad interval default interval '1 hour')
returns table (pedidos_expirados int, suscripciones_expiradas int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pedidos int;
  v_suscripciones int;
begin
  with expirados as (
    update public.pedidos
      set estado = 'cancelado', payment_status = 'canceled'
      where estado = 'pendiente_pago'
        and created_at < now() - p_antiguedad
      returning 1
  )
  select count(*)::int into v_pedidos from expirados;

  with expiradas as (
    update public.suscripciones
      set estado = 'cancelada', payment_status = 'canceled', fecha_fin = now()
      where estado = 'pendiente_pago'
        and created_at < now() - p_antiguedad
      returning 1
  )
  select count(*)::int into v_suscripciones from expiradas;

  return query select v_pedidos, v_suscripciones;
end;
$$;

-- Nadie autenticado debe poder invocar esto como RPC: es un job de sistema.
revoke all on function public.expirar_pagos_pendientes(interval) from public, authenticated, anon;

-- Programa el job cada 15 minutos si pg_cron está disponible en el proyecto.
-- Se hace condicional para que la migración no falle en entornos (p. ej. el
-- Supabase local de CI) donde la extensión no esté instalada.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    -- Reprograma de forma idempotente (unschedule previo si existía).
    perform cron.unschedule('itaca_expirar_pagos_pendientes')
      where exists (select 1 from cron.job where jobname = 'itaca_expirar_pagos_pendientes');
    perform cron.schedule(
      'itaca_expirar_pagos_pendientes',
      '*/15 * * * *',
      $cron$ select public.expirar_pagos_pendientes(); $cron$
    );
  else
    raise notice 'pg_cron no disponible: expirar_pagos_pendientes debe programarse manualmente (Edge Function + cron externo).';
  end if;
end;
$$;

-- ============================================================
-- 2. Reposición de stock al cancelar un pedido ya pagado (reembolso)
-- ============================================================

create or replace function public.reponer_stock_al_cancelar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Solo se repone si el pedido ya había descontado stock (estaba 'reservado'
  -- o más avanzado) y ahora se cancela. Un pedido que se cancela desde
  -- 'pendiente_pago' nunca descontó stock, así que no se repone.
  if new.estado = 'cancelado'
     and old.estado in ('reservado', 'confirmado', 'entregado') then
    update public.productos
      set stock = stock + new.cantidad
      where id = new.producto_id;
  end if;
  return new;
end;
$$;

create trigger pedidos_reponer_stock
  after update on public.pedidos
  for each row execute function public.reponer_stock_al_cancelar();
