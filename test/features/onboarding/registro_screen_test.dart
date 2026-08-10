import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/features/onboarding/presentation/registro_screen.dart';
import 'package:itaca/l10n/app_localizations.dart';

/// Quien entra por un enlace de invitación (`/registro?academia=<id>`) ya
/// trae la academia fijada: no debe ver el desplegable con todas las
/// academias aprobadas de la plataforma.

const _academias = [
  (id: 'a1', nombre: 'Itaca Jiu Jitsu'),
  (id: 'a2', nombre: 'Otra academia'),
];

Widget _app({String? academiaId}) => ProviderScope(
  overrides: [
    academiasAprobadasProvider.overrideWith((ref) async => _academias),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: RegistroScreen(academiaId: academiaId),
  ),
);

void main() {
  // CONGELADO: multi-academy registration selection frozen for v1 (single academy only)
  // testWidgets('sin enlace de invitación, elige de la lista de academias', (
  //   tester,
  // ) async {
  //   await tester.pumpWidget(_app());
  //   await tester.pumpAndSettle();
  //
  //   expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  // });
  //
  // testWidgets('con enlace de invitación, la academia viene fijada', (
  //   tester,
  // ) async {
  //   await tester.pumpWidget(_app(academiaId: 'a1'));
  //   await tester.pumpAndSettle();
  //
  //   expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  //   expect(find.text('Itaca Jiu Jitsu'), findsOneWidget);
  //   expect(find.text('Otra academia'), findsNothing);
  // });
  //
  // testWidgets('enlace a una academia que ya no está aprobada, avisa', (
  //   tester,
  // ) async {
  //   await tester.pumpWidget(_app(academiaId: 'no-existe'));
  //   await tester.pumpAndSettle();
  //
  //   expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  //   expect(find.textContaining('ya no es válido'), findsOneWidget);
  // });
}
