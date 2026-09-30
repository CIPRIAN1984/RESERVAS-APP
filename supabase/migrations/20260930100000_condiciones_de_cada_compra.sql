-- ITACA — Cada cuota guarda las condiciones con las que se compró, y el
-- cobro en efectivo apunta cuánto se recibió y quién lo registró.
--
-- Auditoría externa del 30/09/2026, punto 4:
--
-- 1. Editar una tarifa cambiaba las condiciones de las cuotas ya vendidas:
--    `_saldo_clases` leía `clases_incluidas` y `periodicidad` de la tarifa
--    en cada consulta. Subir una tarifa de 8 a 12 clases regalaba 4 a quien
--    ya había pagado por 8; bajarla le quitaba clases pagadas.
--    Ahora cada suscripción guarda una copia (nombre, precio, periodicidad,
--    clases incluidas) al crearse, y el saldo usa esa copia.
--
-- 2. Activar una cuota en efectivo no dejaba constancia de cuánto dinero se
--    recibió ni de quién lo cobró: no servía como registro de caja.
--    Ahora `activar_cuota_efectivo` guarda `importe_cobrado`, `cobrado_por`
--    y `cobrado_at`. Una prueba de 1 día se apunta con importe 0.

-- ============================================================
-- 1. Columnas
-- ============================================================
-- La app puede leer `suscripciones` (según RLS: el alumno las suyas, el
-- staff las de su academia) pero no escribir en ella (sin UPDATE ni INSERT
-- para `authenticated`). Las columnas nuevas siguen esa misma regla: se
-- leen, y solo las escriben el disparador y las funciones del servidor.

alter table public.suscripciones
  add column if not exists tarifa_nombre text,
  add column if not exists precio numeric(10,2),
  add column if not exists periodicidad text,
  add column if not exists clases_incluidas integer,
  add column if not exists importe_cobrado numeric(10,2),
  add column if not exists cobrado_por uuid references public.profiles (id),
  add column if not exists cobrado_at timestamptz;

alter table public.suscripciones
  drop constraint if exists suscripciones_importe_cobrado_check;
alter table public.suscripciones
  add constraint suscripciones_importe_cobrado_check
  check (importe_cobrado is null or importe_cobrado >= 0);

-- ============================================================
-- 2. Copiar las condiciones al crear la cuota (o si cambia de tarifa)
-- ============================================================

create or replace function public.copiar_condiciones_tarifa()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  select t.nombre, t.precio, t.periodicidad, t.clases_incluidas
    into new.tarifa_nombre, new.precio, new.periodicidad, new.clases_incluidas
    from public.tarifas t
   where t.id = new.tarifa_id;
  return new;
end;
$function$;

revoke execute on function public.copiar_condiciones_tarifa()
  from public, anon, authenticated;

drop trigger if exists suscripciones_copiar_condiciones on public.suscripciones;
create trigger suscripciones_copiar_condiciones
  before insert or update of tarifa_id on public.suscripciones
  for each row execute function public.copiar_condiciones_tarifa();

-- Las cuotas que ya existen: se copian las condiciones actuales de su
-- tarifa. Es lo mejor que se puede reconstruir (no se guardaba antes); en
-- producción, a 30/09/2026, ninguna tarifa con cuotas se había editado.
-- Solo se rellenan columnas nuevas: no se toca nada de lo que ya había.
update public.suscripciones s
   set tarifa_nombre = t.nombre,
       precio = t.precio,
       periodicidad = t.periodicidad,
       clases_incluidas = t.clases_incluidas
  from public.tarifas t
 where t.id = s.tarifa_id
   and s.periodicidad is null;

alter table public.suscripciones
  alter column periodicidad set not null;

