-- ITACA — Encargo de Cipri del 17/11/2026: la lista de espera se queda
-- APAGADA en el piloto mientras los avisos no estén verificados.
--
-- Por qué: la lista de espera sube sola a quien espera cuando alguien cancela
-- y, si no viene, se le descuenta la clase. Esa persona solo se entera por el
-- aviso al móvil, y ese aviso no se ha verificado de extremo a extremo (en la
-- web ni existe). Cipri no quiere que alguien pierda una clase por una plaza
-- que nunca supo que tenía.
--
-- Qué hace: un Dueño ya no puede ENCENDERLA desde la app (el interruptor sale
-- bloqueado y, además, el servidor lo rechaza). No cambia lo que ya haya
-- guardado en ninguna academia ni toca el resto de la lógica de reservas: para
-- volver a abrirla basta con quitar este disparador cuando los avisos estén
-- verificados. El trabajo del servidor (migraciones, sembrado) no se ve
-- afectado: solo las peticiones con la sesión de un usuario.

create or replace function public.bloquear_encender_lista_espera()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $function$
begin
  if new.lista_espera_activa
     and not coalesce(old.lista_espera_activa, false)
     and current_user in ('authenticated', 'anon') then
    raise exception
      'La lista de espera no está disponible en esta versión: todavía no hay avisos verificados.';
  end if;
  return new;
end;
$function$;

create trigger academias_bloquear_lista_espera
  before update of lista_espera_activa on public.academias
  for each row execute function public.bloquear_encender_lista_espera();

-- Una función de disparador no se llama a mano.
revoke execute on function public.bloquear_encender_lista_espera()
  from public, anon, authenticated;
