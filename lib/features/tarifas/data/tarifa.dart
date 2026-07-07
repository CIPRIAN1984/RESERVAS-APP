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
  }) = _Tarifa;

  factory Tarifa.fromJson(Map<String, dynamic> json) => _$TarifaFromJson(json);
}

const Map<String, String> etiquetasPeriodicidad = {
  'mensual': 'al mes',
  'trimestral': 'al trimestre',
  'anual': 'al año',
};