-- ============================================================
-- 3. _saldo_clases: las condiciones de la cuota, no las de la tarifa hoy
-- ============================================================
-- Igual que en 20260930090000 salvo de dónde salen `clases_incluidas`,
-- `periodicidad` y el nombre.

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
  select s.*
    into v_suscripcion
    from public.suscripciones s
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

  with consumidas as (
    select a.clase_id
      from public.asistencias a
      join public.clases c on c.id = a.clase_id
     where a.alumno_id = p_alumno_id
       and c.estado <> 'cancelada'
       and c.fecha_hora_inicio >= v_ciclo.inicio
       and c.fecha_hora_inicio < v_ciclo.fin
    union
    select i.clase_id
      from public.inscripciones i
      join public.clases c on c.id = i.clase_id
     where i.alumno_id = p_alumno_id
       and i.estado = 'inscrito'
       and c.estado <> 'cancelada'
       and c.fecha_hora_fin <= now()
       and c.fecha_hora_inicio >= v_ciclo.inicio
       and c.fecha_hora_inicio < v_ciclo.fin
       and not exists (
         select 1 from public.asistencias a2
          where a2.clase_id = i.clase_id and a2.alumno_id = i.alumno_id
       )
    union
    select i.clase_id
      from public.inscripciones i
      join public.clases c on c.id = i.clase_id
     where i.alumno_id = p_alumno_id
       and i.estado = 'cancelado'
       and i.cancelacion_tardia = true
       and c.estado <> 'cancelada'
       and c.fecha_hora_inicio >= v_ciclo.inicio
       and c.fecha_hora_inicio < v_ciclo.fin
  )
  select count(*)::int into v_gastadas from consumidas;

  select count(*)::int into v_reservadas
    from public.inscripciones i
    join public.clases c on c.id = i.clase_id
   where i.alumno_id = p_alumno_id
     and i.estado = 'inscrito'
     and c.estado <> 'cancelada'
     and c.fecha_hora_fin > now()
     and c.fecha_hora_inicio >= v_ciclo.inicio
     and c.fecha_hora_inicio < v_ciclo.fin
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

-- ============================================================
-- 4. activar_cuota_efectivo: con importe y quién cobra
-- ============================================================
-- Cambia de firma (p_importe al final, opcional para no romper una app
-- abierta con la versión anterior): hay que borrar la vieja, porque CREATE
-- OR REPLACE con otra lista de parámetros crearía una segunda función.

drop function if exists public.activar_cuota_efectivo(uuid, uuid, timestamptz, boolean);

create or replace function public.activar_cuota_efectivo(
  p_alumno_id uuid,
  p_tarifa_id uuid,
  p_fecha_fin timestamptz default null,
  p_prueba boolean default false,
  -- Lo que se ha recibido de verdad. Sin él, el precio de la tarifa.
  p_importe numeric default null
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

  if p_prueba and p_fecha_fin is not null then
    raise exception 'La prueba dura siempre 1 día: no lleva fecha de fin propia.';
  end if;

  if not p_prueba and p_fecha_fin is not null and p_fecha_fin <= now() then
    raise exception 'La fecha de fin debe ser futura.';
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

  update public.suscripciones
     set estado = 'expirada',
         fecha_fin = least(coalesce(fecha_fin, now()), now())
   where alumno_id = p_alumno_id
     and academia_id = v_actor_academia_id
     and proveedor_pago = 'efectivo'
     and estado in ('activa', 'pendiente_pago', 'prueba', 'pausada');

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

  -- OJO: el disparador `set_suscripcion_defaults` pisa estado,
  -- payment_status, fecha_inicio y fecha_fin en cada alta. Por eso se
  -- inserta primero y se activa después con un UPDATE. Las condiciones de
  -- la tarifa las copia `copiar_condiciones_tarifa` en el alta.
  insert into public.suscripciones (
    alumno_id, tarifa_id, academia_id, proveedor_pago, referencia_externa
  )
  values (
    p_alumno_id, p_tarifa_id, v_actor_academia_id, 'efectivo', null
  )
  returning id into v_suscripcion_id;

  update public.suscripciones
     set estado = case when p_prueba then 'prueba' else 'activa' end,
         payment_status = 'active',
         fecha_fin = case
           when p_prueba then now() + interval '1 day'
           else p_fecha_fin
         end,
         importe_cobrado = case
           when p_prueba then 0
           else coalesce(p_importe, v_tarifa_precio)
         end,
         cobrado_por = v_actor_id,
         cobrado_at = now()
   where id = v_suscripcion_id;

  return v_suscripcion_id;
end;
$$;

revoke all on function public.activar_cuota_efectivo(uuid, uuid, timestamptz, boolean, numeric)
  from public, anon;
grant execute on function public.activar_cuota_efectivo(uuid, uuid, timestamptz, boolean, numeric)
  to authenticated;
