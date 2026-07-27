-- ITACA — Fase 3: bucket de Storage para fotos de perfil.
--
-- Convención de ruta: cada archivo se guarda bajo "<auth.uid()>/avatar.<ext>",
-- de modo que la política de escritura pueda restringir a cada usuario a su
-- propia carpeta comparando el primer segmento de la ruta con auth.uid().

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Lectura pública (las fotos de perfil no son sensibles y se muestran en
-- ranking, novedades, etc. a cualquier usuario de la academia).
create policy avatars_select on storage.objects
  for select
  using (bucket_id = 'avatars');

create policy avatars_insert_own on storage.objects
  for insert
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_update_own on storage.objects
  for update
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_delete_own on storage.objects
  for delete
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
