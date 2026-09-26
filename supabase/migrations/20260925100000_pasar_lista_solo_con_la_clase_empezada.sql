-- ITACA — Solo se puede confirmar asistencia de una clase que ya ha
-- empezado (o empieza en menos de media hora).
--
-- Auditoría externa del 23/09/2026, punto 4: «Confirmar todos» —y el
-- «Validar» de cada alumno— se podían usar con una clase de mañana, o de la
-- semana que viene. Eso marca presente a gente que todavía no ha venido: el
-- historial, el ranking y la graduación cuentan entrenos que no han pasado.
--
-- La media hora de margen es para poder marcar a la gente según llega. Tiene
-- que coincidir con `margenPasarLista` en la app
-- (lib/features/calendario/domain/pasar_lista.dart).
--
-- El resto de la política no cambia (ver 20260920120000): staff de la
-- academia de la clase, y el alumno con una reserva 'inscrito'.

drop policy if exists asistencias_insert on public.asistencias;

create policy asistencias_insert on public.asistencias
  for insert
  with check (
    validado_por = auth.uid()
    and public.current_rol() in ('profesor', 'dueño')
    and exists (
      select 1 from public.clases c
      where c.id = clase_id
        and c.academia_id = public.current_academia_id()
        and c.fecha_hora_inicio <= now() + interval '30 minutes'
    )
    and exists (
      select 1 from public.inscripciones i
      where i.clase_id = asistencias.clase_id
        and i.alumno_id = asistencias.alumno_id
        and i.estado = 'inscrito'
    )
  );
