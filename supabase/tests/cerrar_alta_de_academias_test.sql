-- Tests pgTAP de que el alta de academias nuevas está cerrada en el
-- servidor, no solo escondida en la app.
--
-- Antes de esta migración, cualquiera que llamara al registro de Supabase
-- Auth con los metadatos correctos (`flujo: 'registro_academia'`) se creaba
-- una academia nueva y un perfil de dueño pendiente de aprobar, sin pasar
-- por ninguna pantalla de la app. Congelar el botón nunca cerró esa puerta.

begin;
select plan(3);

-- ── 1. El flujo registro_academia ya no crea nada ──────────────────────────
select throws_ok(
  $$ insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data)
     values (
       '00000000-0000-0000-0000-0000000000c1',
       'academia-nueva@test.dev',
       now(),
       jsonb_build_object(
         'flujo', 'registro_academia',
         'nombre', 'Alguien',
         'apellidos', 'Cualquiera',
         'nombre_academia', 'Academia Colada'
       )
     ) $$,
  'El alta de nuevas academias está desactivada: ITACA es la única '
    'academia operativa por ahora.',
  'Intentar registrar una academia nueva se rechaza en el propio trigger'
);

select is(
  (select count(*)::int from public.academias where nombre = 'Academia Colada'),
  0,
  'No se cuela ninguna academia nueva aunque el INSERT en auth.users fallara a medias'
);

-- ── 2. El flujo normal de unirse a una academia aprobada sigue intacto ─────
insert into public.academias (id, nombre, estado) values (
  '00000000-0000-0000-0000-0000000000a9',
  'Academia Ya Aprobada',
  'approved'
);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data)
values (
  '00000000-0000-0000-0000-0000000000c2',
  'alumno-normal@test.dev',
  now(),
  jsonb_build_object(
    'flujo', 'unirse',
    'nombre', 'Alumno',
    'apellidos', 'Normal',
    'academia_id', '00000000-0000-0000-0000-0000000000a9'
  )
);

select ok(
  exists (
    select 1 from public.profiles
    where id = '00000000-0000-0000-0000-0000000000c2'
      and rol = 'alumno'
      and estado = 'activo'
  ),
  'Unirse a una academia ya aprobada sigue funcionando exactamente igual'
);

select * from finish();
rollback;
