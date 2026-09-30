-- ITACA — El padre o tutor puede ver la cuota y el saldo de clases de sus
-- hijos.
--
-- Auditoría externa del 30/09/2026, punto 5: los hijos no tienen cuenta
-- propia (los gestiona el tutor), pero ni la RLS de `suscripciones` ni
-- `clases_restantes` dejaban al tutor ver la cuota de su hijo ni cuántas
-- clases le quedan. Ahora sí, y solo de SUS hijos: `es_padre_de` mira
-- `relaciones_familia`, en la que ningún cliente puede escribir a mano
-- (migración 20260903120000).

drop policy if exists suscripciones_select on public.suscripciones;
create policy suscripciones_select on public.suscripciones
  for select
  using (
    alumno_id = auth.uid()
    or public.es_padre_de(alumno_id)
    or (academia_id = public.current_academia_id() and public.current_rol() in ('profesor', 'dueño'))
    or public.current_rol() = 'administrador'
  );

create or replace function public.clases_restantes(p_alumno_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_rol text;
  v_actor_academia uuid;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select rol, academia_id into v_actor_rol, v_actor_academia
    from public.profiles where id = v_actor_id;

  -- El propio alumno, su padre o tutor, o el staff de su academia.
  if p_alumno_id <> v_actor_id and not public.es_padre_de(p_alumno_id) then
    if v_actor_rol not in ('dueño', 'profesor') then
      raise exception 'No autorizado.';
    end if;
    if not exists (
      select 1 from public.profiles
       where id = p_alumno_id and academia_id = v_actor_academia
    ) then
      raise exception 'No autorizado.';
    end if;
  end if;

  return public._saldo_clases(p_alumno_id);
end;
$function$;

revoke all on function public.clases_restantes(uuid) from public, anon;
grant execute on function public.clases_restantes(uuid) to authenticated;
