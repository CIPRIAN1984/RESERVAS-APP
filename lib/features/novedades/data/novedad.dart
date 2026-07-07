import 'package:freezed_annotation/freezed_annotation.dart';

part 'novedad.freezed.dart';

@freezed
abstract class Novedad with _$Novedad {
  const factory Novedad({
    required String id,
    required String academiaId,
    required String autorId,
    String? autorNombre,
    required String titulo,
    required String contenido,
    required bool fijado,
    required DateTime createdAt,
  }) = _Novedad;

  /// Parses a row from a `novedades` select with an `autor:profiles(nombre)` embed.
  factory Novedad.fromRow(Map<String, dynamic> row) {
    final autor = row['autor'] as Map<String, dynamic>?;
    return Novedad(
      id: row['id'] as String,
      academiaId: row['academia_id'] as String,
      autorId: row['autor_id'] as String,
      autorNombre: autor?['nombre'] as String?,
      titulo: row['titulo'] as String,
      contenido: row['contenido'] as String,
      fijado: row['fijado'] as bool,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
