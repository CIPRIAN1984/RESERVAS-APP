-- Tests pgTAP de documentos_alumno (certificado médico / descargo de
-- responsabilidad): quién puede subir, ver y borrar el documento de quién,
-- y que el bucket de Storage sea privado con las mismas reglas.

begin;
select plan(19);

-- ── Semilla: dos academias, cada una con dueño, alumno y un hijo con tutor ──
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000e1', 'duenoDocsA@test.dev'),
  ('00000000-0000-0000-0000-0000000000e2', 'alumnoDocsA@test.dev'),
  ('00000000-0000-0000-0000-0000000000e3', 'tutorDocsA@test.dev'),
  ('00000000-0000-0000-0000-0000000000e4', 'hijoDocsA@test.dev'),
  ('00000000-0000-0000-0000-0000000000e5', 'duenoDocsB@test.dev'),
  ('00000000-0000-0000-0000-0000000000e6', 'alumnoDocsB@test.dev');

insert into public.academias (id, nombre, estado) values
  ('00000000-0000-0000-0000-000000000da1', 'Academia Docs A', 'approved'),
  ('00000000-0000-0000-0000-000000000da2', 'Academia Docs B', 'approved');

insert into public.profiles (id, academia_id, rol, nombre, estado) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-000000000da1', 'dueño', 'Dueño Docs A', 'activo'),
  ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-000000000da1', 'alumno', 'Alumno Docs A', 'activo'),
  ('00000000-0000-0000-0000-0000000000e3', '00000000-0000-0000-0000-000000000da1', 'alumno', 'Tutor Docs A', 'activo'),
  ('00000000-0000-0000-0000-0000000000e4', '00000000-0000-0000-0000-000000000da1', 'alumno', 'Hijo Docs A', 'activo'),
  ('00000000-0000-0000-0000-0000000000e5', '00000000-0000-0000-0000-000000000da2', 'dueño', 'Dueño Docs B', 'activo'),
  ('00000000-0000-0000-0000-0000000000e6', '00000000-0000-0000-0000-000000000da2', 'alumno', 'Alumno Docs B', 'activo');

insert into public.relaciones_familia (parent_id, child_id) values
  ('00000000-0000-0000-0000-0000000000e3', '00000000-0000-0000-0000-0000000000e4');

