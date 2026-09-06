-- Dar de baja a un hijo, solo mientras no haya empezado (06/09/2026).
--
-- Lo que de verdad puede salir mal aquí no es que el borrado no funcione:
-- es que funcione **de más**. Un padre borrando a un niño que ya entrena se
-- lleva por delante el registro de una cuota cobrada en mano, y eso Cipri
-- no lo ve venir hasta que le cuadran mal las cuentas del mes.
--
-- Así que se prueba sobre todo lo que NO debe poder hacerse: borrar al hijo
-- de otro, borrar a alguien que ya tiene clase, asistencia, cuota, pedido o
-- préstamo, y borrar a una persona con cuenta propia.

begin;
select plan(18);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000a001', 'padre-baja@test.dev'),
  ('00000000-0000-0000-0000-00000000a002', 'otro-padre-baja@test.dev'),
  ('00000000-0000-0000-0000-00000000a003', 'duena-baja@test.dev'),
  ('00000000-0000-0000-0000-00000000a004', 'hijo-con-cuenta@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-00000000a0ff', 'Academia Bajas', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-00000000a003',
   '00000000-0000-0000-0000-00000000a0ff', 'dueño', 'Dueña', 'activo'),
  ('00000000-0000-0000-0000-00000000a001',
   '00000000-0000-0000-0000-00000000a0ff', 'alumno', 'Padre', 'activo'),
  ('00000000-0000-0000-0000-00000000a002',
   '00000000-0000-0000-0000-00000000a0ff', 'alumno', 'OtroPadre', 'activo');

-- Seis menores: uno limpio y cinco con un rastro distinto cada uno. Y un
-- séptimo «hijo» que en realidad tiene cuenta propia.
insert into public.profiles (
  id, academia_id, rol, nombre, estado, tiene_cuenta
) values
  ('00000000-0000-0000-0000-00000000b001',
   '00000000-0000-0000-0000-00000000a0ff', 'alumno', 'Limpio', 'activo', false),
  ('00000000-0000-0000-0000-00000000b002',
   '00000000-0000-0000-0000-00000000a0ff', 'alumno', 'ConClase', 'activo', false),
  ('00000000-0000-0000-0000-00000000b003',
   '00000000-0000-0000-0000-00000000a0ff', 'alumno', 'ConAsistencia', 'activo', false),
  ('00000000-0000-0000-0000-00000000b004',
   '00000000-0000-0000-0000-00000000a0ff', 'alumno', 'ConCuota', 'activo', false),
  ('00000000-0000-0000-0000-00000000b005',
   '00000000-0000-0000-0000-00000000a0ff', 'alumno', 'ConPrestamo', 'activo', false),
  ('00000000-0000-0000-0000-00000000b006',
   '00000000-0000-0000-0000-00000000a0ff', 'alumno', 'DeOtro', 'activo', false),
  ('00000000-0000-0000-0000-00000000a004',
   '00000000-0000-0000-0000-00000000a0ff', 'alumno', 'ConCuenta', 'activo', true);

insert into public.relaciones_familia (parent_id, child_id) values
  ('00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000b001'),
  ('00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000b002'),
  ('00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000b003'),
  ('00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000b004'),
  ('00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000b005'),
  ('00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000a004'),
  ('00000000-0000-0000-0000-00000000a002', '00000000-0000-0000-0000-00000000b006');

insert into public.clases (
  id, academia_id, profesor_id, titulo,
  fecha_hora_inicio, fecha_hora_fin, aforo_maximo
) values (
  '00000000-0000-0000-0000-00000000c001',
  '00000000-0000-0000-0000-00000000a0ff',
  '00000000-0000-0000-0000-00000000a003',
  'Infantil', now() + interval '1 day', now() + interval '1 day 1 hour', 20
);

insert into public.inscripciones (clase_id, alumno_id, academia_id, estado) values
  ('00000000-0000-0000-0000-00000000c001',
   '00000000-0000-0000-0000-00000000b002',
   '00000000-0000-0000-0000-00000000a0ff', 'inscrito');

insert into public.asistencias (clase_id, alumno_id, validado_por) values
  ('00000000-0000-0000-0000-00000000c001',
   '00000000-0000-0000-0000-00000000b003',
   '00000000-0000-0000-0000-00000000a003');

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad) values
  ('00000000-0000-0000-0000-00000000d001',
   '00000000-0000-0000-0000-00000000a0ff', 'Mensual', 45, 'mensual');

insert into public.suscripciones (alumno_id, academia_id, tarifa_id, estado, fecha_inicio)
values
  ('00000000-0000-0000-0000-00000000b004',
   '00000000-0000-0000-0000-00000000a0ff',
   '00000000-0000-0000-0000-00000000d001', 'activa', now());

-- `prestamos` exige producto o descripción, uno de los dos.
insert into public.prestamos (alumno_id, academia_id, gestionado_por, descripcion)
values
  ('00000000-0000-0000-0000-00000000b005',
   '00000000-0000-0000-0000-00000000a0ff',
   '00000000-0000-0000-0000-00000000a003',
   'Kimono prestado');

