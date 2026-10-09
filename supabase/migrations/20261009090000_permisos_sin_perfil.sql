-- ITACA — Auditoría externa del 09/10/2026, punto 1: una cuenta sin perfil
-- podía saltarse controles de permisos.
--
-- Cómo se consigue una cuenta sin perfil: registrarse con la clave pública
-- de la app sin mandar `nombre`. `handle_new_user` deja pasar ese caso a
-- propósito (es como se siembra el Administrador desde el panel de
-- Supabase), y el usuario queda en `auth.users` sin fila en `profiles`.
--
-- Con esa cuenta, `current_rol()` y `current_academia_id()` devuelven NULL.
-- En SQL `NULL <> 'administrador'` no es verdadero ni falso, es NULL, y un
-- `if NULL then raise …` NO lanza el error. Tres funciones se fiaban solo
-- de una comprobación así:
--
-- 1. `cancelar_reserva(clase, alumno)`: cancelaba la reserva de cualquier
--    alumno. Comprobado en local antes de arreglarlo.
-- 2. `aprobar_academia(id)`: aprobaba una academia pendiente y activaba a
--    sus miembros pendientes. Hoy no hay ninguna pendiente en producción.
-- 3. `rechazar_academia(id)`: igual, aunque solo toca academias pendientes.
--
-- El resto de funciones con el mismo patrón tienen detrás una segunda
-- comprobación que sí para a una cuenta sin perfil (la academia de la clase
-- o del alumno tiene que ser la suya, y con NULL no lo es).
-- `sin_perfil_no_puede_nada_test.sql` llama a TODAS como cuenta sin perfil,
-- para que ninguna dependa de que alguien se acuerde.
--
-- No se arregla dentro de `current_rol()` (devolver otra cosa que NULL):
-- el disparador `check_suscripcion_estado_transicion` cuenta con que sea
-- NULL cuando no hay usuario (webhook de Stripe, trabajos programados) y
-- los pararía a todos.

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
  -- 09/10/2026: cada pieza con `coalesce(…, false)`. Sin perfil,
  -- `current_rol()` es NULL, la expresión entera quedaba NULL, y el
  -- `if … and not v_es_correccion_staff` de abajo, NULL también, no
  -- lanzaba el error: se cancelaba la reserva de otro.
  v_es_correccion_staff :=
    v_usuario_id <> v_actor_id
    and coalesce(public.current_rol() in ('dueño', 'profesor'), false)
    and coalesce(
      public.academia_id_de(v_usuario_id) = public.current_academia_id(),
      false
    );

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


create or replace function public.aprobar_academia(p_academia_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- `is distinct from` y no `<>`: sin perfil, NULL <> 'administrador' es
  -- NULL y el `if` no lanzaba el error.
  if public.current_rol() is distinct from 'administrador' then
    raise exception 'Solo un administrador puede aprobar academias.';
  end if;

  update public.academias
    set estado = 'approved', approved_by = auth.uid(), approved_at = now()
    where id = p_academia_id;

  update public.profiles
    set estado = 'activo'
    where academia_id = p_academia_id and estado = 'pendiente_aprobacion';
end;
$$;

revoke all on function public.aprobar_academia(uuid) from public, anon;
grant execute on function public.aprobar_academia(uuid) to authenticated;

create or replace function public.rechazar_academia(p_academia_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.current_rol() is distinct from 'administrador' then
    raise exception 'Solo un administrador puede rechazar academias.';
  end if;

  update public.academias
    set estado = 'rejected'
    where id = p_academia_id and estado = 'pending';

  if not found then
    raise exception 'Academia pendiente no encontrada.';
  end if;
end;
$$;

revoke all on function public.rechazar_academia(uuid) from public, anon;
grant execute on function public.rechazar_academia(uuid) to authenticated;

-- De paso: `ciclo_vigente` estaba abierta a cualquiera con sesión pero no
-- la llama nadie (ni la app ni otra función), y además fallaba al usarla
-- porque `ciclo_en`, que llama por dentro, ya estaba cerrada desde el
-- 25/09. Una función expuesta que no se usa es superficie sin motivo.
revoke execute on function public.ciclo_vigente(timestamptz, timestamptz, text)
  from public, anon, authenticated;
