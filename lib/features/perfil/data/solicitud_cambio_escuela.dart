import 'package:freezed_annotation/freezed_annotation.dart';

part 'solicitud_cambio_escuela.freezed.dart';

/// A student's own request, as returned by the `listar_mis_solicitudes_cambio` RPC.
@freezed
abstract class MiSolicitudCambio with _$MiSolicitudCambio {
  const factory MiSolicitudCambio({
    required String id,
    required String estado,
    required String academiaDestinoId,
    required String academiaDestinoNombre,
    required DateTime createdAt,
  }) = _MiSolicitudCambio;

  factory MiSolicitudCambio.fromRow(Map<String, dynamic> row) =>
      MiSolicitudCambio(
        id: row['id'] as String,
        estado: row['estado'] as String,
        academiaDestinoId: row['academia_destino_id'] as String,
        academiaDestinoNombre: row['nombre'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}

/// A pending request targeting the caller's academia, as returned by the
/// `listar_solicitudes_pendientes_destino` RPC.
@freezed
abstract class SolicitudPendiente with _$SolicitudPendiente {
  const factory SolicitudPendiente({
    required String id,
    required String alumnoId,
    required String alumnoNombre,
    required String academiaOrigenId,
    required String academiaOrigenNombre,
    required DateTime createdAt,
  }) = _SolicitudPendiente;

  factory SolicitudPendiente.fromRow(Map<String, dynamic> row) =>
      SolicitudPendiente(
        id: row['id'] as String,
        alumnoId: row['alumno_id'] as String,
        alumnoNombre: row['nombre'] as String,
        academiaOrigenId: row['academia_origen_id'] as String,
        academiaOrigenNombre: row['academia_origen_nombre'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