create or replace function pg_temp.actuar_como(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- ── 1. Un alumno sube su propio certificado ─────────────────────────────────
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000e2');
select lives_ok(
  $$ insert into public.documentos_alumno (alumno_id, tipo, storage_path, subido_por)
     values ('00000000-0000-0000-0000-0000000000e2', 'certificado_medico', '00000000-0000-0000-0000-0000000000e2/certificado_medico.pdf', '00000000-0000-0000-0000-0000000000e2') $$,
  'Un alumno puede subir su propio certificado médico'
);

select is(
  (select academia_id from public.documentos_alumno where alumno_id = '00000000-0000-0000-0000-0000000000e2'),
  '00000000-0000-0000-0000-000000000da1'::uuid,
  'La academia se autocompleta desde el perfil del alumno, no la manda el cliente'
);

-- ── 2. Un tutor sube el descargo de responsabilidad de su hijo ──────────────
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000e3');
select lives_ok(
  $$ insert into public.documentos_alumno (alumno_id, tipo, storage_path, subido_por)
     values ('00000000-0000-0000-0000-0000000000e4', 'descargo_responsabilidad', '00000000-0000-0000-0000-0000000000e4/descargo_responsabilidad.pdf', '00000000-0000-0000-0000-0000000000e3') $$,
  'El tutor puede subir el descargo de responsabilidad de su hijo'
);

-- ── 3. Un alumno NO puede subir un documento a nombre de otro ───────────────
select throws_ok(
  $$ insert into public.documentos_alumno (alumno_id, tipo, storage_path, subido_por)
     values ('00000000-0000-0000-0000-0000000000e4', 'certificado_medico', '00000000-0000-0000-0000-0000000000e4/certificado_medico.pdf', '00000000-0000-0000-0000-0000000000e2') $$,
  'new row violates row-level security policy for table "documentos_alumno"',
  'Un alumno sin relación con el niño no puede subir su documento'
);

-- ── 4. El dueño de la misma academia sube uno en nombre de un alumno ────────
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000e1');
select lives_ok(
  $$ insert into public.documentos_alumno (alumno_id, tipo, storage_path, subido_por)
     values ('00000000-0000-0000-0000-0000000000e2', 'descargo_responsabilidad', '00000000-0000-0000-0000-0000000000e2/descargo_responsabilidad.pdf', '00000000-0000-0000-0000-0000000000e1') $$,
  'El dueño puede subir un documento en nombre de un alumno de su academia (llega en papel a recepción)'
);

-- ── 5. El dueño de OTRA academia no puede subir ni ver ──────────────────────
-- Usa al hijo (e4), que a estas alturas solo tiene ocupado el tipo
-- descargo_responsabilidad (test 2): certificado_medico sigue libre, así
-- que un fallo aquí solo puede deberse a la RLS, no a la clave única.
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000e5');
select throws_ok(
  $$ insert into public.documentos_alumno (alumno_id, tipo, storage_path, subido_por)
     values ('00000000-0000-0000-0000-0000000000e4', 'certificado_medico', 'x/certificado_medico.pdf', '00000000-0000-0000-0000-0000000000e5') $$,
  'new row violates row-level security policy for table "documentos_alumno"',
  'El dueño de otra academia no puede subir el documento de un alumno ajeno'
);
select is(
  (select count(*)::int from public.documentos_alumno where alumno_id = '00000000-0000-0000-0000-0000000000e2'),
  0,
  'El dueño de otra academia no ve los documentos del alumno de la academia A'
);

-- ── 6. Aislamiento de lectura por academia y por familia ────────────────────
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000e2');
select is(
  (select count(*)::int from public.documentos_alumno),
  2,
  'El alumno solo ve sus propios documentos (certificado + descargo), no los del resto de la academia'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000e1');
select is(
  (select count(*)::int from public.documentos_alumno),
  3,
  'El dueño ve todos los documentos de su academia: el alumno (2) y el hijo (1)'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000e3');
select is(
  (select count(*)::int from public.documentos_alumno),
  1,
  'El tutor solo ve el documento de su hijo, no los del resto de la academia'
);

-- ── 7. Reemplazar un documento (upsert) sustituye al anterior ──────────────
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000e2');
select lives_ok(
  $$ insert into public.documentos_alumno (alumno_id, tipo, storage_path, subido_por)
     values ('00000000-0000-0000-0000-0000000000e2', 'certificado_medico', '00000000-0000-0000-0000-0000000000e2/certificado_medico.pdf', '00000000-0000-0000-0000-0000000000e2')
     on conflict (alumno_id, tipo)
     do update set storage_path = excluded.storage_path, subido_por = excluded.subido_por, created_at = now() $$,
  'Volver a subir el mismo tipo de documento actualiza el registro (upsert), no lo duplica'
);
select is(
  (select count(*)::int from public.documentos_alumno where alumno_id = '00000000-0000-0000-0000-0000000000e2'),
  2,
  'Sigue habiendo un único registro por (alumno, tipo) tras el upsert'
);

-- ── 8. El alumno no puede borrar su propio documento; el dueño sí ──────────
-- La RLS no lanza un error en un DELETE que no ve ninguna fila: simplemente
-- no borra nada. Se comprueba que la fila sigue ahí, en vez de esperar una
-- excepción que nunca llega.
delete from public.documentos_alumno
  where alumno_id = '00000000-0000-0000-0000-0000000000e2' and tipo = 'certificado_medico';

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000e1');
select is(
  (select count(*)::int from public.documentos_alumno
    where alumno_id = '00000000-0000-0000-0000-0000000000e2' and tipo = 'certificado_medico'),
  1,
  'Un alumno no puede borrar su propio certificado: la fila sigue ahí (solo el staff corrige errores)'
);

select lives_ok(
  $$ delete from public.documentos_alumno
     where alumno_id = '00000000-0000-0000-0000-0000000000e2' and tipo = 'certificado_medico' $$,
  'El dueño de la academia sí puede borrar un documento para corregirlo'
);

-- ── 9. El bucket es privado, con límite de tamaño y tipos de archivo ───────
select is(
  (select public from storage.buckets where id = 'documentos-alumnos'),
  false,
  'El bucket documentos-alumnos NO es público: son documentos sensibles'
);
select is(
  (select allowed_mime_types from storage.buckets where id = 'documentos-alumnos'),
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
  'El bucket solo admite imágenes o PDF'
);

-- ── 10. Storage: mismas reglas de aislamiento que la tabla ─────────────────
select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000e2');
select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('documentos-alumnos', '00000000-0000-0000-0000-0000000000e2/certificado_medico.pdf') $$,
  'Un alumno puede subir el archivo a su propia carpeta del bucket'
);

select pg_temp.actuar_como('00000000-0000-0000-0000-0000000000e5');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('documentos-alumnos', '00000000-0000-0000-0000-0000000000e2/otro.pdf') $$,
  'new row violates row-level security policy for table "objects"',
  'El dueño de otra academia no puede escribir en la carpeta de un alumno ajeno'
);

-- ── 11. El trigger de autocompletado no es una RPC pública ─────────────────
select ok(
  not has_function_privilege('anon', 'public.set_documento_alumno_academia()', 'EXECUTE'),
  'set_documento_alumno_academia no es invocable por anon: no es un endpoint RPC'
);

select * from finish();
rollback;
