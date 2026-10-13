-- ITACA — Auditoría externa del 09/10/2026, punto 6: apuntar a quien llega
-- a clase sin reserva.
--
-- Qué pasaba: quien llegaba sin reservar no podía figurar en la clase. El
-- profesor no podía reservar por él (`reservar_clase` solo deja por uno
-- mismo o por los hijos), ni pasarle lista (una asistencia exige una
-- reserva 'inscrito' desde el 20/09), y desde que empieza la clase ya no
-- se admiten reservas.
--
-- Decisión de Cipri (09/10/2026): el Dueño o el Profesor pueden apuntarlo
-- desde la clase, **respetando las reglas**: el aforo, la cuota si la
-- academia la exige, y las clases de su tarifa. Queda apuntado y con la
-- asistencia confirmada por quien lo hizo.
--
-- Ventana: la misma que pasar lista (media hora antes de empezar en
-- adelante; ver `asistencias_insert`). Antes no tiene sentido: aún no ha
-- llegado nadie.

create or replace function public.apuntar_en_clase(
  p_clase_id uuid,
  p_alumno_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_rol text;
  v_actor_estado text;
  v_actor_academia uuid;
  v_clase_academia uuid;
  v_clase_estado text;
  v_inicio timestamptz;
  v_aforo int;
  v_exigir_cuota boolean;
  v_alumno_academia uuid;
  v_alumno_rol text;
  v_alumno_estado text;
  v_entrena boolean;
  v_espera_id uuid;
  v_inscritos int;
  v_saldo jsonb;
begin
  select rol, estado, academia_id
    into v_actor_rol, v_actor_estado, v_actor_academia
    from public.profiles
   where id = v_actor_id;

  -- `coalesce`: sin perfil todo es NULL y un `if NULL` no lanza nada
  -- (ver 20261009090000_permisos_sin_perfil.sql).
  if not coalesce(
    v_actor_rol in ('dueño', 'profesor') and v_actor_estado = 'activo',
    false
  ) then
    raise exception 'Solo el Dueño o un Profesor pueden apuntar a alguien en la clase.';
  end if;

  -- Mismo orden de candados que reservar_clase: la clase y después el alumno.
  select c.academia_id, c.estado, c.fecha_hora_inicio, c.aforo_maximo,
         a.exigir_cuota_para_reservar
    into v_clase_academia, v_clase_estado, v_inicio, v_aforo, v_exigir_cuota
    from public.clases c
    join public.academias a on a.id = c.academia_id
   where c.id = p_clase_id
   for update of c;

  if not found or v_clase_academia is distinct from v_actor_academia then
    raise exception 'Clase no encontrada.';
  end if;

  if v_clase_estado = 'cancelada' then
    raise exception 'Esta clase está cancelada.';
  end if;

  if now() < v_inicio - interval '30 minutes' then
    raise exception 'Se puede apuntar a quien ha venido desde media hora antes de la clase.';
  end if;

  select academia_id, rol, estado, entrena
    into v_alumno_academia, v_alumno_rol, v_alumno_estado, v_entrena
    from public.profiles
   where id = p_alumno_id;

  if not found or v_alumno_academia is distinct from v_clase_academia then
    raise exception 'Esa persona no es de tu academia.';
  end if;

  if v_alumno_estado <> 'activo' then
    raise exception 'Esa persona no está activa en la academia.';
  end if;

  if not v_entrena then
    raise exception 'Tiene marcado que no entrena.';
  end if;

  perform pg_advisory_xact_lock(7301, hashtext(p_alumno_id::text));

  if exists (
    select 1 from public.asistencias
     where clase_id = p_clase_id and alumno_id = p_alumno_id
  ) then
    raise exception 'Ya tiene la asistencia confirmada en esta clase.';
  end if;

  if exists (
    select 1 from public.inscripciones
     where clase_id = p_clase_id and alumno_id = p_alumno_id
       and estado = 'inscrito'
  ) then
    raise exception 'Ya estaba apuntado: confírmale la asistencia en la lista.';
  end if;

  -- Las mismas reglas que reservar_clase, solo para alumnos.
  if v_alumno_rol = 'alumno' then
    if v_exigir_cuota
       and not public._cuota_cubre(p_alumno_id, v_clase_academia, v_inicio) then
      raise exception 'No tiene cuota para esta clase. Cóbrasela antes de apuntarlo.';
    end if;

    v_saldo := public._saldo_clases(p_alumno_id, v_inicio);
    if (v_saldo->>'tiene_cuota')::boolean
       and not (v_saldo->>'ilimitada')::boolean
       and (v_saldo->>'disponibles')::int <= 0
    then
      raise exception 'No le quedan clases en su tarifa. Cóbrale una clase extra antes de apuntarlo.';
    end if;
  end if;

  -- Si estaba en la lista de espera, pasa a tener plaza (si la hay).
  select id into v_espera_id
    from public.inscripciones
   where clase_id = p_clase_id and alumno_id = p_alumno_id and estado = 'espera'
   for update;

  if v_espera_id is not null then
    select count(*)::int into v_inscritos
      from public.inscripciones
     where clase_id = p_clase_id and estado = 'inscrito';
    if v_inscritos >= v_aforo then
      raise exception 'Aforo completo para esta clase.';
    end if;
    update public.inscripciones
       set estado = 'inscrito', promovida_at = now()
     where id = v_espera_id;
  else
    -- `check_aforo` (disparador) rechaza la inserción si está llena.
    insert into public.inscripciones (clase_id, alumno_id, academia_id, estado)
    values (p_clase_id, p_alumno_id, v_clase_academia, 'inscrito');
  end if;

  insert into public.asistencias (clase_id, alumno_id, validado_por)
  values (p_clase_id, p_alumno_id, v_actor_id);
end;
$function$;

revoke all on function public.apuntar_en_clase(uuid, uuid) from public, anon;
grant execute on function public.apuntar_en_clase(uuid, uuid) to authenticated;
