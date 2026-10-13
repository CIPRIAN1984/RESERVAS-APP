import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_repository.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/academia.dart';
import 'package:itaca/features/onboarding/domain/mensaje_registro.dart';
import 'package:itaca/features/onboarding/presentation/registro_screen.dart';
import 'package:itaca/l10n/app_localizations.dart';

/// Auditoría del 09/10/2026: si Supabase pide confirmar el correo, al
/// registrarse no hay sesión y la pantalla se quedaba igual, sin decir
/// nada. Y los errores salían en inglés, tal cual los da Supabase.

class _AuthFalso implements AuthRepository {
  _AuthFalso({required this.entra});

  final bool entra;
  int llamadas = 0;

  @override
  Future<bool> signUpAlumno({
    required String email,
    required String password,
    required String academiaId,
    required String nombre,
    String? apellidos,
  }) async {
    llamadas++;
    return entra;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(AuthRepository repo) => ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(repo),
    academiasAprobadasProvider.overrideWith(
      (ref) async => const <AcademiaOption>[],
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('es'),
    home: const RegistroScreen(academiaId: 'ac1'),
  ),
);

Future<void> _rellenarYEnviar(WidgetTester tester) async {
  final campos = find.byType(TextFormField);
  await tester.enterText(campos.at(0), 'Riojano');
  await tester.enterText(campos.at(2), 'riojano@ejemplo.es');
  await tester.enterText(campos.at(3), 'una-contraseña-larga');
  await tester.ensureVisible(find.byType(ElevatedButton));
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('si hay que confirmar el correo, se lo dice', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _AuthFalso(entra: false);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _rellenarYEnviar(tester);

    expect(repo.llamadas, 1);
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(
      find.text(textoRevisaTuCorreo('riojano@ejemplo.es')),
      findsOneWidget,
    );
  });

  testWidgets('si entra directamente, no enseña el aviso', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(_AuthFalso(entra: true)));
    await tester.pumpAndSettle();

    await _rellenarYEnviar(tester);

    expect(find.text('Revisa tu correo'), findsNothing);
  });

  group('mensajeRegistro', () {
    test('correo ya registrado', () {
      expect(
        mensajeRegistro('User already registered'),
        startsWith('Ya hay una cuenta con ese correo'),
      );
    });

    test('contraseña filtrada (cuando se active la protección)', () {
      expect(
        mensajeRegistro(
          'Password is known to be weak and easy to guess, please choose a '
          'different one.',
        ),
        contains('filtraciones'),
      );
    });

    test('lo desconocido no sale en inglés', () {
      expect(
        mensajeRegistro('Database error saving new user'),
        'No se ha podido completar el registro. Inténtalo de nuevo.',
      );
    });
  });
}
