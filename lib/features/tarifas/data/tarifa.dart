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

    /// Clases que da **en cada periodo de la tarifa**: al mes en una
    /// mensual, en los 3 meses de una trimestral, en el año de una anual.
    /// `null` = ilimitada. Así cuenta el servidor desde el 25/09/2026
    /// (`ciclo_en`); antes este comentario decía «al mes» y la app también.
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

/// Cómo se le cuenta al usuario lo que incluye una tarifa. Las clases son
/// por periodo de la tarifa (auditoría del 09/10/2026: el bono trimestral
/// de 10 sesiones salía como «10 clases al mes»).
String etiquetaClasesIncluidas(int? clasesIncluidas, String periodicidad) {
  if (clasesIncluidas == null) return 'Clases ilimitadas';
  final clases = clasesIncluidas == 1 ? '1 clase' : '$clasesIncluidas clases';
  return switch (periodicidad) {
    'trimestral' => '$clases al trimestre',
    'anual' => '$clases al año',
    'suelta' => clases,
    _ => '$clases al mes',
  };
}

/// Etiqueta y ayuda del campo «clases» al crear o editar una tarifa.
({String etiqueta, String ayuda}) campoClasesIncluidas(String periodicidad) =>
    switch (periodicidad) {
      'trimestral' => (
        etiqueta: 'Clases al trimestre',
        ayuda:
            'Las que puede hacer en los 3 meses. 2 días por semana son '
            'unas 24.',
      ),
      'anual' => (
        etiqueta: 'Clases al año',
        ayuda: 'Las que puede hacer en todo el año.',
      ),
      'suelta' => (
        etiqueta: 'Clases incluidas',
        ayuda: 'Normalmente 1: es un pago único.',
      ),
      _ => (
        etiqueta: 'Clases al mes',
        ayuda: '2 días por semana son 8; 3 por semana, 12.',
      ),
    };
