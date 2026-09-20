-- ITACA — Las pruebas de 1 día también respetan el límite de clases de su
-- tarifa.
--
-- `_saldo_clases()` solo reconocía suscripciones con estado 'activa' al
-- calcular cuántas clases le quedan a alguien. Una prueba nace con estado
-- 'prueba' (ver 20260827120000_prueba_y_pausada.sql: "cuenta como cuota al
-- reservar, igual que 'activa'"), así que esta función nunca la encontraba:
-- devolvía `tiene_cuota: false` para cualquiera con una prueba en marcha.
--
-- El efecto en cadena: `reservar_clase()` sí exige cuota activa o de prueba
-- para el primer filtro (si la academia lo exige), pero el segundo filtro
-- — el que bloquea cuando ya no quedan clases en el ciclo — solo se aplica
-- `if (v_saldo->>'tiene_cuota')::boolean`, y con una prueba esa condición
-- siempre era falsa. Resultado: quien está de prueba puede reservar todas
-- las clases que quiera, aunque la tarifa de prueba tenga
-- `clases_incluidas` puesto a 1.
--
-- Se corrige aquí, en el único sitio que hace falta: `_saldo_clases()` pasa
-- a buscar también `estado = 'prueba'` (su `payment_status` ya se guarda
-- como 'active' desde `activar_cuota_efectivo`, así que el resto de la
-- condición no cambia). `clases_restantes()` y `reservar_clase()` delegan
-- en ella, así que quedan corregidos sin tocarlos.

create or replace function public._saldo_clases(p_alumno_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_suscripcion record;
  v_ciclo record;
  v_gastadas int;
  v_reservadas int;
begin
  select s.*, t.clases_incluidas, t.periodicidad, t.nombre as tarifa_nombre
    into v_suscripcion
    from public.suscripciones s
    join public.tarifas t on t.id = s.tarifa_id
   where s.alumno_id = p_alumno_id
     and s.estado in ('activa', 'prueba')
     and s.payment_status = 'active'
     and s.fecha_inicio <= now()
     and (s.fecha_fin is null or s.fecha_fin > now())
   order by s.fecha_inicio desc
   limit 1;

  if not found then
    return jsonb_build_object(
      'tiene_cuota', false,
      'ilimitada', false,
      'incluidas', 0,
      'gastadas', 0,
      'reservadas', 0,
      'disponibles', 0
    );
  end if;

  select * into v_ciclo
    from public.ciclo_vigente(
      v_suscripcion.fecha_inicio,
      v_suscripcion.fecha_fin,
      v_suscripcion.periodicidad
    );

  if v_suscripcion.clases_incluidas is null then
    return jsonb_build_object(
      'tiene_cuota', true,
      'ilimitada', true,
      'tarifa', v_suscripcion.tarifa_nombre,
      'ciclo_inicio', v_ciclo.inicio,
      'ciclo_fin', v_ciclo.fin
    );
  end if;

  select count(*)::int into v_gastadas
    from public.asistencias a
    join public.clases c on c.id = a.clase_id
   where a.alumno_id = p_alumno_id
     and c.fecha_hora_inicio >= v_ciclo.inicio
     and c.fecha_hora_inicio < v_ciclo.fin;

  select count(*)::int into v_reservadas
    from public.inscripciones i
    join public.clases c on c.id = i.clase_id
   where i.alumno_id = p_alumno_id
     and i.estado = 'inscrito'
     and c.fecha_hora_inicio > now()
     and c.fecha_hora_inicio >= v_ciclo.inicio
     and c.fecha_hora_inicio < v_ciclo.fin
     and not exists (
       select 1 from public.asistencias a
        where a.clase_id = i.clase_id and a.alumno_id = i.alumno_id
     );

  return jsonb_build_object(
    'tiene_cuota', true,
    'ilimitada', false,
    'tarifa', v_suscripcion.tarifa_nombre,
    'incluidas', v_suscripcion.clases_incluidas,
    'gastadas', v_gastadas,
    'reservadas', v_reservadas,
    'disponibles', greatest(
      0, v_suscripcion.clases_incluidas - v_gastadas - v_reservadas
    ),
    'ciclo_inicio', v_ciclo.inicio,
    'ciclo_fin', v_ciclo.fin
  );
end;
$function$;
