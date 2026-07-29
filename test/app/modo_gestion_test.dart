import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/app_mode.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';

/// El rediseño introdujo dos modos en la barra inferior, pero las pantallas
/// siguieron decidiendo por ROL. Resultado: a un dueño se le daba la versión
/// de gestión siempre y se quedaba sin poder apuntarse a clase.
///
/// `enModoGestionProvider` es la respuesta correcta a esa pregunta y estas
/// pruebas fijan las dos mitades: hace falta el modo Y el permiso.

Profile _perfil({required String rol}) => Profile(
  id: 'u1',
  academiaId: 'a1',
  rol: rol,
  nombre: 'Riojano',
  apellidos: 'Ejemplo',
  estado: 'activo',
);

class _ModoFijo extends AppModeNotifier {
  _ModoFijo(this._inicial);
  final AppMode _inicial;
  @override
  AppMode build() => _inicial;
}

/// Hay que **esperar** a que el perfil se resuelva: el provider lee `.value`,
/// y con el perfil a medias devolvería `false` siempre — una prueba que pasa
/// por el motivo equivocado no protege de nada.
Future<bool> _gestionando({required String rol, required AppMode modo}) async {
  final container = ProviderContainer(
    overrides: [
      currentProfileProvider.overrideWith((ref) async => _perfil(rol: rol)),
      appModeProvider.overrideWith(() => _ModoFijo(modo)),
    ],
  );
  addTearDown(container.dispose);
  await container.read(currentProfileProvider.future);
  return container.read(enModoGestionProvider);
}

void main() {
  group('enModoGestionProvider', () {
    test(
      'un dueño en modo Entrenamiento NO gestiona: viene a entrenar',
      () async {
        expect(
          await _gestionando(rol: 'dueño', modo: AppMode.entrenamiento),
          isFalse,
          reason: 'Es el fallo que dejaba al dueño sin poder reservar clase.',
        );
      },
    );

    test('un profesor en modo Entrenamiento tampoco gestiona', () async {
      expect(
        await _gestionando(rol: 'profesor', modo: AppMode.entrenamiento),
        isFalse,
      );
    });

    test('un dueño en modo Gestor sí gestiona', () async {
      expect(await _gestionando(rol: 'dueño', modo: AppMode.gestor), isTrue);
    });

    test('un profesor en modo Gestor sí gestiona', () async {
      expect(await _gestionando(rol: 'profesor', modo: AppMode.gestor), isTrue);
    });

    test('un alumno nunca gestiona, ni aunque el modo diga Gestor', () async {
      // El modo lo elige el cliente; el permiso no puede depender de eso.
      expect(await _gestionando(rol: 'alumno', modo: AppMode.gestor), isFalse);
    });

    test('sin sesión no se gestiona nada', () {
      final container = ProviderContainer(
        overrides: [currentProfileProvider.overrideWith((ref) async => null)],
      );
      addTearDown(container.dispose);
      expect(container.read(enModoGestionProvider), isFalse);
    });
  });
}
