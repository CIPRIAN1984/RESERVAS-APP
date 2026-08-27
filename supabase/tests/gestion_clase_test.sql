-- Gestión de una clase ya publicada: editar, cerrar/reabrir, cancelar.
-- Ver 20260818063921_gestionar_clase_publicada.sql.
begin;
select plan(22);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000e001', 'dueno-gestion@test.dev'),
  ('00000000-0000-0000-0000-00000000e002', 'alumno-uno-gestion@test.dev'),
  ('00000000-0000-0000-0000-00000000e003', 'alumno-dos-gestion@test.dev'),
  ('00000000-0000-0000-0000-00000000e004', 'ajeno-gestion@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-00000000eee1', 'Academia Gestión', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-00000000eee1', 'dueño', 'Dueño', 'activo'),
  ('00000000-0000-0000-0000-00000000e002', '00000000-0000-0000-0000-00000000eee1', 'alumno', 'Alumno Uno', 'activo'),
  ('00000000-0000-0000-0000-00000000e003', '00000000-0000-0000-0000-00000000eee1', 'alumno', 'Alumno Dos', 'activo'),
  ('00000000-0000-0000-0000-00000000e004', '00000000-0000-0000-0000-00000000eee1', 'alumno', 'Ajeno', 'activo');

insert into public.clases (
  id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo
) values (
  '00000000-0000-0000-0000-00000000c501',
  '00000000-0000-0000-0000-00000000eee1',
  '00000000-0000-0000-0000-00000000e001',
  'No Gi',
  now() + interval '1 day',
  now() + interval '1 day 1 hour',
  10
);

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

-- 1. Por defecto una clase nace activa.
select is(
  (select estado from public.clases where id = '00000000-0000-0000-0000-00000000c501'),
  'activa',
  'Una clase nueva nace en estado activa'
);

-- 2. Un alumno no puede cerrar ni cancelar clases ajenas a su rol.
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e002');
select throws_ok(
  $$ select public.cambiar_estado_clase('00000000-0000-0000-0000-00000000c501', true) $$,
  null,
  'Un alumno no puede cerrar una clase'
);
select throws_ok(
  $$ select public.cancelar_clase('00000000-0000-0000-0000-00000000c501') $$,
  null,
  'Un alumno no puede cancelar una clase'
);
select throws_ok(
  $$ select public.editar_clase(
       '00000000-0000-0000-0000-00000000c501', 'Otro título', null,
       now() + interval '2 days', now() + interval '2 days 1 hour', 10
     ) $$,
  null,
  'Un alumno no puede editar una clase'
);

-- 3. Ni tocando la columna estado directamente: el UPDATE de tabla completa
-- está revocado, solo quedan las columnas editables a mano.
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e001');
select throws_ok(
  $$ update public.clases set estado = 'cancelada'
       where id = '00000000-0000-0000-0000-00000000c501' $$,
  null,
  'Ni el propio dueño puede tocar el estado con un UPDATE directo'
);

-- 4-5. El dueño cierra la clase: sigue en pie, pero ya no admite reservas.
select lives_ok(
  $$ select public.cambiar_estado_clase('00000000-0000-0000-0000-00000000c501', true) $$,
  'El dueño puede cerrar la clase'
);
select is(
  (select estado from public.clases where id = '00000000-0000-0000-0000-00000000c501'),
  'cerrada',
  'La clase queda en estado cerrada'
);

-- 6. Con la clase cerrada, un alumno nuevo no puede reservar.
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e002');
select throws_ok(
  $$ select public.reservar_clase('00000000-0000-0000-0000-00000000c501') $$,
  null,
  'Una clase cerrada no admite reservas nuevas'
);

-- 7-8. El dueño la reabre: vuelve a admitir reservas.
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e001');
select public.cambiar_estado_clase('00000000-0000-0000-0000-00000000c501', false);
select is(
  (select estado from public.clases where id = '00000000-0000-0000-0000-00000000c501'),
  'activa',
  'Reabrir la clase la deja activa otra vez'
);
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e002');
select is(
  public.reservar_clase('00000000-0000-0000-0000-00000000c501'),
  'inscrito',
  'Reabierta, un alumno ya puede reservar de nuevo'
);

-- 9. Un segundo alumno se apunta, para comprobar que cancelar libera a todos.
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e003');
select is(
  public.reservar_clase('00000000-0000-0000-0000-00000000c501'),
  'inscrito',
  'El segundo alumno también reserva'
);

-- 10-13. El dueño cancela: la clase queda cancelada, ambos inscritos
-- liberados (estado cancelado) y notificados.
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e001');
select is(
  public.cancelar_clase('00000000-0000-0000-0000-00000000c501'),
  2,
  'Cancelar avisa exactamente a los 2 alumnos que estaban apuntados'
);
select is(
  (select estado from public.clases where id = '00000000-0000-0000-0000-00000000c501'),
  'cancelada',
  'La clase queda cancelada'
);
select is(
  (
    select count(*)::int from public.inscripciones
    where clase_id = '00000000-0000-0000-0000-00000000c501' and estado = 'cancelado'
  ),
  2,
  'Los dos apuntados quedan liberados (estado cancelado)'
);
-- notificaciones_outbox está revocada por completo a authenticated: hay que
-- consultarla como el propio rol de la migración/prueba, no como el dueño.
reset role;
select is(
  (
    select count(*)::int from public.notificaciones_outbox
    where data ->> 'clase_id' = '00000000-0000-0000-0000-00000000c501'
      and data ->> 'type' = 'clase_cancelada'
  ),
  2,
  'Se encolan 2 notificaciones push, una por alumno afectado'
);

-- 14-15. Una clase cancelada no se puede reabrir ni volver a cancelar.
-- (reset role dejó la sesión sin JWT; hay que volver a actuar como el
-- dueño o estas comprobaciones fallarían por "No autorizado", no por la
-- razón real que se quiere probar.)
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e001');
select throws_ok(
  $$ select public.cambiar_estado_clase('00000000-0000-0000-0000-00000000c501', false) $$,
  null,
  'Una clase cancelada no se puede reabrir'
);
select throws_ok(
  $$ select public.cancelar_clase('00000000-0000-0000-0000-00000000c501') $$,
  null,
  'Una clase cancelada no se puede volver a cancelar'
);

-- 16. Ni editarse.
select throws_ok(
  $$ select public.editar_clase(
       '00000000-0000-0000-0000-00000000c501', 'Otro título', null,
       now() + interval '3 days', now() + interval '3 days 1 hour', 10
     ) $$,
  null,
  'Una clase cancelada no se puede editar'
);

-- 17-19. Editar una clase activa: cambiar la hora avisa a los apuntados;
-- no se puede bajar el aforo por debajo de las plazas ya confirmadas.
insert into public.clases (
  id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo
) values (
  '00000000-0000-0000-0000-00000000c502',
  '00000000-0000-0000-0000-00000000eee1',
  '00000000-0000-0000-0000-00000000e001',
  'Fundamentos',
  now() + interval '2 days',
  now() + interval '2 days 1 hour',
  2
);
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e002');
select public.reservar_clase('00000000-0000-0000-0000-00000000c502');

select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e001');
select throws_ok(
  $$ select public.editar_clase(
       '00000000-0000-0000-0000-00000000c502', 'Fundamentos', null,
       now() + interval '2 days', now() + interval '2 days 1 hour', 0
     ) $$,
  null,
  'El aforo no puede bajar de las plazas ya confirmadas'
);
select public.editar_clase(
  '00000000-0000-0000-0000-00000000c502', 'Fundamentos', null,
  now() + interval '2 days 2 hours', now() + interval '2 days 3 hours', 2
);
reset role;
select is(
  (
    select count(*)::int from public.notificaciones_outbox
    where data ->> 'clase_id' = '00000000-0000-0000-0000-00000000c502'
      and data ->> 'type' = 'clase_editada'
  ),
  1,
  'Cambiar la hora avisa al único alumno apuntado'
);

-- 20-21. listar_clases_semana() cuenta a quien todavía no tiene la
-- asistencia validada, para el botón «Confirmar todos» de la vista de
-- día (ver 20260818071115_pendientes_confirmar_vista_dia.sql).
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e001');
select is(
  (
    select pendientes_confirmar from public.listar_clases_semana(
      now(), now() + interval '3 days'
    ) where id = '00000000-0000-0000-0000-00000000c502'
  ),
  1::bigint,
  'El único inscrito sin validar cuenta como pendiente'
);

reset role;
insert into public.asistencias (clase_id, alumno_id, validado_por) values (
  '00000000-0000-0000-0000-00000000c502',
  '00000000-0000-0000-0000-00000000e002',
  '00000000-0000-0000-0000-00000000e001'
);
select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e001');
select is(
  (
    select pendientes_confirmar from public.listar_clases_semana(
      now(), now() + interval '3 days'
    ) where id = '00000000-0000-0000-0000-00000000c502'
  ),
  0::bigint,
  'Validada la asistencia, ya no cuenta como pendiente'
);

select * from finish();
rollback;