-- ============================================================
-- Qué ve el padre que puede borrar
-- ============================================================

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-00000000a001","role":"authenticated"}', true);

select is(
  (select count(*)::int from public.hijos_borrables()),
  1,
  'De seis hijos, solo se puede borrar al que no ha empezado'
);

select is(
  (select h from public.hijos_borrables() h),
  '00000000-0000-0000-0000-00000000b001'::uuid,
  'Y ese es justo el que no tiene nada'
);

-- ============================================================
-- Lo que NO se puede hacer
-- ============================================================

select throws_ok(
  $$select public.borrar_hijo('00000000-0000-0000-0000-00000000b006')$$,
  'Solo puedes dar de baja a tus propios hijos.',
  'Un padre no puede borrar al hijo de otra familia'
);

select throws_like(
  $$select public.borrar_hijo('00000000-0000-0000-0000-00000000b002')$$,
  '%ya ha empezado%',
  'Con una clase reservada, ya no lo borra el padre'
);

select throws_like(
  $$select public.borrar_hijo('00000000-0000-0000-0000-00000000b003')$$,
  '%ya ha empezado%',
  'Con una asistencia, tampoco'
);

select throws_like(
  $$select public.borrar_hijo('00000000-0000-0000-0000-00000000b005')$$,
  '%ya ha empezado%',
  'Con un préstamo de material, tampoco'
);

-- La cuota lleva su propio mensaje a propósito: es el caso más frecuente y
-- el que peor se entiende mezclado con «ya ha empezado».
select throws_like(
  $$select public.borrar_hijo('00000000-0000-0000-0000-00000000b004')$$,
  '%cuota registrada%',
  'Con una cuota cobrada, el mensaje habla de la cuota'
);

select throws_like(
  $$select public.borrar_hijo('00000000-0000-0000-0000-00000000a004')$$,
  '%su propia cuenta%',
  'A quien entra con su propia cuenta no lo borra nadie desde aquí'
);

-- ============================================================
-- Lo que sí se puede
-- ============================================================

select lives_ok(
  $$select public.borrar_hijo('00000000-0000-0000-0000-00000000b001')$$,
  'Un alta recién hecha se puede deshacer'
);

reset role;

-- Y lo importante de verdad: nada de lo anterior ha borrado a nadie.
--
-- Estas dos comprobaciones van con permisos de servidor a propósito. Con la
-- sesión del padre, la primera versión de esta prueba leía **cero** cuotas y
-- parecía que el borrado se las había llevado: era la RLS de `suscripciones`
-- ocultándoselas al padre, que es exactamente lo que debe hacer. Leyéndolas
-- así se comprueba lo que hay en la tabla, no lo que el padre alcanza a ver.
select is(
  (select count(*)::int from public.profiles
   where id in ('00000000-0000-0000-0000-00000000b002',
                '00000000-0000-0000-0000-00000000b003',
                '00000000-0000-0000-0000-00000000b004',
                '00000000-0000-0000-0000-00000000b005',
                '00000000-0000-0000-0000-00000000b006',
                '00000000-0000-0000-0000-00000000a004')),
  6,
  'Tras seis intentos rechazados, siguen existiendo los seis'
);

select is(
  (select count(*)::int from public.suscripciones
   where alumno_id = '00000000-0000-0000-0000-00000000b004'),
  1,
  'Y la cuota cobrada en mano sigue ahí — que es lo que de verdad importa'
);

select is(
  (select count(*)::int from public.profiles
   where id = '00000000-0000-0000-0000-00000000b001'),
  0,
  'El perfil del niño desaparece'
);

select is(
  (select count(*)::int from public.relaciones_familia
   where child_id = '00000000-0000-0000-0000-00000000b001'),
  0,
  'Y la relación de familia se va sola: es la única clave foránea en cascada'
);

select is(
  (select count(*)::int from public.profiles
   where id = '00000000-0000-0000-0000-00000000a001'),
  1,
  'Borrar al hijo no se lleva por delante al padre'
);

-- ============================================================
-- Permisos
-- ============================================================

select is(
  has_function_privilege('anon', 'public.borrar_hijo(uuid)', 'execute'),
  false,
  'Sin sesión no se puede borrar a nadie'
);

select is(
  has_function_privilege('authenticated', 'public.borrar_hijo(uuid)', 'execute'),
  true,
  'Con sesión sí — el filtro de quién es quién está dentro de la función'
);

select is(
  has_function_privilege('anon', 'public.hijos_borrables()', 'execute'),
  false,
  'Sin sesión tampoco se puede preguntar qué hijos hay'
);

-- Las dos son security definer: sin `search_path` fijado, cualquiera con
-- permiso para crear una tabla en otro esquema podría colar la suya. Es el
-- fallo que se coló el 03/09 y no cazó ninguna prueba.
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('borrar_hijo', 'hijos_borrables')
      and (p.proconfig is null
           or not exists (
             select 1 from unnest(p.proconfig) c where c like 'search_path=%'
           ))),
  0,
  'Las dos funciones nuevas fijan su search_path'
);

select * from finish();
rollback;
