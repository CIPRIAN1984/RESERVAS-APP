-- Tarifas con clases por ciclo.
--
-- Aquí se protege dinero por partida doble: que el saldo sea el de verdad
-- (contarle de más a alguien es cobrarle de más), y que nadie pueda mirar ni
-- tocar el saldo de otro.
begin;
select plan(14);

-- ------------------------------------------------------------
-- Escenario: dos academias
-- ------------------------------------------------------------

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000cc101', 'dueno-clases-a@test.dev'),
  ('00000000-0000-0000-0000-0000000cc102', 'alumno-clases-a@test.dev'),
  ('00000000-0000-0000-0000-0000000cc103', 'alumno-ilimitado-a@test.dev'),
  ('00000000-0000-0000-0000-0000000cc201', 'dueno-clases-b@test.dev'),
  ('00000000-0000-0000-0000-0000000cc202', 'alumno-clases-b@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000cc0aa', 'Academia clases A', 'approved'),
  ('00000000-0000-0000-0000-0000000cc0bb', 'Academia clases B', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000cc101',
   '00000000-0000-0000-0000-0000000cc0aa', 'dueño',  'Dueño A',      'activo'),
  ('00000000-0000-0000-0000-0000000cc102',
   '00000000-0000-0000-0000-0000000cc0aa', 'alumno', 'Alumno 8',     'activo'),
  ('00000000-0000-0000-0000-0000000cc103',
   '00000000-0000-0000-0000-0000000cc0aa', 'alumno', 'Alumno libre', 'activo'),
  ('00000000-0000-0000-0000-0000000cc201',
   '00000000-0000-0000-0000-0000000cc0bb', 'dueño',  'Dueño B',      'activo'),
  ('00000000-0000-0000-0000-0000000cc202',
   '00000000-0000-0000-0000-0000000cc0bb', 'alumno', 'Alumno B',     'activo');

insert into public.tarifas
  (id, academia_id, nombre, precio, periodicidad, activo, clases_incluidas)
values
  ('00000000-0000-0000-0000-0000000cc0f1',
   '00000000-0000-0000-0000-0000000cc0aa', '2 días', 50, 'mensual', true, 8),
  ('00000000-0000-0000-0000-0000000cc0f2',
   '00000000-0000-0000-0000-0000000cc0aa', 'Libre', 80, 'mensual', true, null),
  ('00000000-0000-0000-0000-0000000cc0f3',
   '00000000-0000-0000-0000-0000000cc0bb', 'Trimestral B', 140, 'trimestral',
   true, 12);

create or replace function pg_temp.actuar_como(p_uid uuid)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text,
    true
  );
  perform set_config('role', 'authenticated', true);
end;
$$;

-- ------------------------------------------------------------
-- La tarifa acepta un número de clases, o ninguno
-- ------------------------------------------------------------

select is(
  (select clases_incluidas from public.tarifas
    where id = '00000000-0000-0000-0000-0000000cc0f1'),
  8,
  'Una tarifa puede llevar 8 clases al mes'
);

select is(
  (select clases_incluidas from public.tarifas
    where id = '00000000-0000-0000-0000-0000000cc0f2'),
  null,
  'Sin número es ilimitada'
);

select throws_ok(
  $$ insert into public.tarifas
       (academia_id, nombre, precio, periodicidad, clases_incluidas)
     values ('00000000-0000-0000-0000-0000000cc0aa', 'Cero', 10, 'mensual', 0)
  $$,
  null,
  'Cero clases no tiene sentido y se rechaza'
);

select lives_ok(
  $$ insert into public.tarifas
       (academia_id, nombre, precio, periodicidad, clases_incluidas)
     values ('00000000-0000-0000-0000-0000000cc0aa', 'Visita', 12, 'suelta', 1)
  $$,
  'Existe la periodicidad «suelta» para el drop-in'
);

-- ------------------------------------------------------------
-- El ciclo va de fecha a fecha
-- ------------------------------------------------------------

-- Una cuota que empezó hace 40 días: el ciclo vigente es el segundo mes, no
-- el primero. Si esto fallara, se le estarían regalando o quitando clases.
select is(
  (select (inicio > now() - interval '11 days'
             and inicio <= now())
     from public.ciclo_vigente(
       now() - interval '40 days', null, 'mensual')),
  true,
  'A los 40 días el ciclo vigente ya es el segundo mes'
);

