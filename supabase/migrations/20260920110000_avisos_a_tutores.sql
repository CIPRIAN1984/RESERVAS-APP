-- ITACA — Los avisos de un menor sin cuenta llegan a su tutor, no al vacío.
--
-- Cancelar una clase, editarla, promover a alguien de la lista de espera o
-- publicar una novedad encolaban el aviso con `user_id = alumno_id`. Para
-- un adulto eso es correcto: tiene su propia cuenta y su propio móvil. Para
-- un hijo (`profiles.tiene_cuenta = false`, ver 20260903123919), no hay
-- ningún dispositivo registrado con ese `user_id` — `send-push` no
-- encuentra ningún token, no manda nada, y aun así marca el aviso como
-- "enviado". El padre no se entera nunca de nada de su hijo: ni de que se
-- ha cancelado su clase, ni de que ha entrado en lista de espera, ni de
-- una novedad de la academia.
--
-- Se corrige con una función de un único propósito: dado un alumno,
-- devuelve a quién hay que avisar de verdad — él mismo si tiene cuenta
-- propia, o su tutor si no la tiene. Los cuatro sitios que encolaban avisos
-- por `alumno_id` directamente pasan a resolver primero el destinatario.
--
-- No cambia ninguna regla de quién puede reservar, cancelar o editar: solo
-- a quién le llega el aviso de que ha pasado.

-- ============================================================
-- 1. destinatario_notificacion: el propio alumno, o su tutor si es menor
-- ============================================================

