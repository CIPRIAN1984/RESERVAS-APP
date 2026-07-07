import 'package:freezed_annotation/freezed_annotation.dart';

part 'tecnica.freezed.dart';
part 'tecnica.g.dart';

@freezed
abstract class Tecnica with _$Tecnica {
  const factory Tecnica({
    required String id,
    @JsonKey(name: 'academia_id') required String academiaId,
    required String cinturon,
    required String nombre,
    String? descripcion,
    required int orden,
  }) = _Tecnica;

  factory Tecnica.fromJson(Map<String, dynamic> json) =>
      _$TecnicaFromJson(json);
}

/// Fixed belt progression order (not alphabetical) used to group and sort
/// the technique tree.
const List<String> ordenCinturones = [
  'blanco',
  'azul',
  'morado',
  'marron',
  'negro',
];

const Map<String, String> nombreCinturones = {
  'blanco': 'Blanco',
  'azul': 'Azul',
  'morado': 'Morado',
  'marron': 'Marrón',
  'negro': 'Negro',
};
