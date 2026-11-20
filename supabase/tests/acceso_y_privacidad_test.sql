-- Acceso y privacidad (17/11/2026). Ver 20261117090000_acceso_y_privacidad.sql.
--
-- Todo se comprueba desde el servidor, con la sesión de cada persona: una
-- cuenta pendiente o de baja no ve nada de otros; el alumno ve lo suyo; el
-- tutor, lo de sus hijos; el Profesor, lo de dar clase pero no importes,
-- tarifas ni certificados; el Dueño, todo lo de su academia.

begin;
select plan(55);

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000a00aa', 'Academia AP', 'approved');

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000a0001', 'dueno-ap@test.dev'),
  ('00000000-0000-0000-0000-0000000a0002', 'profe-ap@test.dev'),
  ('00000000-0000-0000-0000-0000000a0003', 'alumno1-ap@test.dev'),
  ('00000000-0000-0000-0000-0000000a0004', 'alumno2-ap@test.dev'),
  ('00000000-0000-0000-0000-0000000a0005', 'tutor-ap@test.dev'),
  ('00000000-0000-0000-0000-0000000a0007', 'baja-ap@test.dev');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000a0001', '00000000-0000-0000-0000-0000000a00aa', 'dueño', 'Dueño', 'activo'),
  ('00000000-0000-0000-0000-0000000a0002', '00000000-0000-0000-0000-0000000a00aa', 'profesor', 'Profe', 'activo'),
  ('00000000-0000-0000-0000-0000000a0003', '00000000-0000-0000-0000-0000000a00aa', 'alumno', 'Alumno Uno', 'activo'),
  ('00000000-0000-0000-0000-0000000a0004', '00000000-0000-0000-0000-0000000a00aa', 'alumno', 'Alumno Dos', 'activo'),
  ('00000000-0000-0000-0000-0000000a0005', '00000000-0000-0000-0000-0000000a00aa', 'alumno', 'Tutor', 'activo'),
  ('00000000-0000-0000-0000-0000000a0006', '00000000-0000-0000-0000-0000000a00aa', 'alumno', 'Hijo', 'activo'),
  ('00000000-0000-0000-0000-0000000a0007', '00000000-0000-0000-0000-0000000a00aa', 'alumno', 'De Baja', 'baja');

-- El hijo es un menor sin cuenta.
update public.profiles set tiene_cuenta = false
 where id = '00000000-0000-0000-0000-0000000a0006';
insert into public.relaciones_familia (parent_id, child_id) values
  ('00000000-0000-0000-0000-0000000a0005', '00000000-0000-0000-0000-0000000a0006');

-- Dos altas por el registro de verdad (disparador `handle_new_user`).
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000a0008', 'nueva-ap@test.dev', now(),
   jsonb_build_object('flujo', 'unirse', 'nombre', 'Nueva', 'apellidos', 'Alta',
                      'academia_id', '00000000-0000-0000-0000-0000000a00aa')),
  ('00000000-0000-0000-0000-0000000a0009', 'rechazada-ap@test.dev', now(),
   jsonb_build_object('flujo', 'unirse', 'nombre', 'Otra', 'apellidos', 'Alta',
                      'academia_id', '00000000-0000-0000-0000-0000000a00aa'));

insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-0000000a0c01', '00000000-0000-0000-0000-0000000a00aa', '00000000-0000-0000-0000-0000000a0002',
   'Futura', now() + interval '2 days', now() + interval '2 days 1 hour', 10),
  ('00000000-0000-0000-0000-0000000a0c02', '00000000-0000-0000-0000-0000000a00aa', '00000000-0000-0000-0000-0000000a0002',
   'Pasada', now() - interval '2 days', now() - interval '2 days' + interval '1 hour', 10);

insert into public.inscripciones (clase_id, alumno_id, estado) values
  ('00000000-0000-0000-0000-0000000a0c01', '00000000-0000-0000-0000-0000000a0003', 'inscrito'),
  ('00000000-0000-0000-0000-0000000a0c01', '00000000-0000-0000-0000-0000000a0004', 'inscrito'),
  ('00000000-0000-0000-0000-0000000a0c01', '00000000-0000-0000-0000-0000000a0006', 'inscrito'),
  ('00000000-0000-0000-0000-0000000a0c02', '00000000-0000-0000-0000-0000000a0004', 'inscrito');
