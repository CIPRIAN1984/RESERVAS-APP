-- ITACA — Renovar antes de tiempo no pierde días, y una pausa conserva
-- también las clases pendientes.
--
-- Auditoría externa del 30/09/2026, punto 3. Decisión de Cipri: si se
-- renueva una cuota que aún está en vigor, la nueva empieza cuando acaba la
-- actual. Ver DECISIONS.md, entrada del 30/09/2026.

-- ============================================================
-- 1. Estado 'programada' y registro de pausas
-- ============================================================

alter table public.suscripciones drop constraint if exists suscripciones_estado_check;
alter table public.suscripciones
  add constraint suscripciones_estado_check
  check (estado in (
    'pendiente_pago', 'activa', 'prueba', 'pausada', 'programada',
    'cancelada', 'expirada'
  ));

-- El índice de «una cuota en curso por alumno» no incluye 'programada' (una
-- renovación convive con la cuota que la precede), pero sí hay como mucho
-- una renovación esperando.
create unique index if not exists suscripciones_programada_unica_idx
  on public.suscripciones (alumno_id)
  where estado = 'programada';

create table if not exists public.pausas_suscripcion (
  id uuid primary key default gen_random_uuid(),
  suscripcion_id uuid not null references public.suscripciones (id) on delete cascade,
  desde timestamptz not null,
  hasta timestamptz,
  check (hasta is null or hasta >= desde)
);

create index if not exists pausas_suscripcion_idx
  on public.pausas_suscripcion (suscripcion_id, desde);

-- Solo la tocan las funciones del servidor.
alter table public.pausas_suscripcion enable row level security;
revoke all on public.pausas_suscripcion from anon, authenticated;

-- Las cuotas que ya estén pausadas (en producción, ninguna a 30/09/2026):
-- se abre su pausa ahora, para que al reanudarse tengan dónde cerrarla.
insert into public.pausas_suscripcion (suscripcion_id, desde)
select s.id, now()
  from public.suscripciones s
 where s.estado = 'pausada'
   and not exists (
     select 1 from public.pausas_suscripcion p
      where p.suscripcion_id = s.id and p.hasta is null
   );

-- ============================================================
-- 2. Tiempo efectivo: el tiempo de la cuota sin contar las pausas
-- ============================================================

create or replace function public._tiempo_efectivo(
  p_suscripcion_id uuid,
  p_t timestamptz
)
returns timestamptz
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select p_t - coalesce(sum(least(coalesce(p.hasta, 'infinity'), p_t) - p.desde), interval '0')
    from public.pausas_suscripcion p
   where p.suscripcion_id = p_suscripcion_id
     and p.desde < p_t;
$function$;

-- El inverso: de tiempo efectivo a fecha real. Cada pausa que empezó antes
-- empuja la fecha lo que duró.
create or replace function public._tiempo_real(
  p_suscripcion_id uuid,
  p_e timestamptz
)
returns timestamptz
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_r timestamptz := p_e;
  v_pausa record;
begin
  for v_pausa in
    select desde, hasta
      from public.pausas_suscripcion
     where suscripcion_id = p_suscripcion_id
     order by desde
  loop
    if v_r >= v_pausa.desde then
      if v_pausa.hasta is null then
        return 'infinity';
      end if;
      v_r := v_r + (v_pausa.hasta - v_pausa.desde);
    end if;
  end loop;
  return v_r;
end;
$function$;

-- El ciclo de una cuota concreta que contiene la fecha de referencia, con
-- las pausas descontadas: un ciclo que cruza una pausa se alarga lo que
-- duró la pausa.
create or replace function public.ciclo_de_suscripcion(
  p_suscripcion_id uuid,
  p_fecha_inicio timestamptz,
  p_fecha_fin timestamptz,
  p_periodicidad text,
  p_referencia timestamptz
)
returns table (inicio timestamptz, fin timestamptz)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_ciclo record;
begin
  if p_periodicidad = 'suelta' then
    return query
      select p_fecha_inicio, coalesce(p_fecha_fin, 'infinity'::timestamptz);
    return;
  end if;

  select * into v_ciclo
    from public.ciclo_en(
      p_fecha_inicio,
      p_fecha_fin,
      p_periodicidad,
      public._tiempo_efectivo(p_suscripcion_id, p_referencia)
    );

  return query
    select public._tiempo_real(p_suscripcion_id, v_ciclo.inicio),
           public._tiempo_real(p_suscripcion_id, v_ciclo.fin);
