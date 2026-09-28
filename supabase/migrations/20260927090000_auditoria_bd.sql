-- ITACA — Auditoría completa del 27/09/2026: dos arreglos de base de datos.
--
-- 1. `set_documento_alumno_academia` era la única función del esquema sin
--    `search_path` fijo (aviso del asesor de seguridad de Supabase). Es un
--    trigger sin privilegios elevados, así que el riesgo era bajo, pero una
--    función sin search_path fijo resuelve `profiles` según quien la
--    ejecute. Se fija, y `todas_las_funciones_fijan_search_path_test.sql`
--    impide que vuelva a colarse otra.
--
-- 2. Índices por alumno en `inscripciones` y `asistencias`. El saldo de
--    clases (`_saldo_clases`), que corre en cada reserva y cada vez que un
--    alumno abre «Mi cuota», filtra las dos tablas por `alumno_id`, y
--    ninguna tenía índice que empezara por esa columna (aviso del asesor de
--    rendimiento). Con 166 alumnos y un año de clases son decenas de miles
--    de filas recorridas enteras en cada reserva.

create or replace function public.set_documento_alumno_academia()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  select academia_id into new.academia_id
    from public.profiles where id = new.alumno_id;
  return new;
end;
$$;

revoke execute on function public.set_documento_alumno_academia()
  from public, anon, authenticated;

create index if not exists inscripciones_alumno_idx
  on public.inscripciones (alumno_id, estado);

create index if not exists asistencias_alumno_idx
  on public.asistencias (alumno_id);
