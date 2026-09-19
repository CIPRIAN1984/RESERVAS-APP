-- ITACA — Documentos del alumno: certificado médico y descargo de
-- responsabilidad firmado.
--
-- No hace falta un estado de revisión (pendiente/aprobado/rechazado): lo
-- único que pide el lanzamiento es saber, documento a documento, si está
-- subido o no, y poder verlo. Si algún día hace falta un flujo de
-- aprobación, se añade entonces.
--
-- Un alumno tiene como mucho un archivo vigente por tipo: volver a subirlo
-- reemplaza al anterior (upsert por `alumno_id, tipo`), igual que el avatar
-- de perfil. No se guarda historial de versiones anteriores.

create table public.documentos_alumno (
  id uuid primary key default gen_random_uuid(),
  -- academia_id se autocompleta desde el perfil del alumno vía trigger
  -- (mismo patrón que prestamos.academia_id en 0008_tienda.sql): no se
  -- confía en el cliente para decidir de qué academia es un documento.
  academia_id uuid not null references public.academias (id),
  alumno_id uuid not null references public.profiles (id),
  tipo text not null
    check (tipo in ('certificado_medico', 'descargo_responsabilidad')),
  -- Ruta dentro del bucket "documentos-alumnos": "<alumno_id>/<tipo>.<ext>".
  storage_path text not null,
  subido_por uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  unique (alumno_id, tipo)
);

create index documentos_alumno_academia_idx
  on public.documentos_alumno (academia_id);

create or replace function public.set_documento_alumno_academia()
returns trigger
language plpgsql
as $$
begin
  select academia_id into new.academia_id
    from public.profiles where id = new.alumno_id;
  return new;
end;
$$;

create trigger documentos_alumno_set_academia
  before insert on public.documentos_alumno
  for each row execute function public.set_documento_alumno_academia();

-- Postgres concede EXECUTE a PUBLIC en toda función nueva por defecto (la
-- migración 20260723143656 lo revocó para las que ya existían entonces,
-- pero cada función nueva vuelve a nacer abierta). No debe ser invocable
-- como RPC: el propio trigger la ejecuta con los privilegios de su dueño.
revoke execute on function public.set_documento_alumno_academia()
  from public, anon, authenticated;

-- ============================================================
-- RLS: documentos_alumno
--
-- Puede subir el propio alumno, su tutor (padre/madre, ver
-- es_padre_de() de 20260812112854), o el staff de su academia — en un
-- gimnasio es habitual que el certificado llegue en papel a recepción y
-- lo suba quien lleva el mostrador, no cada alumno desde su móvil.
-- Solo el staff (o el Administrador de plataforma) puede borrar uno, para
-- corregir un error de subida sin dejar que un alumno se quite de encima
-- su propio justificante.
-- ============================================================

alter table public.documentos_alumno enable row level security;

create policy documentos_alumno_select on public.documentos_alumno
  for select
  using (
    alumno_id = auth.uid()
    or public.es_padre_de(alumno_id)
    or (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

create policy documentos_alumno_insert on public.documentos_alumno
  for insert
  with check (
    subido_por = auth.uid()
    and (
      alumno_id = auth.uid()
      or public.es_padre_de(alumno_id)
      or (
        public.current_rol() in ('profesor', 'dueño')
        and public.academia_id_de(alumno_id) = public.current_academia_id()
      )
    )
  );

create policy documentos_alumno_update on public.documentos_alumno
  for update
  using (
    alumno_id = auth.uid()
    or public.es_padre_de(alumno_id)
    or (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
  )
  with check (
    subido_por = auth.uid()
    and (
      alumno_id = auth.uid()
      or public.es_padre_de(alumno_id)
      or (
        public.current_rol() in ('profesor', 'dueño')
        and public.academia_id_de(alumno_id) = public.current_academia_id()
      )
    )
  );

create policy documentos_alumno_delete on public.documentos_alumno
  for delete
  using (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

-- ============================================================
-- Storage: bucket privado (no como "avatars", que es público). Un
-- certificado médico es un dato de salud: nunca debe quedar servido con
-- una URL pública. El cliente accede con URLs firmadas de corta duración
-- (createSignedUrl), que respetan estas mismas políticas de storage.objects.
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'documentos-alumnos',
  'documentos-alumnos',
  false,
  10485760, -- 10 MiB: certificados escaneados o fotografiados
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do nothing;

create policy documentos_alumnos_select on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'documentos-alumnos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.es_padre_de(((storage.foldername(name))[1])::uuid)
      or (
        public.current_rol() in ('profesor', 'dueño')
        and public.academia_id_de(((storage.foldername(name))[1])::uuid) = public.current_academia_id()
      )
      or public.current_rol() = 'administrador'
    )
  );

create policy documentos_alumnos_insert on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'documentos-alumnos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.es_padre_de(((storage.foldername(name))[1])::uuid)
      or (
        public.current_rol() in ('profesor', 'dueño')
        and public.academia_id_de(((storage.foldername(name))[1])::uuid) = public.current_academia_id()
      )
    )
  );

create policy documentos_alumnos_update on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'documentos-alumnos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.es_padre_de(((storage.foldername(name))[1])::uuid)
      or (
        public.current_rol() in ('profesor', 'dueño')
        and public.academia_id_de(((storage.foldername(name))[1])::uuid) = public.current_academia_id()
      )
    )
  );

create policy documentos_alumnos_delete on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'documentos-alumnos'
    and (
      (
        public.current_rol() in ('profesor', 'dueño')
        and public.academia_id_de(((storage.foldername(name))[1])::uuid) = public.current_academia_id()
      )
      or public.current_rol() = 'administrador'
    )
  );
