-- Una puerta de SOLO LECTURA para el agente personal del dueño.
--
-- Cipri quiere que su agente (ChatGPT) pueda preguntarle cosas a la app:
-- cuánta gente vino, quién no ha pagado, quién lleva semanas sin aparecer,
-- qué clases hay esta semana.
--
-- Tres decisiones de fondo, que son las que hacen que esto sea seguro:
--
--  1. **Las funciones de consulta NO son `security definer`.** Podrían
--     serlo (tomando la academia del parámetro), pero entonces un fallo
--     futuro que le concediera `execute` a `authenticated` dejaría a
--     cualquier alumno leer la academia entera pasando otro uuid. Al
--     dejarlas como invocador, el único que ve algo es quien ya puede
--     verlo: `service_role`, que es la Edge Function. Si alguien se
--     equivoca con los permisos, RLS sigue tapando el agujero.
--
--  2. **La clave se guarda troceada (sha256), nunca entera.** `crear_clave_agente`
--     la devuelve una sola vez, al crearla. Ni yo ni nadie puede volver a
--     leerla después: si se pierde, se revoca y se hace otra.
--
--  3. **El correo de los alumnos va detrás de su propio interruptor**
--     (`incluye_contacto`, por defecto `false`). Cipri decidió incluirlo
--     sabiendo que ese dato sale de la app hacia la empresa del agente;
--     dejarlo aparte permite cerrarlo sin tocar el resto.
--
-- Por esta puerta no se puede escribir: no hay ni una sola función de
-- escritura, y `service_role` solo recibe `execute` sobre las cuatro
-- consultas de abajo.

-- ---------------------------------------------------------------------------
-- 1. Claves
-- ---------------------------------------------------------------------------

create table if not exists public.claves_agente (
  id uuid primary key default gen_random_uuid(),
  academia_id uuid not null references public.academias(id) on delete cascade,
  nombre text not null,
  clave_hash text not null unique,
  -- Los últimos 4 caracteres, para que Cipri reconozca cuál es cuál en la
  -- lista sin que eso sirva para adivinar la clave.
  pista text not null,
  incluye_contacto boolean not null default false,
  creada_at timestamptz not null default now(),
  creada_por uuid references public.profiles(id) on delete set null,
  ultimo_uso_at timestamptz,
  revocada_at timestamptz
);

create index if not exists claves_agente_academia_idx
  on public.claves_agente (academia_id);

-- ---------------------------------------------------------------------------
-- 2. Registro de lo que ha leído el agente
-- ---------------------------------------------------------------------------

create table if not exists public.consultas_agente (
  id bigint generated always as identity primary key,
  clave_id uuid not null references public.claves_agente(id) on delete cascade,
  academia_id uuid not null references public.academias(id) on delete cascade,
  consulta text not null,
  parametros jsonb not null default '{}'::jsonb,
  filas integer not null default 0,
  at timestamptz not null default now()
);

create index if not exists consultas_agente_academia_idx
  on public.consultas_agente (academia_id, at desc);

-- RLS activada y **sin ninguna política**: así nadie llega a estas tablas
-- desde la app. El único que entra es `service_role` (la Edge Function),
-- que se salta RLS por definición, y el dueño a través de las funciones
-- `security definer` de más abajo, que filtran por su academia.
alter table public.claves_agente enable row level security;
alter table public.consultas_agente enable row level security;

revoke all on public.claves_agente from public, anon, authenticated;
revoke all on public.consultas_agente from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Gestión de claves — la usa el dueño desde la app
-- ---------------------------------------------------------------------------

create or replace function public.crear_clave_agente(
  p_nombre text,
  p_incluye_contacto boolean default false
)
returns text
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_academia uuid := public.current_academia_id();
  v_clave    text;
