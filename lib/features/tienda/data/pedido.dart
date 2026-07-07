import 'package:freezed_annotation/freezed_annotation.dart';

part 'pedido.freezed.dart';

@freezed
abstract class Pedido with _$Pedido {
  const factory Pedido({
    required String id,
    required String alumnoId,
    String? alumnoNombre,
    required String productoId,
    String? productoNombre,
    required int cantidad,
    required String estado,
    required num precioSnapshot,
    required String paymentStatus,
    required DateTime createdAt,
  }) = _Pedido;

  /// Parses a row from a select with optional `alumno:profiles(nombre)` and
  /// `producto:productos(nombre)` embeds.
  factory Pedido.fromRow(Map<String, dynamic> row) {
    final alumno = row['alumno'] as Map<String, dynamic>?;
    final producto = row['producto'] as Map<String, dynamic>?;
    return Pedido(
      id: row['id'] as String,
      alumnoId: row['alumno_id'] as String,
      alumnoNombre: alumno?['nombre'] as String?,
      productoId: row['producto_id'] as String,
      productoNombre: producto?['nombre'] as String?,
      cantidad: row['cantidad'] as int,
      estado: row['estado'] as String,
      precioSnapshot: row['precio_snapshot'] as num,
      paymentStatus: row['payment_status'] as String? ?? 'pending',
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
