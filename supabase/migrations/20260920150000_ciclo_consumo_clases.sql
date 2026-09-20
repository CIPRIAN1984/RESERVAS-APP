-- Política comercial decidida por Cipri (20/09/2026, punto 6 de la
-- auditoría externa): el crédito de una clase se retiene al reservar
-- (ya lo hacía _saldo_clases), se devuelve si se cancela con margen, y se
-- consume para siempre en dos casos que hasta ahora no distinguía nadie:
--
--   1. Confirmar asistencia — ya consumía la clase (tabla `asistencias`).
--   2. Un no presentado — clase ya terminada, seguía 'inscrito' y nadie
--      marcó asistencia. Hasta hoy esto NO consumía nada: `_saldo_clases`
--      solo miraba `fecha_hora_inicio > now()` para "reservadas" y
--      `asistencias` para "gastadas", así que una clase pasada sin marcar
--      desaparecía de las dos cuentas. Se podía reservar sin límite y no
--      presentarse nunca sin gastar ni una clase de la tarifa.
--   3. Una cancelación fuera de plazo (después de
--      `cancelacion_limite_minutos`) tampoco consumía nada: `cancelar_
--      reserva` marcaba `cancelacion_tardia = true` pero _saldo_clases
--      nunca miraba esa columna. Cancelar tarde y cancelar con margen
--      liberaban la plaza exactamente igual.
--
-- Ninguno de los dos son ataques ni fallos de permisos — es simplemente
-- que la cuenta de "cuántas clases te quedan" nunca implementó la política
-- de negocio real. Se corrige aquí, sin tocar la mecánica de reservar (que
-- ya retiene el crédito) ni la de marcar asistencia (que ya consume).
--
-- ============================================================
-- 1. _saldo_clases: "gastadas" ahora suma tres orígenes, no solo la
--    asistencia confirmada.
-- ============================================================

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

  -- "Gastadas" ahora es la unión de tres orígenes, cada clase contada una
  -- sola vez:
  --   a) asistencia confirmada — consume para siempre;
  --   b) no presentado — la clase ya terminó (fecha_hora_fin <= now()),
  --      seguía 'inscrito' y nadie marcó asistencia. Se consume sola al
  --      terminar la clase. El Dueño o el Profesor pueden perdonarla
  --      llamando a cancelar_reserva en nombre del alumno: esa llamada
  --      nunca se marca como tardía cuando quien cancela es el staff en
  --      nombre de otra persona (ver cancelar_reserva más abajo), así que
  --      libera el crédito en vez de consumirlo;
  --   c) cancelación fuera de plazo — se avisó demasiado tarde para
  --      liberar la plaza a otro alumno, así que cuenta igual que si no se
  --      hubiera cancelado. `cancelacion_tardia` solo llega a `true`
  --      cuando cancela el propio alumno o su tutor fuera del margen de
  --      `academias.cancelacion_limite_minutos`; una corrección del staff
  --      nunca la marca así.
  select count(*)::int into v_gastadas
    from (
      select a.clase_id
        from public.asistencias a
        join public.clases c on c.id = a.clase_id
       where a.alumno_id = p_alumno_id
         and c.fecha_hora_inicio >= v_ciclo.inicio
         and c.fecha_hora_inicio < v_ciclo.fin
      union all
      select i.clase_id
        from public.inscripciones i
        join public.clases c on c.id = i.clase_id
       where i.alumno_id = p_alumno_id
         and i.estado = 'inscrito'
         and c.fecha_hora_fin <= now()
         and c.fecha_hora_inicio >= v_ciclo.inicio
         and c.fecha_hora_inicio < v_ciclo.fin
         and not exists (
           select 1 from public.asistencias a2
            where a2.clase_id = i.clase_id and a2.alumno_id = i.alumno_id
         )
      union all
      select i.clase_id
        from public.inscripciones i
        join public.clases c on c.id = i.clase_id
       where i.alumno_id = p_alumno_id
         and i.estado = 'cancelado'
         and i.cancelacion_tardia = true
         and c.fecha_hora_inicio >= v_ciclo.inicio
         and c.fecha_hora_inicio < v_ciclo.fin
    ) consumidas;

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

-- ============================================================
-- 2. cancelar_reserva: cancelar en nombre de otro alumno (Dueño o
--    Profesor corrigiendo) nunca cuenta como tardía. El resto de la
--    función no cambia: mismos permisos, misma promoción de lista de
--    espera, mismo aviso al destinatario real.
-- ============================================================

