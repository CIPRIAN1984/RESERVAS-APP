-- Deshacer una asistencia confirmada por error.
--
-- Cipri: "puede que le doy a confirmar a todos y me doy cuenta que a uno
-- no quiero confirmarlo, quiero tener la opción". Hasta ahora `asistencias`
-- solo tenía permiso de INSERT para `authenticated` — una vez marcada, no
-- había forma de deshacerla ni desde la app ni con una llamada directa a la
-- API: faltaba el propio GRANT de tabla, no solo la política de fila.
grant delete on table public.asistencias to authenticated;

-- Mismo alcance que ya usa `asistencias_insert`: solo profesor/dueño de la
-- propia academia. No se restringe a "quien la validó": si el dueño marcó
-- por error y el profesor lo ve después, tiene que poder deshacerlo igual.
create policy asistencias_delete on public.asistencias
  for delete
  using (
    academia_id = public.current_academia_id()
    and public.current_rol() in ('profesor', 'dueño')
  );
