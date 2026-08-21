import 'package:freezed_annotation/freezed_annotation.dart';

import 'rol.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

@freezed
abstract class Profile with _$Profile {
  const Profile._();

  const factory Profile({
    required String id,
    @JsonKey(name: 'academia_id') String? academiaId,
    required String rol,
    required String nombre,
    String? apellidos,
    @JsonKey(name: 'foto_url') String? fotoUrl,
    String? cinturon,
    required String estado,
    // Familias: si no es null, este perfil es un menor con ese padre/tutor.
    // Null = adulto (o administrador).
    @JsonKey(name: 'parent_id') String? parentId,
    // Desde cuándo lleva el alumno en su cinturón actual — arranca en la
    // fecha de alta y se reinicia con cada promoción (ver Miembros).
    @JsonKey(name: 'fecha_inicio_cinturon') DateTime? fechaInicioCinturon,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);

  Rol get rolEnum => RolX.fromValue(rol);
  bool get isAdministrador => rolEnum == Rol.administrador;
  bool get isDueno => rolEnum == Rol.dueno;
  bool get isProfesor => rolEnum == Rol.profesor;
  bool get isAlumno => rolEnum == Rol.alumno;

  /// True while the owning academia hasn't been approved by the platform admin yet.
  bool get pendienteAprobacion => estado == 'pendiente_aprobacion';
}
