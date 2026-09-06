-- Dar de baja a un alumno: se archiva, no se borra (06/09/2026).
--
-- Las reglas las puso Cipri (ver DECISIONS.md de hoy):
--   1. El alumno nunca se da de baja solo. La baja es del Dueño.
--   2. Se guarda el historial: asistencias, cuotas cobradas, cinturón y
--      antigüedad se quedan. Si vuelve, se reactiva y sigue donde lo dejó.
--   3. La cuota se cierra con fecha de hoy — no se borra, que es el registro
--      de un cobro, pero deja de estar activa.
--   4. El alumno de baja puede entrar en la app, pero no reservar.
--
-- El riesgo de esta migración no es escribir la baja: es que algún sitio se
-- olvide de mirarla y un alumno dado de baja siga contando en el ranking, en
-- las listas o en las estadísticas. Por eso `supabase/tests/baja_alumno_test.sql`
-- los recorre uno a uno.

-- ============================================================
-- El estado nuevo
-- ============================================================

alter table public.profiles
  drop constraint if exists profiles_estado_check;

alter table public.profiles
  add constraint profiles_estado_check
  check (estado in ('activo', 'pendiente_aprobacion', 'baja'));

alter table public.profiles
  add column if not exists fecha_baja timestamptz;

comment on column public.profiles.fecha_baja is
  'Cuándo se dio de baja. Se conserva al reactivar como rastro de que hubo '
  'una baja; lo que manda para saber si está activo es `estado`.';

-- `estado` sigue sin poder escribirlo el cliente: la lección de la migración
-- 0013 es que un `revoke` de columna no sirve si ya hay un GRANT de tabla
-- entera. Aquí no se toca ningún grant, así que sigue vigente: la baja solo
-- se puede dar por las funciones de abajo.

-- ============================================================
-- `cancelar_reserva`: el Dueño también puede cancelar por un alumno suyo
-- ============================================================
-- Este cuerpo se ha sacado de la definición VIVA de la función y se le ha
-- parcheado únicamente el bloque de autorización, sin reescribir el resto.
-- Reconstruirla de memoria fue el fallo del 03/09: se perdió `promovida_at`,
-- cambió el orden de la cola y se renombraron las claves que devuelve.

CREATE OR REPLACE FUNCTION public.cancelar_reserva(p_clase_id uuid, p_alumno_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  -- Sin `p_alumno_id`, cancelo lo mío. Con él, solo si soy su padre o
  -- tutor. `es_padre_de` es security definer y mira relaciones_familia, en
  -- la que ya ningún cliente puede escribir a mano (migración 20260903120000).
  v_usuario_id := coalesce(p_alumno_id, v_actor_id);

  -- Se amplía el 06/09/2026: además del propio alumno y de su padre, el
  -- Dueño y el Profesor de la academia pueden cancelar la reserva de un
  -- alumno suyo. Hacía falta para que `dar_de_baja_alumno` pueda liberar las
  -- plazas futuras del que se va **reutilizando esta función**, en vez de
  -- copiar aquí la promoción de la lista de espera. Duplicar esa lógica es
  -- exactamente el fallo del 03/09.
  if v_usuario_id <> v_actor_id
     and not public.es_padre_de(v_usuario_id)
     and not (
       public.current_rol() in ('dueño', 'profesor')
       and public.academia_id_de(v_usuario_id) = public.current_academia_id()
     )
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
    -- Retira de la cola a quien ya no cumple las condiciones para reservar
    -- esta clase: inactivo, sin cuota cuando la academia la exige, o con
    -- cuota limitada ya sin clases disponibles. Se calcula el saldo una
    -- sola vez por candidato (CTE), no una vez por condición.
    with candidatos as (
      select
        w.id,
        p.estado as perfil_estado,
        p.rol,
        case when p.rol = 'alumno' then public._saldo_clases(w.alumno_id) end as saldo
      from public.inscripciones w
      join public.profiles p on p.id = w.alumno_id
      where w.clase_id = p_clase_id
        and w.estado = 'espera'
    ),
    no_elegibles as (
      select id from candidatos
      where perfil_estado <> 'activo'
        or (
          rol = 'alumno'
          and (
            (
              v_exigir_cuota
              and not (saldo->>'tiene_cuota')::boolean
            )
            or (
              (saldo->>'tiene_cuota')::boolean
              and not (saldo->>'ilimitada')::boolean
              and (saldo->>'disponibles')::int <= 0
            )
          )
        )
    )
    update public.inscripciones w
      set estado = 'cancelado',
          cancelada_at = now()
      where w.id in (select id from no_elegibles);

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


-- ============================================================
-- Dar de baja
-- ============================================================

create or replace function public.dar_de_baja_alumno(p_alumno_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_academia_id uuid := public.current_academia_id();
  v_rol text := public.current_rol();
  v_estado text;
  v_rol_alumno text;
  v_clase_id uuid;
begin
  -- «Solo yo les puedo dar de baja»: el Dueño. El Profesor pasa lista y da
  -- clases, pero las altas y bajas son del que lleva el negocio.
  if v_rol not in ('dueño', 'administrador') then
    raise exception 'Solo el dueño de la academia puede dar de baja a un alumno.';
  end if;

  select estado, rol into v_estado, v_rol_alumno
    from public.profiles
    where id = p_alumno_id
      and (academia_id = v_academia_id or v_rol = 'administrador')
    for update;

  if not found then
    raise exception 'Ese alumno no es de tu academia.';
  end if;

  if v_rol_alumno <> 'alumno' then
    raise exception 'Solo se puede dar de baja a un alumno. Cambia antes su rol.';
  end if;

  if v_estado = 'baja' then
    raise exception 'Este alumno ya estaba dado de baja.';
  end if;

  -- 1) Sus reservas futuras se liberan **reutilizando `cancelar_reserva`**,
  --    que es quien sabe ascender a la lista de espera. Copiar aquí esa
  --    lógica es el fallo del 03/09; llamarla cuesta un bucle.
  for v_clase_id in
    select i.clase_id
      from public.inscripciones i
      join public.clases c on c.id = i.clase_id
     where i.alumno_id = p_alumno_id
       and i.estado in ('inscrito', 'espera')
       and c.fecha_hora_inicio > now()
  loop
    perform public.cancelar_reserva(v_clase_id, p_alumno_id);
  end loop;

  -- 2) La cuota se cierra con fecha de hoy. NO se borra: es el registro de
  --    un cobro y en España hay que conservarlo años.
  update public.suscripciones
     set estado = 'cancelada',
         fecha_fin = least(coalesce(fecha_fin, now()), now())
   where alumno_id = p_alumno_id
     and estado in ('activa', 'prueba', 'pausada', 'pendiente_pago');

  -- 3) Y solo entonces, la baja.
  update public.profiles
     set estado = 'baja',
         fecha_baja = now()
   where id = p_alumno_id;
