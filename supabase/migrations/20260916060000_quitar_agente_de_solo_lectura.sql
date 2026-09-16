-- Cipri cancela la función del agente personal: se retira por completo.
--
-- Deshace exactamente lo que añadió `20260914100000_agente_de_solo_lectura.sql`:
-- las dos tablas, las diez funciones y sus permisos. No toca ninguna otra
-- tabla, columna ni función de la aplicación — esto nunca escribió en nada
-- que no fuera lo suyo.
--
-- Las claves que hubiera creadas se van con la tabla; no había ningún dato
-- de alumnos en estas tablas, solo huellas de claves y un registro de
-- accesos.

drop function if exists public.agente_alumnos(uuid, boolean, boolean);
drop function if exists public.agente_correo_de(uuid, uuid);
drop function if exists public.agente_horario(uuid, date, date);
drop function if exists public.agente_avisos(uuid, integer);
drop function if exists public.agente_proximo_cinturon(text, boolean);
drop function if exists public.agente_resumen(uuid, date, date);
drop function if exists public.agente_cuotas_al_dia(uuid);

drop function if exists public.listar_consultas_agente(integer);
drop function if exists public.revocar_clave_agente(uuid);
drop function if exists public.listar_claves_agente();
drop function if exists public.crear_clave_agente(text, boolean);

drop table if exists public.consultas_agente;
drop table if exists public.claves_agente;
