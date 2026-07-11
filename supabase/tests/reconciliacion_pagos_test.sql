-- Tests pgTAP de la reconciliación de pagos (migración 0018): expiración de
-- pagos pendientes obsoletos y reposición de stock al cancelar.

begin;
select plan(4);

-- ── Semilla ──────────────────────────────────────────────────────────────
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000d1', 'duenoR@test.dev'),
  ('00000000-0000-0000-0000-0000000000d2', 'alumnoR@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-000000000ee1', 'Academia R', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-000000000ee1', 'dueño', 'Dueño R', 'activo'),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-000000000ee1', 'alumno', 'Alumno R', 'activo');

insert into public.productos (id, academia_id, nombre, precio, stock) values
  ('00000000-0000-0000-0000-000000000f01', '00000000-0000-0000-0000-000000000ee1', 'Kimono', 80, 10);

-- Un pedido pendiente_pago "antiguo" (2 horas) y uno reciente.
insert into public.pedidos (id, academia_id, alumno_id, producto_id, cantidad, estado, created_at) values
  ('00000000-0000-0000-0000-000000000a01', '00000000-0000-0000-0000-000000000ee1', '00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-000000000f01', 1, 'pendiente_pago', now() - interval '2 hours'),
  ('00000000-0000-0000-0000-000000000a02', '00000000-0000-0000-0000-000000000ee1', '00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-000000000f01', 1, 'pendiente_pago', now());

-- ── 1. La expiración cancela solo el pedido antiguo ──────────────────────
select public.expirar_pagos_pendientes();

select is(
  (select estado from public.pedidos where id = '00000000-0000-0000-0000-000000000a01'),
  'cancelado',
  'El pedido pendiente_pago antiguo se cancela'
);
select is(
  (select estado from public.pedidos where id = '00000000-0000-0000-0000-000000000a02'),
  'pendiente_pago',
  'El pedido pendiente_pago reciente se mantiene'
);

-- ── 2. Cancelar un pedido ya reservado (pagado) repone el stock ──────────
-- Lo llevamos a 'reservado' (el trigger de 0016 descuenta stock: 10 -> 9).
update public.pedidos set estado = 'reservado' where id = '00000000-0000-0000-0000-000000000a02';
select is(
  (select stock from public.productos where id = '00000000-0000-0000-0000-000000000f01'),
  9,
  'Al reservar (pagar) se descuenta 1 de stock (10 -> 9)'
);

-- Ahora lo cancelamos (simula charge.refunded): el stock vuelve a 10.
update public.pedidos set estado = 'cancelado' where id = '00000000-0000-0000-0000-000000000a02';
select is(
  (select stock from public.productos where id = '00000000-0000-0000-0000-000000000f01'),
  10,
  'Al cancelar un pedido pagado se repone el stock (9 -> 10)'
);

select * from finish();
rollback;