begin
  if public.current_rol() not in ('dueño', 'administrador') then
    raise exception 'Solo el dueño puede crear claves para un agente.';
  end if;

  if v_academia is null then
    raise exception 'No tienes ninguna academia asignada.';
  end if;

  if coalesce(trim(p_nombre), '') = '' then
    raise exception 'Ponle un nombre a la clave para saber cuál es.';
  end if;

  v_clave := 'itc_' || encode(extensions.gen_random_bytes(24), 'hex');

  insert into public.claves_agente (
    academia_id, nombre, clave_hash, pista, incluye_contacto, creada_por
  )
  values (
    v_academia,
    trim(p_nombre),
    encode(extensions.digest(v_clave, 'sha256'), 'hex'),
    right(v_clave, 4),
    coalesce(p_incluye_contacto, false),
    auth.uid()
  );

  -- La única vez en la vida que esta clave se ve entera.
  return v_clave;
end;
$$;

create or replace function public.listar_claves_agente()
returns table (
  id uuid,
  nombre text,
  pista text,
  incluye_contacto boolean,
  creada_at timestamptz,
  ultimo_uso_at timestamptz,
  revocada_at timestamptz,
  consultas bigint
)
language sql
security definer
set search_path = public, pg_temp
as $$
  select c.id,
         c.nombre,
         c.pista,
         c.incluye_contacto,
         c.creada_at,
         c.ultimo_uso_at,
         c.revocada_at,
         (select count(*) from public.consultas_agente q where q.clave_id = c.id)
  from public.claves_agente c
  where c.academia_id = public.current_academia_id()
    and public.current_rol() in ('dueño', 'administrador')
  order by c.creada_at desc;
$$;

