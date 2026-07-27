-- Reduce la superficie RPC expuesta por PostgREST.
--
-- PostgreSQL concede EXECUTE sobre funciones nuevas a PUBLIC por defecto.
-- En un esquema expuesto por Supabase eso convierte también funciones
-- auxiliares y triggers en endpoints RPC. Revocamos ese comportamiento y
-- concedemos únicamente las operaciones que usa el cliente Flutter.

-- Las funciones futuras nacen cerradas; cada migración deberá conceder
-- explícitamente los roles que necesite.
alter default privileges in schema public
  revoke execute on functions from public, anon, authenticated;

-- Partimos de una lista cerrada para corregir también todas las funciones
-- creadas por las migraciones anteriores.
revoke execute on all functions in schema public
  from public, anon, authenticated;

-- El backend de confianza conserva acceso completo. El propietario postgres
-- mantiene sus privilegios implícitos para triggers y tareas pg_cron.
grant execute on all functions in schema public to service_role;
alter default privileges in schema public
  grant execute on functions to service_role;

-- RPC pública necesaria para los dos formularios de alta: antes de iniciar
-- sesión se debe poder elegir una academia ya aprobada.
grant execute on function public.listar_academias_aprobadas()
  to anon, authenticated;

-- Helpers SECURITY DEFINER usados dentro de las políticas RLS. No se
-- conceden a anon: las lecturas públicas pasan por la RPC anterior.
grant execute on function public.current_academia_id() to authenticated;
grant execute on function public.current_rol() to authenticated;

-- RPC del cliente autenticado. Todas validan identidad/rol o respetan RLS.
grant execute on function public.aprobar_academia(uuid) to authenticated;
grant execute on function public.cancelar_reserva(uuid) to authenticated;
grant execute on function public.generar_mis_clases_recurrentes()
  to authenticated;
grant execute on function public.listar_clases_semana(timestamptz, timestamptz)
  to authenticated;
grant execute on function public.listar_mis_solicitudes_cambio()
  to authenticated;
grant execute on function public.listar_solicitudes_pendientes_destino()
  to authenticated;
grant execute on function public.ranking_mensual(date) to authenticated;
grant execute on function public.rechazar_academia(uuid) to authenticated;
grant execute on function public.registrar_device_token(text, text)
  to authenticated;
grant execute on function public.reservar_clase(uuid) to authenticated;
grant execute on function public.resolver_cambio_escuela(uuid, boolean)
  to authenticated;

-- Fija la resolución de nombres de todas las funciones señaladas por el
-- Security Advisor. pg_temp queda al final para evitar que objetos temporales
-- suplanten relaciones o funciones de public.
alter function public.check_suscripcion_estado_transicion()
  set search_path = public, pg_temp;
alter function public.listar_clases_semana(timestamptz, timestamptz)
  set search_path = public, pg_temp;
alter function public.ranking_mensual(date)
  set search_path = public, pg_temp;
alter function public.set_academia_id_desde_clase()
  set search_path = public, pg_temp;
alter function public.set_pedido_defaults()
  set search_path = public, pg_temp;
alter function public.set_prestamo_academia()
  set search_path = public, pg_temp;
alter function public.set_solicitud_origen()
  set search_path = public, pg_temp;
alter function public.set_suscripcion_academia()
  set search_path = public, pg_temp;
alter function public.set_suscripcion_defaults()
  set search_path = public, pg_temp;

-- El bucket es público, por lo que las URLs públicas no necesitan una policy
-- SELECT. Se conserva SELECT del directorio propio para que el cliente pueda
-- listar o reemplazar su avatar sin permitir enumerar todos los objetos.
drop policy if exists avatars_select on storage.objects;
drop policy if exists avatars_select_own on storage.objects;
create policy avatars_select_own on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
