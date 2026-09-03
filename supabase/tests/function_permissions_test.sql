-- Regresiones de permisos de funciones expuestas por PostgREST.
begin;
select plan(16);

-- 1-2. El alta puede listar academias; el resto de RPC no queda abierto.
select ok(
  has_function_privilege(
    'anon',
    'public.listar_academias_aprobadas()',
    'EXECUTE'
  ),
  'Anon puede listar únicamente las academias aprobadas para registrarse'
);

select is(
  (
    select count(*)::int
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and has_function_privilege('anon', p.oid, 'EXECUTE')
      and p.oid <> 'public.listar_academias_aprobadas()'::regprocedure
  ),
  0,
  'Anon no puede ejecutar ninguna otra función de public'
);

-- 3-4. Las funciones de trigger no son endpoints RPC.
select is(
  (
    select count(*)::int
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and exists (
        select 1
        from pg_trigger t
        where t.tgfoid = p.oid
          and not t.tgisinternal
      )
      and has_function_privilege('anon', p.oid, 'EXECUTE')
  ),
  0,
  'Anon no puede invocar funciones internas de trigger'
);

select is(
  (
    select count(*)::int
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and exists (
        select 1
        from pg_trigger t
        where t.tgfoid = p.oid
          and not t.tgisinternal
      )
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  ),
  0,
  'Authenticated no puede invocar funciones internas de trigger'
);

-- 5-7. Se mantienen las RPC necesarias y se cierran las administrativas.
select ok(
  has_function_privilege(
    'authenticated',
    'public.reservar_clase(uuid,uuid)',
    'EXECUTE'
  ),
  'Authenticated conserva la RPC de reserva'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.registrar_device_token(text,text)',
    'EXECUTE'
  ),
  'Authenticated conserva el registro de su token push'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.generar_clases_recurrentes(date,date)',
    'EXECUTE'
  ),
  'La generación global de clases queda reservada al backend'
);

-- 8. service_role conserva acceso para Edge Functions y operaciones internas.
select ok(
  has_function_privilege(
    'service_role',
    'public.generar_clases_recurrentes(date,date)',
    'EXECUTE'
  ),
  'service_role conserva acceso a las funciones internas'
);

-- 9. Todas las funciones detectadas por el advisor tienen search_path fijo.
select is(
  (
    select count(*)::int
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'check_suscripcion_estado_transicion',
        'listar_clases_semana',
        'ranking_periodo',
        'set_academia_id_desde_clase',
        'set_pedido_defaults',
        'set_prestamo_academia',
        'set_solicitud_origen',
        'set_suscripcion_academia',
        'set_suscripcion_defaults'
      )
      and not coalesce(p.proconfig, '{}'::text[])
        && array['search_path=public, pg_temp']
  ),
  0,
  'Todas las funciones auditadas fijan search_path'
);

-- 10-12. Storage permite gestionar el avatar propio, no listar el bucket.
select ok(
  not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'avatars_select'
  ),
  'La política de listado público de avatares fue eliminada'
);

select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'avatars_select_own'
      and roles = array['authenticated'::name]
  ),
  'Existe lectura autenticada limitada al directorio propio'
);

-- El módulo de técnicas se eliminó de raíz (ver
-- 20260729090000_eliminar_arbol_progreso.sql): su función de siembra ya no
-- debe existir en la base de datos.
select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'sembrar_tecnicas_default'
  ),
  'La función de siembra de técnicas ya no existe'
);

-- 13-14. El bucket de avatares tiene un tope de tamaño y de tipo de
-- archivo (ver 20260813130136_limitar_avatares.sql): antes, cualquier
-- autenticado podía subir un archivo de cualquier tamaño o tipo a su propia
-- carpeta, servido después desde la URL pública del bucket.
select is(
  (select file_size_limit from storage.buckets where id = 'avatars'),
  5242880::bigint,
  'El bucket avatars tiene un límite de tamaño de 5 MiB'
);

select is(
  (select allowed_mime_types from storage.buckets where id = 'avatars'),
  array['image/jpeg', 'image/png', 'image/webp'],
  'El bucket avatars solo admite jpeg, png y webp'
);

-- 15-16. `ranking_mensual` se sustituyó por `ranking_periodo` (ver
-- 20260818073509_ranking_periodo.sql): la vieja no debe seguir viva como
-- RPC huérfana, y la nueva debe estar donde antes estaba la vieja.
select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'ranking_mensual'
  ),
  'ranking_mensual ya no existe: la sustituye ranking_periodo'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.ranking_periodo(date,date)',
    'EXECUTE'
  ),
  'Authenticated puede pedir el ranking por periodo'
);

select * from finish();
rollback;
