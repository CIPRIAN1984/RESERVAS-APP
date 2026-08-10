-- Reconciliación: esta migración se aplicó a producción el 29/07/2026 a las
-- 16:56, 56 minutos después de 20260729160000_cuota_en_efectivo.sql, con
-- exactamente el mismo SQL. No cambia el esquema (todas las operaciones son
-- idempotentes: `create or replace function`, `drop constraint if exists`),
-- pero faltaba el archivo local — el historial de migraciones de producción
-- la tenía registrada y el repositorio no. Se reconstruye aquí, letra por
-- letra, a partir de `supabase_migrations.schema_migrations` para que una
-- base local reconstruida desde cero (`supabase db reset`, CI) llegue al
-- mismo estado exacto que producción. Ver DECISIONS.md, 2026-08-10.

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

  if not found
     or v_actor_rol <> 'dueño'
     or v_actor_estado <> 'activo'
     or v_actor_academia_id is null then
    raise exception 'Solo el Dueño activo puede registrar cuotas en efectivo.';
  end if;

  if p_fecha_fin is not null and p_fecha_fin <= now() then
    raise exception 'La fecha de fin debe ser futura.';
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

  update public.suscripciones
     set estado = 'expirada',
         fecha_fin = least(coalesce(fecha_fin, now()), now())
   where alumno_id = p_alumno_id
     and academia_id = v_actor_academia_id
     and proveedor_pago = 'efectivo'
     and estado in ('activa', 'pendiente_pago');

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

  insert into public.suscripciones (
    alumno_id, tarifa_id, academia_id, proveedor_pago, referencia_externa
  )
  values (
    p_alumno_id, p_tarifa_id, v_actor_academia_id, 'efectivo', null
  )
  returning id into v_suscripcion_id;

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
