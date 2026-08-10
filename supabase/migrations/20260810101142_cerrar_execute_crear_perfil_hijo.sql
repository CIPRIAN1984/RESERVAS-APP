-- La migración familias_tutores creó crear_perfil_hijo() con el comentario
-- «no conceder execute directo: la Edge Function es la puerta», pero nunca
-- ejecutó el revoke. Por defecto Postgres concede EXECUTE a PUBLIC en toda
-- función nueva: sin este revoke, cualquiera sin sesión podía llamar a
-- /rest/v1/rpc/crear_perfil_hijo y crear un «hijo» colgando de cualquier
-- padre, porque la función es SECURITY DEFINER y no comprueba quién llama.
--
-- Repite el fallo documentado en la migración 0013: un revoke que falta no
-- se nota hasta que se busca expresamente con el Security Advisor.

revoke all on function public.crear_perfil_hijo(uuid, uuid, text, text, text)
  from public, anon, authenticated;
