import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_tecnica.freezed.dart';
part 'media_tecnica.g.dart';

@freezed
abstract class MediaTecnica with _$MediaTecnica {
  const factory MediaTecnica({
    required String id,
    @JsonKey(name: 'tecnica_id') required String tecnicaId,
    required String tipo,
    required String url,
    @JsonKey(name: 'subido_por') required String subidoPor,
  }) = _MediaTecnica;

  factory MediaTecnica.fromJson(Map<String, dynamic> json) =>
      _$MediaTecnicaFromJson(json);
}
