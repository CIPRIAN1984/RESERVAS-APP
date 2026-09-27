-- ITACA — El saldo de clases se calcula en el ciclo real de cada clase.
--
-- Auditoría externa del 23/09/2026, verificada contra la base de datos:
--
-- 1. `ciclo_vigente()` ignoraba la periodicidad de la tarifa. Salvo
--    'suelta', todas se trataban como mensuales: una tarifa trimestral de
--    10 clases («bono 10 sesiones») reponía las 10 clases cada mes, y una
--    anual igual. El fallo estaba en la función desde el 31/07/2026 y
--    ninguna prueba lo cazó porque ninguna comprobaba un ciclo de 3 meses.
--
-- 2. `_saldo_clases()` calculaba siempre el ciclo de HOY. Al reservar una
--    clase del ciclo siguiente se comprobaba el saldo del ciclo actual:
--    podía bloquear una reserva legítima (este mes agotado, el que viene
--    libre) o dejar reservar sin límite en el ciclo siguiente (esas
--    reservas no contaban en ningún sitio).
--
-- 3. Entre el inicio y el final de una clase, una plaza sin confirmar no
--    contaba ni como reservada (se exigía `fecha_hora_inicio > now()`) ni
--    como ausencia (se exige `fecha_hora_fin <= now()`): durante esa hora el
--    saldo parecía mayor de lo real. Ahora «reservada» dura hasta que la
--    clase TERMINA, y justo ahí pasa a ausencia. No hay hueco.
--
-- 4. Dos reservas simultáneas del mismo alumno en clases distintas leían el
--    mismo saldo a la vez y podían gastar dos veces el último crédito:
--    `reservar_clase` bloqueaba la fila de la clase, no al alumno. Ahora se
--    toma un candado por alumno (`pg_advisory_xact_lock`) antes de mirar su
--    saldo, y lo mismo hace la promoción desde lista de espera.
--
--    Orden de candados, siempre el mismo para no bloquearse entre sí:
--    primero la fila de la CLASE, después el ALUMNO.
--
-- 5. Consecuencia de lo anterior: la cuota que manda es la que cubre el DÍA
--    DE LA CLASE. Si la clase cae después de que acabe la cuota pagada,
--    para ese día no hay cuota: si la academia no la exige (ITACA, por
--    decisión de Cipri) se reserva igual y sale «sin cuota»; si la exige,
--    se rechaza. Antes bastaba con tener cuota HOY para reservar clases de
--    dentro de un mes.

-- ============================================================
-- 1. ciclo_en: el ciclo de una cuota que contiene una fecha concreta
-- ============================================================
--
-- Mensual = 1 mes, trimestral = 3, anual = 12, contados desde la fecha de
-- inicio de la cuota. 'suelta' es un único ciclo de inicio a fin.
--
-- Los meses se suman siempre desde la fecha de inicio (inicio + n meses),
-- nunca uno detrás de otro, para que los finales de mes no se vayan
-- desplazando: una cuota del 31 de enero tiene ciclos 31 ene → 28 feb →
-- 31 mar → 30 abr. `age()` puede quedarse un mes corto en esos casos, así
-- que el resultado se corrige comprobando los bordes.

create or replace function public.ciclo_en(
  p_fecha_inicio timestamptz,
  p_fecha_fin timestamptz,
  p_periodicidad text,
  p_referencia timestamptz
)
returns table (inicio timestamptz, fin timestamptz)
language plpgsql
stable
set search_path = public, pg_temp
as $function$
declare
  v_largo int;
  v_n int;
begin
  if p_periodicidad = 'suelta' then
    return query
      select p_fecha_inicio, coalesce(p_fecha_fin, 'infinity'::timestamptz);
    return;
  end if;

  v_largo := case p_periodicidad
               when 'trimestral' then 3
               when 'anual' then 12
               else 1
             end;

  if p_referencia <= p_fecha_inicio then
    v_n := 0;
  else
    v_n := (
      extract(year from age(p_referencia, p_fecha_inicio))::int * 12
      + extract(month from age(p_referencia, p_fecha_inicio))::int
    ) / v_largo;

    while p_fecha_inicio + make_interval(months => (v_n + 1) * v_largo)
          <= p_referencia loop
      v_n := v_n + 1;
    end loop;

    while v_n > 0
          and p_fecha_inicio + make_interval(months => v_n * v_largo)
              > p_referencia loop
      v_n := v_n - 1;
    end loop;
  end if;

  return query
    select p_fecha_inicio + make_interval(months => v_n * v_largo),
           p_fecha_inicio + make_interval(months => (v_n + 1) * v_largo);
