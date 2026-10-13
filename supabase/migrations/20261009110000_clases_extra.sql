-- ITACA — Auditoría externa del 09/10/2026, punto 3: una clase suelta
-- comprada con la cuota en vigor se puede usar YA.
--
-- Qué fallaba: el alumno con cuota en vigor que se queda sin clases paga un
-- «día suelto», y `activar_cuota_efectivo` lo trataba como cualquier otro
-- cobro con la cuota en vigor: una renovación que empieza cuando acaba la
-- actual. No le servía para entrenar hoy, aunque la app le decía «compra
-- una suelta».
--
-- Decisión de Cipri (09/10/2026): la clase extra vale **hasta que acabe su
-- cuota actual**. Se suma a las clases de esa cuota y caduca con ella.
--
-- Cómo:
-- - Estado nuevo de suscripción, 'extra', con `extra_de` apuntando a la
--   cuota a la que se suma. Es una fila de `suscripciones` como cualquier
--   otro cobro (importe, quién, cuándo, condiciones copiadas): la caja la
--   ve igual. No cuenta como «cuota en curso» (no entra en el índice de una
--   por alumno), y la app, que siempre filtra por estado, no la confunde con
--   la cuota.
-- - `_saldo_clases` suma las extras de la cuota como una bolsa para toda la
--   vida de la cuota: si en un ciclo se gastan más clases de las incluidas,
--   el exceso sale de la bolsa. En una cuota de un solo ciclo (lo normal:
--   un mes) es simplemente «incluidas + extras».
-- - La caducidad no se guarda aparte: la extra vive lo que viva su cuota,
--   también si la cuota se pausa y se alarga.
-- - Con la cuota pausada no se vende una extra: mientras está pausada el
--   alumno ya puede venir «sin cuota», y venderle una suelta suelta
--   cerraría la cuota pausada con el tiempo que le quedaba.

alter table public.suscripciones
  add column if not exists extra_de uuid references public.suscripciones (id);

comment on column public.suscripciones.extra_de is
  'Solo en estado ''extra'': la cuota a la que se suman estas clases. '
  'Valen mientras esa cuota esté en vigor.';

alter table public.suscripciones drop constraint suscripciones_estado_check;
alter table public.suscripciones add constraint suscripciones_estado_check
  check (estado in (
    'pendiente_pago', 'activa', 'prueba', 'pausada', 'programada',
    'cancelada', 'expirada', 'extra'
  ));

alter table public.suscripciones add constraint suscripciones_extra_coherente
  check ((estado = 'extra') = (extra_de is not null));

create index if not exists suscripciones_extra_de_idx
  on public.suscripciones (extra_de)
  where extra_de is not null;

-- ============================================================
-- 1. Alta de una extra
-- ============================================================
-- Igual que la renovación programada: una marca local a la transacción que
-- solo puede poner `activar_cuota_efectivo` (la app no tiene SQL libre ni
-- INSERT en `suscripciones`). Sin ella, el alta nacería 'pendiente_pago' y
-- chocaría con la cuota activa en el índice de una por alumno.

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
    when coalesce(current_setting('itaca.alta_extra', true), '') = 'on'
         and current_user <> 'authenticated'
      then 'extra'
    else 'pendiente_pago'
  end;
  new.payment_status := 'pending';
  new.fecha_inicio := now();
  new.fecha_fin := null;
  return new;
end;
$function$;

revoke execute on function public.set_suscripcion_defaults() from public, anon, authenticated;

-- ============================================================
-- 2. Lo gastado y lo reservado de un ciclo
-- ============================================================
-- Sale de `_saldo_clases` tal cual estaba (20260930110000), para poder
-- contarlo también en los otros ciclos de la cuota.

