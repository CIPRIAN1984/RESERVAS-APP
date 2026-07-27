-- ITACA — Fase 10: solicitud de cambio de escuela (resto del módulo 7, Perfil).
--
-- Flujo: el alumno solicita cambiarse a otra academia (aprobada); resuelve
-- el Dueño de la academia DESTINO (es quien decide si acepta al alumno),
-- con el Administrador como aprobador de respaldo. Un único paso de
-- aprobación, sin flujo multi-etapa.

create table if not exists public.solicitudes_cambio_escuela (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references public.profiles (id),
  -- Se autocompleta desde el perfil del alumno vía trigger.
  academia_origen_id uuid not null references public.academias (id),
  academia_destino_id uuid not null references public.academias (id),
  estado text not null default 'pendiente' check (estado in ('pendiente', 'aprobada', 'rechazada')),
  resuelto_por uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  resuelto_at timestamptz,
  constraint solicitud_origen_destino_distintos check (academia_origen_id <> academia_destino_id)
);

-- Un alumno solo puede tener una solicitud pendiente a la vez.
create unique index if not exists solicitudes_pendiente_unica_idx
  on public.solicitudes_cambio_escuela (alumno_id)
  where estado = 'pendiente';

-- ============================================================
-- Trigger de autocompletado
-- ============================================================

create or replace function public.set_solicitud_origen()
returns trigger
language plpgsql
as $$
begin
  select academia_id into new.academia_origen_id from public.profiles where id = new.alumno_id;
  return new;
end;
$$;

create trigger solicitudes_set_origen
  before insert on public.solicitudes_cambio_escuela
  for each row execute function public.set_solicitud_origen();

-- ============================================================
-- RLS
-- (sin política de UPDATE: la resolución solo ocurre vía la RPC
-- security definer de abajo, que comprueba la autorización ella misma.)
-- ============================================================

alter table public.solicitudes_cambio_escuela enable row level security;

create policy solicitudes_select on public.solicitudes_cambio_escuela
  for select
  using (
    alumno_id = auth.uid()
    or (academia_destino_id = public.current_academia_id() and public.current_rol() = 'dueño')
    or public.current_rol() = 'administrador'
  );

create policy solicitudes_insert on public.solicitudes_cambio_escuela
  for insert
  with check (
    alumno_id = auth.uid()
    and academia_destino_id <> public.current_academia_id()
  );

-- ============================================================
-- RPC: resolver solicitud (aprobar o rechazar)
-- ============================================================

create or replace function public.resolver_cambio_escuela(p_solicitud_id uuid, p_aprobar boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alumno_id uuid;
  v_destino_id uuid;
  v_estado_actual text;
begin
  select alumno_id, academia_destino_id, estado
    into v_alumno_id, v_destino_id, v_estado_actual
    from public.solicitudes_cambio_escuela
    where id = p_solicitud_id;

  if v_estado_actual is null then
    raise exception 'Solicitud no encontrada.';
  end if;

  if v_estado_actual <> 'pendiente' then
    raise exception 'La solicitud ya ha sido resuelta.';
  end if;

  if not (
    public.current_rol() = 'administrador'
    or (public.current_rol() = 'dueño' and v_destino_id = public.current_academia_id())
  ) then
    raise exception 'No autorizado para resolver esta solicitud.';
  end if;

  update public.solicitudes_cambio_escuela
    set estado = case when p_aprobar then 'aprobada' else 'rechazada' end,
        resuelto_por = auth.uid(),
        resuelto_at = now()
    where id = p_solicitud_id;

  if p_aprobar then
    update public.profiles set academia_id = v_destino_id where id = v_alumno_id;
  end if;
end;
$$;
