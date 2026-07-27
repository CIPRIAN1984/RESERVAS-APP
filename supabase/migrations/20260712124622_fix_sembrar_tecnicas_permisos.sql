-- Corrige un fallo de seguridad de la migración anterior: `sembrar_tecnicas_default`
-- es SECURITY DEFINER pero no comprobaba el rol de quien la llama. Al ser una
-- función en `public`, PostgREST la expone como RPC por defecto, así que
-- cualquier usuario autenticado podía invocarla directamente con un
-- academia_id arbitrario y sembrar técnicas en una academia ajena, saltándose
-- la política tecnicas_insert. Se añade la misma comprobación de rol que ya
-- tiene `aprobar_academia`.

create or replace function public.sembrar_tecnicas_default(p_academia_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_rol() <> 'administrador' then
    raise exception 'Solo un administrador puede sembrar la plantilla de técnicas.';
  end if;

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