insert into public.asistencias (clase_id, alumno_id, validado_por) values
  ('00000000-0000-0000-0000-0000000a0c02', '00000000-0000-0000-0000-0000000a0004', '00000000-0000-0000-0000-0000000a0002');

insert into public.novedades (academia_id, autor_id, titulo, contenido) values
  ('00000000-0000-0000-0000-0000000a00aa', '00000000-0000-0000-0000-0000000a0001', 'Aviso', 'Texto');

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad) values
  ('00000000-0000-0000-0000-0000000a0d01', '00000000-0000-0000-0000-0000000a00aa', 'Mensual', 50, 'mensual');
insert into public.suscripciones (id, alumno_id, academia_id, tarifa_id, proveedor_pago)
values ('00000000-0000-0000-0000-0000000a0e01', '00000000-0000-0000-0000-0000000a0004',
        '00000000-0000-0000-0000-0000000a00aa', '00000000-0000-0000-0000-0000000a0d01', 'efectivo');
update public.suscripciones
   set estado = 'activa', payment_status = 'active', importe_cobrado = 50,
       fecha_inicio = now() - interval '1 day', fecha_fin = now() + interval '29 days'
 where id = '00000000-0000-0000-0000-0000000a0e01';

insert into public.productos (id, academia_id, nombre, precio, stock) values
  ('00000000-0000-0000-0000-0000000a0f01', '00000000-0000-0000-0000-0000000a00aa', 'Kimono', 90, 2);

insert into public.documentos_alumno (alumno_id, tipo, storage_path, subido_por) values
  ('00000000-0000-0000-0000-0000000a0004', 'certificado_medico',
   '00000000-0000-0000-0000-0000000a0004/certificado_medico.pdf', '00000000-0000-0000-0000-0000000a0004');
insert into storage.objects (bucket_id, name, owner) values
  ('documentos-alumnos', '00000000-0000-0000-0000-0000000a0004/certificado_medico.pdf',
   '00000000-0000-0000-0000-0000000a0004');

create or replace function pg_temp.actuar_como(p_uid uuid)
returns void
language plpgsql
as $function$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text,
    true
  );
  perform set_config('role', 'authenticated', true);
end;
$function$;

