-- Corrige la promoción desde lista de espera: no comprobaba las clases
-- restantes de la tarifa, solo que la cuota siguiera activa.
--
-- reservar_clase() bloquea a un alumno con cuota limitada y saldo a cero
-- (ver 20260810100910_bloquear_reserva_sin_clases.sql), pero
-- cancelar_reserva() solo retiraba de la cola a quien ya no tenía cuota
-- ACTIVA — nunca comprobó si a quien sí la tenía le quedaban clases. Un
-- alumno sin ninguna clase disponible podía ser promovido igualmente si
-- llevaba tiempo en la cola.
--
-- De paso, otro fallo menor emparejado: la limpieza de la cola exigía
-- cuota activa a todo alumno sin mirar si la academia exige cuota para
-- reservar (academias.exigir_cuota_para_reservar, por defecto false —
-- ver DECISIONS.md 03/08/2026). reservar_clase() sí respeta ese ajuste;
-- cancelar_reserva() no lo miraba y podía sacar de la cola a alguien que
-- nunca necesitó cuota para estar ahí.
--
-- ============================================================
-- Función interna: cálculo de saldo sin comprobación de "quién pregunta"
-- ============================================================
-- clases_restantes() exige que quien llama sea el propio alumno o
-- dueño/profesor de su academia — correcto para una llamada directa desde
-- la app, pero cancelar_reserva() necesita mirar el saldo de OTRO alumno
-- (el que está en cola) sin que quien cancela tenga ese permiso. Se separa
-- el cálculo puro en una función interna sin comprobación de identidad,
-- solo invocable desde dentro de otra función security definer (revocada
-- de public/anon/authenticated más abajo), y clases_restantes() pasa a
-- delegar en ella tras su propia comprobación de permisos.

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
     and s.estado = 'activa'
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

revoke all on function public._saldo_clases(uuid) from public, anon, authenticated;

-- clases_restantes() delega el cálculo, conserva su propia comprobación de
-- quién puede preguntar por el saldo de quién.
create or replace function public.clases_restantes(p_alumno_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_rol text;
  v_actor_academia uuid;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select rol, academia_id into v_actor_rol, v_actor_academia
    from public.profiles where id = v_actor_id;

  if p_alumno_id <> v_actor_id then
    if v_actor_rol not in ('dueño', 'profesor') then
      raise exception 'No autorizado.';
    end if;
    if not exists (
      select 1 from public.profiles
       where id = p_alumno_id and academia_id = v_actor_academia
    ) then
      raise exception 'No autorizado.';
    end if;
  end if;

  return public._saldo_clases(p_alumno_id);
end;
$function$;

-- ============================================================
-- cancelar_reserva(): la limpieza de la cola ahora respeta
-- exigir_cuota_para_reservar y comprueba clases_restantes, igual que
-- reservar_clase().
-- ============================================================

create or replace function public.cancelar_reserva(p_clase_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_usuario_id uuid := auth.uid();
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
begin
  if v_usuario_id is null then
    raise exception 'No autorizado.';
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
    -- Retira de la cola a quien ya no cumple las condiciones para reservar
    -- esta clase: inactivo, sin cuota cuando la academia la exige, o con
    -- cuota limitada ya sin clases disponibles. Se calcula el saldo una
    -- sola vez por candidato (CTE), no una vez por condición.
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

        insert into public.notificaciones_outbox (
          user_id,
          titulo,
          cuerpo,
          data
        ) values (
          v_promovido_id,
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

  return jsonb_build_object(
    'estado_cancelado', v_estado_cancelado,
    'cancelacion_tardia', v_cancelacion_tardia,
    'alumno_promovido_id', v_promovido_id
  );
end;
$function$;

revoke all on function public.cancelar_reserva(uuid) from public, anon;
grant execute on function public.cancelar_reserva(uuid) to authenticated;
