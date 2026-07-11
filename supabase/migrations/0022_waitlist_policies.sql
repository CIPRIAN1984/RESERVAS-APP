-- ITC.2 Lab — lista de espera y políticas operativas de reservas.
--
-- Automatiza las plazas cuando una clase está completa, registra cancelaciones
-- tardías sin retener artificialmente el hueco y materializa horarios
-- recurrentes en la zona horaria real de la academia.

-- ============================================================
-- Configuración de reservas por academia
-- ============================================================

alter table public.academias
  add column if not exists lista_espera_activa boolean not null default true,
  add column if not exists cancelacion_limite_minutos int not null default 240,
  add column if not exists zona_horaria text not null default 'Europe/Madrid';

alter table public.academias
  drop constraint if exists academias_cancelacion_limite_check;
alter table public.academias
  add constraint academias_cancelacion_limite_check
  check (cancelacion_limite_minutos between 0 and 10080);

alter table public.academias
  drop constraint if exists academias_zona_horaria_check;
alter table public.academias
  add constraint academias_zona_horaria_check
  check (zona_horaria in ('Europe/Madrid', 'Atlantic/Canary'));

grant update (
  lista_espera_activa,
  cancelacion_limite_minutos,
  zona_horaria
) on public.academias to authenticated;

-- ============================================================
-- Estados de inscripción y trazabilidad
-- ============================================================

alter table public.inscripciones
  add column if not exists cancelada_at timestamptz,
  add column if not exists cancelacion_tardia boolean not null default false,
  add column if not exists promovida_at timestamptz;

alter table public.inscripciones
  drop constraint if exists inscripciones_estado_check;
alter table public.inscripciones
  add constraint inscripciones_estado_check
  check (estado in ('inscrito', 'espera', 'cancelado'));

drop index if exists public.inscripciones_activa_unica_idx;
create unique index inscripciones_activa_unica_idx
  on public.inscripciones (clase_id, alumno_id)
  where estado in ('inscrito', 'espera');

create index if not exists inscripciones_espera_fifo_idx
  on public.inscripciones (clase_id, created_at, id)
  where estado = 'espera';

-- ============================================================
-- Reserva: plaza directa o lista de espera bajo el mismo bloqueo
-- ============================================================

drop function if exists public.reservar_clase(uuid);

create function public.reservar_clase(p_clase_id uuid)
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
         a.lista_espera_activa
    into v_clase_academia_id,
         v_inicio,
         v_aforo_maximo,
         v_lista_espera_activa
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

-- ============================================================
-- Cancelación: libera plaza y promociona automáticamente la cola FIFO
-- ============================================================

drop function if exists public.cancelar_reserva(uuid);

create function public.cancelar_reserva(p_clase_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_usuario_id uuid := auth.uid();
  v_inscripcion_id uuid;
  v_estado_cancelado text;
  v_academia_id uuid;
  v_titulo text;
  v_inicio timestamptz;
  v_aforo_maximo int;
  v_limite_minutos int;
  v_cancelacion_tardia boolean := false;
  v_ocupadas int;
  v_espera_id uuid;
  v_promovido_id uuid;
begin
  if v_usuario_id is null then
    raise exception 'No autorizado.';
  end if;

  select i.id,
         i.estado,
         c.academia_id,
         c.titulo,
         c.fecha_hora_inicio,
         c.aforo_maximo,
         a.cancelacion_limite_minutos
    into v_inscripcion_id,
         v_estado_cancelado,
         v_academia_id,
         v_titulo,
         v_inicio,
         v_aforo_maximo,
         v_limite_minutos
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

  if v_estado_cancelado = 'inscrito' then
    v_cancelacion_tardia :=
      now() > v_inicio - make_interval(mins => v_limite_minutos);
  end if;

  update public.inscripciones
    set estado = 'cancelado',
        cancelada_at = now(),
        cancelacion_tardia = v_cancelacion_tardia
    where id = v_inscripcion_id;

  if v_estado_cancelado = 'inscrito' and v_inicio > now() then
    -- Retira de la cola las cuentas que ya no cumplen las condiciones.
    update public.inscripciones w
      set estado = 'cancelado',
          cancelada_at = now()
      where w.clase_id = p_clase_id
        and w.estado = 'espera'
        and not exists (
          select 1
            from public.profiles p
            where p.id = w.alumno_id
              and p.estado = 'activo'
              and (
                p.rol in ('profesor', 'dueño')
                or (
                  p.rol = 'alumno'
                  and exists (
                    select 1
                      from public.suscripciones s
                      where s.alumno_id = p.id
                        and s.academia_id = v_academia_id
                        and s.estado = 'activa'
                        and s.payment_status = 'active'
                        and s.fecha_inicio <= now()
                        and (s.fecha_fin is null or s.fecha_fin > now())
                  )
                )
              )
        );

    select count(*)::int
      into v_ocupadas
      from public.inscripciones
      where clase_id = p_clase_id and estado = 'inscrito';

    if v_ocupadas < v_aforo_maximo then
      select id, alumno_id
        into v_espera_id, v_promovido_id
        from public.inscripciones
        where clase_id = p_clase_id and estado = 'espera'
        order by created_at, id
        limit 1
        for update;

      if found then
        update public.inscripciones
          set estado = 'inscrito',
              promovida_at = now()
          where id = v_espera_id;

        insert into public.notificaciones_outbox (
          user_id,
          titulo,
          cuerpo,
          data
        ) values (
          v_promovido_id,
          'Plaza confirmada',
          'Has conseguido plaza en ' || v_titulo || '.',
          jsonb_build_object(
            'type', 'waitlist_promoted',
            'clase_id', p_clase_id
          )
        );
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'estado_cancelado', v_estado_cancelado,
    'cancelacion_tardia', v_cancelacion_tardia,
    'alumno_promovido_id', v_promovido_id
  );
