-- ITACA — Notificaciones push (FCM), Fase 1: almacén de tokens y outbox.
--
-- Modelo: cada dispositivo del usuario registra su token FCM en device_tokens.
-- Los eventos de negocio que deben notificar (nueva novedad, pedido listo,
-- suscripción impagada…) no llaman a Stripe/FCM desde el trigger (Postgres no
-- debe hacer HTTP síncrono en la transacción); en su lugar escriben una fila
-- en notificaciones_outbox, que una Edge Function programada procesa y envía
-- vía FCM, marcando cada fila como enviada. Así el envío es reintentabley
-- desacoplado del commit del evento.

-- ============================================================
-- Tokens de dispositivo (uno o varios por usuario)
-- ============================================================

create table if not exists public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

-- Cada usuario solo ve y gestiona sus propios tokens.
create policy device_tokens_select on public.device_tokens
  for select using (user_id = auth.uid());

create policy device_tokens_insert on public.device_tokens
  for insert with check (user_id = auth.uid());

create policy device_tokens_update on public.device_tokens
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy device_tokens_delete on public.device_tokens
  for delete using (user_id = auth.uid());

-- Alta/renovación idempotente del token del dispositivo actual. Si el token ya
-- existía asociado a otro usuario (móvil compartido, reinstalación), lo
-- reasigna al usuario actual.
create or replace function public.registrar_device_token(p_token text, p_platform text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'No autenticado.';
  end if;
  insert into public.device_tokens (token, user_id, platform)
  values (p_token, auth.uid(), p_platform)
  on conflict (token)
  do update set user_id = excluded.user_id,
                platform = excluded.platform,
                updated_at = now();
end;
$$;

-- ============================================================
-- Outbox de notificaciones (lo consume la Edge Function send-push)
-- ============================================================

create table if not exists public.notificaciones_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  titulo text not null,
  cuerpo text not null,
  data jsonb not null default '{}'::jsonb,
  enviada boolean not null default false,
  created_at timestamptz not null default now(),
  enviada_at timestamptz
);

create index if not exists notificaciones_outbox_pendientes_idx
  on public.notificaciones_outbox (created_at) where not enviada;

-- Solo el service_role (Edge Functions) lee/marca la outbox; nadie desde el
-- cliente. RLS activo sin políticas = acceso denegado a authenticated/anon.
alter table public.notificaciones_outbox enable row level security;

-- ============================================================
-- Disparador de ejemplo: encolar push a los alumnos al publicar una novedad
-- ============================================================

create or replace function public.encolar_push_nueva_novedad()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notificaciones_outbox (user_id, titulo, cuerpo, data)
  select p.id,
         'Nueva novedad',
         new.titulo,
         jsonb_build_object('tipo', 'novedad', 'novedad_id', new.id::text)
  from public.profiles p
  where p.academia_id = new.academia_id
    and p.rol = 'alumno'
    and p.id <> new.autor_id;
  return new;
end;
$$;

create trigger novedades_encolar_push
  after insert on public.novedades
  for each row execute function public.encolar_push_nueva_novedad();
