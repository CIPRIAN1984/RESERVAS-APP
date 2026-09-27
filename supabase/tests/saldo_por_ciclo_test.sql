-- El saldo de clases se calcula en el ciclo real de cada clase (ver
-- 20260925090000_saldo_por_ciclo_real.sql): periodicidad de la tarifa,
-- ciclo de la clase y no el de hoy, sin hueco durante la clase, y candado
-- por alumno al reservar.
begin;
select plan(22);

set local timezone = 'UTC';

-- ── 1-8. ciclo_en: la periodicidad sí cuenta ────────────────────────────

select is(
  (select inicio from public.ciclo_en('2026-01-15 10:00+00', null, 'mensual', '2026-03-20 00:00+00')),
  '2026-03-15 10:00+00'::timestamptz,
  'Mensual: el ciclo del 20 de marzo empieza el 15 de marzo'
);
select is(
  (select fin from public.ciclo_en('2026-01-15 10:00+00', null, 'mensual', '2026-03-20 00:00+00')),
  '2026-04-15 10:00+00'::timestamptz,
  'Mensual: y termina el 15 de abril'
);
select is(
  (select row(inicio, fin)::text from public.ciclo_en('2026-01-15 10:00+00', null, 'trimestral', '2026-03-20 00:00+00')),
  row('2026-01-15 10:00+00'::timestamptz, '2026-04-15 10:00+00'::timestamptz)::text,
  'Trimestral: el 20 de marzo sigue en el primer trimestre (15 ene → 15 abr)'
);
select is(
  (select row(inicio, fin)::text from public.ciclo_en('2026-01-15 10:00+00', null, 'trimestral', '2026-04-20 00:00+00')),
  row('2026-04-15 10:00+00'::timestamptz, '2026-07-15 10:00+00'::timestamptz)::text,
  'Trimestral: el 20 de abril ya es el segundo trimestre (15 abr → 15 jul)'
);
select is(
  (select row(inicio, fin)::text from public.ciclo_en('2026-01-15 10:00+00', null, 'anual', '2026-11-01 00:00+00')),
  row('2026-01-15 10:00+00'::timestamptz, '2027-01-15 10:00+00'::timestamptz)::text,
  'Anual: noviembre sigue en el mismo año de cuota'
);
select is(
  (select row(inicio, fin)::text from public.ciclo_en('2026-01-15 10:00+00', null, 'suelta', '2026-11-01 00:00+00')),
  row('2026-01-15 10:00+00'::timestamptz, 'infinity'::timestamptz)::text,
  'Suelta sin caducidad: un único ciclo sin fin'
);
select is(
  (select row(inicio, fin)::text from public.ciclo_en('2026-01-31 10:00+00', null, 'mensual', '2026-02-28 12:00+00')),
  row('2026-02-28 10:00+00'::timestamptz, '2026-03-31 10:00+00'::timestamptz)::text,
  'Fin de mes: una clase el 28 de febrero por la tarde cae en el segundo ciclo'
);
select is(
  (select row(inicio, fin)::text from public.ciclo_en('2026-01-31 10:00+00', null, 'mensual', '2026-02-28 09:00+00')),
  row('2026-01-31 10:00+00'::timestamptz, '2026-02-28 10:00+00'::timestamptz)::text,
  'Fin de mes: la misma mañana, antes de la hora de inicio, sigue en el primero'
);