end;
$function$;

revoke all on function public.ciclo_en(timestamptz, timestamptz, text, timestamptz)
  from public, anon, authenticated;

-- ciclo_vigente se conserva con su firma de siempre: es el ciclo de hoy.
create or replace function public.ciclo_vigente(
  p_fecha_inicio timestamptz,
  p_fecha_fin timestamptz,
  p_periodicidad text
)
returns table (inicio timestamptz, fin timestamptz)
language sql
stable
set search_path = public, pg_temp
as $function$
  select * from public.ciclo_en(p_fecha_inicio, p_fecha_fin, p_periodicidad, now());
$function$;

-- ============================================================
-- 2. _saldo_clases(alumno, referencia): saldo del ciclo que contiene la
--    fecha de referencia (la de la clase que se reserva, o hoy).
-- ============================================================
--
-- La cuota que cuenta es la que CUBRE esa fecha. Si la clase cae después
-- de que termine la cuota pagada, no hay cuota para ese día: el límite no
-- se aplica y la clase sale «sin cuota» en la lista, como decidió Cipri
-- (se reserva igual y se cobra en mano).
--
-- Cada clase del ciclo cuenta una sola vez, en uno de dos montones:
--   gastadas   = asistencia confirmada
--              + no presentado (la clase ya terminó, seguía inscrito)
--              + cancelación fuera de plazo
--   reservadas = inscrito, la clase aún no ha terminado, sin asistencia

