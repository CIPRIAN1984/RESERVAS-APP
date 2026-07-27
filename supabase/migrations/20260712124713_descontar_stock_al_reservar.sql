-- ITACA — Pagos, Fase 3: descuento de stock al confirmar el pago.
--
-- Gap preexistente a la integración de pagos (ver 0008_tienda.sql): la
-- columna productos.stock nunca se decrementaba en ningún flujo, aunque la
-- UI (catalogo_tab.dart) ya deshabilita "Reservar" cuando stock = 0.
--
-- Ahora que un pedido solo pasa a 'reservado' cuando el webhook de Stripe
-- confirma el pago (ver 0014_pedidos_pagos.sql), ese es el punto natural
-- para descontar stock. Se implementa como trigger AFTER UPDATE en pedidos
-- (no como RPC) porque el webhook ya hace un UPDATE simple con
-- service_role — no hace falta cambiar la Edge Function, y así el mismo
-- trigger cubre también el caso, ya permitido por el GRANT de 0014, de que
-- el staff marque un pedido como 'reservado' a mano.
--
-- El check `stock >= 0` de 0008_tienda.sql hace de guarda ante la carrera
-- rara del último artículo: dos confirmaciones de pago concurrentes sobre
-- el mismo producto harán que una de las dos actualizaciones falle en vez
-- de dejar stock negativo. Se acepta ese riesgo (ya asumido en el plan
-- original) en vez de reservar stock en el INSERT del pedido.
--
-- security definer + search_path fijo: mismo patrón que el resto de
-- triggers de siembra/autocompletado del proyecto (ver 0006_progreso.sql),
-- para no depender de que quien dispara el UPDATE tenga permiso de UPDATE
-- directo sobre productos.

create or replace function public.descontar_stock_al_reservar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado = 'reservado' and old.estado is distinct from 'reservado' then
    update public.productos
      set stock = stock - new.cantidad
      where id = new.producto_id;
  end if;
  return new;
end;
$$;

create trigger pedidos_descontar_stock
  after update on public.pedidos
  for each row execute function public.descontar_stock_al_reservar();
