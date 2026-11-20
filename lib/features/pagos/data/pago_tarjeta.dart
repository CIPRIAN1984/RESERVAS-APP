/// Un pago de cuota con tarjeta, como lo guarda el servidor (`pagos_stripe`).
class PagoTarjeta {
  const PagoTarjeta({
    required this.id,
    required this.estado,
    required this.importeEsperado,
    this.importePagado,
    this.error,
    this.alumno,
    required this.creado,
  });

  factory PagoTarjeta.fromRow(Map<String, dynamic> row) {
    final alumno = row['alumno'] as Map<String, dynamic>?;
    return PagoTarjeta(
      id: row['id'] as String,
      estado: row['estado'] as String,
      importeEsperado: (row['importe_esperado'] as num).toDouble(),
      importePagado: (row['importe_pagado'] as num?)?.toDouble(),
      error: row['error'] as String?,
      alumno: alumno == null
          ? null
          : [
              alumno['nombre'],
              alumno['apellidos'],
            ].whereType<String>().join(' '),
      creado: DateTime.parse(row['created_at'] as String),
    );
  }

  final String id;

  /// `creado` (esperando el pago), `pagado`, `fallido`, `expirado`
  /// (abandonado), `reembolsado` o `revisar` (cobrado pero sin poder activar).
  final String estado;
  final double importeEsperado;
  final double? importePagado;
  final String? error;
  final String? alumno;
  final DateTime creado;

  /// Lo que la academia tiene que mirar sin esperar a que el alumno avise.
  bool get conProblema =>
      estado == 'revisar' ||
      estado == 'fallido' ||
      estado == 'expirado' ||
      (estado == 'creado' && error != null);
}
