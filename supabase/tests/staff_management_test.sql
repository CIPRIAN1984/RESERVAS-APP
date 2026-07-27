-- Regresiones de gestión de Profesores y equipo.
begin;
select plan(9);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000e101', 'dueno-equipo-a@test.dev'),
  ('00000000-0000-0000-0000-00000000e102', 'alumno-equipo-a@test.dev'),
  ('00000000-0000-0000-0000-00000000e103', 'profesor-equipo-a@test.dev'),
  ('00000000-0000-0000-0000-00000000e201', 'dueno-equipo-b@test.dev'),
  ('00000000-0000-0000-0000-00000000e202', 'alumno-equipo-b@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-00000000e1aa', 'Equipo A', 'approved'),
  ('00000000-0000-0000-0000-00000000e2bb', 'Equipo B', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-00000000e101', '00000000-0000-0000-0000-00000000e1aa', 'dueño', 'Dueño A', 'activo'),
  ('00000000-0000-0000-0000-00000000e102', '00000000-0000-0000-0000-00000000e1aa', 'alumno', 'Alumno A', 'activo'),
  ('00000000-0000-0000-0000-00000000e103', '00000000-0000-0000-0000-00000000e1aa', 'profesor', 'Profesor A', 'activo'),
  ('00000000-0000-0000-0000-00000000e201', '00000000-0000-0000-0000-00000000e2bb', 'dueño', 'Dueño B', 'activo'),
  ('00000000-0000-0000-0000-00000000e202', '00000000-0000-0000-0000-00000000e2bb', 'alumno', 'Alumno B', 'activo');

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

select ok(
  has_function_privilege(
    'authenticated',
    'public.cambiar_rol_miembro(uuid,text)',
    'EXECUTE'
  ),
  'Authenticated puede alcanzar la RPC, que valida el rol en servidor'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e102');
select throws_ok(
  $$ select public.cambiar_rol_miembro(
       '00000000-0000-0000-0000-00000000e103',
       'alumno'
     ) $$,
  null,
  'Un Alumno no puede gestionar roles'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e101');
select throws_ok(
  $$ select public.cambiar_rol_miembro(
       '00000000-0000-0000-0000-00000000e202',
       'profesor'
     ) $$,
  null,
  'El Dueño no puede cambiar un miembro de otra academia'
);

select throws_ok(
  $$ select public.cambiar_rol_miembro(
       '00000000-0000-0000-0000-00000000e201',
       'profesor'
     ) $$,
  null,
  'El Dueño no puede modificar a otro Dueño'
);

select throws_ok(
  $$ select public.cambiar_rol_miembro(
       '00000000-0000-0000-0000-00000000e101',
       'profesor'
     ) $$,
  null,
  'El Dueño no puede modificar su propio rol'
);

select lives_ok(
  $$ select public.cambiar_rol_miembro(
       '00000000-0000-0000-0000-00000000e102',
       'profesor'
     ) $$,
  'El Dueño puede ascender a un Alumno de su academia'
);

reset role;
select is(
  (
    select rol
    from public.profiles
    where id = '00000000-0000-0000-0000-00000000e102'
  ),
  'profesor',
  'El ascenso queda persistido'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-00000000e101');
select lives_ok(
  $$ select public.cambiar_rol_miembro(
       '00000000-0000-0000-0000-00000000e103',
       'alumno'
     ) $$,
  'El Dueño puede devolver un Profesor al rol Alumno'
);

reset role;
select is(
  (
    select rol
    from public.profiles
    where id = '00000000-0000-0000-0000-00000000e103'
  ),
  'alumno',
  'El cambio de Profesor a Alumno queda persistido'
);

select * from finish();
rollback;
