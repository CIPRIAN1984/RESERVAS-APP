-- Cipri (dueño) no tenía forma de tocar una clase una vez creada: ni
-- editarla, ni cerrarla a nuevas reservas, ni cancelarla. Primera fase de
-- mejoras tras el piloto, punto 1.
--
-- Estados de una clase:
--   activa    (por defecto) admite reservas normalmente.
--   cerrada   ya no admite reservas nuevas, pero sigue en pie: quien ya
--             tenía plaza la mantiene. Reversible (se puede reabrir).
--   cancelada terminal: la clase no ocurre. Libera a todos los apuntados
--             (inscritos y lista de espera) y les avisa por notificación
--             push, igual que ya hace la promoción de lista de espera.
--
-- ============================================================
-- 1. Estado en la propia clase
-- ============================================================

alter table public.clases
  add column if not exists estado text not null default 'activa'
    check (estado in ('activa', 'cerrada', 'cancelada'));

alter table public.clases
  add column if not exists cancelada_at timestamptz;

-- El cliente ya tenía UPDATE de tabla completa en `clases` (solo acotado por
-- la RLS clases_update, que restringe la FILA pero no la COLUMNA — un
-- revoke de columna suelto no serviría de nada con ese grant de tabla
-- todavía puesto, como ya pasó una vez con Stripe). Se cierra a las
-- columnas editables a mano; `estado`/`cancelada_at` solo cambian a través
-- de las RPC de abajo, que son las únicas que liberan y avisan a los
-- apuntados cuando corresponde.
revoke update on public.clases from authenticated;
grant update (titulo, descripcion, fecha_hora_inicio, fecha_hora_fin, aforo_maximo)
  on public.clases to authenticated;

-- ============================================================
-- 2. reservar_clase() respeta el nuevo estado
-- ============================================================

