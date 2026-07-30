-- Recorrido integral con identidades ficticias.
--
-- Valida en una sola transacción los límites entre Auth, perfiles, academia,
-- equipo, tarifas, clases, reservas, lista de espera y asistencia. La
-- activación de la cuota simula el resultado ya verificado de Stripe: el
-- webhook real vive fuera de Postgres y escribe como service_role.
begin;
select plan(24);

-- ── Identidades iniciales ──────────────────────────────────────────────────
insert into auth.users (id, email, email_confirmed_at) values
  (
    '00000000-0000-0000-0000-00000000ef01',
    'admin-recorrido@test.dev',
    now()
  );

set local role service_role;

select lives_ok(
  $$ select public.bootstrap_initial_admin(
       '00000000-0000-0000-0000-00000000ef01',
       'Admin',
       'Recorrido'
     ) $$,
  'El operador crea el Administrador inicial confirmado'
);

reset role;

select is(
  (
    select rol
    from public.profiles
    where id = '00000000-0000-0000-0000-00000000ef01'
  ),
  'administrador',
  'El Administrador inicial queda disponible para aprobar academias'
);

-- El trigger de Auth crea atómicamente la academia y el perfil del Dueño.
insert into auth.users (
  id,
  email,
  email_confirmed_at,
  raw_user_meta_data
) values (
  '00000000-0000-0000-0000-00000000ef02',
  'dueno-recorrido@test.dev',
  now(),
  jsonb_build_object(
    'flujo', 'registro_academia',
    'nombre', 'Dueño',
    'apellidos', 'Ficticio',
    'nombre_academia', 'Academia Recorrido Ficticio',
    'direccion', 'Calle de Prueba 1',
    'telefono', '+34000000000',
    'email_contacto', 'academia-recorrido@test.dev'
  )
);

select ok(
  exists (
    select 1
    from public.academias a
    join public.profiles p on p.academia_id = a.id
    where p.id = '00000000-0000-0000-0000-00000000ef02'
      and a.nombre = 'Academia Recorrido Ficticio'
      and a.estado = 'pending'
      and a.created_by = p.id
  ),
  'El alta del Dueño crea su academia pendiente en la misma transacción'
);

select ok(
  exists (
    select 1
    from public.profiles
    where id = '00000000-0000-0000-0000-00000000ef02'
      and rol = 'dueño'
      and estado = 'pendiente_aprobacion'
  ),
  'El Dueño queda pendiente hasta la revisión del Administrador'
);

create or replace function pg_temp.actuar_como(p_uid uuid)
returns void
language plpgsql
as $function$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', p_uid,
      'role', 'authenticated'
    )::text,
    true
  );
  perform set_config('role', 'authenticated', true);
end;
$function$;

select pg_temp.actuar_como(
  '00000000-0000-0000-0000-00000000ef01'
);

select lives_ok(
  $$ select public.aprobar_academia(
       (
         select academia_id
         from public.profiles
         where id = '00000000-0000-0000-0000-00000000ef02'
       )
     ) $$,
  'El Administrador aprueba la academia pendiente'
);

reset role;

select ok(
  exists (
    select 1
    from public.academias a
    join public.profiles p on p.academia_id = a.id
    where p.id = '00000000-0000-0000-0000-00000000ef02'
      and a.estado = 'approved'
      and a.approved_by = '00000000-0000-0000-0000-00000000ef01'
      and p.estado = 'activo'
  ),
  'La aprobación activa la academia y su Dueño'
);

-- ── Alumnos y equipo ───────────────────────────────────────────────────────
-- La metadata intenta autoasignar un rol elevado al primer usuario. El
-- trigger debe ignorarlo y crear siempre un Alumno.
insert into auth.users (
  id,
  email,
  email_confirmed_at,
  raw_user_meta_data
)
select
  '00000000-0000-0000-0000-00000000ef03',
  'profesor-recorrido@test.dev',
  now(),
  jsonb_build_object(
    'flujo', 'unirse',
    'nombre', 'Profesor',
    'apellidos', 'Ficticio',
    'academia_id', academia_id::text,
    'rol', 'administrador'
  )
from public.profiles
where id = '00000000-0000-0000-0000-00000000ef02';

insert into auth.users (
  id,
  email,
  email_confirmed_at,
  raw_user_meta_data
)
select
  '00000000-0000-0000-0000-00000000ef04',
  'alumno-uno-recorrido@test.dev',
  now(),
  jsonb_build_object(
    'flujo', 'unirse',
    'nombre', 'Alumno',
    'apellidos', 'Uno',
    'academia_id', academia_id::text
  )
