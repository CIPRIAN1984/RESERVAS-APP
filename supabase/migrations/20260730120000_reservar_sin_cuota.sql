-- ============================================================
-- Reservar sin cuota, y que se note
-- ============================================================
--
-- Hasta ahora `reservar_clase` rechazaba a cualquier Alumno sin una
-- suscripción activa y cobrada. Decisión de producto de Cipri: prefiere que
-- la gente se pueda apuntar igualmente y verlo marcado en la lista de la
-- clase, para cobrarles en mano cuando aparezcan por el gimnasio.
--
-- Se hace con un interruptor por academia en vez de quitar la comprobación,
-- para que se pueda volver atrás desde la propia app sin tocar la base de
-- datos. Por defecto NO se exige cuota, que es lo que ha pedido.
--
-- Lo que NO cambia: sigue haciendo falta cuenta activa, seguir perteneciendo
-- a la academia, que la clase sea futura, el aforo y la lista de espera.

alter table public.academias
  add column if not exists exigir_cuota_para_reservar boolean not null
    default false;

comment on column public.academias.exigir_cuota_para_reservar is
  'Si es true, solo los alumnos con cuota activa y cobrada pueden reservar. '
  'Por defecto false: se les deja reservar y quedan marcados como sin cuota '
  'en la lista de la clase.';

-- El Dueño lo cambia desde Ajustes de reservas. Va en la lista de columnas
-- concedidas una por una: `academias` tiene revocado el update de tabla
-- entera para que nadie pueda tocarse las columnas de Stripe ni el estado.
grant update (exigir_cuota_para_reservar) on public.academias to authenticated;

-- ============================================================
-- reservar_clase: la cuota pasa a ser condicional
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
  v_inicio timestamptz;
  v_aforo_maximo int;
  v_lista_espera_activa boolean;
  v_exigir_cuota boolean;
  v_inscritos int;
  v_resultado text;
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
         c.fecha_hora_inicio,
         c.aforo_maximo,
         a.lista_espera_activa,
         a.exigir_cuota_para_reservar
    into v_clase_academia_id,
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

revoke all on function public.reservar_clase(uuid) from public, anon;
grant execute on function public.reservar_clase(uuid) to authenticated;
