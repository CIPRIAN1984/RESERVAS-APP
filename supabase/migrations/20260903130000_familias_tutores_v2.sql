-- Familias y tutores, segunda versión: un padre con varios hijos
--
-- La primera versión (20260810100946) está congelada y **rota de raíz**:
-- `crear_perfil_hijo` inserta un perfil con un uuid nuevo, pero
-- `profiles.id` tiene una clave foránea contra `auth.users`, así que la
-- inserción falla siempre. Nunca ha podido crear un solo hijo. FREEZE.md ya
-- lo anotó el 12/08/2026: "exige una fila en auth.users para el perfil del
-- menor y nunca la crea".
--
-- Aquí se arregla la causa, no el síntoma.
--
-- DECISIONES DE PRODUCTO (Cipri, 03/09/2026):
--   * Un padre que solo trae al hijo y no entrena **no cuenta como alumno**:
--     no sale en la lista de Miembros ni en «Sin cuota». Si además entrena,
--     cuenta como alumno también. De ahí la columna `entrena`.
--   * **Una cuota por hijo**, como cualquier otro alumno. No hay cuota
--     familiar ni descuento de hermanos, así que el modelo de cobros no se
--     toca en absoluto.
--
-- DECISIONES TÉCNICAS:
--   * Los menores son perfiles normales **sin cuenta** (`tiene_cuenta` a
--     false). Se elige esto en vez de crearles una cuenta falsa en
--     `auth.users` porque un menor no debe poder iniciar sesión nunca, y
--     una cuenta que existe es una cuenta que algún día alguien usa. Como
--     son perfiles normales, todo lo demás (inscripciones, asistencias,
--     cuotas, ranking, cinturones, graduación) les funciona sin tocar nada.
--   * El precio de esa decisión es quitar la clave foránea
--     `profiles.id -> auth.users.id`. Lo que esa clave daba gratis era el
--     borrado en cascada al eliminar un usuario, y eso se recupera con un
--     disparador explícito.

-- ============================================================
-- 1. Un perfil ya no obliga a tener cuenta
-- ============================================================

alter table public.profiles
  drop constraint if exists profiles_id_fkey;

alter table public.profiles
  add column if not exists tiene_cuenta boolean not null default true;

comment on column public.profiles.tiene_cuenta is
  'false = perfil sin cuenta propia (un menor dado de alta por su tutor). '
  'Nunca puede iniciar sesión: no existe en auth.users.';

-- Lo que hacía el `on delete cascade` de la clave foránea que se acaba de
-- quitar: si se borra la cuenta, se borra su perfil. Los menores no tienen
-- cuenta, así que a ellos no les afecta — se quedan, que es lo que se
-- quiere: sus asistencias y su historial no dependen de nadie más.
create or replace function public.borrar_perfil_al_borrar_cuenta()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.profiles where id = old.id;
  return old;
end;
$$;

revoke all on function public.borrar_perfil_al_borrar_cuenta() from public, anon, authenticated;

drop trigger if exists on_auth_user_deleted on auth.users;
create trigger on_auth_user_deleted
  after delete on auth.users
  for each row execute function public.borrar_perfil_al_borrar_cuenta();

-- ============================================================
-- 2. Quién entrena y quién solo trae a sus hijos
-- ============================================================

alter table public.profiles
  add column if not exists entrena boolean not null default true;

comment on column public.profiles.entrena is
  'false = solo tutor: no aparece en Miembros ni en los contadores de '
  'alumnos, y no puede reservar clases para sí mismo. Sí gestiona a sus '
  'hijos. Decisión de producto de Cipri, 03/09/2026.';

-- Cada cual decide si entrena o no en su propio perfil, y un padre puede
-- decidirlo también sobre sus hijos (política profiles_update). No es un
-- privilegio: activarlo o desactivarlo solo cambia en qué listas sales.
--
-- Ojo con el orden (lección de la migración 0013): esto es un grant de
-- columna sobre una tabla en la que `authenticated` NO tiene UPDATE de
-- tabla entera. Si lo tuviera, este grant no añadiría ninguna restricción.
grant update (entrena) on public.profiles to authenticated;