end;
$function$;

revoke all on function public.cancelar_reserva(uuid) from public, anon;
grant execute on function public.cancelar_reserva(uuid) to authenticated;

-- ============================================================
-- Clases recurrentes respetando zona horaria y cambios DST
-- ============================================================

create or replace function public.generar_clases_recurrentes(
  p_desde date default current_date,
  p_hasta date default (current_date + interval '28 days')::date
)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_generadas int;
begin
  with dias as (
    select d::date as dia
      from generate_series(
        p_desde,
        p_hasta - 1,
        interval '1 day'
      ) as d
  ),
  sesiones as (
    select
      cr.id as plantilla_id,
      cr.academia_id,
      cr.profesor_id,
      cr.titulo,
      cr.descripcion,
      ((dias.dia + cr.hora_inicio) at time zone a.zona_horaria) as inicio,
      (
        ((dias.dia + cr.hora_inicio) at time zone a.zona_horaria)
        + make_interval(mins => cr.duracion_min)
      ) as fin,
      cr.aforo_maximo
    from public.clases_recurrentes cr
    join public.academias a on a.id = cr.academia_id
    join dias
      on extract(dow from dias.dia)::int = cr.dia_semana
    where cr.activo
      and dias.dia >= cr.fecha_inicio
      and (cr.fecha_fin is null or dias.dia <= cr.fecha_fin)
  ),
  insertadas as (
    insert into public.clases (
      academia_id,
      profesor_id,
      titulo,
      descripcion,
      fecha_hora_inicio,
      fecha_hora_fin,
      aforo_maximo,
      plantilla_id
    )
    select
      academia_id,
      profesor_id,
      titulo,
      descripcion,
      inicio,
      fin,
      aforo_maximo,
      plantilla_id
    from sesiones
    on conflict (
      plantilla_id,
      fecha_hora_inicio
    ) where plantilla_id is not null
    do nothing
    returning 1
  )
  select count(*)::int into v_generadas from insertadas;

  return v_generadas;
end;
$function$;

create or replace function public.generar_mis_clases_recurrentes()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_academia uuid := public.current_academia_id();
  v_generadas int;
begin
  if public.current_rol() not in ('profesor', 'dueño') then
    raise exception 'Solo profesor o dueño pueden generar clases.';
  end if;

  with dias as (
    select d::date as dia
      from generate_series(
        current_date,
        (current_date + interval '28 days') - 1,
        interval '1 day'
      ) as d
  ),
  sesiones as (
    select
      cr.id as plantilla_id,
      cr.academia_id,
      cr.profesor_id,
      cr.titulo,
      cr.descripcion,
      ((dias.dia + cr.hora_inicio) at time zone a.zona_horaria) as inicio,
      (
        ((dias.dia + cr.hora_inicio) at time zone a.zona_horaria)
        + make_interval(mins => cr.duracion_min)
      ) as fin,
      cr.aforo_maximo
    from public.clases_recurrentes cr
    join public.academias a on a.id = cr.academia_id
    join dias
      on extract(dow from dias.dia)::int = cr.dia_semana
    where cr.activo
      and cr.academia_id = v_academia
      and dias.dia >= cr.fecha_inicio
      and (cr.fecha_fin is null or dias.dia <= cr.fecha_fin)
  ),
  insertadas as (
    insert into public.clases (
      academia_id,
      profesor_id,
      titulo,
      descripcion,
      fecha_hora_inicio,
      fecha_hora_fin,
      aforo_maximo,
      plantilla_id
    )
    select
      academia_id,
      profesor_id,
      titulo,
      descripcion,
      inicio,
      fin,
      aforo_maximo,
      plantilla_id
    from sesiones
    on conflict (
      plantilla_id,
      fecha_hora_inicio
    ) where plantilla_id is not null
    do nothing
    returning 1
  )
  select count(*)::int into v_generadas from insertadas;

  return v_generadas;
end;
$function$;
