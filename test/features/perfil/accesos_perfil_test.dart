import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/perfil/presentation/perfil_screen.dart';

/// Al sustituir el cajón lateral por la barra inferior, Tarifas y Tienda se
/// quedaron sin ningún sitio desde el que llegar en modo Entrenamiento: un
/// alumno no podía ni consultar su cuota ni comprar material. Se recolocaron
/// en Perfil y estas pruebas impiden que se vuelvan a perder.

Profile _perfil({required String rol}) => Profile(
  id: 'u1',
  academiaId: 'a1',
  rol: rol,
  nombre: 'Riojano',
  apellidos: 'Ejemplo',
  estado: 'activo',
);

Widget _app(Profile perfil) => ProviderScope(
  overrides: [
    currentUserIdProvider.overrideWithValue(perfil.id),
    currentProfileProvider.overrideWith((ref) async => perfil),
    currentAcademiaProvider.overrideWith((ref) async => null),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: PerfilScreen()),
  ),
);

void main() {
  testWidgets('un alumno llega a su cuota y a la tienda desde Perfil', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1400));
    await tester.pumpWidget(_app(_perfil(rol: 'alumno')));
    await tester.pumpAndSettle();

    expect(find.text('Mi cuota'), findsOneWidget);
    expect(find.text('Tienda y material'), findsOneWidget);
  });

  testWidgets('un dueño también los tiene: entrena en la misma academia', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1400));
    await tester.pumpWidget(_app(_perfil(rol: 'dueño')));
    await tester.pumpAndSettle();

    expect(find.text('Mi cuota'), findsOneWidget);
    expect(find.text('Tienda y material'), findsOneWidget);
  });

  testWidgets(
    'el Administrador de plataforma no los ve: no pertenece a ninguna academia',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      await tester.pumpWidget(_app(_perfil(rol: 'administrador')));
      await tester.pumpAndSettle();

      expect(find.text('Mi cuota'), findsNothing);
      expect(find.text('Tienda y material'), findsNothing);
    },
  );
}
