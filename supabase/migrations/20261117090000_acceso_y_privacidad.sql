-- ITACA — Auditoría del 13/11/2026 y encargo de Cipri del 17/11/2026:
-- acceso y privacidad antes de meter a nadie.
--
-- Qué pasaba (comprobado en producción el 13/11):
-- - El registro está abierto y la cuenta nacía 'activo'. Cualquiera con el
--   enlace veía nombre, apellidos, foto y cinturón de todos los miembros,
--   quién es hijo de quién y quién va a cada clase.
-- - Un alumno dado de baja seguía viendo lo mismo.
-- - Un Profesor veía lo que ha pagado cada alumno, podía cambiar tarifas y
--   veía y borraba certificados médicos.
-- - Un alumno podía crear, llamando al servidor, un pedido de tienda
--   «pagado y entregado».
--
-- Qué queda (criterio de Cipri):
-- - La cuenta nueva nace 'pendiente_aprobacion'. El Dueño la aprueba o la
--   rechaza desde Miembros. El enlace de registro no concede acceso.
-- - Pendiente o de baja = como no tener perfil: ningún dato de otros.
-- - El alumno ve lo suyo; el tutor, lo de sus hijos; el Profesor, lo
--   necesario para dar clase y pasar lista; el Dueño, todo lo de la academia.
-- - Compañeros de clase y ranking siguen (decisiones del 18/08), pero por
--   funciones que solo dan nombre, foto y cinturón a alumnos activos.
-- - La tienda queda fuera de esta entrega: cerrada también en el servidor.
--
-- No lleva ningún `drop` (el conector de Supabase los para; ver
-- OPERATIONS.md): las políticas se cambian con `alter policy`.

-- ============================================================
-- 1. Quien no está activo no tiene rol ni academia
-- ============================================================
-- Todas las políticas y casi todas las funciones preguntan por
-- `current_rol()` y `current_academia_id()`. Si solo responden para un
-- perfil 'activo', una cuenta pendiente o de baja queda exactamente igual
-- que una cuenta sin perfil, que ya está cerrada y probada función a
-- función (20261009090000_permisos_sin_perfil.sql).

create or replace function public.current_rol()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select rol from public.profiles where id = auth.uid() and estado = 'activo';
$$;

create or replace function public.current_academia_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select academia_id from public.profiles where id = auth.uid() and estado = 'activo';
$$;

-- ============================================================
-- 2. El alta nace pendiente
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_flujo text := coalesce(v_meta->>'flujo', 'unirse');
  v_nombre text := nullif(trim(v_meta->>'nombre'), '');
  v_apellidos text := nullif(trim(v_meta->>'apellidos'), '');
  v_academia_id uuid;
begin
  -- Sin metadata de ITACA (p. ej. un usuario creado desde el dashboard de
  -- Supabase o el Administrador sembrado a mano): no se toca nada, su perfil
  -- se gestiona por otra vía.
  if v_nombre is null then
    return new;
  end if;

  if v_flujo = 'registro_academia' then
    raise exception
      'El alta de nuevas academias está desactivada: ITACA es la única '
      'academia operativa por ahora.';

  else
    v_academia_id := (v_meta->>'academia_id')::uuid;
    if v_academia_id is null then
      raise exception 'Falta la academia de destino.';
    end if;

    if not exists (
      select 1 from public.academias
      where id = v_academia_id and estado = 'approved'
    ) then
      raise exception 'La academia seleccionada no existe o no está aprobada.';
    end if;

    -- 17/11/2026: nace PENDIENTE. Registrarse no da acceso a nada hasta que
    -- el Dueño lo aprueba desde Miembros.
    insert into public.profiles (id, academia_id, rol, nombre, apellidos, estado)
    values (new.id, v_academia_id, 'alumno', v_nombre, v_apellidos, 'pendiente_aprobacion');
  end if;

  return new;
end;
$function$;

-- ============================================================
-- 3. Aprobar o rechazar un alta
-- ============================================================

