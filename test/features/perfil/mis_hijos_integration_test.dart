import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/perfil/application/profile_providers.dart';
import 'package:itaca/features/perfil/presentation/perfil_screen.dart';

/// Familias y tutores está congelado para v1 (ver FREEZE.md): la sección
/// "Mis hijos" no debe aparecer en Perfil aunque el perfil tenga hijos
/// asignados, porque el botón llevaba a una ruta (`Routes.misHijos`) que el
/// router ya no resuelve. Antes de este cierre el botón seguía siendo
/// visible y tapable pese a la ruta congelada.

Profile _perfil({required String rol}) => Profile(
  id: 'u1',
  academiaId: 'a1',
  rol: rol,
  nombre: 'Riojano',
  apellidos: 'Ejemplo',
  estado: 'activo',
);

Profile _hijo({required String id, required String nombre}) => Profile(
  id: id,
  academiaId: 'a1',
  rol: 'alumno',
  nombre: nombre,
  apellidos: 'Ejemplo',
  estado: 'activo',
  parentId: 'u1',
  cinturon: 'blanco',
);

Widget _app({required Profile perfil, required List<Profile> hijos}) =>
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(perfil.id),
        currentProfileProvider.overrideWith((ref) async => perfil),
        currentAcademiaProvider.overrideWith((ref) async => null),
        hijosProvider.overrideWith((ref) async => hijos),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: PerfilScreen()),
      ),
    );

void main() {
  testWidgets('un padre sin hijos no ve la sección Mis hijos', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1400));
    await tester.pumpWidget(
      _app(
        perfil: _perfil(rol: 'alumno'),
        hijos: [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mis hijos'), findsNothing);
    expect(find.textContaining('Gestionar hijos'), findsNothing);
  });

  testWidgets('un padre CON hijos tampoco ve la sección: sigue congelada', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1400));
    final hijos = [
      _hijo(id: 'h1', nombre: 'Juan'),
      _hijo(id: 'h2', nombre: 'María'),
    ];
    await tester.pumpWidget(
      _app(
        perfil: _perfil(rol: 'alumno'),
        hijos: hijos,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mis hijos'), findsNothing);
    expect(find.textContaining('Gestionar hijos'), findsNothing);
  });
}