create or replace function public.reservar_clase(p_clase_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_usuario_id uuid := auth.uid();
  v_academia_id uuid;
  v_rol text;
  v_estado text;
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
  if v_usuario_id is null then
    raise exception 'No autorizado.';
  end if;

  select academia_id, rol, estado
    into v_academia_id, v_rol, v_estado
    from public.profiles
    where id = v_usuario_id;

  if not found or v_estado <> 'activo' then
    raise exception 'Tu cuenta no está activa.';
  end if;

  if v_rol not in ('alumno', 'profesor', 'dueño') or v_academia_id is null then
    raise exception 'Tu cuenta no puede reservar clases.';
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

  if exists (
    select 1
      from public.inscripciones
      where clase_id = p_clase_id
        and alumno_id = v_usuario_id
        and estado in ('inscrito', 'espera')
  ) then
    raise exception 'Ya tienes una reserva o plaza de espera en esta clase.';
  end if;

  -- Solo si la academia lo exige. Con el ajuste por defecto, quien no tiene
  -- cuota reserva igual y sale marcado en la lista de la clase.
  if v_exigir_cuota and v_rol = 'alumno' and not exists (
    select 1
      from public.suscripciones
      where alumno_id = v_usuario_id
        and academia_id = v_academia_id
        and estado = 'activa'
        and payment_status = 'active'
        and fecha_inicio <= now()
        and (fecha_fin is null or fecha_fin > now())
  ) then
    raise exception 'Debes tener una cuota activa para reservar esta clase.';
  end if;

  -- Caso distinto del de arriba: aquí SÍ hay una cuota activa con número de
  -- clases, y ya no le queda ninguna este ciclo. No aplica a quien no tiene
  -- cuota (ese caso ya lo decide el bloque de arriba) ni a las ilimitadas.
  if v_rol = 'alumno' then
    v_saldo := public.clases_restantes(v_usuario_id);
    if (v_saldo->>'tiene_cuota')::boolean
       and not (v_saldo->>'ilimitada')::boolean
       and (v_saldo->>'disponibles')::int <= 0
    then
      raise exception
        'No te quedan clases en tu tarifa este mes. Renueva o compra una clase suelta.';
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
-- 3. listar_clases_semana() devuelve el estado, para que la app pueda
--    ocultar/marcar según corresponda.
-- ============================================================

-- Cambia la lista de columnas de salida (añade `estado`): hay que borrarla
-- antes, `create or replace` no admite cambiar el tipo de retorno.
drop function if exists public.listar_clases_semana(timestamptz, timestamptz);

create function public.listar_clases_semana(p_desde timestamptz, p_hasta timestamptz)
returns table (
  id uuid,
  titulo text,
  descripcion text,
  fecha_hora_inicio timestamptz,
  fecha_hora_fin timestamptz,
  aforo_maximo int,
  profesor_id uuid,
  profesor_nombre text,
  inscritos_count bigint,
  mi_estado text,
  estado text
)
language sql
stable
set search_path = public, pg_temp
as $$
  select
    c.id,
    c.titulo,
    c.descripcion,
    c.fecha_hora_inicio,
    c.fecha_hora_fin,
    c.aforo_maximo,
    c.profesor_id,
    p.nombre as profesor_nombre,
    (select count(*) from public.inscripciones i
       where i.clase_id = c.id and i.estado = 'inscrito') as inscritos_count,
    (select i.estado from public.inscripciones i
       where i.clase_id = c.id and i.alumno_id = auth.uid()
       order by i.created_at desc limit 1) as mi_estado,
    c.estado
  from public.clases c
  join public.profiles p on p.id = c.profesor_id
  where c.fecha_hora_inicio >= p_desde and c.fecha_hora_inicio < p_hasta
  order by c.fecha_hora_inicio;
$$;

-- drop function borra también el GRANT anterior: hay que volver a darlo.
revoke all on function public.listar_clases_semana(timestamptz, timestamptz)
  from public, anon;
grant execute on function public.listar_clases_semana(timestamptz, timestamptz)
  to authenticated;

-- ============================================================
-- 4. Editar una clase ya publicada
-- ============================================================
--
-- No es un simple UPDATE desde el cliente porque, si cambia la hora y hay
-- alumnos ya apuntados, hay que avisarles (decisión de Cipri, 18/08/2026) —
-- el mismo mecanismo de notificaciones_outbox que ya usa la promoción de
-- lista de espera.

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
    select
      i.alumno_id,
      'Cambio de horario',
      'La clase ' || p_titulo || ' ha cambiado de hora.',
      jsonb_build_object('type', 'clase_editada', 'clase_id', p_clase_id)
    from public.inscripciones i
    where i.clase_id = p_clase_id
      and i.estado in ('inscrito', 'espera');
  end if;
end;
$function$;

revoke all on function
  public.editar_clase(uuid, text, text, timestamptz, timestamptz, int)
  from public, anon;
grant execute on function
  public.editar_clase(uuid, text, text, timestamptz, timestamptz, int)
  to authenticated;

-- ============================================================
-- 5. Cerrar / reabrir una clase a nuevas reservas (reversible)
-- ============================================================

create or replace function public.cambiar_estado_clase(p_clase_id uuid, p_cerrar boolean)
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
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select rol, academia_id into v_actor_rol, v_actor_academia
    from public.profiles where id = v_actor_id;

  if v_actor_rol not in ('dueño', 'profesor') then
    raise exception 'No autorizado.';
  end if;

  select academia_id, estado into v_clase_academia, v_clase_estado
    from public.clases
    where id = p_clase_id
    for update;

  if not found or v_clase_academia is distinct from v_actor_academia then
    raise exception 'Clase no encontrada.';
  end if;

  if v_clase_estado = 'cancelada' then
    raise exception 'Esta clase está cancelada: no se puede reabrir.';
  end if;

  update public.clases
    set estado = case when p_cerrar then 'cerrada' else 'activa' end
    where id = p_clase_id;
end;
$function$;

revoke all on function public.cambiar_estado_clase(uuid, boolean) from public, anon;
grant execute on function public.cambiar_estado_clase(uuid, boolean) to authenticated;

-- ============================================================
-- 6. Cancelar una clase (terminal): libera a todos los apuntados y avisa
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
  )
  insert into public.notificaciones_outbox (user_id, titulo, cuerpo, data)
  select
    alumno_id,
    'Clase cancelada',
    'Se ha cancelado ' || v_titulo || '.',
    jsonb_build_object('type', 'clase_cancelada', 'clase_id', p_clase_id)
  from afectados;

  get diagnostics v_notificados = row_count;
  return v_notificados;
end;
$function$;

revoke all on function public.cancelar_clase(uuid) from public, anon;
grant execute on function public.cancelar_clase(uuid) to authenticated;
