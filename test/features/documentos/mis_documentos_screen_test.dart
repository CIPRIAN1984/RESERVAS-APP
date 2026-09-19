import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/documentos/application/documentos_providers.dart';
import 'package:itaca/features/documentos/presentation/mis_documentos_screen.dart';
import 'package:itaca/features/perfil/application/profile_providers.dart';

/// «Documentos» en Perfil: el propio usuario siempre ve su sección, y una
/// sección más por cada hijo a su cargo — o ninguna, si no tiene hijos.

Profile _hijo(String id, String nombre) => Profile(
  id: id,
  academiaId: 'a1',
  rol: 'alumno',
  nombre: nombre,
  apellidos: 'Ejemplo',
  estado: 'activo',
);

Widget _app({required List<Profile> hijos}) => ProviderScope(
  overrides: [
    currentUserIdProvider.overrideWithValue('u1'),
    hijosProvider.overrideWith((ref) async => hijos),
    documentosDeProvider('u1').overrideWith((ref) async => const []),
    for (final hijo in hijos)
      documentosDeProvider(hijo.id).overrideWith((ref) async => const []),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: MisDocumentosScreen()),
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  testWidgets('sin hijos, solo se ve la sección propia', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    await tester.pumpWidget(_app(hijos: const []));
    await tester.pumpAndSettle();

    expect(find.text('Tus documentos'), findsOneWidget);
    expect(find.textContaining('Documentos de'), findsNothing);
  });

  testWidgets('con hijos, hay una sección propia y una por cada hijo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 2000));
    await tester.pumpWidget(
      _app(hijos: [_hijo('h1', 'Nico'), _hijo('h2', 'Vera')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tus documentos'), findsOneWidget);
    expect(find.text('Documentos de Nico Ejemplo'), findsOneWidget);
    expect(find.text('Documentos de Vera Ejemplo'), findsOneWidget);
  });
}
