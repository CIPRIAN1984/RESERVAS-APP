-- Regresiones del bootstrap de un único Administrador inicial.
begin;
select plan(9);

-- El trigger de alta ignora usuarios sin metadata de registro, que es justo
-- el estado esperado tras crear el usuario manualmente desde Auth.
insert into auth.users (id, email, email_confirmed_at) values
  (
    '00000000-0000-0000-0000-00000000ad01',
    'admin-confirmado@test.dev',
    now()
  ),
  (
    '00000000-0000-0000-0000-00000000ad02',
    'segundo-admin@test.dev',
    now()
  ),
  (
    '00000000-0000-0000-0000-00000000ad03',
    'usuario-con-perfil@test.dev',
    now()
  );

insert into public.academias (id, nombre, estado) values
  (
    '00000000-0000-0000-0000-00000000adaa',
    'Academia Bootstrap',
    'approved'
  );

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  (
    '00000000-0000-0000-0000-00000000ad03',
    '00000000-0000-0000-0000-00000000adaa',
    'alumno',
    'Usuario existente',
    'activo'
  );

select ok(
  not has_function_privilege(
    'anon',
    'public.bootstrap_initial_admin(uuid,text,text)',
    'EXECUTE'
  ),
  'Anon no puede iniciar el Administrador'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.bootstrap_initial_admin(uuid,text,text)',
    'EXECUTE'
  ),
  'Un usuario autenticado no puede autoascenderse'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.bootstrap_initial_admin(uuid,text,text)',
    'EXECUTE'
  ),
  'service_role puede ejecutar el bootstrap operativo'
);

set local role service_role;

select throws_ok(
  $$ select public.bootstrap_initial_admin(
       '00000000-0000-0000-0000-00000000ad99',
       'No existe',
       null
     ) $$,
  null,
  'No se puede crear un Administrador para un usuario inexistente'
);

select throws_ok(
  $$ select public.bootstrap_initial_admin(
       '00000000-0000-0000-0000-00000000ad03',
       'Usuario existente',
       null
     ) $$,
  null,
  'No se convierte en Administrador un perfil ya existente'
);

select lives_ok(
  $$ select public.bootstrap_initial_admin(
       '00000000-0000-0000-0000-00000000ad01',
       '  Admin  ',
       '  Inicial  '
     ) $$,
  'El usuario confirmado puede convertirse en el primer Administrador'
);

reset role;

select is(
  (
    select rol
    from public.profiles
    where id = '00000000-0000-0000-0000-00000000ad01'
  ),
  'administrador',
  'El perfil creado tiene el rol Administrador'
);

select ok(
  exists (
    select 1
    from public.profiles
    where id = '00000000-0000-0000-0000-00000000ad01'
      and academia_id is null
      and nombre = 'Admin'
      and apellidos = 'Inicial'
      and estado = 'activo'
  ),
  'El Administrador queda activo, sin academia y con datos normalizados'
);

set local role service_role;

select throws_ok(
  $$ select public.bootstrap_initial_admin(
       '00000000-0000-0000-0000-00000000ad02',
       'Segundo',
       'Administrador'
     ) $$,
  null,
  'No puede crearse un segundo Administrador mediante el bootstrap'
);

reset role;

select * from finish();
rollback;