create or replace function public.destinatario_notificacion(p_alumno_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case
    when p.tiene_cuenta then p.id
    else (
      select rf.parent_id
        from public.relaciones_familia rf
        where rf.child_id = p.id
        limit 1
    )
  end
  from public.profiles p
  where p.id = p_alumno_id;
$$;

-- Función interna, como _saldo_clases: solo la usan otras funciones
-- security definer, nunca el cliente directamente.
revoke all on function public.destinatario_notificacion(uuid)
  from public, anon, authenticated;

-- ============================================================
-- 2. cancelar_clase: un aviso por destinatario real, no por inscripción
-- ============================================================

create or replace function public.cancelar_clase(p_clase_id uuid)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_rol text;
  v_actor_academia uuid;
  v_clase_academia uuid;
  v_clase_estado text;
  v_titulo text;
  v_notificados int;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select rol, academia_id into v_actor_rol, v_actor_academia
    from public.profiles where id = v_actor_id;

  if v_actor_rol not in ('dueño', 'profesor') then
    raise exception 'No autorizado.';
  end if;

  select academia_id, estado, titulo
    into v_clase_academia, v_clase_estado, v_titulo
    from public.clases
    where id = p_clase_id
    for update;

  if not found or v_clase_academia is distinct from v_actor_academia then
    raise exception 'Clase no encontrada.';
  end if;

  if v_clase_estado = 'cancelada' then
    raise exception 'Esta clase ya está cancelada.';
  end if;

  update public.clases
    set estado = 'cancelada', cancelada_at = now()
    where id = p_clase_id;

  with afectados as (
    update public.inscripciones
      set estado = 'cancelado', cancelada_at = now()
      where clase_id = p_clase_id
        and estado in ('inscrito', 'espera')
      returning alumno_id
  ),
  destinatarios as (
    select distinct public.destinatario_notificacion(alumno_id) as destinatario
    from afectados
  )
  insert into public.notificaciones_outbox (user_id, titulo, cuerpo, data)
  select
    destinatario,
    'Clase cancelada',
    'Se ha cancelado ' || v_titulo || '.',
    jsonb_build_object('type', 'clase_cancelada', 'clase_id', p_clase_id)
  from destinatarios
  where destinatario is not null;

  get diagnostics v_notificados = row_count;
  return v_notificados;
end;
$function$;

-- ============================================================
-- 3. editar_clase: mismo cambio para el aviso de cambio de horario
-- ============================================================

create or replace function public.editar_clase(
  p_clase_id uuid,
  p_titulo text,
  p_descripcion text,
  p_fecha_hora_inicio timestamptz,
  p_fecha_hora_fin timestamptz,
  p_aforo_maximo int
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_rol text;
  v_actor_academia uuid;
  v_clase_academia uuid;
  v_clase_estado text;
  v_inicio_actual timestamptz;
  v_inscritos_actuales int;
  v_cambia_horario boolean;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select rol, academia_id into v_actor_rol, v_actor_academia
    from public.profiles where id = v_actor_id;

  if v_actor_rol not in ('dueño', 'profesor') then
    raise exception 'No autorizado.';
  end if;

  if p_titulo is null or trim(p_titulo) = '' then
    raise exception 'El título no puede estar vacío.';
  end if;

  if p_fecha_hora_fin <= p_fecha_hora_inicio then
    raise exception 'La hora de fin debe ser posterior a la de inicio.';
  end if;

  if p_aforo_maximo <= 0 then
    raise exception 'El aforo debe ser mayor que cero.';
  end if;

  select academia_id, estado, fecha_hora_inicio
    into v_clase_academia, v_clase_estado, v_inicio_actual
    from public.clases
    where id = p_clase_id
    for update;

  if not found or v_clase_academia is distinct from v_actor_academia then
    raise exception 'Clase no encontrada.';
  end if;

  if v_clase_estado = 'cancelada' then
    raise exception 'No se puede editar una clase cancelada.';
  end if;

  select count(*)::int into v_inscritos_actuales
    from public.inscripciones
    where clase_id = p_clase_id and estado = 'inscrito';

  if p_aforo_maximo < v_inscritos_actuales then
    raise exception
      'El aforo no puede ser menor que las % plazas ya confirmadas.',
      v_inscritos_actuales;
  end if;

  v_cambia_horario := p_fecha_hora_inicio <> v_inicio_actual;

  update public.clases
    set titulo = p_titulo,
        descripcion = p_descripcion,
        fecha_hora_inicio = p_fecha_hora_inicio,
        fecha_hora_fin = p_fecha_hora_fin,
        aforo_maximo = p_aforo_maximo
    where id = p_clase_id;

  if v_cambia_horario then
    insert into public.notificaciones_outbox (user_id, titulo, cuerpo, data)
    select distinct
      d.destinatario,
      'Cambio de horario',
      'La clase ' || p_titulo || ' ha cambiado de hora.',
      jsonb_build_object('type', 'clase_editada', 'clase_id', p_clase_id)
    from (
      select public.destinatario_notificacion(i.alumno_id) as destinatario
      from public.inscripciones i
      where i.clase_id = p_clase_id
        and i.estado in ('inscrito', 'espera')
    ) d
    where d.destinatario is not null;
  end if;
end;
$function$;

-- ============================================================
-- 4. cancelar_reserva: el aviso de "plaza confirmada" al promocionar
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
  if v_usuario_id <> v_actor_id
     and not public.es_padre_de(v_usuario_id)
     and not (
       public.current_rol() in ('dueño', 'profesor')
       and public.academia_id_de(v_usuario_id) = public.current_academia_id()
     )
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

  if v_estado_cancelado = 'inscrito' then
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

-- ============================================================
-- 5. encolar_push_nueva_novedad: una fila por destinatario real, sin
-- duplicar el aviso cuando un mismo tutor tiene varios hijos en la
-- academia (o su propio perfil de alumno, además de sus hijos).
-- ============================================================

create or replace function public.encolar_push_nueva_novedad()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
begin
  insert into public.notificaciones_outbox (user_id, titulo, cuerpo, data)
  select distinct d.destinatario,
         'Nueva novedad',
         new.titulo,
         jsonb_build_object('tipo', 'novedad', 'novedad_id', new.id::text)
  from (
    select public.destinatario_notificacion(p.id) as destinatario
    from public.profiles p
    where p.academia_id = new.academia_id
      and p.rol = 'alumno'
      and p.id <> new.autor_id
  ) d
  where d.destinatario is not null;
  return new;
end;
$function$;