create or replace function public.aprobar_miembro(p_miembro_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_academia uuid := public.current_academia_id();
  v_estado text;
begin
  if not coalesce(public.current_rol() = 'dueño', false) or v_academia is null then
    raise exception 'Solo el Dueño puede aprobar altas.';
  end if;

  select estado into v_estado
    from public.profiles
   where id = p_miembro_id and academia_id = v_academia
   for update;

  if not found then
    raise exception 'Esa persona no es de tu academia.';
  end if;

  if v_estado <> 'pendiente_aprobacion' then
    raise exception 'Esa alta ya no está pendiente.';
  end if;

  update public.profiles set estado = 'activo' where id = p_miembro_id;
end;
$function$;

revoke all on function public.aprobar_miembro(uuid) from public, anon;
grant execute on function public.aprobar_miembro(uuid) to authenticated;

-- Rechazar no borra: la cuenta queda de baja (sin acceso) y se puede
-- reactivar si fue un error.
create or replace function public.rechazar_miembro(p_miembro_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_academia uuid := public.current_academia_id();
  v_estado text;
begin
  if not coalesce(public.current_rol() = 'dueño', false) or v_academia is null then
    raise exception 'Solo el Dueño puede rechazar altas.';
  end if;

  select estado into v_estado
    from public.profiles
   where id = p_miembro_id and academia_id = v_academia
   for update;

  if not found then
    raise exception 'Esa persona no es de tu academia.';
  end if;

  if v_estado <> 'pendiente_aprobacion' then
    raise exception 'Esa alta ya no está pendiente.';
  end if;

  update public.profiles
     set estado = 'baja', fecha_baja = now()
   where id = p_miembro_id;
end;
$function$;

revoke all on function public.rechazar_miembro(uuid) from public, anon;
grant execute on function public.rechazar_miembro(uuid) to authenticated;

-- ============================================================
-- 4. Quién ve qué fila
-- ============================================================

-- Perfiles: el mío, los de mis hijos, y los del equipo (Profesor y Dueño)
-- de mi academia, que salen como profesor de la clase y autor de un aviso.
-- El listado completo, solo para el equipo.
alter policy profiles_select on public.profiles
  using (
    id = auth.uid()
    or public.es_padre_de(id)
    or (
      academia_id = public.current_academia_id()
      and (
        rol in ('profesor', 'dueño')
        or public.current_rol() in ('profesor', 'dueño')
      )
    )
    or public.current_rol() = 'administrador'
  );

-- Reservas y asistencias: las mías, las de mis hijos, y el equipo todas.
alter policy inscripciones_select on public.inscripciones
  using (
    alumno_id = auth.uid()
    or public.es_padre_de(alumno_id)
    or (
      academia_id = public.current_academia_id()
      and public.current_rol() in ('profesor', 'dueño')
    )
    or public.current_rol() = 'administrador'
  );

alter policy asistencias_select on public.asistencias
  using (
    alumno_id = auth.uid()
    or public.es_padre_de(alumno_id)
    or (
      academia_id = public.current_academia_id()
      and public.current_rol() in ('profesor', 'dueño')
    )
    or public.current_rol() = 'administrador'
  );

-- Familias: la mía (como tutor o como hijo) y el equipo las de su academia.
alter policy relaciones_familia_select on public.relaciones_familia
  using (
    parent_id = auth.uid()
    or child_id = auth.uid()
    or (
      public.current_rol() in ('profesor', 'dueño')
      and public.academia_id_de(parent_id) = public.current_academia_id()
    )
    or public.current_rol() = 'administrador'
  );

-- Cuotas (llevan importes): el alumno, su tutor y el Dueño. El Profesor no.
alter policy suscripciones_select on public.suscripciones
  using (
    alumno_id = auth.uid()
    or public.es_padre_de(alumno_id)
    or (
      academia_id = public.current_academia_id()
      and public.current_rol() = 'dueño'
    )
    or public.current_rol() = 'administrador'
  );

-- Tarifas: las ve todo miembro activo; las crea y cambia solo el Dueño.
alter policy tarifas_insert on public.tarifas
  with check (
    academia_id = public.current_academia_id()
    and public.current_rol() = 'dueño'
  );

alter policy tarifas_update on public.tarifas
  using (
    (academia_id = public.current_academia_id() and public.current_rol() = 'dueño')
    or public.current_rol() = 'administrador'
  )
  with check (
    (academia_id = public.current_academia_id() and public.current_rol() = 'dueño')
    or public.current_rol() = 'administrador'
  );

alter policy tarifas_delete on public.tarifas
  using (
    (academia_id = public.current_academia_id() and public.current_rol() = 'dueño')
    or public.current_rol() = 'administrador'
  );

-- Documentos (certificado médico = dato de salud): el alumno, su tutor y el
-- Dueño. El Profesor ni los ve ni los sube ni los borra.
alter policy documentos_alumno_select on public.documentos_alumno
  using (
    alumno_id = auth.uid()
    or public.es_padre_de(alumno_id)
    or (academia_id = public.current_academia_id() and public.current_rol() = 'dueño')
    or public.current_rol() = 'administrador'
  );

alter policy documentos_alumno_insert on public.documentos_alumno
  with check (
    subido_por = auth.uid()
    and (
      alumno_id = auth.uid()
      or public.es_padre_de(alumno_id)
      or (
        public.current_rol() = 'dueño'
        and public.academia_id_de(alumno_id) = public.current_academia_id()
      )
    )
  );

alter policy documentos_alumno_update on public.documentos_alumno
  using (
    alumno_id = auth.uid()
    or public.es_padre_de(alumno_id)
    or (academia_id = public.current_academia_id() and public.current_rol() = 'dueño')
  )
  with check (
    subido_por = auth.uid()
    and (
      alumno_id = auth.uid()
      or public.es_padre_de(alumno_id)
      or (
        public.current_rol() = 'dueño'
        and public.academia_id_de(alumno_id) = public.current_academia_id()
      )
    )
  );

alter policy documentos_alumno_delete on public.documentos_alumno
  using (
    (academia_id = public.current_academia_id() and public.current_rol() = 'dueño')
    or public.current_rol() = 'administrador'
  );

-- Y los ficheros en sí, con la misma regla.
alter policy documentos_alumnos_select on storage.objects
  using (
    bucket_id = 'documentos-alumnos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.es_padre_de(((storage.foldername(name))[1])::uuid)
      or (
        public.current_rol() = 'dueño'
        and public.academia_id_de(((storage.foldername(name))[1])::uuid) = public.current_academia_id()
      )
      or public.current_rol() = 'administrador'
    )
  );

alter policy documentos_alumnos_insert on storage.objects
  with check (
    bucket_id = 'documentos-alumnos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.es_padre_de(((storage.foldername(name))[1])::uuid)
      or (
        public.current_rol() = 'dueño'
        and public.academia_id_de(((storage.foldername(name))[1])::uuid) = public.current_academia_id()
      )
    )
  );