from public.profiles
where id = '00000000-0000-0000-0000-00000000ef02';

insert into auth.users (
  id,
  email,
  email_confirmed_at,
  raw_user_meta_data
)
select
  '00000000-0000-0000-0000-00000000ef05',
  'alumno-dos-recorrido@test.dev',
  now(),
  jsonb_build_object(
    'flujo', 'unirse',
    'nombre', 'Alumno',
    'apellidos', 'Dos',
    'academia_id', academia_id::text
  )
from public.profiles
where id = '00000000-0000-0000-0000-00000000ef02';

select is(
  (
    select count(*)::int
    from public.profiles
    where id in (
      '00000000-0000-0000-0000-00000000ef03',
      '00000000-0000-0000-0000-00000000ef04',
      '00000000-0000-0000-0000-00000000ef05'
    )
      and rol = 'alumno'
      and estado = 'activo'
  ),
  3,
  'Las altas para unirse nacen activas y siempre con rol Alumno'
);

select is(
  (
    select rol
    from public.profiles
    where id = '00000000-0000-0000-0000-00000000ef03'
  ),
  'alumno',
  'La metadata de Auth no permite autoasignarse un rol elevado'
);

select pg_temp.actuar_como(
  '00000000-0000-0000-0000-00000000ef02'
);

select lives_ok(
  $$ select public.cambiar_rol_miembro(
       '00000000-0000-0000-0000-00000000ef03',
       'profesor'
     ) $$,
  'El Dueño promociona al miembro elegido a Profesor'
);

reset role;

select is(
  (
    select rol
    from public.profiles
    where id = '00000000-0000-0000-0000-00000000ef03'
  ),
  'profesor',
  'La promoción a Profesor queda persistida'
);

-- ── Oferta, calendario y cobro simulado ────────────────────────────────────
select pg_temp.actuar_como(
  '00000000-0000-0000-0000-00000000ef02'
);

select lives_ok(
  $$ insert into public.tarifas (
       id,
       academia_id,
       nombre,
       precio,
       periodicidad
     ) values (
       '00000000-0000-0000-0000-00000000eff1',
       public.current_academia_id(),
       'Mensual ficticia',
       49.90,
       'mensual'
     ) $$,
  'El Dueño publica una tarifa para su academia'
);

select pg_temp.actuar_como(
  '00000000-0000-0000-0000-00000000ef03'
);

select lives_ok(
  $$ insert into public.clases (
       id,
       academia_id,
       profesor_id,
       titulo,
       descripcion,
       fecha_hora_inicio,
       fecha_hora_fin,
       aforo_maximo
     ) values (
       '00000000-0000-0000-0000-00000000efc1',
       public.current_academia_id(),
       auth.uid(),
       'Clase integral ficticia',
       'Datos creados solo dentro de pgTAP',
       now() + interval '1 day',
       now() + interval '1 day 1 hour',
       1
     ) $$,
  'El Profesor crea una clase futura de aforo uno'
);

select pg_temp.actuar_como(
  '00000000-0000-0000-0000-00000000ef04'
);

select is(
  (
    select count(*)::int
    from public.listar_clases_semana(
      now(),
      now() + interval '2 days'
    )
    where id = '00000000-0000-0000-0000-00000000efc1'
  ),
  1,
  'El Alumno ve la clase de su academia en el calendario'
);

-- Desde julio de 2026 exigir la cuota por delante es un ajuste de cada
-- academia, apagado por defecto. Esta lo enciende, que es lo que da sentido
-- al paso siguiente y a la promoción desde la lista de espera de más abajo.
select pg_temp.actuar_como(
  '00000000-0000-0000-0000-00000000ef02'
);

update public.academias
   set exigir_cuota_para_reservar = true
 where id = public.current_academia_id();

select pg_temp.actuar_como(
  '00000000-0000-0000-0000-00000000ef04'
);

select throws_ok(
  $$ select public.reservar_clase(
       '00000000-0000-0000-0000-00000000efc1'
     ) $$,
  null,
  'La reserva se rechaza mientras el Alumno no tenga una cuota cobrada'
);

reset role;
select set_config('request.jwt.claims', '{}', true);