create or replace function public._consumo_ciclo(
  p_alumno_id uuid,
  p_suscripcion_id uuid,
  p_inicio timestamptz,
  p_fin timestamptz,
  out gastadas int,
  out reservadas int
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
begin
  with clases_del_ciclo as (
    -- Las del ciclo que no son de dentro de una pausa de esta cuota (a
    -- esas se va «sin cuota») ni canceladas por la academia.
    select c.id, c.fecha_hora_fin
      from public.clases c
     where c.estado <> 'cancelada'
       and c.fecha_hora_inicio >= p_inicio
       and c.fecha_hora_inicio < p_fin
       and not exists (
         select 1 from public.pausas_suscripcion p
          where p.suscripcion_id = p_suscripcion_id
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
  select count(*)::int into gastadas from consumidas;

  with clases_del_ciclo as (
    select c.id, c.fecha_hora_fin
      from public.clases c
     where c.estado <> 'cancelada'
       and c.fecha_hora_inicio >= p_inicio
       and c.fecha_hora_inicio < p_fin
       and not exists (
         select 1 from public.pausas_suscripcion p
          where p.suscripcion_id = p_suscripcion_id
            and c.fecha_hora_inicio >= p.desde
            and c.fecha_hora_inicio < coalesce(p.hasta, 'infinity')
       )
  )
  select count(*)::int into reservadas
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
end;
$function$;

revoke all on function public._consumo_ciclo(uuid, uuid, timestamptz, timestamptz)
  from public, anon, authenticated;

-- ============================================================
-- 3. _saldo_clases: las extras de la cuota se suman
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
  v_otro record;
  v_consumo record;
  v_extras int;
  v_exceso_otros int := 0;
  v_bolsa int := 0;
  v_ref timestamptz;
  v_vueltas int := 0;
begin
  -- 'programada': una renovación que empieza cuando acaba la actual. Solo
  -- cubre fechas desde su inicio, así que hoy no cuenta y una clase de
  -- después del fin de la actual sí. Las 'extra' no son cuotas: se suman
  -- a la suya más abajo.
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

  select * into v_consumo
    from public._consumo_ciclo(
      p_alumno_id, v_suscripcion.id, v_ciclo.inicio, v_ciclo.fin
    );

  -- 09/10/2026: clases extra (sueltas compradas con esta cuota en vigor).
  select coalesce(sum(e.clases_incluidas), 0)::int
    into v_extras
    from public.suscripciones e
   where e.extra_de = v_suscripcion.id
     and e.estado = 'extra';

  if v_extras > 0 then
    -- Lo que los OTROS ciclos de la cuota se han pasado de sus clases ya ha
    -- salido de la bolsa. Se recorren desde el principio de la cuota; tope
    -- de 36 vueltas por si la cuota no tiene fin.
    v_ref := v_suscripcion.fecha_inicio;
    loop
      select * into v_otro
        from public.ciclo_de_suscripcion(
          v_suscripcion.id,
          v_suscripcion.fecha_inicio,
          v_suscripcion.fecha_fin,
          v_suscripcion.periodicidad,
          v_ref
        );
      exit when v_otro.fin <= v_ref;

      if v_otro.inicio <> v_ciclo.inicio then
        v_exceso_otros := v_exceso_otros + greatest(
          0,
          (select c.gastadas + c.reservadas
             from public._consumo_ciclo(
               p_alumno_id, v_suscripcion.id, v_otro.inicio, v_otro.fin
             ) c)
          - v_suscripcion.clases_incluidas
        );
      end if;

      v_vueltas := v_vueltas + 1;
      exit when v_vueltas >= 36
        or v_otro.fin >= coalesce(v_suscripcion.fecha_fin, 'infinity');
      v_ref := v_otro.fin;
    end loop;

    v_bolsa := greatest(0, v_extras - v_exceso_otros);
  end if;

  return jsonb_build_object(
    'tiene_cuota', true,
    'ilimitada', false,
    'tarifa', v_suscripcion.tarifa_nombre,
    'incluidas', v_suscripcion.clases_incluidas + v_bolsa,
    'gastadas', v_consumo.gastadas,
    'reservadas', v_consumo.reservadas,
    'disponibles', greatest(
      0,
      v_suscripcion.clases_incluidas + v_bolsa
        - v_consumo.gastadas - v_consumo.reservadas
    ),
    'ciclo_inicio', v_ciclo.inicio,
    'ciclo_fin', v_ciclo.fin
  )
  -- Solo si tiene alguna: quien no compra extras ve el saldo de siempre.
  || case when v_bolsa > 0
       then jsonb_build_object('extras', v_bolsa)
       else '{}'::jsonb
     end;
end;
$function$;

revoke all on function public._saldo_clases(uuid, timestamptz)
  from public, anon, authenticated;

-- ============================================================
-- 4. activar_cuota_efectivo: la suelta con cuota en vigor es una extra
-- ============================================================

create or replace function public.activar_cuota_efectivo(
  p_alumno_id uuid,
  p_tarifa_id uuid,
  p_fecha_fin timestamptz default null,
  p_prueba boolean default false,
  p_importe numeric default null,
  -- Meses de calendario desde que empieza la cuota (que en una renovación
  -- es el fin de la actual). Si llega, manda sobre p_fecha_fin.
  p_meses integer default null,
  -- 09/10/2026: identificador del cobro, lo genera la app al abrir la hoja.
  -- Si la conexión se corta después de guardar y el Dueño pulsa otra vez,
  -- llega la misma clave y se devuelve el cobro ya hecho, sin duplicarlo.
  p_clave uuid default null
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
  v_tarifa_periodicidad text;
  v_meses_periodo int;
  v_meses int := p_meses;
  v_existente_id uuid;
  v_existente_alumno uuid;
  v_base_id uuid;
  v_base_estado text;
  v_base_fin timestamptz;
  v_base_incluidas int;
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

  -- ¿Es un reintento de un cobro ya guardado? Se mira con el alumno ya
  -- bloqueado: dos llamadas a la vez con la misma clave esperan una a la
  -- otra, y la segunda encuentra el cobro de la primera.
  if p_clave is not null then
    select id, alumno_id into v_existente_id, v_existente_alumno
      from public.suscripciones
     where clave_cobro = p_clave;
    if found then
      if v_existente_alumno is distinct from p_alumno_id then
        raise exception 'Ese cobro ya se registró para otro alumno.';
      end if;
      return v_existente_id;
    end if;
  end if;

  select academia_id, activo, precio, periodicidad
    into v_tarifa_academia_id, v_tarifa_activa, v_tarifa_precio,
         v_tarifa_periodicidad
    from public.tarifas
    where id = p_tarifa_id;

  if not found or v_tarifa_academia_id is distinct from v_actor_academia_id then
    raise exception 'Esa tarifa no es de tu academia.';
  end if;

  if not v_tarifa_activa then
    raise exception 'Esa tarifa está desactivada.';
  end if;

  -- 09/10/2026 (auditoría, punto 2): la duración sale de la tarifa. Antes
  -- todas se trataban como mensuales: el bono trimestral de 80 € cobrado
  -- «1 mes» duraba un mes, y «3 meses» proponía 240 €.
  v_meses_periodo := case v_tarifa_periodicidad
    when 'mensual' then 1
    when 'trimestral' then 3
    when 'anual' then 12
  end;

  if not p_prueba then
    if v_tarifa_periodicidad = 'suelta' then
      -- Una clase, que se puede usar durante un mes.
      if p_meses is not null and p_meses <> 1 then
        raise exception 'Una clase suelta se cobra de una en una.';
      end if;
      if p_fecha_fin is null then
        v_meses := 1;
      end if;
    elsif p_meses is not null and p_meses % v_meses_periodo <> 0 then
      raise exception 'Esta tarifa es %: se cobra por periodos de % meses.',
        v_tarifa_periodicidad, v_meses_periodo;
    end if;
  end if;

  -- 09/10/2026 (auditoría, punto 3; decisión de Cipri): una suelta con la
  -- cuota en vigor es una clase EXTRA de esa cuota. Se puede usar ya y
  -- caduca con ella. Antes era una renovación para cuando acabara.
  if not p_prueba and v_tarifa_periodicidad = 'suelta' then
    select id, estado, fecha_fin, clases_incluidas
      into v_base_id, v_base_estado, v_base_fin, v_base_incluidas
      from public.suscripciones
     where alumno_id = p_alumno_id
       and estado in ('activa', 'pausada')
       and payment_status = 'active'
       and (fecha_fin is null or fecha_fin > now())
     order by fecha_inicio desc
     limit 1
     for update;

    if found then
      if v_base_estado = 'pausada' then
        raise exception 'Tiene la cuota pausada: mientras lo esté puede venir '
                        'sin cuota. Reanúdala antes de cobrarle una clase extra.';
      end if;

      if v_base_incluidas is null then
        raise exception 'Su cuota ya tiene clases ilimitadas: no le hace falta '
                        'una clase extra.';
      end if;

      perform set_config('itaca.alta_extra', 'on', true);

      insert into public.suscripciones (
        alumno_id, tarifa_id, academia_id, proveedor_pago, referencia_externa,
        clave_cobro, extra_de
      )
      values (
        p_alumno_id, p_tarifa_id, v_actor_academia_id, 'efectivo', null,
        p_clave, v_base_id
      )
      returning id into v_suscripcion_id;

      perform set_config('itaca.alta_extra', 'off', true);

      -- La fecha de fin es la de la cuota hoy, para enseñarla. La que
      -- manda es la de la cuota en cada momento: si se pausa y se alarga,
      -- la extra dura lo mismo (`_saldo_clases` la lee desde la cuota).
      update public.suscripciones
         set payment_status = 'active',
             fecha_inicio = now(),
             fecha_fin = v_base_fin,
             importe_cobrado = coalesce(p_importe, v_tarifa_precio),
             cobrado_por = v_actor_id,
             cobrado_at = now()
       where id = v_suscripcion_id;

      return v_suscripcion_id;
    end if;
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
    when v_meses is not null then v_inicio + make_interval(months => v_meses)
    when p_fecha_fin is not null then v_inicio + (p_fecha_fin - now())
    else null
  end;

  perform set_config('itaca.alta_programada', case when v_renovacion then 'on' else 'off' end, true);

  insert into public.suscripciones (
    alumno_id, tarifa_id, academia_id, proveedor_pago, referencia_externa,
    clave_cobro
  )
  values (
    p_alumno_id, p_tarifa_id, v_actor_academia_id, 'efectivo', null,
    p_clave
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
           -- Precio de la tarifa por cada periodo pagado (la suelta, una).
           else coalesce(
             p_importe,
             v_tarifa_precio * coalesce(v_meses / v_meses_periodo, 1)
           )
         end,
         cobrado_por = v_actor_id,
         cobrado_at = now()
   where id = v_suscripcion_id;

  return v_suscripcion_id;
end;
$$;

revoke all on function public.activar_cuota_efectivo(uuid, uuid, timestamptz, boolean, numeric, integer, uuid)
  from public, anon;
grant execute on function public.activar_cuota_efectivo(uuid, uuid, timestamptz, boolean, numeric, integer, uuid)
  to authenticated;
