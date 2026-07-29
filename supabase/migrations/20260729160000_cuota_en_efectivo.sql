-- Cuotas cobradas en efectivo, gestionadas por el Dueño.
--
-- Problema que resuelve: `reservar_clase` exige al Alumno una suscripción con
-- `payment_status = 'active'`, y ese estado **solo** lo enciende el webhook de
-- Stripe. Mientras Stripe no esté conectado a cobros reales, ningún Alumno
-- puede reservar jamás — lo que hace imposible probar la app en paralelo con
-- MAAT, que es justo el plan acordado.
--
-- La mayoría de las academias cobran también en mano. Esto da al Dueño la
-- forma de reconocer ese cobro sin inventarse un pago de Stripe.
--
-- Cómo convive con Stripe sin pisarse:
--   * Las suscripciones en efectivo llevan `proveedor_pago = 'efectivo'` y
--     `referencia_externa` a NULL.
--   * El webhook de Stripe localiza sus filas por `referencia_externa`, así
--     que nunca alcanza a una de efectivo.
--   * A la inversa, estas funciones rechazan tocar una suscripción de Stripe:
--     el dinero de tarjeta lo manda Stripe, no la app.

-- ============================================================
-- 1. Que el proveedor de pago sea un valor conocido
-- ============================================================
-- Era texto libre con 'stripe' por defecto. Sin esto, un error de escritura
-- ('Efectivo', 'cash') crearía una cuota que ninguna consulta encontraría.

update public.suscripciones
   set proveedor_pago = 'stripe'
 where proveedor_pago is null;

alter table public.suscripciones
  alter column proveedor_pago set not null;

alter table public.suscripciones
  drop constraint if exists suscripciones_proveedor_pago_check;

alter table public.suscripciones
  add constraint suscripciones_proveedor_pago_check
  check (proveedor_pago in ('stripe', 'efectivo'));

-- ============================================================
-- 2. Activar una cuota cobrada en mano
-- ============================================================
-- Devuelve el id de la suscripción creada.
--
-- `p_fecha_fin` es hasta cuándo vale lo pagado. Se admite NULL (sin fecha de
-- caducidad) para el caso de "ya me lo paga cada mes y lo voy renovando", pero
-- la app enviará siempre una fecha: una cuota en efectivo que no caduca nunca
-- se convierte en un alumno que entrena gratis sin que nadie se entere.

create or replace function public.activar_cuota_efectivo(
  p_alumno_id uuid,
  p_tarifa_id uuid,
  p_fecha_fin timestamptz default null
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
  v_suscripcion_id uuid;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select academia_id, rol, estado
    into v_actor_academia_id, v_actor_rol, v_actor_estado
    from public.profiles
    where id = v_actor_id;

  -- Solo el Dueño: quien cobra en mano es quien responde de ese dinero.
  if not found
     or v_actor_rol <> 'dueño'
     or v_actor_estado <> 'activo'
     or v_actor_academia_id is null then
    raise exception 'Solo el Dueño activo puede registrar cuotas en efectivo.';
  end if;

  if p_fecha_fin is not null and p_fecha_fin <= now() then
    raise exception 'La fecha de fin debe ser futura.';
  end if;

  -- Se bloquea la fila del alumno para que dos altas simultáneas no dejen
  -- dos cuotas activas a la vez.
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

  -- Profesores y Dueños ya reservan sin cuota; darles una sería un cobro
  -- fantasma en las cuentas de la academia.
  if v_alumno_rol <> 'alumno' then
    raise exception 'Solo los Alumnos necesitan cuota para reservar.';
  end if;

  select academia_id, activo
    into v_tarifa_academia_id, v_tarifa_activa
    from public.tarifas
    where id = p_tarifa_id;

  if not found or v_tarifa_academia_id is distinct from v_actor_academia_id then
    raise exception 'Esa tarifa no es de tu academia.';
  end if;

  if not v_tarifa_activa then
    raise exception 'Esa tarifa está desactivada.';
  end if;

  -- Cerrar la cuota en efectivo anterior: un alumno tiene una cuota, no una
  -- pila de ellas. Hay un índice único por alumno sobre los estados 'activa'
  -- y 'pendiente_pago', así que además es obligatorio dejar sitio.
  update public.suscripciones
     set estado = 'expirada',
         fecha_fin = least(coalesce(fecha_fin, now()), now())
   where alumno_id = p_alumno_id
     and academia_id = v_actor_academia_id
     and proveedor_pago = 'efectivo'
     and estado in ('activa', 'pendiente_pago');

  -- Una de Stripe no se toca desde aquí, pero tampoco puede convivir con
  -- esta por el índice único. Mejor decirlo claro que reventar con un error
  -- de clave duplicada que no significa nada para quien lo lee.
  if exists (
    select 1
      from public.suscripciones
     where alumno_id = p_alumno_id
       and proveedor_pago = 'stripe'
       and estado in ('activa', 'pendiente_pago')
  ) then
    raise exception 'Ese alumno ya tiene una cuota domiciliada por tarjeta. '
                    'Cancélala primero desde Stripe.';
  end if;

  -- OJO: el disparador `set_suscripcion_defaults` pisa estado,
  -- payment_status, fecha_inicio y fecha_fin en cada alta — es la protección
  -- que impide que nadie se auto-active la cuota. Por eso hay que insertar
  -- primero y activar después con un UPDATE; hacerlo en el INSERT no tiene
  -- ningún efecto y la cuota se queda en 'pendiente_pago' sin que se note.
  insert into public.suscripciones (
    alumno_id, tarifa_id, academia_id, proveedor_pago, referencia_externa
  )
  values (
    p_alumno_id, p_tarifa_id, v_actor_academia_id, 'efectivo', null
  )
  returning id into v_suscripcion_id;

  -- El disparador `check_suscripcion_estado_transicion` deja pasar este
  -- cambio porque quien llama es el Dueño, comprobado más arriba.
  update public.suscripciones
     set estado = 'activa',
         payment_status = 'active',
         fecha_fin = p_fecha_fin
   where id = v_suscripcion_id;

  return v_suscripcion_id;
end;
$$;

revoke all on function public.activar_cuota_efectivo(uuid, uuid, timestamptz)
  from public, anon;
grant execute on function public.activar_cuota_efectivo(uuid, uuid, timestamptz)
  to authenticated;

-- ============================================================
-- 3. Retirar una cuota en efectivo
-- ============================================================
-- Para cuando el alumno deja de pagar o se registró por error. No sirve para
-- las de Stripe: ahí hay que cancelar en Stripe, o la app y el banco dirían
-- cosas distintas.

create or replace function public.desactivar_cuota_efectivo(
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
    raise exception 'Solo el Dueño activo puede retirar cuotas en efectivo.';
  end if;

  select academia_id, proveedor_pago
    into v_susc_academia_id, v_susc_proveedor
    from public.suscripciones
    where id = p_suscripcion_id
    for update;

  if not found or v_susc_academia_id is distinct from v_actor_academia_id then
    raise exception 'Esa cuota no es de tu academia.';
  end if;

  if v_susc_proveedor <> 'efectivo' then
    raise exception 'Las cuotas de Stripe se cancelan desde Stripe.';
  end if;

  update public.suscripciones
     set estado = 'cancelada',
         payment_status = 'canceled',
         fecha_fin = now()
   where id = p_suscripcion_id;
end;
$$;

revoke all on function public.desactivar_cuota_efectivo(uuid) from public, anon;
grant execute on function public.desactivar_cuota_efectivo(uuid) to authenticated;
