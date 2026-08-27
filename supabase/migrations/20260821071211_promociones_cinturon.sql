-- «Listo para graduarse»: cuánto lleva un alumno en su cinturón actual y
-- cuántos entrenos acumula desde entonces, para la ficha de Miembros.
--
-- Regla confirmada por Cipri: se cuenta desde la fecha de alta (para los
-- alumnos que ya había) y desde la última promoción en adelante. El ritmo
-- exigido es 3 entrenos/semana; niños gradúan de color cada 6 meses (≈26
-- semanas), adultos cada 2 años (≈104 semanas) — igual para cada transición,
-- de blanco a azul o de marrón a negro. El total acumulado cuenta, no un
-- mínimo semanal estricto.
--
-- `fecha_inicio_cinturon` arranca en `created_at` para quien ya estaba
-- (backfill) y en `now()` para cualquier alumno que se dé de alta a partir
-- de aquí (default de columna) — así nunca hace falta tocar el trigger de
-- registro.
alter table public.profiles
  add column if not exists fecha_inicio_cinturon timestamptz not null default now();

update public.profiles
  set fecha_inicio_cinturon = created_at
  where rol = 'alumno';

-- Promueve a un alumno de su academia a un cinturón nuevo y reinicia el
-- contador de entrenos. Solo Profesor/Dueño activos; el CHECK de
-- `profiles.cinturon` ya rechaza cualquier color inventado.
create or replace function public.promover_cinturon(
  p_alumno_id uuid,
  p_nuevo_cinturon text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_academia_id uuid;
  v_actor_rol text;
  v_actor_estado text;
  v_alumno_academia_id uuid;
  v_alumno_rol text;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select academia_id, rol, estado
    into v_actor_academia_id, v_actor_rol, v_actor_estado
    from public.profiles
    where id = v_actor_id;

  if not found
     or v_actor_rol not in ('profesor', 'dueño')
     or v_actor_estado <> 'activo'
     or v_actor_academia_id is null then
    raise exception 'Solo el Profesor o el Dueño activo pueden promover a un alumno.';
  end if;

  select academia_id, rol
    into v_alumno_academia_id, v_alumno_rol
    from public.profiles
    where id = p_alumno_id
    for update;

  if not found or v_alumno_academia_id <> v_actor_academia_id then
    raise exception 'El alumno no pertenece a tu academia.';
  end if;

  if v_alumno_rol <> 'alumno' then
    raise exception 'Solo se puede promover a un alumno.';
  end if;

  update public.profiles
    set cinturon = p_nuevo_cinturon, fecha_inicio_cinturon = now()
    where id = p_alumno_id;
end;
$$;

comment on function public.promover_cinturon(uuid, text) is
  'Permite al Profesor/Dueño activo cambiar el cinturón de un alumno de su academia y reiniciar su contador de entrenos.';

revoke all on function public.promover_cinturon(uuid, text)
  from public, anon;
grant execute on function public.promover_cinturon(uuid, text)
  to authenticated, service_role;