end;
$function$;

revoke all on function public.dar_de_baja_alumno(uuid) from public, anon;
grant execute on function public.dar_de_baja_alumno(uuid) to authenticated;

-- ============================================================
-- Reactivar
-- ============================================================
-- Vuelve tal y como se fue: con su cinturón, su antigüedad y sus asistencias.
-- La cuota NO se reactiva sola — el Dueño le cobra de nuevo cuando toque, que
-- es una decisión de dinero y no puede tomarla un botón.

create or replace function public.reactivar_alumno(p_alumno_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_academia_id uuid := public.current_academia_id();
  v_rol text := public.current_rol();
  v_estado text;
begin
  if v_rol not in ('dueño', 'administrador') then
    raise exception 'Solo el dueño de la academia puede reactivar a un alumno.';
  end if;

  select estado into v_estado
    from public.profiles
    where id = p_alumno_id
      and (academia_id = v_academia_id or v_rol = 'administrador')
    for update;

  if not found then
    raise exception 'Ese alumno no es de tu academia.';
  end if;

  if v_estado <> 'baja' then
    raise exception 'Este alumno no está dado de baja.';
  end if;

  update public.profiles
     set estado = 'activo'
   where id = p_alumno_id;
end;
$function$;

revoke all on function public.reactivar_alumno(uuid) from public, anon;
grant execute on function public.reactivar_alumno(uuid) to authenticated;

-- ============================================================
-- Los sitios que tienen que dejar de contar a un alumno de baja
-- ============================================================
-- Estos tres cuerpos también se han sacado de la definición VIVA y solo se
-- les ha añadido el filtro; no se han reescrito.

-- ranking_periodo
-- El ranking es de quien entrena AHORA. Quien se fue en marzo no compite
-- en el ranking de septiembre, aunque sus asistencias sigan guardadas.
CREATE OR REPLACE FUNCTION public.ranking_periodo(p_desde date DEFAULT NULL::date, p_hasta date DEFAULT NULL::date)
 RETURNS TABLE(alumno_id uuid, nombre text, apellidos text, foto_url text, cinturon text, asistencias_count bigint)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select
    p.id as alumno_id,
    p.nombre,
    p.apellidos,
    p.foto_url,
    p.cinturon,
    count(a.id) as asistencias_count
  from public.profiles p
  left join public.asistencias a
    on a.alumno_id = p.id
    and (p_desde is null or a.fecha >= p_desde::timestamptz)
    and (p_hasta is null or a.fecha < (p_hasta + 1)::timestamptz)
  where p.rol = 'alumno' and p.estado <> 'baja' and p.academia_id = public.current_academia_id()
  group by p.id, p.nombre, p.apellidos, p.foto_url, p.cinturon
  order by asistencias_count desc, p.nombre asc;
$function$;

-- ultima_asistencia_por_alumno
-- Alimenta el aviso de «inactivos» de Miembros. Un alumno dado de baja no
-- es un inactivo al que perseguir: es alguien que ya se ha ido.
CREATE OR REPLACE FUNCTION public.ultima_asistencia_por_alumno()
 RETURNS TABLE(alumno_id uuid, ultima_asistencia timestamp with time zone)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select a.alumno_id, max(a.fecha) as ultima_asistencia
    from public.asistencias a
    join public.profiles p on p.id = a.alumno_id
   where p.rol = 'alumno' and p.estado <> 'baja'
     and p.entrena
     and p.academia_id = public.current_academia_id()
   group by a.alumno_id;
$function$;

-- progreso_graduacion_alumnos
-- Alimenta «listo para graduarse». No se gradúa a quien ya no viene.
CREATE OR REPLACE FUNCTION public.progreso_graduacion_alumnos()
 RETURNS TABLE(alumno_id uuid, asistencias bigint, es_menor boolean)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select
    p.id as alumno_id,
    count(a.id) as asistencias,
    exists (
      select 1 from public.relaciones_familia rf where rf.child_id = p.id
    ) as es_menor
  from public.profiles p
  left join public.asistencias a
    on a.alumno_id = p.id
    and a.fecha >= coalesce(p.fecha_inicio_cinturon, now())
  where p.rol = 'alumno' and p.estado <> 'baja'
    and p.entrena
    and p.academia_id = public.current_academia_id()
  group by p.id;
$function$;
