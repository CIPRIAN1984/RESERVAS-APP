-- I+ — Eliminación definitiva del árbol de progreso (módulo de técnicas).
--
-- Decisión de producto de Cipri (julio 2026): el árbol de técnicas se retira
-- de raíz y no vuelve. Las técnicas que había eran una plantilla genérica de
-- relleno (berimbolo, loop choke, armbar…) que **no** es el sistema Ítaca; el
-- método pedagógico real vive en el repositorio `itacaplus` y no se replica
-- aquí.
--
-- Comprobado antes de borrar (29/07/2026, proyecto dpcdpcvjcutcqyqcacti):
--   tecnicas = 14 filas (exactamente las 14 de la plantilla por defecto)
--   media_tecnica = 0 filas
--   progreso_alumno_tecnica = 14 filas (auto-sembradas por trigger)
-- Es decir: ni una sola fila creada por una persona. No se pierde nada real.
--
-- Es una operación IRREVERSIBLE: una vez aplicada, las tablas y su contenido
-- desaparecen. Se aplica a producción solo con visto bueno explícito.

-- ============================================================
-- 1. aprobar_academia deja de sembrar técnicas
-- ============================================================
-- Se redefine antes de borrar la función que llamaba, para que la RPC nunca
-- quede apuntando a algo inexistente.

create or replace function public.aprobar_academia(p_academia_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_rol() <> 'administrador' then
    raise exception 'Solo un administrador puede aprobar academias.';
  end if;

  update public.academias
    set estado = 'approved', approved_by = auth.uid(), approved_at = now()
    where id = p_academia_id;

  update public.profiles
    set estado = 'activo'
    where academia_id = p_academia_id and estado = 'pendiente_aprobacion';
end;
$$;

-- Mantiene los mismos privilegios que fijó el endurecimiento de permisos.
revoke all on function public.aprobar_academia(uuid) from public, anon;
grant execute on function public.aprobar_academia(uuid) to authenticated;

-- ============================================================
-- 2. Triggers de siembra automática
-- ============================================================

drop trigger if exists profiles_seed_progreso on public.profiles;
drop trigger if exists tecnicas_seed_progreso on public.tecnicas;

-- ============================================================
-- 3. Funciones del módulo
-- ============================================================

drop function if exists public.sembrar_tecnicas_default(uuid);
drop function if exists public.seed_progreso_para_alumno();
drop function if exists public.seed_progreso_para_tecnica();

-- ============================================================
-- 4. Tablas (en orden de dependencia; cascade limpia políticas e índices)
-- ============================================================

drop table if exists public.progreso_alumno_tecnica cascade;
drop table if exists public.media_tecnica cascade;
drop table if exists public.tecnicas cascade;
