import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/perfil/application/profile_providers.dart';
import 'package:itaca/features/perfil/presentation/perfil_screen.dart';

/// El acceso a «Mi familia» desde Perfil.
///
/// Estuvo congelado hasta el 04/09/2026 porque la versión vieja llevaba a
/// una pantalla que no podía funcionar (ver FREEZE.md). Ahora la base de
/// datos y la pantalla están rehechas, así que el acceso vuelve — y se
/// enseña **siempre**, no solo a quien ya tiene hijos: si solo se enseñara
/// a quien los tiene, nadie podría dar de alta al primero.

Profile _perfil({required String rol, bool entrena = true}) => Profile(
  id: 'u1',
  academiaId: 'a1',
  rol: rol,
  nombre: 'Riojano',
  apellidos: 'Ejemplo',
  estado: 'activo',
  entrena: entrena,
);

Widget _app({required Profile perfil}) => ProviderScope(
  overrides: [
    currentUserIdProvider.overrideWithValue(perfil.id),
    currentProfileProvider.overrideWith((ref) async => perfil),
    currentAcademiaProvider.overrideWith((ref) async => null),
    hijosProvider.overrideWith((ref) async => const []),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: PerfilScreen()),
  ),
);

void main() {
  testWidgets('un alumno ve el acceso a Mi familia aunque no tenga hijos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1400));
    await tester.pumpWidget(_app(perfil: _perfil(rol: 'alumno')));
    await tester.pumpAndSettle();

    expect(find.text('Mi familia'), findsOneWidget);
  });

  testWidgets('el Administrador de plataforma no ve Mi familia', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1400));
    await tester.pumpWidget(_app(perfil: _perfil(rol: 'administrador')));
    await tester.pumpAndSettle();

    expect(
      find.text('Mi familia'),
      findsNothing,
      reason: 'No pertenece a ninguna academia: no tiene hijos que gestionar.',
    );
  });

  testWidgets('el interruptor de «yo también entreno» refleja el perfil', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1400));
    await tester.pumpWidget(_app(perfil: _perfil(rol: 'alumno')));
    await tester.pumpAndSettle();

    expect(find.text('Yo también entreno'), findsOneWidget);
    expect(
      find.textContaining('Cuentas como alumno'),
      findsOneWidget,
      reason: 'Con entrena a true, el texto explica que sí cuenta.',
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('un tutor que no entrena lo ve reflejado y explicado', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1400));
    await tester.pumpWidget(
      _app(perfil: _perfil(rol: 'alumno', entrena: false)),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(
      find.textContaining('no sales en la lista de alumnos'),
      findsOneWidget,
      reason: 'Tiene que quedar claro qué implica tenerlo apagado.',
    );
  });
}