-- ------------------------------------------------------------
-- 1. El registro no da acceso
-- ------------------------------------------------------------
select is(
  (select estado from public.profiles where id = '00000000-0000-0000-0000-0000000a0008'),
  'pendiente_aprobacion',
  'La cuenta nueva nace pendiente de aprobación'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000a0008');

select is((select count(*)::int from public.profiles), 1, 'Pendiente: solo ve su propio perfil');
select is((select count(*)::int from public.inscripciones), 0, 'Pendiente: no ve quién va a ninguna clase');
select is((select count(*)::int from public.asistencias), 0, 'Pendiente: no ve asistencias');
select is((select count(*)::int from public.relaciones_familia), 0, 'Pendiente: no ve familias');
select is((select count(*)::int from public.clases), 0, 'Pendiente: no ve el calendario');
select is((select count(*)::int from public.novedades), 0, 'Pendiente: no ve los avisos');
select is((select count(*)::int from public.suscripciones), 0, 'Pendiente: no ve cuotas');
select is(
  (select count(*)::int from public.listar_clases_semana(now() - interval '7 days', now() + interval '7 days')),
  0, 'Pendiente: el calendario de la app le sale vacío'
);
select is((select count(*)::int from public.ranking_periodo()), 0, 'Pendiente: no ve el ranking');
select is(
  (select count(*)::int from public.companeros_de_clase('00000000-0000-0000-0000-0000000a0c01')),
  0, 'Pendiente: no ve los compañeros de una clase'
);
select throws_ok(
  $$ select public.reservar_clase('00000000-0000-0000-0000-0000000a0c01') $$,
  'Tu cuenta no está activa.',
  'Pendiente: no puede reservar'
);
select throws_ok(
  $$ select public.crear_hijo('Niño', 'Pendiente') $$,
  'Tu cuenta no está activa.',
  'Pendiente: no puede dar de alta hijos'
);

reset role;
select is(
  (select count(*)::int from public.notificaciones_outbox
    where user_id in ('00000000-0000-0000-0000-0000000a0008', '00000000-0000-0000-0000-0000000a0007')),
  0, 'Ni la cuenta pendiente ni la de baja reciben el aviso de una novedad'
);

-- ------------------------------------------------------------
-- 2. De baja: igual
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000a0007');

select is((select count(*)::int from public.profiles), 1, 'De baja: solo ve su propio perfil');
select is((select count(*)::int from public.inscripciones), 0, 'De baja: no ve reservas de nadie');
select is((select count(*)::int from public.clases), 0, 'De baja: no ve el calendario');
select is((select count(*)::int from public.ranking_periodo()), 0, 'De baja: no ve el ranking');
select is(
  (select count(*)::int from public.companeros_de_clase('00000000-0000-0000-0000-0000000a0c01')),
  0, 'De baja: no ve los compañeros de una clase'
);

-- ------------------------------------------------------------
-- 3. Alumno activo: lo suyo
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000a0003');

select is(
  (select count(*)::int from public.profiles),
  3, 'Alumno: ve su perfil y los del equipo (Dueño y Profesor), no los de otros alumnos'
);
select is((select count(*)::int from public.inscripciones), 1, 'Alumno: solo ve sus propias reservas');
select is((select count(*)::int from public.asistencias), 0, 'Alumno: no ve las asistencias de otros');
select is((select count(*)::int from public.relaciones_familia), 0, 'Alumno: no ve quién es hijo de quién');
select is((select count(*)::int from public.suscripciones), 0, 'Alumno: no ve la cuota de otro');
select is((select count(*)::int from public.documentos_alumno), 0, 'Alumno: no ve el certificado de otro');
select is(
  (select count(*)::int from public.companeros_de_clase('00000000-0000-0000-0000-0000000a0c01')),
  3, 'Alumno: sí ve quién tiene plaza en la clase (nombre, foto y cinturón)'
);
select is(
  (select inscritos_count::int from public.listar_clases_semana(now(), now() + interval '7 days')),
  3, 'Alumno: el calendario le cuenta bien las plazas ocupadas'
);
select is(
  (select count(*)::int from public.ranking_periodo()),
  4, 'Alumno: el ranking solo lleva alumnos activos (ni pendientes ni bajas)'
);
select is((select count(*)::int from public.clases), 2, 'Alumno: ve las clases de su academia');
select is((select count(*)::int from public.novedades), 1, 'Alumno: ve los avisos');
select is(
  (select count(*)::int from public.alumnos_con_cuota_vigente()),
  0, 'Alumno: no recibe la lista de quién tiene cuota'
);
select throws_ok(
  $$ select public.aprobar_miembro('00000000-0000-0000-0000-0000000a0008') $$,
  'Solo el Dueño puede aprobar altas.',
  'Alumno: no aprueba altas'
);

-- ------------------------------------------------------------
-- 4. Tutor: lo de su hijo
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000a0005');

select ok(
  exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-0000000a0006'),
  'Tutor: ve el perfil de su hijo'
);
select is((select count(*)::int from public.inscripciones), 1, 'Tutor: ve la reserva de su hijo y ninguna más');
select is((select count(*)::int from public.relaciones_familia), 1, 'Tutor: ve su propia familia');

-- ------------------------------------------------------------
-- 5. Profesor: lo de dar clase
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000a0002');

select is((select count(*)::int from public.profiles), 9, 'Profesor: ve a los miembros de su academia');
select is((select count(*)::int from public.inscripciones), 4, 'Profesor: ve las reservas, para pasar lista');
select is((select count(*)::int from public.suscripciones), 0, 'Profesor: no ve cuotas ni importes');
select is(
  (select array_agg(x) from public.alumnos_con_cuota_vigente() x),
  array['00000000-0000-0000-0000-0000000a0004'::uuid],
  'Profesor: sí sabe quién tiene cuota en vigor'
);
update public.tarifas set precio = 1 where id = '00000000-0000-0000-0000-0000000a0d01';
select throws_ok(
  $$ insert into public.tarifas (academia_id, nombre, precio, periodicidad)
     values ('00000000-0000-0000-0000-0000000a00aa', 'Del profe', 1, 'mensual') $$,
  '42501', null, 'Profesor: no crea tarifas'
);
select is((select count(*)::int from public.documentos_alumno), 0, 'Profesor: no ve certificados');
select is((select count(*)::int from storage.objects where bucket_id = 'documentos-alumnos'), 0, 'Profesor: no ve los ficheros de documentos');
delete from public.documentos_alumno;
select throws_ok(
  $$ select public.aprobar_miembro('00000000-0000-0000-0000-0000000a0008') $$,
  'Solo el Dueño puede aprobar altas.',
  'Profesor: no aprueba altas'
);

-- ------------------------------------------------------------
-- 6. Dueño: todo lo de su academia
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000a0001');

select is(
  (select precio::int from public.tarifas where id = '00000000-0000-0000-0000-0000000a0d01'),
  50, 'El cambio de precio del Profesor no tuvo efecto'
);
select is((select count(*)::int from public.documentos_alumno), 1, 'El borrado del Profesor no tuvo efecto, y el Dueño ve el certificado');
select is((select count(*)::int from storage.objects where bucket_id = 'documentos-alumnos'), 1, 'Dueño: ve el fichero');
select is((select importe_cobrado::int from public.suscripciones), 50, 'Dueño: ve las cuotas y sus importes');

select lives_ok(
  $$ select public.aprobar_miembro('00000000-0000-0000-0000-0000000a0008') $$,
  'Dueño: aprueba un alta'
);
select lives_ok(
  $$ select public.rechazar_miembro('00000000-0000-0000-0000-0000000a0009') $$,
  'Dueño: rechaza un alta'
);
select is(
  (select estado from public.profiles where id = '00000000-0000-0000-0000-0000000a0009'),
  'baja', 'El alta rechazada queda de baja, sin borrar nada'
);

-- La cuenta aprobada ya entra.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000a0008');
select is((select count(*)::int from public.clases), 2, 'Aprobada: ya ve el calendario');

-- ------------------------------------------------------------
-- 7. Tienda cerrada y pedidos
-- ------------------------------------------------------------
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000a0003');
select throws_ok(
  $$ insert into public.pedidos (producto_id, alumno_id, cantidad)
     values ('00000000-0000-0000-0000-0000000a0f01', '00000000-0000-0000-0000-0000000a0003', 1) $$,
  '42501', null, 'Tienda cerrada: un alumno no crea pedidos'
);
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000a0001');
select throws_ok(
  $$ insert into public.productos (academia_id, nombre, precio, stock)
     values ('00000000-0000-0000-0000-0000000a00aa', 'Nuevo', 10, 1) $$,
  '42501', null, 'Tienda cerrada: tampoco el Dueño crea productos'
);

-- Si un día se reabre (se devuelve el permiso), el pedido nace sin pagar
-- aunque el alumno pida otra cosa.
reset role;
grant insert on public.pedidos to authenticated;
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000a0003');
insert into public.pedidos (id, producto_id, alumno_id, cantidad, estado, payment_status)
values ('00000000-0000-0000-0000-0000000a0f02', '00000000-0000-0000-0000-0000000a0f01',
        '00000000-0000-0000-0000-0000000a0003', 1, 'entregado', 'succeeded');
reset role;
select is(
  (select estado || '/' || payment_status from public.pedidos where id = '00000000-0000-0000-0000-0000000a0f02'),
  'pendiente_pago/pending',
  'Un alumno no puede crear un pedido ya pagado o entregado'
);

-- ------------------------------------------------------------
-- 8. Sin sesión
-- ------------------------------------------------------------
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(
  $$ select count(*) from public.profiles $$,
  '42501', null, 'Sin sesión no se lee ninguna tabla'
);
reset role;

select * from finish();
rollback;
