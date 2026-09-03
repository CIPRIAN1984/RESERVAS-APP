-- Cierra un agujero de seguridad en relaciones_familia
--
-- Encontrado el 03/09/2026 al empezar el trabajo de familias y tutores, y
-- comprobado contra la base de datos de producción (dentro de una
-- transacción revertida, sin dejar nada tocado).
--
-- EL FALLO. La política de inserción de relaciones_familia solo comprobaba
-- quién decía ser el padre:
--
--     with check (parent_id = auth.uid())
--
-- pero **no comprobaba nada sobre el hijo**. Y `authenticated` tenía el
-- permiso INSERT de tabla. Así que cualquier persona con sesión iniciada
-- podía declararse "padre" de cualquier otro perfil de la app.
--
-- Eso no se queda ahí: la política de UPDATE de `profiles` concede permiso
-- sobre los hijos de uno (`es_padre_de(profiles.id)`). Encadenando las dos
-- cosas, un alumno cualquiera podía cambiarle a otro alumno el **nombre,
-- los apellidos y la foto** (las tres únicas columnas que `authenticated`
-- tiene concedidas; el rol, el estado y el cinturón siguen protegidos por
-- la lección de la migración 0013). Reproducido de verdad contra
-- producción: un alumno renombró a otro a «SECUESTRADO» y se revirtió.
--
-- EL ARREGLO. Hoy no hay ni una fila en relaciones_familia y la función de
-- familias está congelada (ver FREEZE.md), así que **ningún cliente
-- necesita escribir en esta tabla**. Se le quita el permiso de escritura y
-- se borran las políticas que lo permitían. Cuando se retome familias, el
-- alta de un hijo pasará por una RPC `security definer` que sí valide que
-- el hijo es un menor recién creado, no un perfil ajeno — igual que
-- `reservar_clase` es la única puerta para reservar.
--
-- De paso, dos permisos sobrantes que estaban a una política de distancia
-- de ser un desastre:
--   * `anon` (gente sin sesión) tenía INSERT, UPDATE y DELETE sobre
--     `relaciones_familia` y sobre `profiles` — incluidas las columnas
--     `rol`, `estado`, `academia_id` e `id` de `profiles`. Hoy no hace
--     daño porque `auth.uid()` es nulo y ninguna política de RLS le da
--     ninguna fila, pero es exactamente el tipo de permiso que convierte
--     un despiste futuro en que alguien se haga administrador.

-- ============================================================
-- 1. relaciones_familia: solo lectura para los clientes
-- ============================================================

drop policy if exists relaciones_familia_insert on public.relaciones_familia;
drop policy if exists relaciones_familia_update on public.relaciones_familia;
drop policy if exists relaciones_familia_delete on public.relaciones_familia;

revoke all on public.relaciones_familia from anon;
revoke insert, update, delete, truncate, references, trigger
  on public.relaciones_familia from authenticated;

-- La lectura se conserva: un padre tiene que poder ver de quién es padre.
-- La política relaciones_familia_select ya la limita a lo suyo y a su
-- propia academia.
grant select on public.relaciones_familia to authenticated;

-- ============================================================
-- 2. profiles: quien no ha iniciado sesión no escribe nada
-- ============================================================

-- Ojo con el orden (lección de la migración 0013): un `revoke` de columna
-- suelto no sirve de nada si el rol conserva el permiso de tabla entera.
-- Aquí se revoca a nivel de tabla, que arrastra también los de columna.
revoke insert, update, delete, truncate, references, trigger
  on public.profiles from anon;

-- `authenticated` conserva lo suyo, que ya estaba bien acotado:
-- SELECT de tabla y UPDATE solo de (nombre, apellidos, foto_url).
