@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/perfil/application/profile_providers.dart';
import 'package:itaca/features/perfil/presentation/mis_hijos_screen.dart';

import '../golden_archived/ayuda_golden.dart';

/// «Mi familia» con el botón de deshacer el alta, mirado de verdad.

Profile _hijo(String id, String nombre, String? cinturon) => Profile(
  id: id,
  academiaId: 'a1',
  rol: 'alumno',
  nombre: nombre,
  apellidos: 'Ruiz',
  cinturon: cinturon,
  estado: 'activo',
);

Widget _app({required List<Profile> hijos, required Set<String> borrables}) =>
    ProviderScope(
      overrides: [
        hijosProvider.overrideWith((ref) async => hijos),
        hijosBorrablesProvider.overrideWith((ref) async => borrables),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const MisHijosScreen()),
    );

void main() {
  setUpAll(cargarTipografias);

  testWidgets('Mi familia: uno ya entrena, el otro se acaba de dar de alta', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        hijos: [_hijo('h1', 'Nico', 'gris_blanco'), _hijo('h2', 'Lucía', null)],
        borrables: const {'h2'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    await comparaCon(find.byType(MaterialApp), 'goldens/familia_borrar.png');
  });

  testWidgets('La confirmación antes de borrar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(hijos: [_hijo('h2', 'Lucía', null)], borrables: const {'h2'}),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Borrar el alta'), findsOneWidget);
    await comparaCon(
      find.byType(MaterialApp),
      'goldens/familia_borrar_confirmar.png',
    );
  });
}
