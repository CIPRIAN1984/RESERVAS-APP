-- Corrige un fallo de seguridad de la migración anterior: un REVOKE de
-- columna concreta no tiene ningún efecto si el rol ya tiene UPDATE a nivel
-- de tabla completa (que es justo lo que Supabase concede por defecto a
-- 'authenticated' sobre cada tabla). Se comprobó en vivo: un Dueño pudo
-- poner `stripe_charges_enabled = true` directamente por REST, saltándose
-- por completo la verificación de Stripe.
--
-- La única forma correcta de restringir columnas cuando ya existe un GRANT
-- ALL de tabla es invertir el modelo: revocar el UPDATE de tabla completa y
-- volver a conceder, explícitamente, solo las columnas que el cliente sí
-- debe poder editar directamente. Las columnas de Stripe (y `created_by`/
-- `approved_by`/`approved_at`) quedan fuera — solo las tocan las Edge
-- Functions (service_role) y las RPC `security definer` ya existentes
-- (`aprobar_academia`), que no dependen de estos privilegios de rol.

revoke update on public.academias from authenticated;

grant update (nombre, direccion, telefono, email_contacto, estado)
  on public.academias to authenticated;
