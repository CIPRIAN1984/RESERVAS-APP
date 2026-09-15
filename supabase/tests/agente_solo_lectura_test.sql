-- La puerta de solo lectura para el agente personal de Cipri (14/09/2026).
--
-- Aquí lo que puede salir caro no es que el agente lea mal: es que **la
-- puerta la pueda abrir alguien más**. Un alumno con sesión iniciada no
-- debe poder llamar a estas funciones pasando el uuid de otra academia, ni
-- asomarse a la tabla de claves.
--
-- Por eso la mitad de la prueba son permisos, y las consultas se ejecutan
-- con `set local role service_role` en vez de como superusuario: en un
-- Postgres local el superusuario se salta todas las comprobaciones, así que
-- probar «como postgres» daría verde con permisos que en producción fallan.
-- Ya pasó al escribir esto: `service_role` no puede leer `auth.users`, y en
-- local no se notaba.

begin;
select plan(36);

-- ---------------------------------------------------------------------------
-- Fixture: dos academias, para comprobar que no se mezclan.
-- ---------------------------------------------------------------------------

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000e0001', 'duena-agente@test.dev'),
  ('00000000-0000-0000-0000-0000000e0002', 'profe-agente@test.dev'),
  ('00000000-0000-0000-0000-0000000e0003', 'paga-y-viene@test.dev'),
  ('00000000-0000-0000-0000-0000000e0004', 'ni-paga-ni-viene@test.dev'),
  ('00000000-0000-0000-0000-0000000e0005', 'se-fue@test.dev'),
  ('00000000-0000-0000-0000-0000000e0006', 'duena-otra@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-0000000e00aa', 'Academia Agente A', 'approved'),
  ('00000000-0000-0000-0000-0000000e00bb', 'Academia Agente B', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, apellidos, estado, cinturon, fecha_inicio_cinturon) values
  ('00000000-0000-0000-0000-0000000e0001', '00000000-0000-0000-0000-0000000e00aa',
   'dueño', 'Cipri', 'Jefe', 'activo', 'negro', now() - interval '1 year'),
  ('00000000-0000-0000-0000-0000000e0002', '00000000-0000-0000-0000-0000000e00aa',
   'profesor', 'Profe', 'Ayudante', 'activo', 'marron', now() - interval '1 year'),
  ('00000000-0000-0000-0000-0000000e0003', '00000000-0000-0000-0000-0000000e00aa',
   'alumno', 'Paga', 'YViene', 'activo', 'azul', now() - interval '6 month'),
  ('00000000-0000-0000-0000-0000000e0004', '00000000-0000-0000-0000-0000000e00aa',
   'alumno', 'Ni', 'Paga', 'activo', 'blanco', now() - interval '6 month'),
  ('00000000-0000-0000-0000-0000000e0005', '00000000-0000-0000-0000-0000000e00aa',
   'alumno', 'Se', 'Fue', 'baja', 'morado', now() - interval '2 year'),
  ('00000000-0000-0000-0000-0000000e0006', '00000000-0000-0000-0000-0000000e00bb',
   'dueño', 'Otra', 'Duena', 'activo', 'negro', now() - interval '1 year');

update public.profiles set fecha_baja = now() - interval '5 day'
 where id = '00000000-0000-0000-0000-0000000e0005';

insert into public.tarifas (id, academia_id, nombre, precio, periodicidad, activo) values
  ('00000000-0000-0000-0000-0000000e00f1', '00000000-0000-0000-0000-0000000e00aa',
   'Mensual', 50, 'mensual', true);

-- Solo uno de los dos alumnos activos tiene la cuota al día.
--
-- Ojo: al insertar no vale poner `activa` directamente. El disparador
-- `set_suscripcion_defaults` fuerza toda cuota nueva a `pendiente_pago` /
-- `pending` — a propósito, para que solo el webhook de Stripe pueda darla
-- por cobrada. Hay que insertarla y activarla después, como hace
-- `production_hardening_test`.
insert into public.suscripciones
  (alumno_id, tarifa_id, academia_id, fecha_inicio)
values
  ('00000000-0000-0000-0000-0000000e0003', '00000000-0000-0000-0000-0000000e00f1',
   '00000000-0000-0000-0000-0000000e00aa', now() - interval '1 month');

update public.suscripciones
   set estado = 'activa',
       payment_status = 'active',
       fecha_fin = now() + interval '1 month'
 where alumno_id = '00000000-0000-0000-0000-0000000e0003';

-- Una clase futura con 10 plazas y una reserva, y una pasada a la que fue
-- «Paga YViene» ayer.
insert into public.clases
  (id, academia_id, profesor_id, titulo, fecha_hora_inicio, fecha_hora_fin, aforo_maximo)
