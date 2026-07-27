-- ITACA — Fase 4: Calendario y Clases (módulo 1).
--
-- Alcance MVP: cada fila de `clases` es una sesión concreta (fecha/hora
-- fijas), no una plantilla recurrente — no hay motor de recurrencia todavía.
-- Un Profesor crea una fila por cada sesión real.
--
-- Nota de permisos: además del Profesor, dejamos que el Dueño también pueda
-- crear/editar clases de su academia (muchos dueños de gimnasio también dan
-- clase, y el Dueño ya tiene visibilidad total de su academia).

create table if not exists public.clases (
  id uuid primary key default gen_random_uuid(),
  academia_id uuid not null references public.academias (id),
  profesor_id uuid not null references public.profiles (id),
  titulo text not null,
  descripcion text,
  fecha_hora_inicio timestamptz not null,
  fecha_hora_fin timestamptz not null,
  aforo_maximo int not null check (aforo_maximo > 0),
  created_at timestamptz not null default now(),
  constraint clases_horario_valido check (fecha_hora_fin > fecha_hora_inicio)
);

create index if not exists clases_academia_fecha_idx on public.clases (academia_id, fecha_hora_inicio);

create table if not exists public.inscripciones (
  id uuid primary key default gen_random_uuid(),
  clase_id uuid not null references public.clases (id) on delete cascade,
  alumno_id uuid not null references public.profiles (id),
  -- Se autocompleta desde clases.academia_id vía trigger (no se confía en el cliente).
  academia_id uuid not null references public.academias (id),
  estado text not null default 'inscrito' check (estado in ('inscrito', 'cancelado')),
  created_at timestamptz not null default now()
);

-- Solo una inscripción activa por alumno y clase.
create unique index if not exists inscripciones_activa_unica_idx
  on public.inscripciones (clase_id, alumno_id)
  where estado = 'inscrito';

create table if not exists public.asistencias (
  id uuid primary key default gen_random_uuid(),
  clase_id uuid not null references public.clases (id) on delete cascade,
  alumno_id uuid not null references public.profiles (id),
  -- Se autocompleta desde clases.academia_id vía trigger.
  academia_id uuid not null references public.academias (id),
  validado_por uuid not null references public.profiles (id),
  fecha timestamptz not null default now(),
  unique (clase_id, alumno_id)
);

create index if not exists asistencias_academia_fecha_idx on public.asistencias (academia_id, fecha);

-- ============================================================
-- Triggers
-- ============================================================

-- Autocompleta academia_id desde la clase referenciada, para no depender de
-- lo que envíe el cliente (y para que las políticas RLS sean fiables).
create or replace function public.set_academia_id_desde_clase()
returns trigger
language plpgsql
as $$
begin
  select academia_id into new.academia_id from public.clases where id = new.clase_id;
  return new;
end;
$$;

create trigger inscripciones_set_academia
  before insert on public.inscripciones
  for each row execute function public.set_academia_id_desde_clase();

create trigger asistencias_set_academia
  before insert on public.asistencias
  for each row execute function public.set_academia_id_desde_clase();

-- Aforo: rechaza la inscripción si ya se alcanzó el máximo de la clase.
-- Comprobado en base de datos (no solo en la app) para evitar condiciones de
-- carrera con altas concurrentes.
create or replace function public.check_aforo()
returns trigger
language plpgsql
as $$
declare
  v_aforo_maximo int;
  v_inscritos int;
begin
  if new.estado <> 'inscrito' then
    return new;
  end if;

  select aforo_maximo into v_aforo_maximo from public.clases where id = new.clase_id;
  select count(*) into v_inscritos
    from public.inscripciones
    where clase_id = new.clase_id and estado = 'inscrito';

  if v_inscritos >= v_aforo_maximo then
    raise exception 'Aforo completo para esta clase.';
  end if;

  return new;
end;
$$;

create trigger inscripciones_check_aforo
  before insert on public.inscripciones
  for each row execute function public.check_aforo();

-- ============================================================
-- RLS: clases
-- ============================================================