end;
$function$;

revoke all on function public._tiempo_efectivo(uuid, timestamptz) from public, anon, authenticated;
revoke all on function public._tiempo_real(uuid, timestamptz) from public, anon, authenticated;
revoke all on function public.ciclo_de_suscripcion(uuid, timestamptz, timestamptz, text, timestamptz)
  from public, anon, authenticated;

-- ============================================================
-- 3. _saldo_clases: renovación programada, ciclo con pausas y clases de
--    dentro de una pausa fuera de la cuenta
-- ============================================================

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
  -- 'programada': una renovación que empieza cuando acaba la actual. Solo
  -- cubre fechas desde su inicio, así que hoy no cuenta y una clase de
  -- después del fin de la actual sí.
  select s.*
    into v_suscripcion
    from public.suscripciones s
   where s.alumno_id = p_alumno_id
     and s.estado in ('activa', 'prueba', 'programada')
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
    from public.ciclo_de_suscripcion(
      v_suscripcion.id,
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

  with clases_del_ciclo as (
    -- Las del ciclo que no son de dentro de una pausa de esta cuota (a
    -- esas se va «sin cuota») ni canceladas por la academia.
    select c.id, c.fecha_hora_fin
      from public.clases c
     where c.estado <> 'cancelada'
       and c.fecha_hora_inicio >= v_ciclo.inicio
       and c.fecha_hora_inicio < v_ciclo.fin
       and not exists (
         select 1 from public.pausas_suscripcion p
          where p.suscripcion_id = v_suscripcion.id
            and c.fecha_hora_inicio >= p.desde
            and c.fecha_hora_inicio < coalesce(p.hasta, 'infinity')
       )
  ),
  consumidas as (
    select a.clase_id
      from public.asistencias a
      join clases_del_ciclo c on c.id = a.clase_id
     where a.alumno_id = p_alumno_id
    union
    select i.clase_id
      from public.inscripciones i
      join clases_del_ciclo c on c.id = i.clase_id
     where i.alumno_id = p_alumno_id
       and i.estado = 'inscrito'
       and c.fecha_hora_fin <= now()
       and not exists (
         select 1 from public.asistencias a2
          where a2.clase_id = i.clase_id and a2.alumno_id = i.alumno_id
       )
    union
    select i.clase_id
      from public.inscripciones i
      join clases_del_ciclo c on c.id = i.clase_id
     where i.alumno_id = p_alumno_id
       and i.estado = 'cancelado'
       and i.cancelacion_tardia = true
  )
  select count(*)::int into v_gastadas from consumidas;

  with clases_del_ciclo as (
    select c.id, c.fecha_hora_fin
      from public.clases c
     where c.estado <> 'cancelada'
       and c.fecha_hora_inicio >= v_ciclo.inicio
       and c.fecha_hora_inicio < v_ciclo.fin
       and not exists (
         select 1 from public.pausas_suscripcion p
          where p.suscripcion_id = v_suscripcion.id
            and c.fecha_hora_inicio >= p.desde
            and c.fecha_hora_inicio < coalesce(p.hasta, 'infinity')
       )
  )
  select count(*)::int into v_reservadas
    from public.inscripciones i
    join clases_del_ciclo c on c.id = i.clase_id
   where i.alumno_id = p_alumno_id
     and i.estado = 'inscrito'
     and c.fecha_hora_fin > now()
     and not exists (
       select 1 from public.asistencias a
        where a.clase_id = i.clase_id and a.alumno_id = i.alumno_id
     )
     and not exists (
       select 1 from public.inscripciones t
        where t.clase_id = i.clase_id
          and t.alumno_id = i.alumno_id
          and t.estado = 'cancelado'
          and t.cancelacion_tardia = true
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
       and estado in ('activa', 'prueba', 'programada')
       and payment_status = 'active'
       and fecha_inicio <= p_fecha
       and (fecha_fin is null or fecha_fin > p_fecha)
  );
$function$;

revoke all on function public._cuota_cubre(uuid, uuid, timestamptz)
  from public, anon, authenticated;

-- ============================================================
-- 4. Alta de una renovación programada
-- ============================================================
-- `set_suscripcion_defaults` pone toda alta en 'pendiente_pago', que cuenta
-- para el índice de «una cuota en curso»: con la actual todavía activa, la
-- renovación no podría ni insertarse. `activar_cuota_efectivo` avisa con
-- una marca local a la transacción de que el alta es una renovación, y
-- entonces nace 'programada'. Desde la app no se puede poner esa marca
-- (no hay SQL libre) ni insertar en `suscripciones` (no hay INSERT).

create or replace function public.set_suscripcion_defaults()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $function$
begin
  select academia_id into new.academia_id from public.profiles where id = new.alumno_id;
  new.estado := case
    when coalesce(current_setting('itaca.alta_programada', true), '') = 'on'
         and current_user <> 'authenticated'
      then 'programada'
    else 'pendiente_pago'
  end;
  new.payment_status := 'pending';
  new.fecha_inicio := now();
  new.fecha_fin := null;
  return new;
end;
$function$;

revoke execute on function public.set_suscripcion_defaults() from public, anon, authenticated;

-- Mover la renovación programada de un alumno para que empiece cuando acaba
-- la cuota que la precede (tras reanudar una pausa). Conserva su duración.
create or replace function public._encadenar_programada(
  p_alumno_id uuid,
  p_nuevo_inicio timestamptz
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $function$
  update public.suscripciones
     set fecha_inicio = p_nuevo_inicio,
         fecha_fin = p_nuevo_inicio + (fecha_fin - fecha_inicio)
   where alumno_id = p_alumno_id
     and estado = 'programada'
     and p_nuevo_inicio is not null;
$function$;

revoke all on function public._encadenar_programada(uuid, timestamptz) from public, anon, authenticated;

-- ============================================================
-- 5. activar_cuota_efectivo: renovación programada y meses
-- ============================================================

drop function if exists public.activar_cuota_efectivo(uuid, uuid, timestamptz, boolean, numeric);

create or replace function public.activar_cuota_efectivo(
  p_alumno_id uuid,
  p_tarifa_id uuid,
  p_fecha_fin timestamptz default null,
  p_prueba boolean default false,
  p_importe numeric default null,
  -- Meses de calendario desde que empieza la cuota (que en una renovación
  -- es el fin de la actual). Si llega, manda sobre p_fecha_fin.
  p_meses integer default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_academia_id uuid;
  v_actor_rol text;
  v_actor_estado text;
  v_alumno_academia_id uuid;
  v_alumno_rol text;
  v_alumno_estado text;
  v_tarifa_academia_id uuid;
  v_tarifa_activa boolean;
  v_tarifa_precio numeric;
  v_actual_fin timestamptz;
  v_renovacion boolean := false;
  v_inicio timestamptz := now();
  v_fin timestamptz;
  v_suscripcion_id uuid;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select academia_id, rol, estado
    into v_actor_academia_id, v_actor_rol, v_actor_estado
    from public.profiles
    where id = v_actor_id;

  if not found
     or v_actor_rol <> 'dueño'
     or v_actor_estado <> 'activo'
     or v_actor_academia_id is null then
    raise exception 'Solo el Dueño activo puede registrar cuotas en efectivo.';
  end if;

  if p_prueba and (p_fecha_fin is not null or p_meses is not null) then
    raise exception 'La prueba dura siempre 1 día: no lleva fecha de fin propia.';
  end if;

  if not p_prueba and p_meses is null and p_fecha_fin is not null
     and p_fecha_fin <= now() then
    raise exception 'La fecha de fin debe ser futura.';
  end if;

  if p_meses is not null and p_meses <= 0 then
    raise exception 'Los meses tienen que ser al menos 1.';
  end if;

  if p_importe is not null and p_importe < 0 then
    raise exception 'El importe cobrado no puede ser negativo.';
  end if;

  select academia_id, rol, estado
    into v_alumno_academia_id, v_alumno_rol, v_alumno_estado
    from public.profiles
    where id = p_alumno_id
    for update;

  if not found or v_alumno_academia_id is distinct from v_actor_academia_id then
    raise exception 'Ese miembro no es de tu academia.';
  end if;

  if v_alumno_estado <> 'activo' then
    raise exception 'Ese miembro todavía no está activo.';
  end if;

  if v_alumno_rol <> 'alumno' then
    raise exception 'Solo los Alumnos necesitan cuota para reservar.';
  end if;

  select academia_id, activo, precio
    into v_tarifa_academia_id, v_tarifa_activa, v_tarifa_precio
    from public.tarifas
    where id = p_tarifa_id;

  if not found or v_tarifa_academia_id is distinct from v_actor_academia_id then
    raise exception 'Esa tarifa no es de tu academia.';
  end if;

  if not v_tarifa_activa then
    raise exception 'Esa tarifa está desactivada.';
  end if;

  -- ¿Es una renovación de una cuota en efectivo todavía en vigor? Entonces
  -- la nueva empieza cuando acabe esa (decisión de Cipri, 30/09/2026).
  if not p_prueba then
    select fecha_fin into v_actual_fin
      from public.suscripciones
     where alumno_id = p_alumno_id
       and academia_id = v_actor_academia_id
       and proveedor_pago = 'efectivo'
       and estado = 'activa'
       and fecha_fin > now()
     for update;
    v_renovacion := found;
  end if;

  if v_renovacion then
    if exists (
      select 1 from public.suscripciones
       where alumno_id = p_alumno_id and estado = 'programada'
    ) then
      raise exception 'Ese alumno ya tiene una renovación pendiente de empezar.';
    end if;
    v_inicio := v_actual_fin;
  else
    -- Sin cuota en vigor que respetar: se cierra la anterior en efectivo
    -- (una prueba, una pausada, una caducada que el job no ha cerrado aún).
    update public.suscripciones
       set estado = 'expirada',
           fecha_fin = least(coalesce(fecha_fin, now()), now())
     where alumno_id = p_alumno_id
       and academia_id = v_actor_academia_id
       and proveedor_pago = 'efectivo'
       and estado in ('activa', 'pendiente_pago', 'prueba', 'pausada');
  end if;

  if exists (
    select 1
      from public.suscripciones
     where alumno_id = p_alumno_id
       and proveedor_pago = 'stripe'
       and estado in ('activa', 'pendiente_pago', 'prueba', 'pausada')
  ) then
    raise exception 'Ese alumno ya tiene una cuota domiciliada por tarjeta. '
                    'Cancélala primero desde Stripe.';
  end if;

  v_fin := case
    when p_prueba then now() + interval '1 day'
    when p_meses is not null then v_inicio + make_interval(months => p_meses)
    when p_fecha_fin is not null then v_inicio + (p_fecha_fin - now())
    else null
  end;

  perform set_config('itaca.alta_programada', case when v_renovacion then 'on' else 'off' end, true);

  insert into public.suscripciones (
    alumno_id, tarifa_id, academia_id, proveedor_pago, referencia_externa
  )
  values (
    p_alumno_id, p_tarifa_id, v_actor_academia_id, 'efectivo', null
  )
  returning id into v_suscripcion_id;

  perform set_config('itaca.alta_programada', 'off', true);

  update public.suscripciones
     set estado = case
           when p_prueba then 'prueba'
           when v_renovacion then 'programada'
           else 'activa'
         end,
         payment_status = 'active',
         fecha_inicio = v_inicio,
         fecha_fin = v_fin,
         importe_cobrado = case
           when p_prueba then 0
           else coalesce(p_importe, v_tarifa_precio * coalesce(p_meses, 1))
         end,
         cobrado_por = v_actor_id,
         cobrado_at = now()
   where id = v_suscripcion_id;

  return v_suscripcion_id;
end;
$$;

revoke all on function public.activar_cuota_efectivo(uuid, uuid, timestamptz, boolean, numeric, integer)
  from public, anon;
grant execute on function public.activar_cuota_efectivo(uuid, uuid, timestamptz, boolean, numeric, integer)
  to authenticated;

-- ============================================================
-- 6. Pausar y reanudar: registrar la pausa y mover la renovación
-- ============================================================

create or replace function public.pausar_cuota_efectivo(
  p_suscripcion_id uuid,
  p_fecha_fin timestamptz default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_academia_id uuid;
  v_actor_rol text;
  v_actor_estado text;
  v_susc_academia_id uuid;
  v_susc_proveedor text;
  v_susc_estado text;
  v_susc_fecha_fin timestamptz;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select academia_id, rol, estado
    into v_actor_academia_id, v_actor_rol, v_actor_estado
    from public.profiles
    where id = v_actor_id;

  if not found
     or v_actor_rol <> 'dueño'
     or v_actor_estado <> 'activo'
     or v_actor_academia_id is null then
    raise exception 'Solo el Dueño activo puede pausar una cuota.';
  end if;

  if p_fecha_fin is not null and p_fecha_fin <= now() then
    raise exception 'La fecha de reanudación debe ser futura.';
  end if;

  select academia_id, proveedor_pago, estado, fecha_fin
    into v_susc_academia_id, v_susc_proveedor, v_susc_estado, v_susc_fecha_fin
    from public.suscripciones
    where id = p_suscripcion_id
    for update;

  if not found or v_susc_academia_id is distinct from v_actor_academia_id then
    raise exception 'Esa cuota no es de tu academia.';
  end if;

  if v_susc_proveedor <> 'efectivo' then
    raise exception 'Las cuotas de Stripe se pausan desde Stripe.';
  end if;

  if v_susc_estado <> 'activa' then
    raise exception 'Solo se puede pausar una cuota activa.';
  end if;

  if v_susc_fecha_fin is not null and v_susc_fecha_fin <= now() then
    raise exception 'Esa cuota ya ha caducado: no hay nada que pausar.';
  end if;

  update public.suscripciones
     set estado = 'pausada',
         resto_al_pausar = v_susc_fecha_fin - now(),
         fecha_fin = p_fecha_fin
   where id = p_suscripcion_id;

  insert into public.pausas_suscripcion (suscripcion_id, desde)
  values (p_suscripcion_id, now());
end;
$$;

revoke all on function public.pausar_cuota_efectivo(uuid, timestamptz) from public, anon;
grant execute on function public.pausar_cuota_efectivo(uuid, timestamptz) to authenticated;

create or replace function public.reanudar_cuota_efectivo(
  p_suscripcion_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_academia_id uuid;
  v_actor_rol text;
  v_actor_estado text;
  v_susc_academia_id uuid;
  v_susc_proveedor text;
  v_susc_estado text;
  v_susc_alumno uuid;
  v_nuevo_fin timestamptz;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select academia_id, rol, estado
    into v_actor_academia_id, v_actor_rol, v_actor_estado
    from public.profiles
    where id = v_actor_id;

  if not found
     or v_actor_rol <> 'dueño'
     or v_actor_estado <> 'activo'
     or v_actor_academia_id is null then
    raise exception 'Solo el Dueño activo puede reanudar una cuota.';
  end if;

  select academia_id, proveedor_pago, estado, alumno_id
    into v_susc_academia_id, v_susc_proveedor, v_susc_estado, v_susc_alumno
    from public.suscripciones
    where id = p_suscripcion_id
    for update;

  if not found or v_susc_academia_id is distinct from v_actor_academia_id then
    raise exception 'Esa cuota no es de tu academia.';
  end if;

  if v_susc_proveedor <> 'efectivo' then
    raise exception 'Las cuotas de Stripe se reanudan desde Stripe.';
  end if;

  if v_susc_estado <> 'pausada' then
    raise exception 'Solo se puede reanudar una cuota pausada.';
  end if;

  update public.pausas_suscripcion
     set hasta = now()
   where suscripcion_id = p_suscripcion_id
     and hasta is null;

  update public.suscripciones
     set estado = 'activa',
         fecha_fin = now() + resto_al_pausar,
         resto_al_pausar = null
   where id = p_suscripcion_id
  returning fecha_fin into v_nuevo_fin;

  perform public._encadenar_programada(v_susc_alumno, v_nuevo_fin);
end;
$$;

revoke all on function public.reanudar_cuota_efectivo(uuid) from public, anon;
grant execute on function public.reanudar_cuota_efectivo(uuid) to authenticated;

-- ============================================================
-- 7. El job de cada 15 minutos: activa las renovaciones
-- ============================================================

drop function if exists public.expirar_pruebas_y_pausas();

create function public.expirar_pruebas_y_pausas()
returns table (
  pruebas_expiradas int,
  pausas_reanudadas int,
  cuotas_caducadas int,
  renovaciones_activadas int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_pruebas int;
  v_pausas int := 0;
  v_caducadas int;
  v_renovaciones int;
  v_pausa record;
begin
  with expiradas as (
    update public.suscripciones
      set estado = 'expirada', payment_status = 'canceled'
      where estado = 'prueba'
        and fecha_fin is not null
        and fecha_fin <= now()
      returning 1
  )
  select count(*)::int into v_pruebas from expiradas;

  -- Pausas que llegan a su fecha de reanudación: se cierra la pausa en esa
  -- fecha, vuelve con lo que le quedaba y su renovación se mueve detrás.
  for v_pausa in
    select id, alumno_id, fecha_fin, resto_al_pausar
      from public.suscripciones
     where estado = 'pausada'
       and fecha_fin is not null
       and fecha_fin <= now()
     for update
  loop
    -- greatest: si la fecha de reanudación quedara antes del inicio de la
    -- pausa (no debería: pausar exige una fecha futura), el job no puede
    -- romperse por ello y dejar sin caducar todo lo demás.
    update public.pausas_suscripcion
       set hasta = greatest(desde, v_pausa.fecha_fin)
     where suscripcion_id = v_pausa.id
       and hasta is null;

    update public.suscripciones
       set estado = 'activa',
           fecha_fin = v_pausa.fecha_fin + v_pausa.resto_al_pausar,
           resto_al_pausar = null
     where id = v_pausa.id;

    perform public._encadenar_programada(
      v_pausa.alumno_id,
      v_pausa.fecha_fin + v_pausa.resto_al_pausar
    );
    v_pausas := v_pausas + 1;
  end loop;

  with caducadas as (
    update public.suscripciones
      set estado = 'expirada'
      where estado = 'activa'
        and proveedor_pago = 'efectivo'
        and fecha_fin is not null
        and fecha_fin <= now()
      returning 1
  )
  select count(*)::int into v_caducadas from caducadas;

  -- Renovaciones que ya han empezado. Solo si el alumno no tiene otra cuota
  -- en curso (p. ej. la anterior pausada): así el job nunca choca con el
  -- índice de «una cuota en curso» ni se queda atascado.
  with activadas as (
    update public.suscripciones s
      set estado = 'activa'
      where s.estado = 'programada'
        and s.fecha_inicio <= now()
        and not exists (
          select 1 from public.suscripciones o
           where o.alumno_id = s.alumno_id
             and o.id <> s.id
             and o.estado in ('activa', 'prueba', 'pausada', 'pendiente_pago')
        )
      returning 1
  )
  select count(*)::int into v_renovaciones from activadas;

  return query select v_pruebas, v_pausas, v_caducadas, v_renovaciones;
end;
$$;

revoke all on function public.expirar_pruebas_y_pausas() from public, authenticated, anon;

-- ============================================================
-- 8. Cancelar una cuota en curso cancela su renovación
-- ============================================================
-- Dar de baja a un alumno o «retirar cuota» la pasan a 'cancelada'. Una
-- renovación pagada por adelantado no debe seguir esperando para activarse
-- sola meses después. (Que la cuota caduque de forma natural —'expirada'—
-- no la toca: es justo cuando la renovación tiene que empezar.)

create or replace function public.cancelar_renovacion_programada()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if new.estado = 'cancelada'
     and old.estado in ('activa', 'prueba', 'pausada') then
    update public.suscripciones
       set estado = 'cancelada'
     where alumno_id = new.alumno_id
       and estado = 'programada';
  end if;
  return new;
end;
$function$;

revoke execute on function public.cancelar_renovacion_programada() from public, anon, authenticated;

drop trigger if exists suscripciones_cancelar_renovacion on public.suscripciones;
create trigger suscripciones_cancelar_renovacion
  after update of estado on public.suscripciones
  for each row execute function public.cancelar_renovacion_programada();
