-- ITACA — Completitud de producto: motor de clases recurrentes.
--
-- Hasta ahora cada fila de `clases` era una sesión suelta (ver comentario de
-- 0003_clases.sql): una academia con horario semanal fijo tenía que crear una
-- clase a mano por cada día. Se añade un motor de plantillas: el staff define
-- una plantilla semanal (día + hora + duración) y un job materializa las
-- sesiones concretas en `clases` con antelación. Las sesiones generadas son
-- filas normales de `clases`, así que inscripciones, aforo y el calendario
-- existente funcionan sin cambios.

-- ============================================================
-- Plantillas de clase recurrente
-- ============================================================

create table if not exists public.clases_recurrentes (
  id uuid primary key default gen_random_uuid(),
  academia_id uuid not null references public.academias (id),
  profesor_id uuid not null references public.profiles (id),
  titulo text not null,
  descripcion text,
  dia_semana int not null check (dia_semana between 0 and 6), -- 0 = domingo (ISO dow)
  hora_inicio time not null,
  duracion_min int not null check (duracion_min > 0),
  aforo_maximo int not null check (aforo_maximo > 0),
  activo boolean not null default true,
  fecha_inicio date not null default current_date,
  fecha_fin date, -- null = sin fin
  created_at timestamptz not null default now(),
  constraint clases_recurrentes_rango_valido check (fecha_fin is null or fecha_fin >= fecha_inicio)
);

create index if not exists clases_recurrentes_academia_idx
  on public.clases_recurrentes (academia_id, activo);

-- Enlaza cada sesión generada con su plantilla, para deduplicar la generación.
alter table public.clases
  add column if not exists plantilla_id uuid references public.clases_recurrentes (id) on delete set null;

-- Una plantilla no puede generar dos sesiones en el mismo instante de inicio.
create unique index if not exists clases_plantilla_inicio_idx
  on public.clases (plantilla_id, fecha_hora_inicio)
  where plantilla_id is not null;

-- ============================================================
-- RLS: mismas reglas que `clases` (staff de la academia gestiona; el resto lee)
-- ============================================================

alter table public.clases_recurrentes enable row level security;

create policy clases_recurrentes_select on public.clases_recurrentes
  for select using (
    academia_id = public.current_academia_id() or public.current_rol() = 'administrador'
  );

create policy clases_recurrentes_insert on public.clases_recurrentes
  for insert with check (
    academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño')
  );

create policy clases_recurrentes_update on public.clases_recurrentes
  for update using (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  ) with check (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

create policy clases_recurrentes_delete on public.clases_recurrentes
  for delete using (
    (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

-- ============================================================
-- Generación de sesiones a partir de las plantillas activas
-- ============================================================

-- Materializa en `clases` todas las sesiones de las plantillas activas cuyo
-- inicio cae en [p_desde, p_hasta). Idempotente: el índice único
-- (plantilla_id, fecha_hora_inicio) + ON CONFLICT DO NOTHING evita duplicar
-- las ya generadas, así que se puede ejecutar tantas veces como haga falta.
--
-- security definer: la ejecuta el scheduler (rol cron). Se revoca a los
-- clientes; la generación es un proceso de sistema, no una acción de usuario.
create or replace function public.generar_clases_recurrentes(
  p_desde date default current_date,
  p_hasta date default (current_date + interval '28 days')::date
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_generadas int;
begin
  with dias as (
    select d::date as dia
    from generate_series(p_desde, p_hasta - 1, interval '1 day') as d
  ),
  sesiones as (
    select
      cr.id as plantilla_id,
      cr.academia_id,
      cr.profesor_id,
      cr.titulo,
      cr.descripcion,
      (dias.dia + cr.hora_inicio) as inicio,
      (dias.dia + cr.hora_inicio + make_interval(mins => cr.duracion_min)) as fin,
      cr.aforo_maximo
    from public.clases_recurrentes cr
    join dias
      on extract(dow from dias.dia)::int = cr.dia_semana
    where cr.activo
      and dias.dia >= cr.fecha_inicio
      and (cr.fecha_fin is null or dias.dia <= cr.fecha_fin)
  ),
  insertadas as (
    insert into public.clases
      (academia_id, profesor_id, titulo, descripcion, fecha_hora_inicio, fecha_hora_fin, aforo_maximo, plantilla_id)
    select academia_id, profesor_id, titulo, descripcion, inicio, fin, aforo_maximo, plantilla_id
    from sesiones
    on conflict (plantilla_id, fecha_hora_inicio) where plantilla_id is not null
    do nothing
    returning 1
  )
  select count(*)::int into v_generadas from insertadas;
  return v_generadas;
end;
$$;

revoke all on function public.generar_clases_recurrentes(date, date) from public, anon;

-- Variante que puede invocar el staff desde la app ("generar ahora" al crear
-- una plantilla): genera SOLO para su propia academia y exige rol de gestión.
-- Reutiliza el mismo motor deduplicado limitando por academia con un filtro
-- previo; para mantenerlo simple, genera todo y confía en que las plantillas
-- ajenas ya deduplican — pero por seguridad comprueba rol y filtra.
create or replace function public.generar_mis_clases_recurrentes()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_academia uuid := public.current_academia_id();
  v_generadas int;
begin
  if public.current_rol() not in ('profesor', 'dueño') then
    raise exception 'Solo profesor o dueño pueden generar clases.';
  end if;

  with dias as (
    select d::date as dia
    from generate_series(current_date, (current_date + interval '28 days') - 1, interval '1 day') as d
  ),
  sesiones as (
    select cr.id as plantilla_id, cr.academia_id, cr.profesor_id, cr.titulo, cr.descripcion,
           (dias.dia + cr.hora_inicio) as inicio,
           (dias.dia + cr.hora_inicio + make_interval(mins => cr.duracion_min)) as fin,
           cr.aforo_maximo
    from public.clases_recurrentes cr
    join dias on extract(dow from dias.dia)::int = cr.dia_semana
    where cr.activo
      and cr.academia_id = v_academia
      and dias.dia >= cr.fecha_inicio
      and (cr.fecha_fin is null or dias.dia <= cr.fecha_fin)
  ),
  insertadas as (
    insert into public.clases
      (academia_id, profesor_id, titulo, descripcion, fecha_hora_inicio, fecha_hora_fin, aforo_maximo, plantilla_id)
    select academia_id, profesor_id, titulo, descripcion, inicio, fin, aforo_maximo, plantilla_id
    from sesiones
    on conflict (plantilla_id, fecha_hora_inicio) where plantilla_id is not null do nothing
    returning 1
  )
  select count(*)::int into v_generadas from insertadas;
  return v_generadas;
end;
$$;

-- Programa la generación semanal (mantiene ~4 semanas por delante) si pg_cron
-- está disponible; si no, se ejecuta manualmente / vía Edge Function.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.unschedule('itaca_generar_clases_recurrentes')
      where exists (select 1 from cron.job where jobname = 'itaca_generar_clases_recurrentes');
    perform cron.schedule(
      'itaca_generar_clases_recurrentes',
      '0 3 * * 1', -- lunes 03:00
      $cron$ select public.generar_clases_recurrentes(); $cron$
    );
  else
    raise notice 'pg_cron no disponible: generar_clases_recurrentes debe programarse manualmente.';
  end if;
end;
$$;