alter table public.clases enable row level security;

create policy clases_select on public.clases
  for select
  using (
    academia_id = public.current_academia_id()
    or public.current_rol() = 'administrador'
  );

create policy clases_insert on public.clases
  for insert
  with check (
    academia_id = public.current_academia_id()
    and public.current_rol() in ('profesor', 'dueño')
  );

create policy clases_update on public.clases
  for update
  using (
    (academia_id = public.current_academia_id() and (profesor_id = auth.uid() or public.current_rol() = 'dueño'))
    or public.current_rol() = 'administrador'
  )
  with check (
    (academia_id = public.current_academia_id() and (profesor_id = auth.uid() or public.current_rol() = 'dueño'))
    or public.current_rol() = 'administrador'
  );

create policy clases_delete on public.clases
  for delete
  using (
    (academia_id = public.current_academia_id() and (profesor_id = auth.uid() or public.current_rol() = 'dueño'))
    or public.current_rol() = 'administrador'
  );

-- ============================================================
-- RLS: inscripciones
-- ============================================================

alter table public.inscripciones enable row level security;

create policy inscripciones_select on public.inscripciones
  for select
  using (
    academia_id = public.current_academia_id()
    or public.current_rol() = 'administrador'
  );

-- Un alumno se inscribe a sí mismo, en una clase de su propia academia.
create policy inscripciones_insert on public.inscripciones
  for insert
  with check (
    alumno_id = auth.uid()
    and exists (
      select 1 from public.clases c
      where c.id = clase_id and c.academia_id = public.current_academia_id()
    )
  );

-- El alumno puede darse de baja (estado='cancelado'); profesor/dueño también
-- pueden gestionar inscripciones de su academia (p. ej. dar de baja a alguien).
create policy inscripciones_update on public.inscripciones
  for update
  using (
    alumno_id = auth.uid()
    or (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  )
  with check (
    alumno_id = auth.uid()
    or (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

-- ============================================================
-- RLS: asistencias
-- ============================================================

alter table public.asistencias enable row level security;

create policy asistencias_select on public.asistencias
  for select
  using (
    academia_id = public.current_academia_id()
    or public.current_rol() = 'administrador'
  );

-- Solo Profesor/Dueño validan asistencia, sobre clases de su propia academia.
create policy asistencias_insert on public.asistencias
  for insert
  with check (
    validado_por = auth.uid()
    and public.current_rol() in ('profesor', 'dueño')
    and exists (
      select 1 from public.clases c
      where c.id = clase_id and c.academia_id = public.current_academia_id()
    )
  );

-- ============================================================
-- RPC: listado semanal para el calendario (Inicio)
-- ============================================================

-- security invoker (por defecto): respeta las RLS de clases/inscripciones
-- del usuario que llama, así que el filtro por academia ya queda cubierto
-- por clases_select sin necesidad de repetirlo aquí.
create or replace function public.listar_clases_semana(p_desde timestamptz, p_hasta timestamptz)
returns table (
  id uuid,
  titulo text,
  descripcion text,
  fecha_hora_inicio timestamptz,
  fecha_hora_fin timestamptz,
  aforo_maximo int,
  profesor_id uuid,
  profesor_nombre text,
  inscritos_count bigint,
  mi_estado text
)
language sql
stable
as $$
  select
    c.id,
    c.titulo,
    c.descripcion,
    c.fecha_hora_inicio,
    c.fecha_hora_fin,
    c.aforo_maximo,
    c.profesor_id,
    p.nombre as profesor_nombre,
    (select count(*) from public.inscripciones i
       where i.clase_id = c.id and i.estado = 'inscrito') as inscritos_count,
    (select i.estado from public.inscripciones i
       where i.clase_id = c.id and i.alumno_id = auth.uid()
       order by i.created_at desc limit 1) as mi_estado
  from public.clases c
  join public.profiles p on p.id = c.profesor_id
  where c.fecha_hora_inicio >= p_desde and c.fecha_hora_inicio < p_hasta
  order by c.fecha_hora_inicio;
$$;