values
  ('00000000-0000-0000-0000-0000000ec001', '00000000-0000-0000-0000-0000000e00aa',
   '00000000-0000-0000-0000-0000000e0002', 'Clase de mañana',
   now() + interval '1 day', now() + interval '1 day 1 hour', 10),
  ('00000000-0000-0000-0000-0000000ec002', '00000000-0000-0000-0000-0000000e00aa',
   '00000000-0000-0000-0000-0000000e0002', 'Clase de ayer',
   now() - interval '1 day', now() - interval '1 day' + interval '1 hour', 10);

insert into public.inscripciones (clase_id, alumno_id, academia_id, estado) values
  ('00000000-0000-0000-0000-0000000ec001', '00000000-0000-0000-0000-0000000e0003',
   '00000000-0000-0000-0000-0000000e00aa', 'inscrito');

insert into public.asistencias (clase_id, alumno_id, academia_id, validado_por, fecha) values
  ('00000000-0000-0000-0000-0000000ec002', '00000000-0000-0000-0000-0000000e0003',
   '00000000-0000-0000-0000-0000000e00aa',
   '00000000-0000-0000-0000-0000000e0002', now() - interval '1 day');

-- ---------------------------------------------------------------------------
-- 1. Permisos: quién NO puede llamar a la puerta
-- ---------------------------------------------------------------------------

select ok(
  not has_function_privilege('authenticated', 'public.agente_resumen(uuid,date,date)', 'execute'),
  'Un usuario con sesión no puede pedir el resumen de ninguna academia'
);
select ok(
  not has_function_privilege('authenticated', 'public.agente_avisos(uuid,integer)', 'execute'),
  'Ni los avisos'
);
select ok(
  not has_function_privilege('authenticated', 'public.agente_alumnos(uuid,boolean,boolean)', 'execute'),
  'Ni la lista de alumnos'
);
select ok(
  not has_function_privilege('authenticated', 'public.agente_horario(uuid,date,date)', 'execute'),
  'Ni el horario'
);
select ok(
  not has_function_privilege('authenticated', 'public.agente_correo_de(uuid,uuid)', 'execute'),
  'Ni el correo de nadie: es la función más golosa de todas'
);
select ok(
  not has_function_privilege('anon', 'public.agente_alumnos(uuid,boolean,boolean)', 'execute'),
  'Y sin sesión, menos todavía'
);
select ok(
  not has_table_privilege('authenticated', 'public.claves_agente', 'select'),
  'La tabla de claves no se lee desde la app'
);
select ok(
  not has_table_privilege('authenticated', 'public.consultas_agente', 'select'),
  'El registro de consultas tampoco'
);
select ok(
  has_function_privilege('service_role', 'public.agente_resumen(uuid,date,date)', 'execute'),
  'La Edge Function sí puede: si no, esto no serviría de nada'
);

-- ---------------------------------------------------------------------------
-- 2. Crear y revocar claves
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000e0003","role":"authenticated"}';
select throws_ok(
  $$ select public.crear_clave_agente('Mi agente', false) $$,
  'Solo el dueño puede crear claves para un agente.',
  'Un alumno no se fabrica su propia llave'
);

set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000e0002","role":"authenticated"}';
select throws_ok(
  $$ select public.crear_clave_agente('Mi agente', false) $$,
  'Solo el dueño puede crear claves para un agente.',
  'Un profesor tampoco'
);

set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000e0001","role":"authenticated"}';
create temporary table clave_creada as
  select public.crear_clave_agente('Agente de Cipri', true) as clave;

select matches(
  (select clave from clave_creada),
  '^itc_[0-9a-f]{48}$',
  'La dueña sí crea la clave, y sale con la pinta esperada'
);

-- Para mirar la tabla por dentro hay que soltar el rol: como `authenticated`
-- da «permission denied», que es justo lo que se quiere (y lo comprueba la
-- sección anterior).
reset role;

create temporary table clave_id as select id from public.claves_agente;
grant select on clave_id to public;

select is(
  (select count(*)::int from public.claves_agente c, clave_creada k
    where c.clave_hash = k.clave),
  0,
  'La clave NO se guarda en claro en ninguna parte'
);

select is(
  (select c.clave_hash from public.claves_agente c),
  (select encode(extensions.digest(k.clave, 'sha256'), 'hex') from clave_creada k),
  'Lo que se guarda es su huella sha256'
);

set local role authenticated;

select is(
  (select count(*)::int from public.listar_claves_agente()),
  1,
  'La dueña ve su clave en la lista'
);

set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000e0006","role":"authenticated"}';
select is(
  (select count(*)::int from public.listar_claves_agente()),
  0,
  'La dueña de la otra academia no ve ni rastro de ella'
);