create or replace function public.cancelar_reserva(p_clase_id uuid, p_alumno_id uuid default null::uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_usuario_id uuid;
  v_inscripcion_id uuid;
  v_estado_cancelado text;
  v_academia_id uuid;
  v_titulo text;
  v_inicio timestamptz;
  v_aforo_maximo int;
  v_limite_minutos int;
  v_exigir_cuota boolean;
  v_cancelacion_tardia boolean := false;
  v_ocupadas int;
  v_espera_id uuid;
  v_promovido_id uuid;
  v_destinatario uuid;
  v_es_correccion_staff boolean;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  -- Sin `p_alumno_id`, cancelo lo mío. Con él, solo si soy su padre o
  -- tutor. `es_padre_de` es security definer y mira relaciones_familia, en
  -- la que ya ningún cliente puede escribir a mano (migración 20260903120000).
  v_usuario_id := coalesce(p_alumno_id, v_actor_id);

  -- Se amplía el 06/09/2026: además del propio alumno y de su padre, el
  -- Dueño y el Profesor de la academia pueden cancelar la reserva de un
  -- alumno suyo. Hacía falta para que `dar_de_baja_alumno` pueda liberar las
  -- plazas futuras del que se va **reutilizando esta función**, en vez de
  -- copiar aquí la promoción de la lista de espera. Duplicar esa lógica es
  -- exactamente el fallo del 03/09.
  --
  -- 20/09/2026: cuando quien cancela es el staff y lo hace por otro
  -- alumno, es una corrección administrativa, no una cancelación del
  -- propio interesado — nunca cuenta como tardía, aunque la clase ya haya
  -- pasado (es justo el caso de perdonar un no presentado). Cancelar la
  -- propia reserva (incluida la del Dueño o Profesor que también entrena)
  -- sigue las reglas normales.
  v_es_correccion_staff :=
    v_usuario_id <> v_actor_id
    and public.current_rol() in ('dueño', 'profesor')
    and public.academia_id_de(v_usuario_id) = public.current_academia_id();

  if v_usuario_id <> v_actor_id
     and not public.es_padre_de(v_usuario_id)
     and not v_es_correccion_staff
  then
    raise exception 'Solo puedes cancelar por ti o por tus hijos.';
  end if;

  select i.id,
         i.estado,
         c.academia_id,
         c.titulo,
         c.fecha_hora_inicio,
         c.aforo_maximo,
         a.cancelacion_limite_minutos,
         a.exigir_cuota_para_reservar
    into v_inscripcion_id,
         v_estado_cancelado,
         v_academia_id,
         v_titulo,
         v_inicio,
         v_aforo_maximo,
         v_limite_minutos,
         v_exigir_cuota
    from public.inscripciones i
    join public.clases c on c.id = i.clase_id
    join public.academias a on a.id = c.academia_id
    where i.clase_id = p_clase_id
      and i.alumno_id = v_usuario_id
      and i.estado in ('inscrito', 'espera')
    order by case when i.estado = 'inscrito' then 0 else 1 end
    limit 1
    for update of i, c;

  if not found then
    raise exception 'No tienes una reserva activa en esta clase.';
  end if;

  if v_estado_cancelado = 'inscrito' and not v_es_correccion_staff then
    v_cancelacion_tardia :=
      now() > v_inicio - make_interval(mins => v_limite_minutos);
  end if;

  update public.inscripciones
    set estado = 'cancelado',
        cancelada_at = now(),
        cancelacion_tardia = v_cancelacion_tardia
    where id = v_inscripcion_id;

  if v_estado_cancelado = 'inscrito' and v_inicio > now() then
    with candidatos as (
      select
        w.id,
        p.estado as perfil_estado,
        p.rol,
        case when p.rol = 'alumno' then public._saldo_clases(w.alumno_id) end as saldo
      from public.inscripciones w
      join public.profiles p on p.id = w.alumno_id
      where w.clase_id = p_clase_id
        and w.estado = 'espera'
    ),
    no_elegibles as (
      select id from candidatos
      where perfil_estado <> 'activo'
        or (
          rol = 'alumno'
          and (
            (
              v_exigir_cuota
              and not (saldo->>'tiene_cuota')::boolean
            )
            or (
              (saldo->>'tiene_cuota')::boolean
              and not (saldo->>'ilimitada')::boolean
              and (saldo->>'disponibles')::int <= 0
            )
          )
        )
    )
    update public.inscripciones w
      set estado = 'cancelado',
          cancelada_at = now()
      where w.id in (select id from no_elegibles);

    select count(*)::int
      into v_ocupadas
      from public.inscripciones
      where clase_id = p_clase_id and estado = 'inscrito';

    if v_ocupadas < v_aforo_maximo then
      select id, alumno_id
        into v_espera_id, v_promovido_id
        from public.inscripciones
        where clase_id = p_clase_id and estado = 'espera'
        order by created_at, id
        limit 1
        for update;

      if found then
        update public.inscripciones
          set estado = 'inscrito',
              promovida_at = now()
          where id = v_espera_id;

        v_destinatario := public.destinatario_notificacion(v_promovido_id);

        if v_destinatario is not null then
          insert into public.notificaciones_outbox (
            user_id,
            titulo,
            cuerpo,
            data
          ) values (
            v_destinatario,
            'Plaza confirmada',
            'Has conseguido plaza en ' || v_titulo || '.',
            jsonb_build_object(
              'type', 'waitlist_promoted',
              'clase_id', p_clase_id
            )
          );
        end if;
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'estado_cancelado', v_estado_cancelado,
    'cancelacion_tardia', v_cancelacion_tardia,
    'alumno_promovido_id', v_promovido_id
  );
end;
$function$;
