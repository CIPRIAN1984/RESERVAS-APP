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
    DateTime? fechaFin,

    /// 'stripe' o 'efectivo'. Una cuota cobrada en mano no se cancela
    /// desde la app: no hay nada que cancelar en Stripe.
    String? proveedorPago,
  }) = _Suscripcion;

  /// Parses a row from a select with a `tarifa:tarifas(nombre, precio, periodicidad)` embed.
  factory Suscripcion.fromRow(Map<String, dynamic> row) {
    final tarifa = row['tarifa'] as Map<String, dynamic>?;
    return Suscripcion(
      id: row['id'] as String,
      alumnoId: row['alumno_id'] as String,
      tarifaId: row['tarifa_id'] as String,
      // Las condiciones con las que se compró (30/09/2026); las de la
      // tarifa de hoy solo si la fila es anterior y no las trae.
      tarifaNombre:
          row['tarifa_nombre'] as String? ?? tarifa?['nombre'] as String?,
      tarifaPrecio: row['precio'] as num? ?? tarifa?['precio'] as num?,
      tarifaPeriodicidad:
          row['periodicidad'] as String? ?? tarifa?['periodicidad'] as String?,
      estado: row['estado'] as String,
      paymentStatus: row['payment_status'] as String? ?? 'pending',
      fechaInicio: DateTime.parse(row['fecha_inicio'] as String),
      fechaFin: row['fecha_fin'] == null
          ? null
          : DateTime.parse(row['fecha_fin'] as String),
      proveedorPago: row['proveedor_pago'] as String?,
    );
  }
}
