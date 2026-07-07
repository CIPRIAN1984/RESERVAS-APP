-- ITACA — Fase 7: Árbol de Progreso (módulo 4).
--
-- El árbol de técnicas es por academia (no global), con una plantilla por
-- defecto sembrada al aprobar la academia (ver `sembrar_tecnicas_default` y
-- el redefine de `aprobar_academia` al final). El progreso de cada alumno se
-- pre-siembra automáticamente vía triggers, tanto al añadir una técnica
-- nueva (para todos los alumnos ya existentes) como al dar de alta un
-- alumno nuevo (para todas las técnicas ya existentes) — así siempre hay un
-- set completo de filas que consultar, sin huecos.

create table if not exists public.tecnicas (
  id uuid primary key default gen_random_uuid(),
  academia_id uuid not null references public.academias (id),
  cinturon text not null check (cinturon in ('blanco', 'azul', 'morado', 'marron', 'negro')),
  nombre text not null,
  descripcion text,
  orden int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists tecnicas_academia_cinturon_idx on public.tecnicas (academia_id, cinturon, orden);

create table if not exists public.media_tecnica (
  id uuid primary key default gen_random_uuid(),
  tecnica_id uuid not null references public.tecnicas (id) on delete cascade,
  tipo text not null check (tipo in ('video', 'foto')),
  url text not null,
  subido_por uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

create table if not exists public.progreso_alumno_tecnica (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references public.profiles (id),
  tecnica_id uuid not null references public.tecnicas (id) on delete cascade,
  estado text not null default 'bloqueada' check (estado in ('bloqueada', 'en_proceso', 'conseguida')),
  marcado_por uuid references public.profiles (id),
  updated_at timestamptz not null default now(),
  unique (alumno_id, tecnica_id)
);

-- ============================================================
-- Triggers de siembra automática (security definer: se ejecutan con
-- privilegios elevados para no depender de políticas RLS de INSERT sobre
-- progreso_alumno_tecnica, que intencionadamente no existen para usuarios
-- normales — todas las filas de progreso nacen aquí, nunca por INSERT
-- directo de la app).
-- ============================================================

create or replace function public.seed_progreso_para_tecnica()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.progreso_alumno_tecnica (alumno_id, tecnica_id, estado)
  select p.id, new.id, 'bloqueada'
  from public.profiles p
  where p.academia_id = new.academia_id and p.rol = 'alumno'
  on conflict (alumno_id, tecnica_id) do nothing;
  return new;
end;
$$;

create trigger tecnicas_seed_progreso
  after insert on public.tecnicas
  for each row execute function public.seed_progreso_para_tecnica();

create or replace function public.seed_progreso_para_alumno()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.rol = 'alumno' and new.academia_id is not null then
    insert into public.progreso_alumno_tecnica (alumno_id, tecnica_id, estado)
    select new.id, t.id, 'bloqueada'
    from public.tecnicas t
    where t.academia_id = new.academia_id
    on conflict (alumno_id, tecnica_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger profiles_seed_progreso
  after insert on public.profiles
  for each row execute function public.seed_progreso_para_alumno();

-- ============================================================
-- RLS: tecnicas
-- ============================================================

alter table public.tecnicas enable row level security;

create policy tecnicas_select on public.tecnicas
  for select
  using (
    academia_id = public.current_academia_id()
    or public.current_rol() = 'administrador'
  );

create policy tecnicas_insert on public.tecnicas
  for insert
  with check (
    academia_id = public.current_academia_id()
    and public.current_rol() in ('profesor', 'dueño')
  );

create policy tecnicas_update on public.tecnicas
  for update
  using (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  )
  with check (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

create policy tecnicas_delete on public.tecnicas
  for delete
  using (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

-- ============================================================
-- RLS: media_tecnica (visibilidad/gestión heredada de la técnica padre)
-- ============================================================

alter table public.media_tecnica enable row level security;

create policy media_tecnica_select on public.media_tecnica
  for select
  using (
    exists (
      select 1 from public.tecnicas t
      where t.id = tecnica_id
        and (t.academia_id = public.current_academia_id() or public.current_rol() = 'administrador')
    )
  );

create policy media_tecnica_insert on public.media_tecnica
  for insert
  with check (
    subido_por = auth.uid()
    and public.current_rol() in ('profesor', 'dueño')
    and exists (
      select 1 from public.tecnicas t
      where t.id = tecnica_id and t.academia_id = public.current_academia_id()
    )
  );

create policy media_tecnica_delete on public.media_tecnica
  for delete
  using (
    public.current_rol() in ('profesor', 'dueño')
    and exists (
      select 1 from public.tecnicas t
      where t.id = tecnica_id and t.academia_id = public.current_academia_id()
    )
  );

-- ============================================================
-- RLS: progreso_alumno_tecnica
-- (sin política de INSERT/DELETE: todas las filas nacen vía los triggers
-- security definer de arriba; solo se permite SELECT y UPDATE del estado.)
-- ============================================================

alter table public.progreso_alumno_tecnica enable row level security;

create policy progreso_select on public.progreso_alumno_tecnica
  for select
  using (
    alumno_id = auth.uid()
    or exists (
      select 1 from public.tecnicas t
      where t.id = tecnica_id and t.academia_id = public.current_academia_id()
    )
    or public.current_rol() = 'administrador'
  );

-- Solo Profesor/Dueño/Administrador marcan el progreso de un alumno
-- (el alumno ve el suyo, pero no lo edita él mismo).
create policy progreso_update on public.progreso_alumno_tecnica
  for update
  using (
    (
      public.current_rol() in ('profesor', 'dueño')
      and exists (
        select 1 from public.tecnicas t
        where t.id = tecnica_id and t.academia_id = public.current_academia_id()
      )
    )
    or public.current_rol() = 'administrador'
  )
  with check (
    (
      public.current_rol() in ('profesor', 'dueño')
      and exists (
        select 1 from public.tecnicas t
        where t.id = tecnica_id and t.academia_id = public.current_academia_id()
      )
    )
    or public.current_rol() = 'administrador'
  );

-- ============================================================
-- Plantilla de técnicas por defecto + hook en la aprobación de academia
-- ============================================================

create or replace function public.sembrar_tecnicas_default(p_academia_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.tecnicas (academia_id, cinturon, nombre, descripcion, orden) values
    (p_academia_id, 'blanco', 'Guardia cerrada', 'Control básico desde la espalda con las piernas cerradas.', 1),
    (p_academia_id, 'blanco', 'Escape de montada', 'Recuperar la guardia desde debajo de montada.', 2),
    (p_academia_id, 'blanco', 'Armbar desde guardia', 'Palanca de brazo básica desde guardia cerrada.', 3),
    (p_academia_id, 'blanco', 'Estrangulación cruzada', 'Cross collar choke desde guardia cerrada.', 4),
    (p_academia_id, 'azul', 'Kimura', 'Llave de hombro desde varias posiciones.', 1),
    (p_academia_id, 'azul', 'Guillotina', 'Estrangulación frontal.', 2),
    (p_academia_id, 'azul', 'Triángulo', 'Estrangulación con las piernas desde guardia.', 3),
    (p_academia_id, 'azul', 'Paso de guardia toreando', 'Paso de pie sujetando las piernas.', 4),
    (p_academia_id, 'morado', 'Berimbolo', 'Inversión desde De la Riva.', 1),
    (p_academia_id, 'morado', 'Ataques de espalda', 'Control y finalización desde la espalda.', 2),
    (p_academia_id, 'morado', 'Loop choke', 'Estrangulación de solapa.', 3),
    (p_academia_id, 'marron', 'Control 50/50', 'Posición avanzada de piernas.', 1),
    (p_academia_id, 'marron', 'Sistemas de paso combinados', 'Encadenar varios pases de guardia.', 2),
    (p_academia_id, 'negro', 'Especialización personal', 'Desarrollo del juego propio bajo supervisión del profesor.', 1)
  on conflict do nothing;
end;
$$;

create or replace function public.aprobar_academia(p_academia_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_rol() <> 'administrador' then
    raise exception 'Solo un administrador puede aprobar academias.';
  end if;

  update public.academias
    set estado = 'approved', approved_by = auth.uid(), approved_at = now()
    where id = p_academia_id;

  update public.profiles
    set estado = 'activo'
    where academia_id = p_academia_id and estado = 'pendiente_aprobacion';

  perform public.sembrar_tecnicas_default(p_academia_id);
end;
$$;
