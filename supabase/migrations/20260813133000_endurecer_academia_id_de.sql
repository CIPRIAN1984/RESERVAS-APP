-- Revisión de seguridad de las 27 funciones security definer del esquema
-- public (RLS/GRANT), de cara al piloto. Resultado completo en el PR; aquí
-- solo el único fallo concreto que encontró: academia_id_de().
--
-- academia_id_de(p_profile_id uuid) devolvía la academia de CUALQUIER
-- perfil, sin comprobar nada — cualquier usuario autenticado podía llamar
-- /rest/v1/rpc/academia_id_de con el id de cualquier otro perfil y
-- averiguar su academia. Se usa dentro de la política RLS
-- relaciones_familia_select (arreglar_recursion_rls_familias.sql), así que
-- no se puede simplemente revocarle el permiso a authenticated — sin
-- EXECUTE, esa misma política dejaría de funcionar para todo el mundo,
-- porque Postgres comprueba el permiso de ejecutar una función en quien
-- hace la consulta, no en quien es su dueño, aunque la función sea
-- security definer.
--
-- Se limita en su lugar lo que devuelve: solo la academia del propio
-- llamante, de un perfil del que sea padre/tutor, o de un perfil que ya
-- comparta su misma academia — exactamente los tres casos que necesita la
-- política que la usa. El resto, null. Comprobado que esto no reintroduce
-- la recursión que arregló arreglar_recursion_rls_familias: consulta
-- relaciones_familia y profiles directamente (no a través de RLS, porque
-- security definer no vuelve a evaluar políticas sobre sus propias
-- consultas internas), igual que ya hacían es_padre_de() y
-- current_academia_id().

create or replace function public.academia_id_de(p_profile_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_profile_id = auth.uid()
     or exists (
       select 1 from public.relaciones_familia
       where parent_id = auth.uid() and child_id = p_profile_id
     )
     or exists (
       select 1
       from public.profiles yo
       join public.profiles ellos on ellos.academia_id = yo.academia_id
       where yo.id = auth.uid() and ellos.id = p_profile_id
     )
  then
    return (select academia_id from public.profiles where id = p_profile_id);
  end if;
  return null;
end;
$$;