create or replace function public._saldo_clases(
  p_alumno_id uuid,
  p_referencia timestamptz
)
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
     and s.fecha_inicio <= p_referencia
     and (s.fecha_fin is null or s.fecha_fin > p_referencia)
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
    from public.ciclo_en(
      v_suscripcion.fecha_inicio,
      v_suscripcion.fecha_fin,
      v_suscripcion.periodicidad,
      p_referencia
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
     and c.fecha_hora_fin > now()
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

revoke all on function public._saldo_clases(uuid, timestamptz)
  from public, anon, authenticated;

-- La versión de un argumento (la que usa `clases_restantes` para enseñar el
-- saldo en la app) es el saldo de hoy.
create or replace function public._saldo_clases(p_alumno_id uuid)
returns jsonb
language sql
security definer
set search_path = public, pg_temp
as $function$
  select public._saldo_clases(p_alumno_id, now());
$function$;

revoke all on function public._saldo_clases(uuid)
  from public, anon, authenticated;

-- ============================================================
-- 3. _cuota_cubre: ¿tiene el alumno una cuota en vigor ese día?
-- ============================================================
--
-- Las mismas condiciones que usa _saldo_clases para elegir la cuota:
-- activa o de prueba (una pausada no cuenta), cobrada, y con ese día dentro
-- de sus fechas.

create or replace function public._cuota_cubre(
  p_alumno_id uuid,
  p_academia_id uuid,
  p_fecha timestamptz
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select exists (
    select 1
      from public.suscripciones
     where alumno_id = p_alumno_id
       and academia_id = p_academia_id
       and estado in ('activa', 'prueba')
       and payment_status = 'active'
       and fecha_inicio <= p_fecha
       and (fecha_fin is null or fecha_fin > p_fecha)
  );
$function$;

revoke all on function public._cuota_cubre(uuid, uuid, timestamptz)
  from public, anon, authenticated;

-- ============================================================
-- 4. _puede_ocupar_plaza: la misma regla para reservar y para subir desde
--    la lista de espera.
-- ============================================================
--
-- Antes la promoción repetía estas condiciones dentro de una consulta y
-- con el saldo de hoy; ahora ambas usan la fecha de la clase.

create or replace function public._puede_ocupar_plaza(
  p_alumno_id uuid,
  p_academia_id uuid,
  p_referencia timestamptz,
  p_exigir_cuota boolean
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_estado text;
  v_rol text;
  v_saldo jsonb;
begin
  select estado, rol into v_estado, v_rol
    from public.profiles
   where id = p_alumno_id;

  if not found or v_estado <> 'activo' then
    return false;
  end if;

  if v_rol <> 'alumno' then
    return true;
  end if;

  -- Mismo criterio que reservar_clase: una cuota que cubra el día de la
  -- clase, solo si la academia lo exige.
  if p_exigir_cuota
     and not public._cuota_cubre(p_alumno_id, p_academia_id, p_referencia) then
    return false;
  end if;

  v_saldo := public._saldo_clases(p_alumno_id, p_referencia);

  return not (
    (v_saldo->>'tiene_cuota')::boolean
    and not (v_saldo->>'ilimitada')::boolean
    and (v_saldo->>'disponibles')::int <= 0
  );
end;
$function$;

revoke all on function public._puede_ocupar_plaza(uuid, uuid, timestamptz, boolean)
  from public, anon, authenticated;

-- ============================================================
-- 5. reservar_clase: saldo del ciclo de la clase y candado por alumno.
--    El resto de la función no cambia.
-- ============================================================

create or replace function public.reservar_clase(p_clase_id uuid, p_alumno_id uuid default null::uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_usuario_id uuid;
  v_academia_id uuid;
  v_rol text;
  v_estado text;
  v_entrena boolean;
  v_clase_academia_id uuid;
  v_clase_estado text;
  v_inicio timestamptz;
  v_aforo_maximo int;
  v_lista_espera_activa boolean;
  v_exigir_cuota boolean;
  v_inscritos int;
  v_resultado text;
  v_saldo jsonb;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  -- Sin `p_alumno_id`, reservo para mí. Con él, solo si soy su padre o
  -- tutor. `es_padre_de` es security definer y mira relaciones_familia, en
  -- la que ya ningún cliente puede escribir a mano (migración 20260903120000).
  v_usuario_id := coalesce(p_alumno_id, v_actor_id);

  if v_usuario_id <> v_actor_id and not public.es_padre_de(v_usuario_id) then
    raise exception 'Solo puedes reservar para ti o para tus hijos.';
  end if;

  select academia_id, rol, estado, entrena
    into v_academia_id, v_rol, v_estado, v_entrena
    from public.profiles
    where id = v_usuario_id;

  if not found or v_estado <> 'activo' then
    raise exception 'Tu cuenta no está activa.';
  end if;

  if v_rol not in ('alumno', 'profesor', 'dueño') or v_academia_id is null then
    raise exception 'Tu cuenta no puede reservar clases.';
  end if;

  -- Quien ha marcado que no entrena no ocupa plaza: si no, saldría en la
  -- lista de la clase pero no en la de alumnos, y el profesor no
  -- entendería nada.
  if not v_entrena then
    if v_usuario_id = v_actor_id then
      raise exception 'Tienes marcado que no entrenas. Cámbialo en tu perfil para reservar.';
    else
      raise exception 'Este alumno tiene marcado que no entrena.';
    end if;
  end if;

  select c.academia_id,
         c.estado,
         c.fecha_hora_inicio,
         c.aforo_maximo,
         a.lista_espera_activa,
         a.exigir_cuota_para_reservar
    into v_clase_academia_id,
         v_clase_estado,
         v_inicio,
         v_aforo_maximo,
         v_lista_espera_activa,
         v_exigir_cuota
    from public.clases c
    join public.academias a on a.id = c.academia_id
    where c.id = p_clase_id
    for update of c;

  if not found or v_clase_academia_id is distinct from v_academia_id then
    raise exception 'Clase no encontrada.';
  end if;

  if v_clase_estado <> 'activa' then
    raise exception 'Esta clase no admite nuevas reservas.';
  end if;

  if v_inicio <= now() then
    raise exception 'Solo puedes reservar clases futuras.';
  end if;

  -- Candado por alumno, DESPUÉS del de la clase (mismo orden en
  -- cancelar_reserva). Sin él, dos reservas simultáneas en clases distintas
  -- leían el mismo saldo y podían gastar dos veces el último crédito.
  perform pg_advisory_xact_lock(7301, hashtext(v_usuario_id::text));

  if exists (
    select 1
      from public.inscripciones
      where clase_id = p_clase_id
        and alumno_id = v_usuario_id
        and estado in ('inscrito', 'espera')
  ) then
    raise exception 'Ya tienes una reserva o plaza de espera en esta clase.';
  end if;

  -- La cuota que se mira es la **del alumno** (el hijo, si se reserva por
  -- él): Cipri decidió una cuota por hijo, no una familiar.
  -- Solo si la academia lo exige. Con el ajuste por defecto, quien no tiene
  -- cuota reserva igual y sale marcado en la lista de la clase. Una prueba
  -- cuenta como cuota (es justo lo que permite probar antes de pagar); una
  -- cuota pausada NO cuenta (es justo lo que significa pausarla).
  -- 25/09/2026: la cuota tiene que cubrir el DÍA DE LA CLASE, no solo hoy.
  -- Antes, con la cuota pagada hasta mañana se podían reservar clases de
  -- dentro de un mes sin haberlas pagado.
  if v_exigir_cuota and v_rol = 'alumno'
     and not public._cuota_cubre(v_usuario_id, v_academia_id, v_inicio) then
    raise exception 'Debes tener una cuota activa para reservar esta clase.';
  end if;

  -- Límite de clases del ciclo AL QUE PERTENECE LA CLASE, no el de hoy.
  if v_rol = 'alumno' then
    v_saldo := public._saldo_clases(v_usuario_id, v_inicio);
    if (v_saldo->>'tiene_cuota')::boolean
       and not (v_saldo->>'ilimitada')::boolean
       and (v_saldo->>'disponibles')::int <= 0
    then
      -- «para esa fecha» y no «este mes»: el ciclo es el de la clase, y
      -- puede ser trimestral o anual.
      raise exception
        'No te quedan clases en tu tarifa para esa fecha. Renueva o compra una clase suelta.';
    end if;
  end if;

  select count(*)::int
    into v_inscritos
    from public.inscripciones
    where clase_id = p_clase_id and estado = 'inscrito';

  if v_inscritos < v_aforo_maximo then
    v_resultado := 'inscrito';
  elsif v_lista_espera_activa then
    v_resultado := 'espera';
  else
    raise exception 'Aforo completo para esta clase.';
  end if;

  insert into public.inscripciones (
    clase_id,
    alumno_id,
    academia_id,
    estado
  ) values (
    p_clase_id,
    v_usuario_id,
    v_academia_id,
    v_resultado
  );

  return v_resultado;
end;
$function$;

-- ============================================================
-- 6. cancelar_reserva: la promoción desde lista de espera usa la misma
--    regla (_puede_ocupar_plaza), con el ciclo de la clase, y toma el
--    candado del alumno antes de darle la plaza.
--    Permisos, cancelación tardía y avisos no cambian.
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
  -- tutor, o el Dueño/Profesor de su academia (ver 06/09/2026).
  v_usuario_id := coalesce(p_alumno_id, v_actor_id);

  -- 20/09/2026: cuando quien cancela es el staff y lo hace por otro
  -- alumno, es una corrección administrativa — nunca cuenta como tardía,
  -- aunque la clase ya haya pasado (es perdonar un no presentado).
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
    -- Retira de la cola a quien ya no podría ocupar la plaza.
    update public.inscripciones w
      set estado = 'cancelado',
          cancelada_at = now()
      where w.clase_id = p_clase_id
        and w.estado = 'espera'
        and not public._puede_ocupar_plaza(
          w.alumno_id, v_academia_id, v_inicio, v_exigir_cuota
        );

    select count(*)::int
      into v_ocupadas
      from public.inscripciones
      where clase_id = p_clase_id and estado = 'inscrito';

    if v_ocupadas < v_aforo_maximo then
      -- El primero de la cola, comprobado otra vez con su candado puesto:
      -- entre la limpieza de arriba y este momento pudo gastar su último
      -- crédito reservando otra clase.
      loop
        select id, alumno_id
          into v_espera_id, v_promovido_id
          from public.inscripciones
          where clase_id = p_clase_id and estado = 'espera'
          order by created_at, id
          limit 1
          for update;

        exit when not found;

        perform pg_advisory_xact_lock(7301, hashtext(v_promovido_id::text));

        if public._puede_ocupar_plaza(
          v_promovido_id, v_academia_id, v_inicio, v_exigir_cuota
        ) then
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

          exit;
        end if;

        update public.inscripciones
          set estado = 'cancelado',
              cancelada_at = now()
          where id = v_espera_id;
        v_promovido_id := null;
      end loop;
    end if;
  end if;

  return jsonb_build_object(
    'estado_cancelado', v_estado_cancelado,
    'cancelacion_tardia', v_cancelacion_tardia,
    'alumno_promovido_id', v_promovido_id
  );
end;
$function$;
