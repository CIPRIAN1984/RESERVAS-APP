import 'package:flutter_test/flutter_test.dart';
import 'package:itaca/core/models/rol.dart';

void main() {
  group('RolX.fromValue', () {
    test('mapea los cuatro roles válidos', () {
      expect(RolX.fromValue('administrador'), Rol.administrador);
      expect(RolX.fromValue('dueño'), Rol.dueno);
      expect(RolX.fromValue('profesor'), Rol.profesor);
      expect(RolX.fromValue('alumno'), Rol.alumno);
    });

    test('acepta "dueno" sin ñ como alias de dueño', () {
      expect(RolX.fromValue('dueno'), Rol.dueno);
    });

    test('lanza ArgumentError ante un rol desconocido', () {
      expect(() => RolX.fromValue('root'), throwsArgumentError);
    });
  });

  group('RolX.value', () {
    test('serializa dueño con ñ (el valor que espera la base de datos)', () {
      expect(Rol.dueno.value, 'dueño');
    });

    test('ida y vuelta value <-> fromValue es estable', () {
      for (final rol in Rol.values) {
        expect(RolX.fromValue(rol.value), rol);
      }
    });
  });
}