insert into public.suscripciones (
  id,
  alumno_id,
  tarifa_id,
  academia_id,
  proveedor_pago,
  referencia_externa
) values
  (
    '00000000-0000-0000-0000-00000000efd1',
    '00000000-0000-0000-0000-00000000ef04',
    '00000000-0000-0000-0000-00000000eff1',
    (
      select academia_id
      from public.profiles
      where id = '00000000-0000-0000-0000-00000000ef04'
    ),
    'stripe',
    'sub_fake_e2e_one'
  ),
  (
    '00000000-0000-0000-0000-00000000efd2',
    '00000000-0000-0000-0000-00000000ef05',
    '00000000-0000-0000-0000-00000000eff1',
    (
      select academia_id
      from public.profiles
      where id = '00000000-0000-0000-0000-00000000ef05'
    ),
    'stripe',
    'sub_fake_e2e_two'
  );

-- Simula exclusivamente el efecto del webhook Stripe ya autenticado.
update public.suscripciones
set estado = 'activa',
    payment_status = 'active'
where id in (
  '00000000-0000-0000-0000-00000000efd1',
  '00000000-0000-0000-0000-00000000efd2'
);

select is(
  (
    select count(*)::int
    from public.suscripciones
    where id in (
      '00000000-0000-0000-0000-00000000efd1',
      '00000000-0000-0000-0000-00000000efd2'
    )
      and estado = 'activa'
      and payment_status = 'active'
  ),
  2,
  'El límite simulado de Stripe deja dos cuotas activas y cobradas'
);

-- ── Reserva, espera, promoción y asistencia ────────────────────────────────
select pg_temp.actuar_como(
  '00000000-0000-0000-0000-00000000ef04'
);

select is(
  public.reservar_clase(
    '00000000-0000-0000-0000-00000000efc1'
  ),
  'inscrito',
  'El primer Alumno con cuota obtiene la plaza'
);

select pg_temp.actuar_como(
  '00000000-0000-0000-0000-00000000ef05'
);

select is(
  public.reservar_clase(
    '00000000-0000-0000-0000-00000000efc1'
  ),
  'espera',
  'El segundo Alumno con cuota entra en lista de espera'
);

select is(
  (
    select jsonb_build_object(
      'inscrito',
      count(*) filter (where estado = 'inscrito'),
      'espera',
      count(*) filter (where estado = 'espera')
    )
    from public.inscripciones
    where clase_id = '00000000-0000-0000-0000-00000000efc1'
  ),
  '{"espera": 1, "inscrito": 1}'::jsonb,
  'El aforo y la espera quedan separados sin sobreventa'
);

select pg_temp.actuar_como(
  '00000000-0000-0000-0000-00000000ef04'
);

select is(
  public.cancelar_reserva(
    '00000000-0000-0000-0000-00000000efc1'
  ) ->> 'cancelacion_tardia',
  'false',
  'La cancelación con antelación libera la plaza sin penalización tardía'
);

reset role;

select is(
  (
    select estado
    from public.inscripciones
    where clase_id = '00000000-0000-0000-0000-00000000efc1'
      and alumno_id = '00000000-0000-0000-0000-00000000ef05'
  ),
  'inscrito',
  'El siguiente Alumno de la cola obtiene la plaza automáticamente'
);

select is(
  (
    select count(*)::int
    from public.notificaciones_outbox
    where user_id = '00000000-0000-0000-0000-00000000ef05'
      and data ->> 'type' = 'waitlist_promoted'
  ),
  1,
  'La promoción automática encola su notificación'
);

select pg_temp.actuar_como(
  '00000000-0000-0000-0000-00000000ef03'
);

select lives_ok(
  $$ insert into public.asistencias (
       clase_id,
       alumno_id,
       validado_por
     ) values (
       '00000000-0000-0000-0000-00000000efc1',
       '00000000-0000-0000-0000-00000000ef05',
       auth.uid()
     ) $$,
  'El Profesor valida la asistencia del Alumno promocionado'
);

reset role;

select is(
  (
    select count(*)::int
    from public.asistencias
    where clase_id = '00000000-0000-0000-0000-00000000efc1'
      and alumno_id = '00000000-0000-0000-0000-00000000ef05'
      and validado_por = '00000000-0000-0000-0000-00000000ef03'
  ),
  1,
  'La asistencia validada queda ligada al Profesor correcto'
);

select pg_temp.actuar_como(
  '00000000-0000-0000-0000-00000000ef02'
);

select is(
  (
    select count(*)::int
    from public.profiles
    where academia_id = public.current_academia_id()
  ),
  4,
  'El Dueño ve el equipo completo de su academia'
);

reset role;

select * from finish();
rollback;