-- ── Semilla ──────────────────────────────────────────────────────────────
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000e5001', 'dueno-ciclo-real@test.dev'),
  ('00000000-0000-0000-0000-0000000e5002', 'trimestral@test.dev'),
  ('00000000-0000-0000-0000-0000000e5003', 'mensual@test.dev'),
  ('00000000-0000-0000-0000-0000000e5004', 'en-clase@test.dev'),
  ('00000000-0000-0000-0000-0000000e5005', 'en-espera@test.dev'),
  ('00000000-0000-0000-0000-0000000e5006', 'ocupa-plaza@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000e50aa', 'Academia ciclo real', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000e5001', '00000000-0000-0000-0000-0000000e50aa', 'dueño', 'Dueño', 'activo'),
  ('00000000-0000-0000-0000-0000000e5002', '00000000-0000-0000-0000-0000000e50aa', 'alumno', 'Trimestral', 'activo'),
  ('00000000-0000-0000-0000-0000000e5003', '00000000-0000-0000-0000-0000000e50aa', 'alumno', 'Mensual', 'activo'),
  ('00000000-0000-0000-0000-0000000e5004', '00000000-0000-0000-0000-0000000e50aa', 'alumno', 'En clase', 'activo'),
  ('00000000-0000-0000-0000-0000000e5005', '00000000-0000-0000-0000-0000000e50aa', 'alumno', 'En espera', 'activo'),
  ('00000000-0000-0000-0000-0000000e5006', '00000000-0000-0000-0000-0000000e50aa', 'alumno', 'Ocupa plaza', 'activo');

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, activo, clases_incluidas) values
  ('00000000-0000-0000-0000-0000000e50f1', '00000000-0000-0000-0000-0000000e50aa', 'Bono 3 trimestral', 30, 'trimestral', true, 3),
  ('00000000-0000-0000-0000-0000000e50f2', '00000000-0000-0000-0000-0000000e50aa', '2 al mes', 20, 'mensual', true, 2),
  ('00000000-0000-0000-0000-0000000e50f3', '00000000-0000-0000-0000-0000000e50aa', '1 al mes', 10, 'mensual', true, 1);

insert into public.suscripciones (id, alumno_id, tarifa_id, academia_id, proveedor_pago) values
  ('00000000-0000-0000-0000-0000000e50e1', '00000000-0000-0000-0000-0000000e5002', '00000000-0000-0000-0000-0000000e50f1', '00000000-0000-0000-0000-0000000e50aa', 'efectivo'),
  ('00000000-0000-0000-0000-0000000e50e2', '00000000-0000-0000-0000-0000000e5003', '00000000-0000-0000-0000-0000000e50f2', '00000000-0000-0000-0000-0000000e50aa', 'efectivo'),
  ('00000000-0000-0000-0000-0000000e50e3', '00000000-0000-0000-0000-0000000e5004', '00000000-0000-0000-0000-0000000e50f2', '00000000-0000-0000-0000-0000000e50aa', 'efectivo'),
  ('00000000-0000-0000-0000-0000000e50e4', '00000000-0000-0000-0000-0000000e5005', '00000000-0000-0000-0000-0000000e50f3', '00000000-0000-0000-0000-0000000e50aa', 'efectivo');

-- Trimestral: empezó hace 40 días (segundo mes del trimestre).
update public.suscripciones
   set estado = 'activa', payment_status = 'active',
       fecha_inicio = now() - interval '40 days', fecha_fin = now() + interval '50 days'
 where id = '00000000-0000-0000-0000-0000000e50e1';
-- Mensuales: empezaron hace 10 días y siguen vigentes varios meses.
update public.suscripciones
   set estado = 'activa', payment_status = 'active',
       fecha_inicio = now() - interval '10 days', fecha_fin = now() + interval '80 days'
 where id in ('00000000-0000-0000-0000-0000000e50e2',
              '00000000-0000-0000-0000-0000000e50e4');
update public.suscripciones
   set estado = 'activa', payment_status = 'active',
       fecha_inicio = now() - interval '5 days', fecha_fin = now() + interval '25 days'
 where id = '00000000-0000-0000-0000-0000000e50e3';

insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  -- Trimestral: tres clases del primer mes del trimestre, ya hechas.
  ('00000000-0000-0000-0000-0000000e5c01', '00000000-0000-0000-0000-0000000e50aa', '00000000-0000-0000-0000-0000000e5001', 'T1', now() - interval '38 days', now() - interval '38 days' + interval '1 hour', 10),
  ('00000000-0000-0000-0000-0000000e5c02', '00000000-0000-0000-0000-0000000e50aa', '00000000-0000-0000-0000-0000000e5001', 'T2', now() - interval '37 days', now() - interval '37 days' + interval '1 hour', 10),
  ('00000000-0000-0000-0000-0000000e5c03', '00000000-0000-0000-0000-0000000e50aa', '00000000-0000-0000-0000-0000000e5001', 'T3', now() - interval '36 days', now() - interval '36 days' + interval '1 hour', 10),
  ('00000000-0000-0000-0000-0000000e5c04', '00000000-0000-0000-0000-0000000e50aa', '00000000-0000-0000-0000-0000000e5001', 'T4', now() + interval '5 days', now() + interval '5 days 1 hour', 10),
  -- Mensual: dos clases de este ciclo ya hechas; tres del ciclo siguiente.
  ('00000000-0000-0000-0000-0000000e5c11', '00000000-0000-0000-0000-0000000e50aa', '00000000-0000-0000-0000-0000000e5001', 'M1', now() - interval '5 days', now() - interval '5 days' + interval '1 hour', 10),
  ('00000000-0000-0000-0000-0000000e5c12', '00000000-0000-0000-0000-0000000e50aa', '00000000-0000-0000-0000-0000000e5001', 'M2', now() - interval '4 days', now() - interval '4 days' + interval '1 hour', 10),
  ('00000000-0000-0000-0000-0000000e5c13', '00000000-0000-0000-0000-0000000e50aa', '00000000-0000-0000-0000-0000000e5001', 'M3', now() + interval '25 days', now() + interval '25 days 1 hour', 10),
  ('00000000-0000-0000-0000-0000000e5c14', '00000000-0000-0000-0000-0000000e50aa', '00000000-0000-0000-0000-0000000e5001', 'M4', now() + interval '26 days', now() + interval '26 days 1 hour', 10),
  ('00000000-0000-0000-0000-0000000e5c15', '00000000-0000-0000-0000-0000000e50aa', '00000000-0000-0000-0000-0000000e5001', 'M5', now() + interval '27 days', now() + interval '27 days 1 hour', 10),
  -- Una clase que está ocurriendo ahora mismo.
  ('00000000-0000-0000-0000-0000000e5c21', '00000000-0000-0000-0000-0000000e50aa', '00000000-0000-0000-0000-0000000e5001', 'Ahora', now() - interval '10 minutes', now() + interval '50 minutes', 10),
  -- Lista de espera: una clase de este ciclo ya hecha y otra llena del siguiente.
  ('00000000-0000-0000-0000-0000000e5c31', '00000000-0000-0000-0000-0000000e50aa', '00000000-0000-0000-0000-0000000e5001', 'E1', now() - interval '5 days', now() - interval '5 days' + interval '1 hour', 10),
  ('00000000-0000-0000-0000-0000000e5c32', '00000000-0000-0000-0000-0000000e50aa', '00000000-0000-0000-0000-0000000e5001', 'E2 llena', now() + interval '25 days', now() + interval '25 days 1 hour', 1);

insert into public.inscripciones (clase_id, alumno_id, academia_id, estado) values
  ('00000000-0000-0000-0000-0000000e5c01', '00000000-0000-0000-0000-0000000e5002', '00000000-0000-0000-0000-0000000e50aa', 'inscrito'),
  ('00000000-0000-0000-0000-0000000e5c02', '00000000-0000-0000-0000-0000000e5002', '00000000-0000-0000-0000-0000000e50aa', 'inscrito'),
  ('00000000-0000-0000-0000-0000000e5c03', '00000000-0000-0000-0000-0000000e5002', '00000000-0000-0000-0000-0000000e50aa', 'inscrito'),
  ('00000000-0000-0000-0000-0000000e5c11', '00000000-0000-0000-0000-0000000e5003', '00000000-0000-0000-0000-0000000e50aa', 'inscrito'),
  ('00000000-0000-0000-0000-0000000e5c12', '00000000-0000-0000-0000-0000000e5003', '00000000-0000-0000-0000-0000000e50aa', 'inscrito'),
  ('00000000-0000-0000-0000-0000000e5c21', '00000000-0000-0000-0000-0000000e5004', '00000000-0000-0000-0000-0000000e50aa', 'inscrito'),
  ('00000000-0000-0000-0000-0000000e5c31', '00000000-0000-0000-0000-0000000e5005', '00000000-0000-0000-0000-0000000e50aa', 'inscrito'),
  ('00000000-0000-0000-0000-0000000e5c32', '00000000-0000-0000-0000-0000000e5006', '00000000-0000-0000-0000-0000000e50aa', 'inscrito');

