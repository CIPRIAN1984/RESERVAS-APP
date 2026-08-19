import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'clase_resumen.dart';
import 'inscrito_alumno.dart';

class ParticipantesClase {
  const ParticipantesClase({
    required this.inscritos,
    required this.listaEspera,
  });

  final List<InscritoAlumno> inscritos;
  final List<InscritoAlumno> listaEspera;
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

  Future<String> unirse({required String claseId}) async {
    final estado = await _client.rpc(
      'reservar_clase',
      params: {'p_clase_id': claseId},
    );
    return (estado as String?) ?? 'inscrito';
  }

  Future<bool> borrarse({required String claseId}) async {
    final resultado = await _client.rpc(
      'cancelar_reserva',
      params: {'p_clase_id': claseId},
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
                  'estado, alumno_id, alumno:profiles(nombre, apellidos, foto_url, cinturon)',
                )
                .eq('clase_id', claseId)
                .inFilter('estado', ['inscrito', 'espera'])
                .order('created_at')
            as List;

    final asistencias =
        await _client
                .from('asistencias')
                .select('alumno_id')
                .eq('clase_id', claseId)
            as List;
    final validados = asistencias.map((a) => a['alumno_id'] as String).toSet();

    final alConteAlDia = await _alumnosConCuotaAlDia(
      inscripciones
          .cast<Map<String, dynamic>>()
          .map((row) => row['alumno_id'] as String)
          .toList(),
    );

    final inscritos = <InscritoAlumno>[];
    final listaEspera = <InscritoAlumno>[];

    for (final raw in inscripciones) {
      final row = raw as Map<String, dynamic>;
      final enEspera = row['estado'] == 'espera';
      final alumno = InscritoAlumno.fromInscripcionJson(
        row,
        asistenciaValidada: !enEspera && validados.contains(row['alumno_id']),
        sinCuota: !alConteAlDia.contains(row['alumno_id']),
      );
      if (enEspera) {
        listaEspera.add(alumno);
      } else {
        inscritos.add(alumno);
      }
    }

    return ParticipantesClase(inscritos: inscritos, listaEspera: listaEspera);
  }

  /// Quién de estos alumnos tiene la cuota al día.
  ///
  /// Las condiciones son **las mismas** que comprueba `reservar_clase` en el
  /// servidor: activa, cobrada y dentro de fechas. Si aquí se relajaran, la
  /// lista de la clase diría «al corriente» de alguien a quien el servidor
  /// considera moroso.
  Future<Set<String>> _alumnosConCuotaAlDia(List<String> alumnoIds) async {
    if (alumnoIds.isEmpty) return const {};
    final ahora = DateTime.now().toUtc().toIso8601String();
    final rows =
        await _client
                .from('suscripciones')
                .select('alumno_id')
                .inFilter('alumno_id', alumnoIds)
                .eq('estado', 'activa')
                .eq('payment_status', 'active')
                .lte('fecha_inicio', ahora)
                .or('fecha_fin.is.null,fecha_fin.gt.$ahora')
            as List;
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => row['alumno_id'] as String)
        .toSet();
  }

  Future<List<InscritoAlumno>> listarInscritos(String claseId) async {
    return (await listarParticipantes(claseId)).inscritos;
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