select throws_ok(
  format($$ select public.revocar_clave_agente(%L) $$,
         (select id from clave_id)),
  'Esa clave no existe o ya estaba revocada.',
  'Ni puede revocársela'
);

set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000e0001","role":"authenticated"}';
select lives_ok(
  format($$ select public.revocar_clave_agente(%L) $$,
         (select id from clave_id)),
  'La dueña sí la revoca'
);
reset role;
select isnt(
  (select revocada_at from public.claves_agente),
  null,
  'Y queda marcada como revocada'
);
set local role authenticated;
select throws_ok(
  format($$ select public.revocar_clave_agente(%L) $$,
         (select id from clave_id)),
  'Esa clave no existe o ya estaba revocada.',
  'Revocarla dos veces avisa, no finge que ha hecho algo'
);

reset role;
set local request.jwt.claims = '';

-- ---------------------------------------------------------------------------
-- 3. Lo que devuelven las consultas — como service_role, que es quien las
--    ejecuta de verdad.
-- ---------------------------------------------------------------------------

set local role service_role;

select is(
  (public.agente_resumen('00000000-0000-0000-0000-0000000e00aa',
                         current_date, current_date + 7) -> 'alumnos' ->> 'activos')::int,
  2,
  'El resumen cuenta 2 alumnos activos: el de baja no suma'
);
select is(
  (public.agente_resumen('00000000-0000-0000-0000-0000000e00aa',
                         current_date, current_date + 7) -> 'alumnos' ->> 'de_baja')::int,
  1,
  'Y lleva la cuenta aparte de quién se fue'
);
select is(
  (public.agente_resumen('00000000-0000-0000-0000-0000000e00aa',
                         current_date, current_date + 7) -> 'cuotas' ->> 'al_dia')::int,
  1,
  'Solo uno tiene la cuota al día'
);
select is(
  (public.agente_resumen('00000000-0000-0000-0000-0000000e00bb',
                         current_date, current_date + 7) -> 'alumnos' ->> 'activos')::int,
  0,
  'La otra academia no ve ni uno de los alumnos de la primera'
);

select is(
  jsonb_array_length(
    public.agente_avisos('00000000-0000-0000-0000-0000000e00aa') -> 'sin_cuota'),
  1,
  'Avisos: sale el que no ha pagado'
);
select is(
  public.agente_avisos('00000000-0000-0000-0000-0000000e00aa')
    -> 'sin_cuota' -> 0 ->> 'nombre',
  'Ni Paga',
  'Y sale con su nombre, que es lo único que hace útil el aviso'
);
select is(
  jsonb_array_length(
    public.agente_avisos('00000000-0000-0000-0000-0000000e00aa') -> 'sin_venir'),
  1,
  'Avisos: el que vino ayer no aparece como desaparecido'
);
select is(
  (public.agente_avisos('00000000-0000-0000-0000-0000000e00aa')
    -> 'sin_venir' -> 0 ->> 'nunca_ha_venido')::boolean,
  true,
  'Del que nunca ha pisado el tatami se dice justo eso'
);
select is(
  jsonb_array_length(
    public.agente_avisos('00000000-0000-0000-0000-0000000e00aa') -> 'listos_para_graduarse'),
  0,
  'Con un solo entreno nadie está listo para graduarse'
);

select is(
  (public.agente_horario('00000000-0000-0000-0000-0000000e00aa',
                         current_date, current_date + 7) -> 0 ->> 'plazas_libres')::int,
  9,
  'El horario descuenta la plaza ya reservada'
);

select is(
  public.agente_alumnos('00000000-0000-0000-0000-0000000e00aa', false) -> 0 ->> 'correo',
  null,
  'Sin el interruptor de contacto, el correo no sale'
);
select is(
  public.agente_alumnos('00000000-0000-0000-0000-0000000e00aa', true) -> 0 ->> 'correo',
  'ni-paga-ni-viene@test.dev',
  'Con el interruptor puesto, sí — y sin superusuario que tape el permiso'
);
select is(
  jsonb_array_length(public.agente_alumnos('00000000-0000-0000-0000-0000000e00aa', false)),
  2,
  'Por defecto la lista no arrastra a los de baja'
);
select is(
  jsonb_array_length(public.agente_alumnos('00000000-0000-0000-0000-0000000e00aa', false, true)),
  3,
  'Y si se piden, aparecen'
);

reset role;

select is(public.agente_proximo_cinturon('azul', false), 'morado',
          'Después del azul va el morado');
select is(public.agente_proximo_cinturon('negro', false), null,
          'Del negro no se pasa: la app no gestiona los grados');

select finish();
rollback;
