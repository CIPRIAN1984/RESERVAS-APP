import 'package:freezed_annotation/freezed_annotation.dart';

part 'suscripcion.freezed.dart';

@freezed
abstract class Suscripcion with _$Suscripcion {
  const factory Suscripcion({
    required String id,
    required String alumnoId,
    required String tarifaId,
    String? tarifaNombre,
    num? tarifaPrecio,
    String? tarifaPeriodicidad,
    required String estado,
    required String paymentStatus,
    required DateTime fechaInicio,
  }) = _Suscripcion;

  /// Parses a row from a select with a `tarifa:tarifas(nombre, precio, periodicidad)` embed.
  factory Suscripcion.fromRow(Map<String, dynamic> row) {
    final tarifa = row['tarifa'] as Map<String, dynamic>?;
    return Suscripcion(
      id: row['id'] as String,
      alumnoId: row['alumno_id'] as String,
      tarifaId: row['tarifa_id'] as String,
      tarifaNombre: tarifa?['nombre'] as String?,
      tarifaPrecio: tarifa?['precio'] as num?,
      tarifaPeriodicidad: tarifa?['periodicidad'] as String?,
      estado: row['estado'] as String,
      paymentStatus: row['payment_status'] as String? ?? 'pending',
      fechaInicio: DateTime.parse(row['fecha_inicio'] as String),
    );
  }
}