alter policy documentos_alumnos_update on storage.objects
  using (
    bucket_id = 'documentos-alumnos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.es_padre_de(((storage.foldername(name))[1])::uuid)
      or (
        public.current_rol() = 'dueño'
        and public.academia_id_de(((storage.foldername(name))[1])::uuid) = public.current_academia_id()
      )
    )
  );

alter policy documentos_alumnos_delete on storage.objects
  using (
    bucket_id = 'documentos-alumnos'
    and (
      (
        public.current_rol() = 'dueño'
        and public.academia_id_de(((storage.foldername(name))[1])::uuid) = public.current_academia_id()
      )
      or public.current_rol() = 'administrador'
    )
  );

-- ============================================================
-- 5. Lo que el alumno sí ve de los demás, por funciones acotadas
-- ============================================================

-- El calendario cuenta las plazas ocupadas de cada clase. Con las reservas
-- ya cerradas por fila, la cuenta la hace la función con sus privilegios,
-- y solo para un miembro activo de esa academia.
create or replace function public.listar_clases_semana(
  p_desde timestamptz,
  p_hasta timestamptz
)
returns table (
  id uuid,
  titulo text,
  descripcion text,
  fecha_hora_inicio timestamptz,
  fecha_hora_fin timestamptz,
  aforo_maximo integer,
  profesor_id uuid,
  profesor_nombre text,
  inscritos_count bigint,
  mi_estado text,
  estado text,
  pendientes_confirmar bigint,
  reservas_familia jsonb
)
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select
    c.id,
    c.titulo,
    c.descripcion,
    c.fecha_hora_inicio,
    c.fecha_hora_fin,
    c.aforo_maximo,
    c.profesor_id,
    p.nombre as profesor_nombre,
    (select count(*) from public.inscripciones i
       where i.clase_id = c.id and i.estado = 'inscrito') as inscritos_count,
    (select i.estado from public.inscripciones i
       where i.clase_id = c.id and i.alumno_id = auth.uid()
       order by i.created_at desc limit 1) as mi_estado,
    c.estado,
    (select count(*) from public.inscripciones i
       where i.clase_id = c.id
         and i.estado = 'inscrito'
         and not exists (
           select 1 from public.asistencias a
           where a.clase_id = c.id and a.alumno_id = i.alumno_id
         )) as pendientes_confirmar,
    coalesce(
      (select jsonb_agg(
                jsonb_build_object('alumno_id', i.alumno_id, 'estado', i.estado)
                order by i.alumno_id
              )
         from public.inscripciones i
         where i.clase_id = c.id
           and i.estado in ('inscrito', 'espera')
           and i.alumno_id in (
             select rf.child_id from public.relaciones_familia rf
             where rf.parent_id = auth.uid()
           )),
      '[]'::jsonb
    ) as reservas_familia
  from public.clases c
  join public.profiles p on p.id = c.profesor_id
  -- Sin perfil activo `current_academia_id()` es NULL y no sale ninguna.
  where c.academia_id = public.current_academia_id()
    and c.fecha_hora_inicio >= p_desde and c.fecha_hora_inicio < p_hasta
  order by c.fecha_hora_inicio;
$function$;

revoke all on function public.listar_clases_semana(timestamptz, timestamptz) from public, anon;
grant execute on function public.listar_clases_semana(timestamptz, timestamptz) to authenticated;

