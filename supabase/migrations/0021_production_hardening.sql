-- ITC.2 Lab — endurecimiento previo a producción.
--
-- Cierra la escalada de privilegios en perfiles/academias, obliga a que las
-- reservas pasen por operaciones atómicas del servidor y evita cancelar una
-- suscripción solo en Postgres dejando el cobro vivo en Stripe.

-- ============================================================
-- Permisos de API explícitos
-- ============================================================

-- Las migraciones no deben depender de privilegios implícitos del entorno.
-- RLS sigue decidiendo qué filas puede ver o modificar cada usuario.
grant select on table
  public.academias,
  public.profiles,
  public.clases,
  public.inscripciones,
  public.asistencias,
  public.novedades,
  public.tecnicas,
  public.media_tecnica,
  public.progreso_alumno_tecnica,
  public.productos,
  public.pedidos,
  public.prestamos,
  public.tarifas,
  public.suscripciones,
  public.solicitudes_cambio_escuela,
  public.device_tokens,
  public.clases_recurrentes
to authenticated;

grant insert, update, delete on table
  public.clases,
  public.novedades,
  public.tecnicas,
  public.productos,
  public.tarifas,
  public.clases_recurrentes
to authenticated;

grant insert on table
  public.asistencias,
  public.media_tecnica,
  public.pedidos,
  public.prestamos,
  public.solicitudes_cambio_escuela,
  public.device_tokens
to authenticated;

grant update on table
  public.progreso_alumno_tecnica,
  public.prestamos,
  public.device_tokens
to authenticated;

grant delete on table
  public.media_tecnica,
  public.device_tokens
to authenticated;

-- El cliente solo cambia el estado logístico del pedido. Datos Stripe,
-- importes y referencias siguen reservados al backend.
grant update (estado) on public.pedidos to authenticated;

-- Tablas internas exclusivas de Edge Functions/service_role.
revoke all on public.stripe_webhook_events from anon, authenticated;
revoke all on public.notificaciones_outbox from anon, authenticated;

-- ============================================================
-- Privilegios de perfiles y academias
-- ============================================================

revoke insert, update, delete on public.profiles from authenticated;
grant update (nombre, apellidos, foto_url)
  on public.profiles to authenticated;

drop policy if exists profiles_update on public.profiles;
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update
  using (id = auth.uid())
  with check (id = auth.uid());

revoke insert, update, delete on public.academias from authenticated;
grant update (nombre, direccion, telefono, email_contacto)
  on public.academias to authenticated;

-- El rechazo deja de ser un UPDATE directo del cliente. Igual que la
-- aprobación, se ejecuta en servidor y comprueba explícitamente el rol.
create or replace function public.rechazar_academia(p_academia_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if public.current_rol() <> 'administrador' then
    raise exception 'Solo un administrador puede rechazar academias.';
  end if;

  update public.academias
    set estado = 'rejected'
    where id = p_academia_id and estado = 'pending';

  if not found then
    raise exception 'Academia pendiente no encontrada.';
  end if;
end;
$function$;

revoke all on function public.aprobar_academia(uuid) from public, anon;
grant execute on function public.aprobar_academia(uuid) to authenticated;
revoke all on function public.rechazar_academia(uuid) from public, anon;
grant execute on function public.rechazar_academia(uuid) to authenticated;

-- ============================================================
-- Reserva/cancelación atómica
-- ============================================================

-- Ningún cliente escribe inscripciones directamente. Así todas las altas
-- adquieren el mismo bloqueo por clase y no pueden superar el aforo mediante
-- dos peticiones concurrentes.
revoke insert, update, delete on public.inscripciones from authenticated;
drop policy if exists inscripciones_insert on public.inscripciones;
drop policy if exists inscripciones_update on public.inscripciones;

-- Refuerza también el trigger existente: incluso una inserción controlada de
-- back office o service_role adquiere el bloqueo de la clase antes de contar.
create or replace function public.check_aforo()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $function$
declare
  v_aforo_maximo int;
  v_inscritos int;
begin
  if new.estado <> 'inscrito' then
    return new;
  end if;

  select aforo_maximo
    into v_aforo_maximo
    from public.clases
    where id = new.clase_id
    for update;

  if not found then
    raise exception 'Clase no encontrada.';
  end if;

  select count(*)::int
    into v_inscritos
    from public.inscripciones
    where clase_id = new.clase_id and estado = 'inscrito';

  if v_inscritos >= v_aforo_maximo then
    raise exception 'Aforo completo para esta clase.';
  end if;

  return new;
end;
$function$;

create or replace function public.reservar_clase(p_clase_id uuid)
returns void
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
  v_inicio timestamptz;
  v_aforo_maximo int;
  v_inscritos int;
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

  -- El bloqueo de la fila de clase serializa todas las reservas de esa clase.
  select academia_id, fecha_hora_inicio, aforo_maximo
    into v_clase_academia_id, v_inicio, v_aforo_maximo
    from public.clases
    where id = p_clase_id
    for update;

  if not found or v_clase_academia_id is distinct from v_academia_id then
    raise exception 'Clase no encontrada.';
  end if;

  if v_inicio <= now() then
    raise exception 'Solo puedes reservar clases futuras.';
  end if;

  if exists (
    select 1
      from public.inscripciones
      where clase_id = p_clase_id
        and alumno_id = v_usuario_id
        and estado = 'inscrito'
  ) then
    raise exception 'Ya estás inscrito en esta clase.';
  end if;

  -- Profesores y dueño pueden reservar sin cuota. Los alumnos necesitan una
  -- suscripción realmente cobrada y dentro de vigencia.
  if v_rol = 'alumno' and not exists (
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

  select count(*)::int
    into v_inscritos
    from public.inscripciones
    where clase_id = p_clase_id and estado = 'inscrito';

  if v_inscritos >= v_aforo_maximo then
    raise exception 'Aforo completo para esta clase.';
  end if;

  insert into public.inscripciones (clase_id, alumno_id, academia_id, estado)
  values (p_clase_id, v_usuario_id, v_academia_id, 'inscrito');
end;
$function$;

create or replace function public.cancelar_reserva(p_clase_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if auth.uid() is null then
    raise exception 'No autorizado.';
  end if;

  update public.inscripciones
    set estado = 'cancelado'
    where clase_id = p_clase_id
      and alumno_id = auth.uid()
      and estado = 'inscrito';

  if not found then
    raise exception 'No tienes una reserva activa en esta clase.';
  end if;
end;
$function$;

revoke all on function public.reservar_clase(uuid) from public, anon;
grant execute on function public.reservar_clase(uuid) to authenticated;
revoke all on function public.cancelar_reserva(uuid) from public, anon;
grant execute on function public.cancelar_reserva(uuid) to authenticated;

-- ============================================================
-- Suscripciones: Stripe es la fuente de verdad para cancelar
-- ============================================================

revoke insert, update, delete on public.suscripciones from authenticated;
drop policy if exists suscripciones_insert on public.suscripciones;
drop policy if exists suscripciones_update on public.suscripciones;
