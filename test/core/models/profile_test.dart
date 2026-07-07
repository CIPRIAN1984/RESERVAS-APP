import 'package:flutter_test/flutter_test.dart';
import 'package:itaca/core/models/profile.dart';

Map<String, dynamic> _json({
  String rol = 'alumno',
  String estado = 'activo',
  String? academiaId = 'aca-1',
}) => {
  'id': 'user-1',
  'academia_id': academiaId,
  'rol': rol,
  'nombre': 'Ana',
  'apellidos': 'García',
  'estado': estado,
};

void main() {
  group('Profile.fromJson', () {
    test('deserializa los campos con snake_case', () {
      final p = Profile.fromJson(_json(academiaId: 'aca-42'));
      expect(p.id, 'user-1');
      expect(p.academiaId, 'aca-42');
      expect(p.nombre, 'Ana');
    });

    test('academiaId puede ser null (caso Administrador de plataforma)', () {
      final p = Profile.fromJson(_json(rol: 'administrador', academiaId: null));
      expect(p.academiaId, isNull);
      expect(p.isAdministrador, isTrue);
    });
  });

  group('predicados de rol', () {
    test('cada rol activa solo su predicado', () {
      expect(Profile.fromJson(_json(rol: 'dueño')).isDueno, isTrue);
      expect(Profile.fromJson(_json(rol: 'dueño')).isAlumno, isFalse);
      expect(Profile.fromJson(_json(rol: 'profesor')).isProfesor, isTrue);
    });
  });

  group('pendienteAprobacion', () {
    test('es true solo con estado pendiente_aprobacion', () {
      expect(
        Profile.fromJson(
          _json(estado: 'pendiente_aprobacion'),
        ).pendienteAprobacion,
        isTrue,
      );
      expect(
        Profile.fromJson(_json(estado: 'activo')).pendienteAprobacion,
        isFalse,
      );
    });
  });
}