-- ============================================================
-- 3. Alta de un hijo: una sola puerta, y valida quién es el hijo
-- ============================================================

-- La vieja no puede funcionar nunca (ver cabecera) y es `security definer`:
-- fuera.
drop function if exists public.crear_perfil_hijo(uuid, uuid, text, text, text);

-- Sustituye a la inserción directa en relaciones_familia, que se retiró el
-- 03/09/2026 por dejar que cualquiera se declarase padre de cualquiera
-- (ver migración 20260903120000). Aquí el hijo **se crea dentro de la
-- función**: no se puede pasar el perfil de otra persona.
create function public.crear_hijo(
  p_nombre text,
  p_apellidos text default null,
  p_cinturon text default null
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_padre_id uuid := auth.uid();
  v_academia_id uuid;
  v_estado text;
  v_hijos int;
  v_hijo_id uuid;
begin
  if v_padre_id is null then
    raise exception 'No autorizado.';
  end if;

  select academia_id, estado
    into v_academia_id, v_estado
    from public.profiles
    where id = v_padre_id;

  if not found or v_estado <> 'activo' then
    raise exception 'Tu cuenta no está activa.';
  end if;

  if v_academia_id is null then
    raise exception 'Tu cuenta no pertenece a ninguna academia.';
  end if;

  -- Un menor no da de alta a nadie: cortaría la cadena de responsabilidad
  -- (y con ella el consentimiento del tutor sobre los datos del niño).
  if exists (
    select 1 from public.relaciones_familia where child_id = v_padre_id
  ) then
    raise exception 'Un menor no puede dar de alta a otras personas.';
  end if;

  if nullif(trim(coalesce(p_nombre, '')), '') is null then
    raise exception 'El nombre del hijo es obligatorio.';
  end if;

  -- Tope sencillo contra el abuso: nadie tiene once hijos en la academia,
  -- y sin él una cuenta podría llenar la tabla de perfiles.
  select count(*) into v_hijos
    from public.relaciones_familia
    where parent_id = v_padre_id;

  if v_hijos >= 10 then
    raise exception 'No puedes tener más de 10 hijos dados de alta.';
  end if;

  insert into public.profiles (
    id,
    academia_id,
    rol,
    nombre,
    apellidos,
    cinturon,
    estado,
    entrena,
    tiene_cuenta,
    fecha_inicio_cinturon
  ) values (
    gen_random_uuid(),
    v_academia_id,
    'alumno',
    trim(p_nombre),
    nullif(trim(coalesce(p_apellidos, '')), ''),
    p_cinturon,
    'activo',
    true,
    false,
    now()
  )
  returning id into v_hijo_id;

  insert into public.relaciones_familia (parent_id, child_id, tipo_relacion)
  values (v_padre_id, v_hijo_id, 'padre');

  return v_hijo_id;
end;
$$;

revoke all on function public.crear_hijo(text, text, text) from public, anon;
grant execute on function public.crear_hijo(text, text, text) to authenticated;

-- ============================================================
-- 4. Reservar y cancelar en nombre de un hijo
-- ============================================================

-- Las dos funciones ya lo hacían todo sobre una variable `v_usuario_id`
-- que salía de `auth.uid()`. El único cambio real es de dónde sale esa
-- variable: de quien llama, o del hijo por el que llama.
--
-- OJO: `create or replace` con una lista de argumentos distinta NO
-- reemplaza, crea una **sobrecarga** — y entonces PostgREST no sabe a cuál
-- llamar. Hay que borrar la firma vieja a mano. (Lección de la migración
-- de prueba/pausada, 27/08/2026.)
drop function if exists public.reservar_clase(uuid);
drop function if exists public.cancelar_reserva(uuid);

create function public.reservar_clase(
  p_clase_id uuid,
  p_alumno_id uuid default null
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_usuario_id uuid;
  v_academia_id uuid;
  v_rol text;
  v_estado text;
  v_entrena boolean;
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
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  -- Sin `p_alumno_id`, reservo para mí. Con él, solo si soy su padre o
  -- tutor. `es_padre_de` es security definer y mira relaciones_familia, en
  -- la que ya ningún cliente puede escribir a mano (migración 20260903120000).
  v_usuario_id := coalesce(p_alumno_id, v_actor_id);

  if v_usuario_id <> v_actor_id and not public.es_padre_de(v_usuario_id) then
    raise exception 'Solo puedes reservar para ti o para tus hijos.';
  end if;

  select academia_id, rol, estado, entrena
    into v_academia_id, v_rol, v_estado, v_entrena
    from public.profiles
    where id = v_usuario_id;

  if not found or v_estado <> 'activo' then
    raise exception 'Tu cuenta no está activa.';
  end if;

  if v_rol not in ('alumno', 'profesor', 'dueño') or v_academia_id is null then
    raise exception 'Tu cuenta no puede reservar clases.';
  end if;

  -- Quien ha marcado que no entrena no ocupa plaza: si no, saldría en la
  -- lista de la clase pero no en la de alumnos, y el profesor no
  -- entendería nada.
  if not v_entrena then
    if v_usuario_id = v_actor_id then
      raise exception 'Tienes marcado que no entrenas. Cámbialo en tu perfil para reservar.';
    else
      raise exception 'Este alumno tiene marcado que no entrena.';
    end if;
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

  -- La cuota que se mira es la **del alumno** (el hijo, si se reserva por
  -- él): Cipri decidió una cuota por hijo, no una familiar.
  -- Solo si la academia lo exige. Con el ajuste por defecto, quien no tiene
  -- cuota reserva igual y sale marcado en la lista de la clase. Una prueba
  -- cuenta como cuota (es justo lo que permite probar antes de pagar); una
  -- cuota pausada NO cuenta (es justo lo que significa pausarla).
  if v_exigir_cuota and v_rol = 'alumno' and not exists (
    select 1
      from public.suscripciones
      where alumno_id = v_usuario_id
        and academia_id = v_academia_id
        and estado in ('activa', 'prueba')
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
    -- `_saldo_clases` y no `clases_restantes`: la segunda vuelve a
    -- comprobar quién pregunta por quién y solo deja a Dueño y Profesor
    -- mirar el saldo de otro, así que un padre reservando para su hijo se
    -- estrellaba ahí con «No autorizado.». Aquí ya se ha autorizado arriba.
    v_saldo := public._saldo_clases(v_usuario_id);
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

revoke all on function public.reservar_clase(uuid, uuid) from public, anon;
grant execute on function public.reservar_clase(uuid, uuid) to authenticated;

create function public.cancelar_reserva(
  p_clase_id uuid,
  p_alumno_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
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

  if v_usuario_id <> v_actor_id and not public.es_padre_de(v_usuario_id) then
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

revoke all on function public.cancelar_reserva(uuid, uuid) from public, anon;
grant execute on function public.cancelar_reserva(uuid, uuid) to authenticated;

-- ============================================================
-- 5. Los tutores no cuentan como alumnos en las listas
-- ============================================================

-- Las dos funciones que alimentan la pantalla de Miembros filtran por
-- `rol = 'alumno'`. Ahora además por `entrena`: si no, un padre que solo
-- trae al niño saldría en «Inactivos» y en «Sin cuota» para siempre,
-- que es justo lo que Cipri no quiere.

create or replace function public.ultima_asistencia_por_alumno()
returns table (alumno_id uuid, ultima_asistencia timestamptz)
language sql
stable
as $$
  select a.alumno_id, max(a.fecha) as ultima_asistencia
    from public.asistencias a
    join public.profiles p on p.id = a.alumno_id
   where p.rol = 'alumno'
     and p.entrena
     and p.academia_id = public.current_academia_id()
   group by a.alumno_id;
$$;

create or replace function public.progreso_graduacion_alumnos()
returns table (
  alumno_id uuid,
  asistencias bigint,
  es_menor boolean
)
language sql
stable
as $$
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
  where p.rol = 'alumno'
    and p.entrena
    and p.academia_id = public.current_academia_id()
  group by p.id;
$$;
