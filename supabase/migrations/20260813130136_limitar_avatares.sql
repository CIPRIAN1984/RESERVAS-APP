-- El bucket "avatars" es público (lectura) y cualquier autenticado puede
-- escribir en su propia carpeta (storage_avatars.sql), pero no tenía límite
-- de tamaño ni de tipo de archivo. Con la API de Storage, nada obligaba a
-- que lo subido fuera realmente una imagen ni la mantenía por debajo de un
-- tamaño razonable: alguien podía subir un archivo enorme (gasto de
-- almacenamiento) o de un tipo distinto a imagen (el bucket es público, así
-- que ese archivo quedaría servido con la URL pública de Supabase Storage).
--
-- El cliente Flutter ya usa image_picker con calidad 85 para fotos de
-- perfil (perfil_screen.dart) — esto no cambia ese comportamiento, solo
-- pone un tope duro en el servidor para cuando algo no pasa por el cliente
-- oficial.
update storage.buckets
set
  file_size_limit = 5242880, -- 5 MiB
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'avatars';