select is(
  (select (fin > now())
     from public.ciclo_vigente(
       now() - interval '40 days', null, 'mensual')),
  true,
  'Y el ciclo vigente todavía no ha terminado'
);

-- ------------------------------------------------------------
-- El saldo
-- ------------------------------------------------------------

reset role;

insert into public.suscripciones
  (id, alumno_id, tarifa_id, academia_id, proveedor_pago)
values
  ('00000000-0000-0000-0000-0000000cc0e1',
   '00000000-0000-0000-0000-0000000cc102',
   '00000000-0000-0000-0000-0000000cc0f1',
   '00000000-0000-0000-0000-0000000cc0aa', 'efectivo'),
  ('00000000-0000-0000-0000-0000000cc0e2',
   '00000000-0000-0000-0000-0000000cc103',
   '00000000-0000-0000-0000-0000000cc0f2',
   '00000000-0000-0000-0000-0000000cc0aa', 'efectivo');

update public.suscripciones
   set estado = 'activa', payment_status = 'active',
       fecha_inicio = now() - interval '3 days',
       fecha_fin = now() + interval '27 days'
 where id in ('00000000-0000-0000-0000-0000000cc0e1',
              '00000000-0000-0000-0000-0000000cc0e2');

-- Dos clases: una que ya pasó (con asistencia) y otra futura (reservada).
insert into public.clases
  (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin,
   aforo_maximo)
values
  ('00000000-0000-0000-0000-0000000cc0c1',
   '00000000-0000-0000-0000-0000000cc0aa',
   '00000000-0000-0000-0000-0000000cc101', 'Ayer',
   now() - interval '1 day', now() - interval '23 hours', 20),
  ('00000000-0000-0000-0000-0000000cc0c2',
   '00000000-0000-0000-0000-0000000cc0aa',
   '00000000-0000-0000-0000-0000000cc101', 'Mañana',
   now() + interval '1 day', now() + interval '1 day 1 hour', 20);

insert into public.asistencias
  (clase_id, alumno_id, academia_id, validado_por)
values
  ('00000000-0000-0000-0000-0000000cc0c1',
   '00000000-0000-0000-0000-0000000cc102',
   '00000000-0000-0000-0000-0000000cc0aa',
   '00000000-0000-0000-0000-0000000cc101');

insert into public.inscripciones
  (clase_id, alumno_id, academia_id, estado)
values
  ('00000000-0000-0000-0000-0000000cc0c2',
   '00000000-0000-0000-0000-0000000cc102',
   '00000000-0000-0000-0000-0000000cc0aa', 'inscrito');

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000cc102');

select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000cc102')
    ->> 'gastadas')::int,
  1,
  'La clase de ayer, ya confirmada, cuenta como gastada'
);

select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000cc102')
    ->> 'reservadas')::int,
  1,
  'La de mañana, reservada y sin confirmar, cuenta como reservada'
);

-- Lo que de verdad importa: 8 − 1 gastada − 1 reservada = 6. Si lo reservado
-- no se descontara, con una sola clase suelta se podrían reservar las ocho
-- de la semana.
select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000cc102')
    ->> 'disponibles')::int,
  6,
  'Quedan 6: lo reservado también descuenta'
);

select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000cc103')
    ->> 'ilimitada')::boolean,
  true,
  'La tarifa sin número sale como ilimitada'
);

-- ------------------------------------------------------------
-- Quién puede mirar el saldo de quién
-- ------------------------------------------------------------

select throws_ok(
  $$ select public.clases_restantes(
       '00000000-0000-0000-0000-0000000cc103') $$,
  null,
  'Un alumno no puede ver el saldo de su compañero'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000cc101');

select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000cc102')
    ->> 'disponibles')::int,
  6,
  'El Dueño sí ve el saldo de un alumno suyo'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000cc201');

select throws_ok(
  $$ select public.clases_restantes(
       '00000000-0000-0000-0000-0000000cc102') $$,
  null,
  'Un Dueño no puede ver el saldo de un alumno de otra academia'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000cc202');

select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000cc202')
    ->> 'tiene_cuota')::boolean,
  false,
  'Quien no tiene cuota sale sin cuota, no revienta'
);

rollback;
