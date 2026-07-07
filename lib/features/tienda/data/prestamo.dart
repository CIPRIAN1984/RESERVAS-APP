import 'package:freezed_annotation/freezed_annotation.dart';

part 'prestamo.freezed.dart';

@freezed
abstract class Prestamo with _$Prestamo {
  const Prestamo._();

  const factory Prestamo({
    required String id,
    required String alumnoId,
    String? alumnoNombre,
    String? productoId,
    String? productoNombre,
    String? descripcion,
    required DateTime fechaPrestamo,
    DateTime? fechaDevolucion,
  }) = _Prestamo;

  /// Parses a row from a select with an optional `alumno:profiles(nombre)`
  /// and `producto:productos(nombre)` embed.
  factory Prestamo.fromRow(Map<String, dynamic> row) {
    final alumno = row['alumno'] as Map<String, dynamic>?;
    final producto = row['producto'] as Map<String, dynamic>?;
    return Prestamo(
      id: row['id'] as String,
      alumnoId: row['alumno_id'] as String,
      alumnoNombre: alumno?['nombre'] as String?,
      productoId: row['producto_id'] as String?,
      productoNombre: producto?['nombre'] as String?,
      descripcion: row['descripcion'] as String?,
      fechaPrestamo: DateTime.parse(row['fecha_prestamo'] as String),
      fechaDevolucion: row['fecha_devolucion'] != null
          ? DateTime.parse(row['fecha_devolucion'] as String)
          : null,
    );
  }

  String get itemDescripcion => productoNombre ?? descripcion ?? 'Material';
  bool get devuelto => fechaDevolucion != null;
}