-- La de espera se apunta la última, a la clase llena del ciclo siguiente.
insert into public.inscripciones (clase_id, alumno_id, academia_id, estado, created_at) values
  ('00000000-0000-0000-0000-0000000e5c32', '00000000-0000-0000-0000-0000000e5005', '00000000-0000-0000-0000-0000000e50aa', 'espera', now() + interval '1 second');

insert into public.asistencias (clase_id, alumno_id, validado_por) values
  ('00000000-0000-0000-0000-0000000e5c01', '00000000-0000-0000-0000-0000000e5002', '00000000-0000-0000-0000-0000000e5001'),
  ('00000000-0000-0000-0000-0000000e5c02', '00000000-0000-0000-0000-0000000e5002', '00000000-0000-0000-0000-0000000e5001'),
  ('00000000-0000-0000-0000-0000000e5c03', '00000000-0000-0000-0000-0000000e5002', '00000000-0000-0000-0000-0000000e5001'),
  ('00000000-0000-0000-0000-0000000e5c11', '00000000-0000-0000-0000-0000000e5003', '00000000-0000-0000-0000-0000000e5001'),
  ('00000000-0000-0000-0000-0000000e5c12', '00000000-0000-0000-0000-0000000e5003', '00000000-0000-0000-0000-0000000e5001'),
  ('00000000-0000-0000-0000-0000000e5c31', '00000000-0000-0000-0000-0000000e5005', '00000000-0000-0000-0000-0000000e5001');

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- ── 9-10. Un trimestral NO repone sus clases cada mes ──────────────────
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000e5002');
select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000e5002') ->> 'disponibles')::int,
  0,
  'Trimestral de 3 clases con 3 hechas el mes pasado: no le queda ninguna en el trimestre'
);
select throws_ok(
  $$ select public.reservar_clase('00000000-0000-0000-0000-0000000e5c04') $$,
  'No te quedan clases en tu tarifa para esa fecha. Renueva o compra una clase suelta.',
  'Y no puede reservar otra clase del mismo trimestre'
);

-- ── 11-14. Reservar en el ciclo siguiente mira el saldo de ese ciclo ────
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000e5003');
select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000e5003') ->> 'disponibles')::int,
  0,
  'Mensual de 2 clases con las 2 hechas: este ciclo está agotado'
);
select is(
  public.reservar_clase('00000000-0000-0000-0000-0000000e5c13'),
  'inscrito',
  'Aun así puede reservar una clase del ciclo siguiente: ese ciclo está sin estrenar'
);
select is(
  public.reservar_clase('00000000-0000-0000-0000-0000000e5c14'),
  'inscrito',
  'Y una segunda del ciclo siguiente'
);
select throws_ok(
  $$ select public.reservar_clase('00000000-0000-0000-0000-0000000e5c15') $$,
  'No te quedan clases en tu tarifa para esa fecha. Renueva o compra una clase suelta.',
  'La tercera del ciclo siguiente se rechaza: ya tiene las 2 de ese ciclo reservadas'
);