create or replace function public.revocar_clave_agente(p_clave_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_afectadas integer;
begin
  if public.current_rol() not in ('dueño', 'administrador') then
    raise exception 'Solo el dueño puede revocar claves de agente.';
  end if;

  update public.claves_agente
     set revocada_at = now()
   where id = p_clave_id
     and academia_id = public.current_academia_id()
     and revocada_at is null;

  get diagnostics v_afectadas = row_count;

  if v_afectadas = 0 then
    raise exception 'Esa clave no existe o ya estaba revocada.';
  end if;
end;
$$;

create or replace function public.listar_consultas_agente(p_limite integer default 50)
returns table (
  at timestamptz,
  clave text,
  consulta text,
  parametros jsonb,
  filas integer
)
language sql
security definer
set search_path = public, pg_temp
as $$
  select q.at, c.nombre, q.consulta, q.parametros, q.filas
  from public.consultas_agente q
  join public.claves_agente c on c.id = q.clave_id
  where q.academia_id = public.current_academia_id()
    and public.current_rol() in ('dueño', 'administrador')
  order by q.at desc
  limit least(greatest(coalesce(p_limite, 50), 1), 500);
$$;

revoke all on function public.crear_clave_agente(text, boolean) from public, anon;
revoke all on function public.listar_claves_agente() from public, anon;
revoke all on function public.revocar_clave_agente(uuid) from public, anon;
revoke all on function public.listar_consultas_agente(integer) from public, anon;

grant execute on function public.crear_clave_agente(text, boolean) to authenticated;
grant execute on function public.listar_claves_agente() to authenticated;
grant execute on function public.revocar_clave_agente(uuid) to authenticated;
grant execute on function public.listar_consultas_agente(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Las consultas del agente
--
-- Ninguna es `security definer` (ver la cabecera). Todas reciben la academia
-- ya resuelta por la Edge Function a partir de la clave presentada.
-- ---------------------------------------------------------------------------

-- Quién tiene la cuota al día. **Mismo criterio exacto** que usa
-- `reservar_clase` y que `MiembrosRepository.alumnosConCuotaAlDia`: activa o
-- en prueba, cobrada y dentro de fechas. Si esto se relajara, el agente le
-- diría a Cipri que alguien está al día cuando el servidor lo considera
-- moroso.
create or replace function public.agente_cuotas_al_dia(p_academia_id uuid)
returns table (alumno_id uuid)
language sql
stable
set search_path = public, pg_temp
as $$
  select distinct s.alumno_id
  from public.suscripciones s
  where s.academia_id = p_academia_id
    and s.estado in ('activa', 'prueba')
    and s.payment_status = 'active'
    and s.fecha_inicio <= now()
    and (s.fecha_fin is null or s.fecha_fin > now());
$$;

create or replace function public.agente_resumen(
  p_academia_id uuid,
  p_desde date,
  p_hasta date
)
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  with rango as (
    select p_desde::timestamptz as desde,
           (p_hasta + 1)::timestamptz as hasta
  ),
  alumnos as (
    select p.id, p.estado, p.created_at, p.fecha_baja
    from public.profiles p
    where p.academia_id = p_academia_id and p.rol = 'alumno'
  ),
  clases as (
    select c.id, c.aforo_maximo, c.estado
    from public.clases c, rango r
    where c.academia_id = p_academia_id
      and c.fecha_hora_inicio >= r.desde
      and c.fecha_hora_inicio < r.hasta
  )
  select jsonb_build_object(
    'periodo', jsonb_build_object('desde', p_desde, 'hasta', p_hasta),
    'alumnos', jsonb_build_object(
      'activos', (select count(*) from alumnos where estado <> 'baja'),
      'de_baja', (select count(*) from alumnos where estado = 'baja'),
      'altas_en_el_periodo',
        (select count(*) from alumnos a, rango r
          where a.created_at >= r.desde and a.created_at < r.hasta),
      'bajas_en_el_periodo',
        (select count(*) from alumnos a, rango r
          where a.fecha_baja >= r.desde and a.fecha_baja < r.hasta)
    ),
    'clases', jsonb_build_object(
      'programadas', (select count(*) from clases where estado <> 'cancelada'),
      'canceladas', (select count(*) from clases where estado = 'cancelada'),
      'plazas_ofrecidas',
        (select coalesce(sum(aforo_maximo), 0) from clases where estado <> 'cancelada'),
      'reservas',
        (select count(*) from public.inscripciones i
          where i.clase_id in (select id from clases) and i.estado = 'inscrito'),
      'asistencias',
        (select count(*) from public.asistencias a
          where a.clase_id in (select id from clases)),
      'ocupacion_media_por_ciento',
        (select case
                  when coalesce(sum(aforo_maximo), 0) = 0 then null
                  else round(
                    100.0 * (select count(*) from public.inscripciones i
                              where i.clase_id in (select id from clases)
                                and i.estado = 'inscrito')
                    / sum(aforo_maximo), 1)
                end
           from clases where estado <> 'cancelada')
    ),
    'cuotas', jsonb_build_object(
      'al_dia', (select count(*) from alumnos a
                  where a.estado <> 'baja'
                    and a.id in (select alumno_id from public.agente_cuotas_al_dia(p_academia_id))),
      'sin_cuota', (select count(*) from alumnos a
                     where a.estado <> 'baja'
                       and a.id not in (select alumno_id from public.agente_cuotas_al_dia(p_academia_id)))
    )
  );
$$;

-- El cinturón que sigue. **Espejo de `progreso_cinturon.dart`**: las dos
-- secuencias y los dos totales (78 entrenos los niños, 312 los adultos)
-- están escritos en Dart y aquí. Hay una prueba que los compara, para que
-- si alguien cambia uno y no el otro salte en vez de mentir en silencio.
create or replace function public.agente_proximo_cinturon(
  p_cinturon text,
  p_es_menor boolean
)
returns text
language sql
immutable
set search_path = pg_temp
as $$
  with secuencia as (
    select case when p_es_menor then
        array['blanco','gris_blanco','gris','gris_negro',
              'amarillo_blanco','amarillo','amarillo_negro',
              'naranja_blanco','naranja','naranja_negro',
              'verde_blanco','verde','verde_negro']
      else
        array['blanco','azul','morado','marron','negro']
      end as pasos
  )
  select case
           when idx = 0 then null                       -- cinturón desconocido
           when idx = array_length(pasos, 1) then null  -- ya está en el tope
           else pasos[idx + 1]
         end
  from secuencia,
       lateral (select coalesce(array_position(pasos, coalesce(p_cinturon, 'blanco')), 0)) as p(idx);
$$;

-- A quién hay que prestar atención. Lleva nombre a propósito: un aviso sin
-- nombre no sirve para nada.
create or replace function public.agente_avisos(
  p_academia_id uuid,
  p_dias_sin_venir integer default 21
)
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  with activos as (
    select p.id, p.nombre, p.apellidos, p.cinturon, p.created_at,
           p.fecha_inicio_cinturon,
           exists (select 1 from public.relaciones_familia rf where rf.child_id = p.id) as es_menor
    from public.profiles p
    where p.academia_id = p_academia_id
      and p.rol = 'alumno'
      and p.estado <> 'baja'
  ),
  ultima as (
    select a.alumno_id, max(a.fecha) as fecha
    from public.asistencias a
    where a.academia_id = p_academia_id
    group by a.alumno_id
  ),
  entrenos as (
    select a.id,
           (select count(*) from public.asistencias s
             where s.alumno_id = a.id and s.fecha >= a.fecha_inicio_cinturon) as asistencias
    from activos a
  )
  select jsonb_build_object(
    'sin_cuota', coalesce((
      select jsonb_agg(jsonb_build_object(
               'nombre', trim(a.nombre || ' ' || coalesce(a.apellidos, '')),
               'cinturon', a.cinturon,
               'alta', a.created_at::date
             ) order by a.nombre)
      from activos a
      where a.id not in (select alumno_id from public.agente_cuotas_al_dia(p_academia_id))
    ), '[]'::jsonb),
    'sin_venir', coalesce((
      select jsonb_agg(jsonb_build_object(
               'nombre', trim(a.nombre || ' ' || coalesce(a.apellidos, '')),
               'cinturon', a.cinturon,
               'ultima_vez', u.fecha::date,
               'dias_sin_venir', case when u.fecha is null then null
                                      else (current_date - u.fecha::date) end,
               'nunca_ha_venido', u.fecha is null
             ) order by u.fecha nulls first, a.nombre)
      from activos a
      left join ultima u on u.alumno_id = a.id
      where u.fecha is null
         or u.fecha < now() - make_interval(days => greatest(coalesce(p_dias_sin_venir, 21), 1))
    ), '[]'::jsonb),
    'listos_para_graduarse', coalesce((
      select jsonb_agg(jsonb_build_object(
               'nombre', trim(a.nombre || ' ' || coalesce(a.apellidos, '')),
               'cinturon', a.cinturon,
               'proximo_cinturon', public.agente_proximo_cinturon(a.cinturon, a.es_menor),
               'entrenos', e.asistencias,
               'entrenos_necesarios', case when a.es_menor then 78 else 312 end
             ) order by e.asistencias desc)
      from activos a
      join entrenos e on e.id = a.id
      where public.agente_proximo_cinturon(a.cinturon, a.es_menor) is not null
        and e.asistencias >= (case when a.es_menor then 78 else 312 end)
    ), '[]'::jsonb)
  );
$$;

create or replace function public.agente_horario(
  p_academia_id uuid,
  p_desde date,
  p_hasta date
)
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce(jsonb_agg(x order by x->>'empieza'), '[]'::jsonb)
  from (
    select jsonb_build_object(
             'titulo', c.titulo,
             'empieza', c.fecha_hora_inicio,
             'termina', c.fecha_hora_fin,
             'profesor', trim(pr.nombre || ' ' || coalesce(pr.apellidos, '')),
             'aforo', c.aforo_maximo,
             'apuntados', (select count(*) from public.inscripciones i
                            where i.clase_id = c.id and i.estado = 'inscrito'),
             'en_espera', (select count(*) from public.inscripciones i
                            where i.clase_id = c.id and i.estado = 'espera'),
             'plazas_libres', greatest(c.aforo_maximo
                              - (select count(*) from public.inscripciones i
                                  where i.clase_id = c.id and i.estado = 'inscrito'), 0),
             'cancelada', c.estado = 'cancelada'
           ) as x
    from public.clases c
    left join public.profiles pr on pr.id = c.profesor_id
    where c.academia_id = p_academia_id
      and c.fecha_hora_inicio >= p_desde::timestamptz
      and c.fecha_hora_inicio < (p_hasta + 1)::timestamptz
  ) s;
$$;

-- El correo de un alumno. Esta sí es `security definer`, y no por comodidad:
-- `service_role` **no tiene permiso de lectura sobre `auth.users`** en
-- producción (comprobado contra la base real; en un Postgres local de
-- pruebas sí lo parece, porque allí se corre como superusuario — de ahí que
-- esto haya que probarlo con `set local role service_role`).
--
-- Se queda lo más estrecha posible: devuelve un único correo, solo si ese
-- perfil es alumno de la academia que se le pasa, y solo `service_role`
-- puede llamarla. La prueba pgTAP comprueba que `authenticated` no.
create or replace function public.agente_correo_de(
  p_alumno_id uuid,
  p_academia_id uuid
)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select u.email
  from auth.users u
  join public.profiles p on p.id = u.id
  where u.id = p_alumno_id
    and p.academia_id = p_academia_id
    and p.rol = 'alumno';
$$;

-- La lista de alumnos. El correo solo sale si la clave lo tiene autorizado,
-- y solo existe para quien tiene cuenta propia (los hijos dados de alta por
-- un padre no tienen).
create or replace function public.agente_alumnos(
  p_academia_id uuid,
  p_incluir_contacto boolean default false,
  p_incluir_bajas boolean default false
)
returns jsonb
language sql
stable
set search_path = public, pg_temp
as $$
  select coalesce(jsonb_agg(x order by x->>'nombre'), '[]'::jsonb)
  from (
    select jsonb_strip_nulls(jsonb_build_object(
             'nombre', trim(p.nombre || ' ' || coalesce(p.apellidos, '')),
             'cinturon', p.cinturon,
             'estado', p.estado,
             'alta', p.created_at::date,
             'fecha_baja', p.fecha_baja::date,
             'es_menor', exists (select 1 from public.relaciones_familia rf
                                  where rf.child_id = p.id),
             'cuota_al_dia', p.id in (select alumno_id
                                        from public.agente_cuotas_al_dia(p_academia_id)),
             'correo', case when coalesce(p_incluir_contacto, false)
                            then public.agente_correo_de(p.id, p_academia_id)
                       end
           )) as x
    from public.profiles p
    where p.academia_id = p_academia_id
      and p.rol = 'alumno'
      and (coalesce(p_incluir_bajas, false) or p.estado <> 'baja')
  ) s;
$$;

-- Solo la Edge Function (service_role) puede llamarlas. Ni `anon` ni
-- `authenticated`: un alumno con sesión no debe poder pasar el uuid de otra
-- academia y leerla entera.
revoke all on function public.agente_cuotas_al_dia(uuid) from public, anon, authenticated;
revoke all on function public.agente_resumen(uuid, date, date) from public, anon, authenticated;
revoke all on function public.agente_avisos(uuid, integer) from public, anon, authenticated;
revoke all on function public.agente_proximo_cinturon(text, boolean) from public, anon, authenticated;
revoke all on function public.agente_horario(uuid, date, date) from public, anon, authenticated;
revoke all on function public.agente_alumnos(uuid, boolean, boolean) from public, anon, authenticated;
revoke all on function public.agente_correo_de(uuid, uuid) from public, anon, authenticated;

grant execute on function public.agente_cuotas_al_dia(uuid) to service_role;
grant execute on function public.agente_resumen(uuid, date, date) to service_role;
grant execute on function public.agente_avisos(uuid, integer) to service_role;
grant execute on function public.agente_proximo_cinturon(text, boolean) to service_role;
grant execute on function public.agente_horario(uuid, date, date) to service_role;
grant execute on function public.agente_alumnos(uuid, boolean, boolean) to service_role;
grant execute on function public.agente_correo_de(uuid, uuid) to service_role;