-- Ranking: igual que antes (nombre, foto, cinturón y número de clases), ya
-- sin depender de que el alumno pueda leer la tabla de perfiles.
create or replace function public.ranking_periodo(
  p_desde date default null,
  p_hasta date default null
)
returns table (
  alumno_id uuid,
  nombre text,
  apellidos text,
  foto_url text,
  cinturon text,
  asistencias_count bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
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
  where p.rol = 'alumno'
    and p.estado = 'activo'
    and p.academia_id = public.current_academia_id()
  group by p.id, p.nombre, p.apellidos, p.foto_url, p.cinturon
  order by asistencias_count desc, p.nombre asc;
$function$;

revoke all on function public.ranking_periodo(date, date) from public, anon;
grant execute on function public.ranking_periodo(date, date) to authenticated;

-- Compañeros de clase (decisión del 18/08/2026): quién tiene plaza, con
-- nombre, foto y cinturón. Nada de cuotas ni de lista de espera.
create or replace function public.companeros_de_clase(p_clase_id uuid)
returns table (
  alumno_id uuid,
  nombre text,
  apellidos text,
  foto_url text,
  cinturon text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select p.id, p.nombre, p.apellidos, p.foto_url, p.cinturon
    from public.inscripciones i
    join public.clases c on c.id = i.clase_id
    join public.profiles p on p.id = i.alumno_id
   where i.clase_id = p_clase_id
     and i.estado = 'inscrito'
     and c.academia_id = public.current_academia_id()
   order by i.created_at;
$function$;

revoke all on function public.companeros_de_clase(uuid) from public, anon;
grant execute on function public.companeros_de_clase(uuid) to authenticated;

-- Miembros marca quién no tiene cuota. El Profesor ya no lee las cuotas
-- (llevan importes): recibe solo la lista de quién tiene una en vigor.
create or replace function public.alumnos_con_cuota_vigente()
returns setof uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select distinct s.alumno_id
    from public.suscripciones s
   where s.academia_id = public.current_academia_id()
     and coalesce(public.current_rol() in ('profesor', 'dueño'), false)
     and s.estado in ('activa', 'prueba', 'programada')
     and s.payment_status = 'active'
     and s.fecha_inicio <= now()
     and (s.fecha_fin is null or s.fecha_fin > now());
$function$;

revoke all on function public.alumnos_con_cuota_vigente() from public, anon;
grant execute on function public.alumnos_con_cuota_vigente() to authenticated;

-- Los avisos de una novedad, solo a alumnos activos: una cuenta pendiente
-- o de baja no recibe nada de la academia.
create or replace function public.encolar_push_nueva_novedad()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  insert into public.notificaciones_outbox (user_id, titulo, cuerpo, data)
  select distinct d.destinatario,
         'Nueva novedad',
         new.titulo,
         jsonb_build_object('tipo', 'novedad', 'novedad_id', new.id::text)
  from (
    select public.destinatario_notificacion(p.id) as destinatario
    from public.profiles p
    where p.academia_id = new.academia_id
      and p.rol = 'alumno'
      and p.estado = 'activo'
      and p.id <> new.autor_id
  ) d
  where d.destinatario is not null;
  return new;
end;
$function$;

revoke execute on function public.encolar_push_nueva_novedad() from public, anon, authenticated;

-- ============================================================
-- 6. Tienda: fuera de esta entrega, cerrada también en el servidor
-- ============================================================
-- No se borra nada: se quitan los permisos de escritura. Para volver a
-- abrirla hay que concederlos otra vez, a propósito.

revoke insert, update, delete on public.productos from authenticated;
revoke insert, update, delete on public.pedidos from authenticated;
revoke insert, update, delete on public.prestamos from authenticated;

-- Y el agujero en sí, por si un día se reabre: el pedido nace siempre
-- «pendiente de pago». Antes un alumno podía insertarlo ya como pagado y
-- entregado (comprobado en producción el 13/11/2026).
create or replace function public.set_pedido_defaults()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $function$
declare
  v_academia_id uuid;
  v_precio numeric(10, 2);
begin
  select academia_id, precio into v_academia_id, v_precio
    from public.productos where id = new.producto_id;
  new.academia_id := v_academia_id;
  new.precio_snapshot := v_precio;
  if current_user in ('authenticated', 'anon') then
    new.estado := 'pendiente_pago';
    new.payment_status := 'pending';
    new.stripe_payment_intent_id := null;
  end if;
  return new;
end;
$function$;

-- ============================================================
-- 7. Sin sesión no se toca ninguna tabla
-- ============================================================
-- `anon` tenía los permisos de tabla por defecto de Supabase y solo le
-- paraban las políticas. Sin sesión la app solo necesita la lista de
-- academias del registro, que es una función.

revoke all on all tables in schema public from anon;
