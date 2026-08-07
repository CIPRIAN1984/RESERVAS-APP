import 'package:freezed_annotation/freezed_annotation.dart';

part 'relacion_familia.freezed.dart';
part 'relacion_familia.g.dart';

@freezed
abstract class RelacionFamilia with _$RelacionFamilia {
  const factory RelacionFamilia({
    required String id,
    @JsonKey(name: 'parent_id') required String parentId,
    @JsonKey(name: 'child_id') required String childId,
    @JsonKey(name: 'tipo_relacion') required String tipoRelacion,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _RelacionFamilia;

  factory RelacionFamilia.fromJson(Map<String, dynamic> json) =>
      _$RelacionFamiliaFromJson(json);
}