-- ── 15-16. Mientras la clase dura, la plaza sigue contando ──────────────
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000e5004');
select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000e5004') ->> 'reservadas')::int,
  1,
  'Una clase que está ocurriendo ahora cuenta como reservada hasta que termina'
);
select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000e5004') ->> 'disponibles')::int,
  1,
  'Y por tanto el saldo no sube durante la clase (2 − 1 = 1)'
);

-- ── 17. Reservar toma el candado del alumno ─────────────────────────────
-- (La prueba de verdad con dos sesiones simultáneas está en la descripción
-- del PR: pgTAP corre en una sola sesión. Aquí se comprueba que el candado
-- existe y queda puesto hasta el final de la transacción.)
reset role;
select ok(
  exists (
    select 1 from pg_locks
     where locktype = 'advisory'
       and pid = pg_backend_pid()
       and classid = 7301
       and objsubid = 2
  ),
  'reservar_clase deja puesto el candado del alumno hasta que termina la transacción'
);

-- ── 18-19. La lista de espera también usa el ciclo de la clase ──────────
-- «En espera» tiene 1 clase al mes y ya la gastó ESTE ciclo; la clase llena
-- es del ciclo siguiente. Al liberarse la plaza, debe subir.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000e5006');
select public.cancelar_reserva('00000000-0000-0000-0000-0000000e5c32');

reset role;
select is(
  (select estado from public.inscripciones
    where clase_id = '00000000-0000-0000-0000-0000000e5c32'
      and alumno_id = '00000000-0000-0000-0000-0000000e5005'),
  'inscrito',
  'Con este ciclo agotado, sube desde la lista de espera a una clase del ciclo siguiente'
);
select ok(
  exists (
    select 1 from public.notificaciones_outbox
     where user_id = '00000000-0000-0000-0000-0000000e5005'
       and data ->> 'type' = 'waitlist_promoted'
  ),
  'Y le llega el aviso de plaza confirmada'
);

-- ── 20-21. Clase después de que acabe la cuota pagada ───────────────────
-- «En clase» tiene la cuota pagada hasta dentro de 25 días. Una clase de
-- dentro de 40 no la cubre ninguna cuota.
insert into public.clases (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo) values
  ('00000000-0000-0000-0000-0000000e5c41', '00000000-0000-0000-0000-0000000e50aa', '00000000-0000-0000-0000-0000000e5001', 'Tras la cuota', now() + interval '40 days', now() + interval '40 days 1 hour', 10);

-- Si la academia no exige cuota (ITACA), se reserva igual: saldrá «sin cuota».
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000e5004');
select is(
  public.reservar_clase('00000000-0000-0000-0000-0000000e5c41'),
  'inscrito',
  'Sin exigir cuota, una clase posterior a la cuota se reserva (y sale «sin cuota»)'
);

-- Si la exige, tener cuota HOY ya no basta: tiene que cubrir ese día.
reset role;
update public.inscripciones set estado = 'cancelado'
 where clase_id = '00000000-0000-0000-0000-0000000e5c41';
update public.academias set exigir_cuota_para_reservar = true
 where id = '00000000-0000-0000-0000-0000000e50aa';
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000e5004');
select throws_ok(
  $$ select public.reservar_clase('00000000-0000-0000-0000-0000000e5c41') $$,
  'Debes tener una cuota activa para reservar esta clase.',
  'Exigiendo cuota, no se puede reservar una clase posterior a la cuota pagada'
);

-- ── 22. Las funciones internas nuevas no son endpoints ──────────────────
reset role;
select ok(
  not has_function_privilege('authenticated', 'public.ciclo_en(timestamptz,timestamptz,text,timestamptz)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public._saldo_clases(uuid,timestamptz)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public._cuota_cubre(uuid,uuid,timestamptz)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public._puede_ocupar_plaza(uuid,uuid,timestamptz,boolean)', 'EXECUTE'),
  'ciclo_en, _saldo_clases(alumno, fecha), _cuota_cubre y _puede_ocupar_plaza no se pueden llamar desde la app'
);

select * from finish();
rollback;
