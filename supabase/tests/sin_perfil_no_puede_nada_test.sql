-- Una cuenta con sesión pero SIN perfil no puede hacer nada (auditoría
-- externa del 09/10/2026, punto 1; ver 20261009090000_permisos_sin_perfil.sql).
--
-- Se consigue registrándose sin `nombre`. Con ella `current_rol()` es NULL,
-- y un `if NULL <> 'administrador' then raise` no lanza nada. Esta prueba
-- llama como esa cuenta a TODAS las funciones que la app puede invocar.
-- La primera aserción es el catálogo: si alguien añade una función nueva
-- llamable por usuarios con sesión, falla hasta que se añada aquí abajo
-- (una por línea, para que dos cambios a la vez no choquen). Las que
-- llegaron después de esta prueba comprueban la cuenta sin perfil en su
-- propia suite; el catálogo obliga a que nadie se olvide de hacerlo.
begin;
select plan(46);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000f0001', 'dueno-sp@test.dev'),
  ('00000000-0000-0000-0000-0000000f0002', 'alumno-sp@test.dev'),
  ('00000000-0000-0000-0000-0000000f0003', 'padre-sp@test.dev'),
  ('00000000-0000-0000-0000-0000000f0009', 'sin-perfil@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000f00aa', 'Academia SP', 'approved'),
  ('00000000-0000-0000-0000-0000000f00bb', 'Academia pendiente SP', 'pending'),
  ('00000000-0000-0000-0000-0000000f00cc', 'Academia destino SP', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000f0001', '00000000-0000-0000-0000-0000000f00aa', 'dueño', 'Dueño', 'activo'),
  ('00000000-0000-0000-0000-0000000f0002', '00000000-0000-0000-0000-0000000f00aa', 'alumno', 'Alumno', 'activo'),
  ('00000000-0000-0000-0000-0000000f0003', '00000000-0000-0000-0000-0000000f00aa', 'alumno', 'Padre', 'activo');

-- Un hijo del padre (sin cuenta) y una solicitud de cambio de escuela.
insert into public.profiles (id, academia_id, rol, nombre, estado)
  select '00000000-0000-0000-0000-0000000f0004', '00000000-0000-0000-0000-0000000f00aa', 'alumno', 'Hijo', 'activo';
insert into public.relaciones_familia (parent_id, child_id) values
  ('00000000-0000-0000-0000-0000000f0003', '00000000-0000-0000-0000-0000000f0004');
insert into public.solicitudes_cambio_escuela (id, alumno_id, academia_origen_id, academia_destino_id) values
  ('00000000-0000-0000-0000-0000000f0e01', '00000000-0000-0000-0000-0000000f0002',
   '00000000-0000-0000-0000-0000000f00aa', '00000000-0000-0000-0000-0000000f00cc');

insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-0000000f0c01', '00000000-0000-0000-0000-0000000f00aa', '00000000-0000-0000-0000-0000000f0001',
   'Futura', now() + interval '2 days', now() + interval '2 days 1 hour', 10),
  ('00000000-0000-0000-0000-0000000f0c02', '00000000-0000-0000-0000-0000000f00aa', '00000000-0000-0000-0000-0000000f0001',
   'Pasada', now() - interval '2 days', now() - interval '2 days' + interval '1 hour', 10);

insert into public.inscripciones (clase_id, alumno_id, estado) values
  ('00000000-0000-0000-0000-0000000f0c01', '00000000-0000-0000-0000-0000000f0002', 'inscrito');
insert into public.inscripciones (clase_id, alumno_id, estado, cancelacion_tardia) values
  ('00000000-0000-0000-0000-0000000f0c02', '00000000-0000-0000-0000-0000000f0002', 'cancelado', true);

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad) values
  ('00000000-0000-0000-0000-0000000f0d01', '00000000-0000-0000-0000-0000000f00aa', 'Mensual', 50, 'mensual');
insert into public.suscripciones (id, alumno_id, academia_id, tarifa_id, estado, payment_status, proveedor_pago, fecha_inicio, fecha_fin)
values ('00000000-0000-0000-0000-0000000f0e02', '00000000-0000-0000-0000-0000000f0002',
        '00000000-0000-0000-0000-0000000f00aa', '00000000-0000-0000-0000-0000000f0d01',
        'activa', 'active', 'efectivo', now() - interval '1 day', now() + interval '29 days');
-- El disparador de alta la deja en 'pendiente_pago'; se activa a mano.
update public.suscripciones set estado = 'activa', payment_status = 'active'
 where id = '00000000-0000-0000-0000-0000000f0e02';

