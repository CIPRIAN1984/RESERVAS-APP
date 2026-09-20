-- Política comercial del punto 6: crédito retenido al reservar, devuelto
-- si se cancela con margen, consumido para siempre al confirmar asistencia
-- o al no presentarse, salvo que el Dueño o el Profesor corrijan un no
-- presentado cancelando en nombre del alumno.
begin;
select plan(7);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000dc001', 'dueno-ciclo@test.dev'),
  ('00000000-0000-0000-0000-0000000dc002', 'alumno-ciclo@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000dc0aa', 'Academia ciclo consumo', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000dc001',
   '00000000-0000-0000-0000-0000000dc0aa', 'dueño', 'Dueño ciclo', 'activo'),
  ('00000000-0000-0000-0000-0000000dc002',
   '00000000-0000-0000-0000-0000000dc0aa', 'alumno', 'Alumno ciclo', 'activo');

insert into public.tarifas
  (id, academia_id, nombre, precio, periodicidad, activo, clases_incluidas)
values
  ('00000000-0000-0000-0000-0000000dc0f1',
   '00000000-0000-0000-0000-0000000dc0aa', 'Mensual 4', 40, 'mensual', true, 4);

insert into public.suscripciones
  (id, alumno_id, tarifa_id, academia_id, proveedor_pago)
values
  ('00000000-0000-0000-0000-0000000dc0e1',
   '00000000-0000-0000-0000-0000000dc002',
   '00000000-0000-0000-0000-0000000dc0f1',
   '00000000-0000-0000-0000-0000000dc0aa', 'efectivo');

update public.suscripciones
   set estado = 'activa', payment_status = 'active',
       fecha_inicio = now() - interval '5 days',
       fecha_fin = now() + interval '25 days'
 where id = '00000000-0000-0000-0000-0000000dc0e1';

-- c1: clase ya terminada, con el alumno todavía 'inscrito' — un no
-- presentado. reservar_clase() no admite clases pasadas, así que se
-- siembra la reserva directamente, como haría una clase real ya vivida.
insert into public.clases
  (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin,
   aforo_maximo)
values
  ('00000000-0000-0000-0000-0000000dc0c1',
   '00000000-0000-0000-0000-0000000dc0aa',
   '00000000-0000-0000-0000-0000000dc001', 'Clase ciclo 1 (pasada)',
   now() - interval '2 days', now() - interval '2 days' + interval '1 hour', 10);

insert into public.inscripciones (clase_id, alumno_id, academia_id, estado) values
  ('00000000-0000-0000-0000-0000000dc0c1', '00000000-0000-0000-0000-0000000dc002',
   '00000000-0000-0000-0000-0000000dc0aa', 'inscrito');

-- c2: empieza dentro de una hora — dentro del margen de cancelación por
-- defecto de la academia (240 minutos). Cancelarla ahora es tardía.
insert into public.clases
  (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin,
   aforo_maximo)
values
  ('00000000-0000-0000-0000-0000000dc0c2',
   '00000000-0000-0000-0000-0000000dc0aa',
   '00000000-0000-0000-0000-0000000dc001', 'Clase ciclo 2 (pronto)',
   now() + interval '1 hour', now() + interval '2 hours', 10);

-- c3: empieza dentro de 10 días — muy fuera del margen. Cancelarla ahora
-- tiene de sobra el margen para no ser tardía.
insert into public.clases
  (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin,
   aforo_maximo)
values
  ('00000000-0000-0000-0000-0000000dc0c3',
   '00000000-0000-0000-0000-0000000dc0aa',
   '00000000-0000-0000-0000-0000000dc001', 'Clase ciclo 3 (lejana)',
   now() + interval '10 days', now() + interval '10 days 1 hour', 10);

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000dc002');

-- ── 1. El no presentado (c1) ya consume su clase sin que nadie haga nada ──
select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000dc002')
    ->> 'disponibles')::int,
  3,
  'La clase 1, ya pasada y nunca marcada, consume sola: quedan 3 de 4'
);

-- ── 2. Cancelar c2 fuera de plazo consume la clase igual que un no presentado ──
select public.reservar_clase('00000000-0000-0000-0000-0000000dc0c2');
select public.cancelar_reserva('00000000-0000-0000-0000-0000000dc0c2');

select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000dc002')
    ->> 'disponibles')::int,
  2,
  'Cancelar dentro del margen de aviso (240 min) consume la clase igual'
);

-- ── 3. Cancelar c3 con margen SÍ devuelve la clase ──────────────────────
select public.reservar_clase('00000000-0000-0000-0000-0000000dc0c3');
select public.cancelar_reserva('00000000-0000-0000-0000-0000000dc0c3');

select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000dc002')
    ->> 'disponibles')::int,
  2,
  'Cancelar con margen de sobra no consume nada: sigue en 2, no baja'
);

-- ── 4. El Dueño corrige el no presentado de c1: se le devuelve la clase ──
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000dc001');
select public.cancelar_reserva(
  '00000000-0000-0000-0000-0000000dc0c1',
  '00000000-0000-0000-0000-0000000dc002'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000dc002');
select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000dc002')
    ->> 'disponibles')::int,
  3,
  'El Dueño corrige el no presentado: la clase se devuelve, vuelve a 3'
);

reset role;
select is(
  (select cancelacion_tardia from public.inscripciones
    where clase_id = '00000000-0000-0000-0000-0000000dc0c1'
      and alumno_id = '00000000-0000-0000-0000-0000000dc002'),
  false,
  'La corrección del Dueño nunca queda marcada como cancelación tardía'
);

-- ── 5. El propio alumno NO puede perdonarse un no presentado pasado ─────
insert into public.clases
  (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin,
   aforo_maximo)
values
  ('00000000-0000-0000-0000-0000000dc0c4',
   '00000000-0000-0000-0000-0000000dc0aa',
   '00000000-0000-0000-0000-0000000dc001', 'Clase ciclo 4 (pasada)',
   now() - interval '1 day', now() - interval '1 day' + interval '1 hour', 10);

insert into public.inscripciones (clase_id, alumno_id, academia_id, estado) values
  ('00000000-0000-0000-0000-0000000dc0c4', '00000000-0000-0000-0000-0000000dc002',
   '00000000-0000-0000-0000-0000000dc0aa', 'inscrito');

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000dc002');
select public.cancelar_reserva('00000000-0000-0000-0000-0000000dc0c4');

select is(
  (public.clases_restantes('00000000-0000-0000-0000-0000000dc002')
    ->> 'disponibles')::int,
  2,
  'El alumno cancelando su propio no presentado sigue consumiendo la clase'
);

reset role;
select is(
  (select cancelacion_tardia from public.inscripciones
    where clase_id = '00000000-0000-0000-0000-0000000dc0c4'
      and alumno_id = '00000000-0000-0000-0000-0000000dc002'),
  true,
  'Solo la corrección del staff en nombre de otro escapa de "tardía": la propia sigue contando como tal'
);

select * from finish();
rollback;
