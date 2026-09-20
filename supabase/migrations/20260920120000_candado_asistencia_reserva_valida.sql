-- Punto 5 de la auditoría externa de seguridad de septiembre de 2026: la
-- política de INSERT de `asistencias` comprobaba quién validaba (staff de
-- la propia academia, sobre una clase de esa academia), pero nunca que el
-- alumno marcado tuviera una reserva `inscrito` en esa clase. Desde la app
-- no se explota — `_marcarAsistencia` solo se ofrece sobre la lista de
-- `listarParticipantes` (alumnos ya inscritos) — pero cualquiera con el
-- token de un profesor/dueño podía llamar directamente a la API y marcar
-- presente a un alumno que nunca reservó, inflando sus clases contadas
-- para el ranking y la graduación sin haber ocupado ninguna plaza real.
--
-- Se cierra en el servidor, no solo en la pantalla: la política exige
-- ahora una fila en `inscripciones` con estado 'inscrito' para el mismo
-- alumno y clase. 'espera' no vale — quien sigue en cola nunca llegó a
-- tener plaza.

drop policy if exists asistencias_insert on public.asistencias;

create policy asistencias_insert on public.asistencias
  for insert
  with check (
    validado_por = auth.uid()
    and public.current_rol() in ('profesor', 'dueño')
    and exists (
      select 1 from public.clases c
      where c.id = clase_id and c.academia_id = public.current_academia_id()
    )
    and exists (
      select 1 from public.inscripciones i
      where i.clase_id = asistencias.clase_id
        and i.alumno_id = asistencias.alumno_id
        and i.estado = 'inscrito'
    )
  );
