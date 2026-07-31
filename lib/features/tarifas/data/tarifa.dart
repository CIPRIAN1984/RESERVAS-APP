import 'package:freezed_annotation/freezed_annotation.dart';

part 'tarifa.freezed.dart';
part 'tarifa.g.dart';

@freezed
abstract class Tarifa with _$Tarifa {
  const factory Tarifa({
    required String id,
    @JsonKey(name: 'academia_id') required String academiaId,
    required String nombre,
    String? descripcion,
    required num precio,
    required String periodicidad,
    required bool activo,

    /// Clases que da **al mes**. `null` = ilimitada.
    ///
    /// Es por mes aunque la tarifa se cobre cada 3 o cada 12: la periodicidad
    /// es de facturación, las clases van por ciclo mensual.
    @JsonKey(name: 'clases_incluidas') int? clasesIncluidas,
  }) = _Tarifa;

  factory Tarifa.fromJson(Map<String, dynamic> json) => _$TarifaFromJson(json);
}

const Map<String, String> etiquetasPeriodicidad = {
  'mensual': 'al mes',
  'trimestral': 'al trimestre',
  'anual': 'al año',
  'suelta': 'pago único',
};

/// Cómo se le cuenta al usuario lo que incluye una tarifa.
String etiquetaClasesIncluidas(int? clasesIncluidas) =>
    switch (clasesIncluidas) {
      null => 'Clases ilimitadas',
      1 => '1 clase al mes',
      final n => '$n clases al mes',
    };
