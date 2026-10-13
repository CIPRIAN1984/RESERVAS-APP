import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'clase_resumen.dart';
import 'inscrito_alumno.dart';

class ParticipantesClase {
  const ParticipantesClase({
    required this.inscritos,
    required this.listaEspera,
    this.cancelacionesTardias = const [],
  });

  final List<InscritoAlumno> inscritos;
  final List<InscritoAlumno> listaEspera;

  /// Quien canceló dentro del margen de aviso: esa clase le cuenta como
  /// gastada. El Dueño o el Profesor pueden perdonársela
  /// ([ClasesRepository.perdonarCancelacionTardia]).
  final List<InscritoAlumno> cancelacionesTardias;
}

class ClasesRepository {
  ClasesRepository(this._client);

  final sb.SupabaseClient _client;

  Future<List<ClaseResumen>> listarClases({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final rows =
        await _client.rpc(
              'listar_clases_semana',
              params: {
                'p_desde': desde.toUtc().toIso8601String(),
                'p_hasta': hasta.toUtc().toIso8601String(),
              },
            )
            as List;
    return rows
        .map((r) => ClaseResumen.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> crearClase({
    required String academiaId,
    required String profesorId,
    required String titulo,
    String? descripcion,
    required DateTime fechaHoraInicio,
    required DateTime fechaHoraFin,
    required int aforoMaximo,
  }) async {
    await _client.from('clases').insert({
      'academia_id': academiaId,
      'profesor_id': profesorId,
      'titulo': titulo,
      'descripcion': descripcion,
      'fecha_hora_inicio': fechaHoraInicio.toUtc().toIso8601String(),
      'fecha_hora_fin': fechaHoraFin.toUtc().toIso8601String(),
      'aforo_maximo': aforoMaximo,
    });
  }

  /// Creates a weekly recurring-class template. Concrete sessions are then
  /// materialized into `clases` by the generation job (see
  /// `generar_clases_recurrentes`); [generarAhora] triggers it immediately so
  /// the upcoming weeks appear without waiting for the scheduled run.
  Future<void> crearPlantillaRecurrente({
    required String academiaId,
    required String profesorId,
    required String titulo,
    String? descripcion,
    required int diaSemana, // 0 = domingo
    required String horaInicio, // 'HH:mm'
    required int duracionMin,
    required int aforoMaximo,
    bool generarAhora = true,
  }) async {
    await _client.from('clases_recurrentes').insert({
      'academia_id': academiaId,
      'profesor_id': profesorId,
      'titulo': titulo,
      'descripcion': descripcion,
      'dia_semana': diaSemana,
      'hora_inicio': horaInicio,
      'duracion_min': duracionMin,
      'aforo_maximo': aforoMaximo,
    });
    if (generarAhora) await generarClasesRecurrentes();
  }

  /// Materializes upcoming sessions from this academia's active templates.
  /// Idempotent; scoped to the caller's academia and staff-only server-side.
  Future<int> generarClasesRecurrentes() async {
    final generadas = await _client.rpc('generar_mis_clases_recurrentes');
    return (generadas as int?) ?? 0;
  }

  /// Vuelve a pedir los datos propios de una clase (título, horario, aforo,
  /// estado) tras editarla/cerrarla/reabrirla, sin depender de que la
  /// pantalla de detalle reciba de nuevo el listado completo del día.
  Future<Map<String, dynamic>> obtenerClase(String claseId) async {
    return await _client
        .from('clases')
        .select(
          'titulo, descripcion, fecha_hora_inicio, fecha_hora_fin, '
          'aforo_maximo, estado',
        )
        .eq('id', claseId)
        .single();
  }

  /// Edita una clase ya publicada. Si cambia la hora, la RPC avisa por push
  /// a quienes ya tenían plaza o estaban en la lista de espera.
  Future<void> editarClase({
    required String claseId,
    required String titulo,
    String? descripcion,
    required DateTime fechaHoraInicio,
    required DateTime fechaHoraFin,
    required int aforoMaximo,
  }) async {
    await _client.rpc(
      'editar_clase',
      params: {
        'p_clase_id': claseId,
        'p_titulo': titulo,
        'p_descripcion': descripcion,
        'p_fecha_hora_inicio': fechaHoraInicio.toUtc().toIso8601String(),
        'p_fecha_hora_fin': fechaHoraFin.toUtc().toIso8601String(),
        'p_aforo_maximo': aforoMaximo,
      },
    );
  }

  /// Cierra (deja de admitir reservas nuevas, reversible) o reabre una
  /// clase.
  Future<void> cambiarEstadoClase({
    required String claseId,
    required bool cerrar,
  }) async {
    await _client.rpc(
      'cambiar_estado_clase',
      params: {'p_clase_id': claseId, 'p_cerrar': cerrar},
    );
  }

  /// Cancela la clase de forma terminal: libera a todos los apuntados
  /// (inscritos y lista de espera) y les avisa por notificación push.
  /// Devuelve cuántos alumnos se han visto afectados.
  Future<int> cancelarClase(String claseId) async {
    final notificados = await _client.rpc(
      'cancelar_clase',
      params: {'p_clase_id': claseId},
    );
    return (notificados as int?) ?? 0;
  }

  /// Reserva plaza. Sin [alumnoId] reserva para uno mismo; con él, para ese
  /// hijo — y el servidor comprueba que de verdad lo sea (`es_padre_de`), no
  /// se fía de lo que mande la app.
  Future<String> unirse({required String claseId, String? alumnoId}) async {
    final estado = await _client.rpc(
      'reservar_clase',
      params: {'p_clase_id': claseId, 'p_alumno_id': ?alumnoId},
    );
    return (estado as String?) ?? 'inscrito';
  }

  /// Cancela la reserva. Sin [alumnoId], la mía; con él, la de ese hijo.
  Future<bool> borrarse({required String claseId, String? alumnoId}) async {
    final resultado = await _client.rpc(
      'cancelar_reserva',
      params: {'p_clase_id': claseId, 'p_alumno_id': ?alumnoId},
    );
    if (resultado is Map<String, dynamic>) {
      return resultado['cancelacion_tardia'] == true;
    }
    return false;
  }

  Future<ParticipantesClase> listarParticipantes(String claseId) async {
    final inscripciones =
        await _client
                .from('inscripciones')
                .select(
                  'estado, cancelacion_tardia, alumno_id, alumno:profiles(nombre, apellidos, foto_url, cinturon)',
                )
                .eq('clase_id', claseId)
                // Las cancelaciones tardías también, para poder perdonarlas.
                .or(
                  'estado.eq.inscrito,estado.eq.espera,cancelacion_tardia.eq.true',
                )
                .order('created_at')
            as List;

    final asistencias =
        await _client
                .from('asistencias')
                .select('alumno_id')
                .eq('clase_id', claseId)
            as List;
    final validados = asistencias.map((a) => a['alumno_id'] as String).toSet();

    final cuotas = await _estadoCuota(claseId);

    final inscritos = <InscritoAlumno>[];
    final listaEspera = <InscritoAlumno>[];
    final tardias = <String, InscritoAlumno>{};

    for (final raw in inscripciones) {
      final row = raw as Map<String, dynamic>;
      if (row['estado'] == 'cancelado') {
        // Una por alumno aunque cancelara tarde dos veces la misma clase:
        // se perdonan juntas.
        tardias[row['alumno_id'] as String] =
            InscritoAlumno.fromInscripcionJson(row, asistenciaValidada: false);
        continue;
      }
      final enEspera = row['estado'] == 'espera';
      final alumno = InscritoAlumno.fromInscripcionJson(
        row,
        asistenciaValidada: !enEspera && validados.contains(row['alumno_id']),
        sinCuota: cuotas[row['alumno_id']]?.sinCuota ?? false,
        sinClases: cuotas[row['alumno_id']]?.sinClases ?? false,
      );
      if (enEspera) {
        listaEspera.add(alumno);
      } else {
        inscritos.add(alumno);
      }
    }

    return ParticipantesClase(
      inscritos: inscritos,
      listaEspera: listaEspera,
      cancelacionesTardias: tardias.values.toList(),
    );
  }

  /// Devuelve la clase a quien canceló tarde. Solo el Dueño o un Profesor
  /// de la academia (lo comprueba el servidor), y queda apuntado quién fue.
  Future<void> perdonarCancelacionTardia({
    required String claseId,
    required String alumnoId,
  }) async {
    await _client.rpc(
      'perdonar_cancelacion_tardia',
      params: {'p_clase_id': claseId, 'p_alumno_id': alumnoId},
    );
  }

  /// Quién de la clase sale «sin cuota» o «sin clases», calculado por el
  /// servidor con **la fecha de la clase** (`estado_cuota_participantes`).
  ///
  /// Antes «sin cuota» se miraba aquí con la cuota de hoy, mientras que
  /// `reservar_clase` mira la del día de la clase desde el 25/09: una clase
  /// de después de que acabara la cuota salía sin marcar. Y «sin clases»
  /// (reserva que se pasa de la tarifa tras una pausa o un cambio de fecha)
  /// solo lo sabe calcular el servidor (auditoría del 09/10/2026).
  Future<Map<String, ({bool sinCuota, bool sinClases})>> _estadoCuota(
    String claseId,
  ) async {
    final filas =
        await _client.rpc(
              'estado_cuota_participantes',
              params: {'p_clase_id': claseId},
            )
            as List;
    return {
      for (final fila in filas.cast<Map<String, dynamic>>())
        fila['alumno_id'] as String: (
          sinCuota: fila['sin_cuota'] as bool? ?? false,
          sinClases: fila['sin_clases'] as bool? ?? false,
        ),
    };
  }

  Future<List<InscritoAlumno>> listarInscritos(String claseId) async {
    return (await listarParticipantes(claseId)).inscritos;
  }

  /// Quién más viene a esta clase, para que los propios alumnos se vean
  /// entre ellos.
  ///
  /// A propósito **no** reutiliza [listarParticipantes]: esa consulta trae
  /// también si cada uno tiene la cuota al día (mirando `suscripciones`), un
  /// dato de pago que un compañero no debe ver. Aquí solo se piden nombre,
  /// foto y cinturón —lo que Cipri decidió que se enseña— y solo los
  /// confirmados (`inscrito`), no la lista de espera: a un compañero no le
  /// aporta ver quién está pendiente de plaza.
  Future<List<InscritoAlumno>> listarCompaneros(String claseId) async {
    final filas =
        await _client
                .from('inscripciones')
                .select(
                  'alumno_id, alumno:profiles(nombre, apellidos, foto_url, cinturon)',
                )
                .eq('clase_id', claseId)
                .eq('estado', 'inscrito')
                .order('created_at')
            as List;

    return filas
        .cast<Map<String, dynamic>>()
        .map(
          (row) => InscritoAlumno.fromInscripcionJson(
            row,
            asistenciaValidada: false,
          ),
        )
        .toList();
  }

  /// Solo los IDs de quien tiene plaza confirmada, para "Confirmar todos"
  /// desde la tarjeta de la vista de día — no hace falta el nombre, la
  /// foto ni el cinturón para eso, así que no reutiliza
  /// `listarParticipantes`.
  Future<List<String>> listarAlumnosInscritos(String claseId) async {
    final rows =
        await _client
                .from('inscripciones')
                .select('alumno_id')
                .eq('clase_id', claseId)
                .eq('estado', 'inscrito')
            as List;
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => row['alumno_id'] as String)
        .toList();
  }

  Future<void> marcarAsistencia({
    required String claseId,
    required String alumnoId,
    required String validadoPor,
  }) async {
    await _client
        .from('asistencias')
        .upsert(
          {
            'clase_id': claseId,
            'alumno_id': alumnoId,
            'validado_por': validadoPor,
          },
          onConflict: 'clase_id,alumno_id',
          ignoreDuplicates: true,
        );
  }

  /// Deshacer una asistencia marcada por error —incluida al confirmar todos
  /// de golpe, si luego resulta que uno no había venido.
  Future<void> deshacerAsistencia({
    required String claseId,
    required String alumnoId,
  }) async {
    await _client
        .from('asistencias')
        .delete()
        .eq('clase_id', claseId)
        .eq('alumno_id', alumnoId);
  }

  /// Pasar lista de golpe: confirma a todos los que llegan sin validar en un
  /// único viaje al servidor, en vez de uno por alumno. La política RLS de
  /// `asistencias` comprueba cada fila igual que en el alta individual, así
  /// que no hace falta ninguna RPC ni migración nueva para esto.
  Future<void> marcarAsistenciaEnBloque({
    required String claseId,
    required List<String> alumnoIds,
    required String validadoPor,
  }) async {
    if (alumnoIds.isEmpty) return;
    await _client
        .from('asistencias')
        .upsert(
          [
            for (final alumnoId in alumnoIds)
              {
                'clase_id': claseId,
                'alumno_id': alumnoId,
                'validado_por': validadoPor,
              },
          ],
          onConflict: 'clase_id,alumno_id',
          ignoreDuplicates: true,
        );
  }
}
