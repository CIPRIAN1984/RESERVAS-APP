-- Corrige un fallo de diseño de la migración anterior: los embeds PostgREST
-- (`alumno:profiles(...)`, `academia_origen:academias(...)`) dependen de que
-- el usuario que consulta tenga permiso RLS de SELECT sobre esas filas. Pero
-- por diseño, un Dueño no puede ver perfiles/academias de otra academia, así
-- que el embed devolvía `null` en vez del nombre — tanto para el Dueño
-- destino (no ve el nombre del alumno ni de la academia de origen) como para
-- el propio alumno (no ve el nombre de la academia destino, al no ser la
-- suya). Se añaden dos RPCs security definer que exponen únicamente el
-- nombre necesario, replicando la misma autorización que ya tenían las
-- políticas de solicitudes_select.

create or replace function public.listar_mis_solicitudes_cambio()
returns table (
  id uuid,
  estado text,
  academia_destino_id uuid,
  academia_destino_nombre text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select s.id, s.estado, s.academia_destino_id, ad.nombre, s.created_at
  from public.solicitudes_cambio_escuela s
  join public.academias ad on ad.id = s.academia_destino_id
  where s.alumno_id = auth.uid()
  order by s.created_at desc;
$$;

create or replace function public.listar_solicitudes_pendientes_destino()
returns table (
  id uuid,
  alumno_id uuid,
  alumno_nombre text,
  academia_origen_id uuid,
  academia_origen_nombre text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select s.id, s.alumno_id, p.nombre, s.academia_origen_id, ao.nombre, s.created_at
  from public.solicitudes_cambio_escuela s
  join public.profiles p on p.id = s.alumno_id
  join public.academias ao on ao.id = s.academia_origen_id
  where s.estado = 'pendiente'
    and (
      public.current_rol() = 'administrador'
      or (public.current_rol() = 'dueño' and s.academia_destino_id = public.current_academia_id())
    )
  order by s.created_at;
$$;
