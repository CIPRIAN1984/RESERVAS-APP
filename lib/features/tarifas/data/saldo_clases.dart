import 'package:freezed_annotation/freezed_annotation.dart';

part 'saldo_clases.freezed.dart';

/// Lo que devuelve la RPC `clases_restantes`: cuántas clases le quedan a un
/// alumno en el ciclo vigente de su tarifa.
@freezed
abstract class SaldoClases with _$SaldoClases {
  const factory SaldoClases({
    required bool tieneCuota,
    required bool ilimitada,
    String? tarifaNombre,
    int? incluidas,
    int? gastadas,
    int? reservadas,
    int? disponibles,
  }) = _SaldoClases;

  factory SaldoClases.fromRpc(Map<String, dynamic> json) => SaldoClases(
    tieneCuota: json['tiene_cuota'] as bool,
    ilimitada: json['ilimitada'] as bool,
    tarifaNombre: json['tarifa'] as String?,
    incluidas: json['incluidas'] as int?,
    gastadas: json['gastadas'] as int?,
    reservadas: json['reservadas'] as int?,
    disponibles: json['disponibles'] as int?,
  );
}
