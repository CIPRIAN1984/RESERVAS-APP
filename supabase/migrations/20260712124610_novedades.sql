-- ITACA — Fase 6: Novedades (módulo 3).
--
-- Tablón de anuncios. Profesor/Dueño publican y fijan; Alumno solo lee.
-- Cualquier Profesor/Dueño de la academia puede fijar/editar/borrar (no solo
-- el autor original), igual que en `clases`, ya que es contenido de la
-- escuela, no personal del autor.

create table if not exists public.novedades (
  id uuid primary key default gen_random_uuid(),
  academia_id uuid not null references public.academias (id),
  autor_id uuid not null references public.profiles (id),
  titulo text not null,
  contenido text not null,
  fijado boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists novedades_academia_orden_idx
  on public.novedades (academia_id, fijado desc, created_at desc);

alter table public.novedades enable row level security;

create policy novedades_select on public.novedades
  for select
  using (
    academia_id = public.current_academia_id()
    or public.current_rol() = 'administrador'
  );

create policy novedades_insert on public.novedades
  for insert
  with check (
    autor_id = auth.uid()
    and academia_id = public.current_academia_id()
    and public.current_rol() in ('profesor', 'dueño')
  );

create policy novedades_update on public.novedades
  for update
  using (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  )
  with check (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

create policy novedades_delete on public.novedades
  for delete
  using (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );
