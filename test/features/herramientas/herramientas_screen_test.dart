import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/herramientas/presentation/herramientas_screen.dart';

/// 17/11/2026: la Tienda queda fuera de la entrega de prueba (cerrada también
/// en el servidor) y las tarifas son solo del Dueño.
Widget _app(String rol) => ProviderScope(
  overrides: [
    currentProfileProvider.overrideWith(
      (ref) async => Profile(
        id: 'u1',
        academiaId: 'a1',
        rol: rol,
        nombre: 'Persona',
        estado: 'activo',
      ),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: HerramientasScreen()),
  ),
);

void main() {
  testWidgets('el Dueño tiene horario y tarifas, y no la Tienda', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_app('dueño'));
    await tester.pumpAndSettle();

    expect(find.text('Horario semanal'), findsOneWidget);
    expect(find.text('Tarifas y planes'), findsOneWidget);
    expect(find.text('Tienda y material'), findsNothing);
  });

  testWidgets('al Profesor no se le ofrecen las tarifas', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_app('profesor'));
    await tester.pumpAndSettle();

    expect(find.text('Horario semanal'), findsOneWidget);
    expect(find.text('Tarifas y planes'), findsNothing);
  });
}
