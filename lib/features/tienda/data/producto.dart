import 'package:freezed_annotation/freezed_annotation.dart';

part 'producto.freezed.dart';
part 'producto.g.dart';

@freezed
abstract class Producto with _$Producto {
  const factory Producto({
    required String id,
    @JsonKey(name: 'academia_id') required String academiaId,
    required String nombre,
    String? descripcion,
    required num precio,
    required int stock,
    @JsonKey(name: 'foto_url') String? fotoUrl,
    required bool activo,
  }) = _Producto;

  factory Producto.fromJson(Map<String, dynamic> json) =>
      _$ProductoFromJson(json);
}