-- ------------------------------------------------------------
-- 0. Catálogo: las funciones que puede llamar cualquiera con sesión
-- ------------------------------------------------------------
select is(
  array(
    select p.proname::text
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and has_function_privilege('authenticated', p.oid, 'execute')
       and p.prorettype <> 'trigger'::regtype
       and not exists (
         select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e'
       )
     order by 1
  ),
  array[
    'academia_id_de',
    'activar_cuota_efectivo',
    'aprobar_academia',
    'borrar_hijo',
    'cambiar_estado_clase',
    'cambiar_rol_miembro',
    'cancelar_clase',
    'cancelar_reserva',
    'clases_restantes',
    -- Sin perfil: horario_repetido_test.sql.
    'crear_clases',
    'crear_hijo',
    'current_academia_id',
    'current_rol',
    'dar_de_baja_alumno',
    'desactivar_cuota_efectivo',
    'editar_clase',
    'es_padre_de',
    'generar_mis_clases_recurrentes',
    'hijos_borrables',
    'listar_academias_aprobadas',
    'listar_clases_semana',
    'listar_mis_solicitudes_cambio',
    'listar_solicitudes_pendientes_destino',
    'mi_padre_id',
    'pausar_cuota_efectivo',
    'perdonar_cancelacion_tardia',
    'progreso_graduacion_alumnos',
    'promover_cinturon',
    'ranking_periodo',
    'reactivar_alumno',
    'reanudar_cuota_efectivo',
    'rechazar_academia',
    'registrar_device_token',
    'reservar_clase',
    'resolver_cambio_escuela',
    'ultima_asistencia_por_alumno'
  ]::text[],
  'Toda función llamable con sesión está cubierta por esta prueba'
);

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000f0009');

-- ------------------------------------------------------------
-- 1. Las que cambian algo: todas tienen que fallar
-- ------------------------------------------------------------
select throws_ok($$ select public.cancelar_reserva('00000000-0000-0000-0000-0000000f0c01', '00000000-0000-0000-0000-0000000f0002') $$,
  'Solo puedes cancelar por ti o por tus hijos.', 'No cancela la reserva de otro');
select throws_ok($$ select public.aprobar_academia('00000000-0000-0000-0000-0000000f00bb') $$,
  'Solo un administrador puede aprobar academias.', 'No aprueba academias');
select throws_ok($$ select public.rechazar_academia('00000000-0000-0000-0000-0000000f00bb') $$,
  'Solo un administrador puede rechazar academias.', 'No rechaza academias');
select throws_ok($$ select public.cambiar_estado_clase('00000000-0000-0000-0000-0000000f0c01', true) $$,
  null, 'No cierra clases');
select throws_ok($$ select public.cancelar_clase('00000000-0000-0000-0000-0000000f0c01') $$,
  null, 'No cancela clases');
select throws_ok($$ select public.editar_clase('00000000-0000-0000-0000-0000000f0c01', 'x', null, now() + interval '3 days', now() + interval '3 days 1 hour', 5) $$,
  null, 'No edita clases');
select throws_ok($$ select public.dar_de_baja_alumno('00000000-0000-0000-0000-0000000f0002') $$,
  null, 'No da de baja alumnos');
select throws_ok($$ select public.reactivar_alumno('00000000-0000-0000-0000-0000000f0002') $$,
  null, 'No reactiva alumnos');
select throws_ok($$ select public.cambiar_rol_miembro('00000000-0000-0000-0000-0000000f0002', 'profesor') $$,
  null, 'No cambia roles');
select throws_ok($$ select public.perdonar_cancelacion_tardia('00000000-0000-0000-0000-0000000f0c02', '00000000-0000-0000-0000-0000000f0002') $$,
  null, 'No perdona cancelaciones tardías');
select throws_ok($$ select public.promover_cinturon('00000000-0000-0000-0000-0000000f0002', 'azul') $$,
  null, 'No promueve cinturones');
select throws_ok($$ select public.reservar_clase('00000000-0000-0000-0000-0000000f0c01', '00000000-0000-0000-0000-0000000f0004') $$,
  null, 'No reserva por otro');
select throws_ok($$ select public.reservar_clase('00000000-0000-0000-0000-0000000f0c01') $$,
  null, 'No reserva para sí');
select throws_ok($$ select public.crear_hijo('Nuevo', 'Hijo', 'blanco') $$,
  null, 'No crea hijos');
select throws_ok($$ select public.borrar_hijo('00000000-0000-0000-0000-0000000f0004') $$,
  null, 'No borra hijos ajenos');
