-- Fase 6 del plan de mejora · Novedades: avisos del gimnasio.
-- Los publica el personal (propietario, administración, recepción y
-- profesores); los leen los miembros activos de la sede al momento.

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 120),
  body text not null default '' check (length(body) <= 4000),
  pinned boolean not null default false,
  author_profile_id uuid references public.profiles (id) on delete set null,
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index announcements_gym_idx on public.announcements (gym_id, pinned desc, published_at desc);
create trigger announcements_updated_at before update on public.announcements
  for each row execute function public.set_updated_at();

alter table public.announcements enable row level security;
revoke all on public.announcements from anon;

create policy announcements_select on public.announcements for select to authenticated
  using (public.has_role(gym_id, enum_range(null::public.gym_role)));

create policy announcements_insert on public.announcements for insert to authenticated
  with check (
    public.has_role(gym_id, array['owner', 'admin', 'front_desk', 'coach']::public.gym_role[])
    and author_profile_id = public.current_profile_id()
  );

-- Editar y borrar: el autor, o propietario y administración cualquiera
create policy announcements_update on public.announcements for update to authenticated
  using (
    public.has_role(gym_id, array['owner', 'admin']::public.gym_role[])
    or (author_profile_id = public.current_profile_id() and public.has_role(gym_id, array['front_desk', 'coach']::public.gym_role[]))
  )
  with check (public.has_role(gym_id, array['owner', 'admin', 'front_desk', 'coach']::public.gym_role[]));
create policy announcements_delete on public.announcements for delete to authenticated
  using (
    public.has_role(gym_id, array['owner', 'admin']::public.gym_role[])
    or (author_profile_id = public.current_profile_id() and public.has_role(gym_id, array['front_desk', 'coach']::public.gym_role[]))
  );

-- Nadie cambia el autor ni la sede de un aviso
create function public.protect_announcement() returns trigger
language plpgsql as $$
begin
  if new.gym_id is distinct from old.gym_id or new.author_profile_id is distinct from old.author_profile_id then
    raise exception 'No se puede cambiar la sede ni el autor de un aviso' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger announcements_protect before update on public.announcements
  for each row execute function public.protect_announcement();

-- Nombre del autor para mostrarlo (los alumnos no leen perfiles ajenos)
create function public.gym_announcements(p_gym uuid, p_limit integer default 20, p_before timestamptz default null)
returns table (id uuid, title text, body text, pinned boolean, published_at timestamptz, edited boolean,
               author_profile_id uuid, author_name text, can_edit boolean)
language sql stable security definer set search_path = '' as $$
  select a.id, a.title, a.body, a.pinned, a.published_at, a.updated_at > a.created_at + interval '1 minute', a.author_profile_id,
         split_part(coalesce(p.full_name, 'ITACA'), ' ', 1),
         public.has_role(a.gym_id, array['owner', 'admin']::public.gym_role[])
           or (a.author_profile_id = public.current_profile_id() and public.has_role(a.gym_id, array['front_desk', 'coach']::public.gym_role[]))
  from public.announcements a
  left join public.profiles p on p.id = a.author_profile_id
  where a.gym_id = p_gym
    and public.has_role(p_gym, enum_range(null::public.gym_role))
    and (p_before is null or a.published_at < p_before or a.pinned)
  order by a.pinned desc, a.published_at desc
  limit least(coalesce(p_limit, 20), 100)
$$;
revoke execute on function public.gym_announcements from public, anon;
grant execute on function public.gym_announcements to authenticated;

-- Tiempo real: los alumnos ven el aviso al momento
alter publication supabase_realtime add table public.announcements;