select throws_ok($$ select public.activar_cuota_efectivo('00000000-0000-0000-0000-0000000f0002', '00000000-0000-0000-0000-0000000f0d01', null, false, 50, 1) $$,
  null, 'No registra cobros');
select throws_ok($$ select public.desactivar_cuota_efectivo('00000000-0000-0000-0000-0000000f0e02') $$,
  null, 'No retira cuotas');
select throws_ok($$ select public.pausar_cuota_efectivo('00000000-0000-0000-0000-0000000f0e02', null) $$,
  null, 'No pausa cuotas');
select throws_ok($$ select public.reanudar_cuota_efectivo('00000000-0000-0000-0000-0000000f0e02') $$,
  null, 'No reanuda cuotas');
select throws_ok($$ select public.resolver_cambio_escuela('00000000-0000-0000-0000-0000000f0e01', true) $$,
  null, 'No resuelve cambios de escuela');
select throws_ok($$ select public.generar_mis_clases_recurrentes() $$,
  null, 'No genera clases');
select throws_ok($$ select public.clases_restantes('00000000-0000-0000-0000-0000000f0002') $$,
  null, 'No lee el saldo de otro');

-- ------------------------------------------------------------
-- 2. Las de lectura: no devuelven nada de la academia
-- ------------------------------------------------------------
select is((select count(*)::int from public.listar_clases_semana(now() - interval '7 days', now() + interval '7 days')), 0, 'No ve clases');
select is((select count(*)::int from public.ranking_periodo(current_date - 30, current_date + 30)), 0, 'No ve el ranking');
select is((select count(*)::int from public.progreso_graduacion_alumnos()), 0, 'No ve progresos');
select is((select count(*)::int from public.ultima_asistencia_por_alumno()), 0, 'No ve asistencias');
select is((select count(*)::int from public.listar_solicitudes_pendientes_destino()), 0, 'No ve solicitudes de otros');
select is((select count(*)::int from public.listar_mis_solicitudes_cambio()), 0, 'No tiene solicitudes propias');
select is((select count(*)::int from public.hijos_borrables()), 0, 'No tiene hijos');
select is(public.mi_padre_id(), null, 'No tiene tutor');
select is(public.academia_id_de('00000000-0000-0000-0000-0000000f0002'), null, 'No averigua la academia de otro');
select is(public.es_padre_de('00000000-0000-0000-0000-0000000f0004'), false, 'No es tutor de nadie');
select is(public.current_rol(), null, 'Sin rol');
select is(public.current_academia_id(), null, 'Sin academia');
select is((select count(*)::int from public.listar_academias_aprobadas()), 2,
  'listar_academias_aprobadas es pública (la usa el registro)');
select lives_ok($$ select public.registrar_device_token('token-sp', 'android') $$,
  'registrar_device_token solo guarda su propio dispositivo');

-- ------------------------------------------------------------
-- 3. Y de verdad no ha cambiado nada
-- ------------------------------------------------------------
reset role;
select is((select estado from public.inscripciones where clase_id = '00000000-0000-0000-0000-0000000f0c01' and alumno_id = '00000000-0000-0000-0000-0000000f0002'),
  'inscrito', 'La reserva ajena sigue en pie');
select is((select estado from public.academias where id = '00000000-0000-0000-0000-0000000f00bb'),
  'pending', 'La academia pendiente sigue pendiente');
select is((select estado from public.clases where id = '00000000-0000-0000-0000-0000000f0c01'),
  'activa', 'La clase sigue activa');
select is((select estado || '/' || rol from public.profiles where id = '00000000-0000-0000-0000-0000000f0002'),
  'activo/alumno', 'El alumno sigue activo y alumno');
select is((select cancelacion_tardia from public.inscripciones where clase_id = '00000000-0000-0000-0000-0000000f0c02'),
  true, 'La cancelación tardía sigue sin perdonar');
select is((select estado from public.suscripciones where id = '00000000-0000-0000-0000-0000000f0e02'),
  'activa', 'La cuota sigue activa');
select is((select count(*)::int from public.suscripciones where alumno_id = '00000000-0000-0000-0000-0000000f0002'),
  1, 'No se ha registrado ningún cobro');
select is((select estado from public.solicitudes_cambio_escuela where id = '00000000-0000-0000-0000-0000000f0e01'),
  'pendiente', 'La solicitud sigue pendiente');
select is((select count(*)::int from public.device_tokens where user_id = '00000000-0000-0000-0000-0000000f0009'),
  1, 'El único rastro es su propio dispositivo');

select * from finish();
rollback;
