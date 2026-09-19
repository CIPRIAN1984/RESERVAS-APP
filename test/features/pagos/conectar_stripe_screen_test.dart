import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/academia.dart';
import 'package:itaca/features/pagos/application/pagos_providers.dart';
import 'package:itaca/features/pagos/data/pagos_repository.dart';
import 'package:itaca/features/pagos/presentation/conectar_stripe_screen.dart';

/// La pantalla de "Cobros", descongelada el 19/09/2026 (ver FREEZE.md).
///
/// Lo que importa aquí es que **diga la verdad sobre en qué punto está la
/// conexión**: un dueño que ve "Cobros activados" cuando en realidad Stripe
/// sigue a medias empezaría a fiarse de una cuota que nadie le está
/// cobrando de verdad.
///
/// No se prueba aquí pulsar "Conectar con Stripe": abre un navegador
/// externo (`url_launcher`) que no hay forma limpia de simular en una
/// prueba de widget sin montar su propio canal de plataforma — se deja
/// fuera a propósito en vez de fingir una cobertura que no hay.

class _RepoFalso implements PagosRepository {
  _RepoFalso({this.estado = 'not_started', this.cobrosHabilitados = false});

  final String estado;
  final bool cobrosHabilitados;
  int vecesRefrescado = 0;

  @override
  Future<String> obtenerUrlOnboarding() async => 'https://stripe.example/x';

  @override
  Future<({String estado, bool cobrosHabilitados})> refrescarEstado() async {
    vecesRefrescado++;
    return (estado: estado, cobrosHabilitados: cobrosHabilitados);
  }
}

Academia _academia({required String estado, bool cobros = false}) => Academia(
  id: 'a1',
  nombre: 'Itaca Jiu Jitsu',
  estado: 'approved',
  stripeOnboardingStatus: estado,
  stripeChargesEnabled: cobros,
);

Widget _pantalla({required Academia academia, PagosRepository? repo}) =>
    ProviderScope(
      overrides: [
        currentAcademiaProvider.overrideWith((ref) async => academia),
        if (repo != null) pagosRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ConectarStripeScreen()),
      ),
    );

void main() {
  testWidgets('sin empezar, invita a conectar y no dice que ya cobra', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 800));
    await tester.pumpWidget(
      _pantalla(academia: _academia(estado: 'not_started')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conecta tu cuenta de Stripe'), findsOneWidget);
    expect(find.text('Conectar con Stripe'), findsOneWidget);
    expect(find.text('Cobros activados'), findsNothing);
  });

  testWidgets('a medias, dice que falta terminar y ofrece continuar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 800));
    await tester.pumpWidget(_pantalla(academia: _academia(estado: 'pending')));
    await tester.pumpAndSettle();

    expect(find.text('Configuración pendiente'), findsOneWidget);
    expect(find.text('Continuar configuración'), findsOneWidget);
  });

  testWidgets('completa, dice que los cobros están activados', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 800));
    await tester.pumpWidget(
      _pantalla(academia: _academia(estado: 'complete', cobros: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cobros activados'), findsOneWidget);
  });

  testWidgets('«Comprobar estado» llama al servidor, no adivina en el móvil', (
    tester,
  ) async {
    final repo = _RepoFalso(estado: 'complete', cobrosHabilitados: true);
    await tester.binding.setSurfaceSize(const Size(412, 800));
    await tester.pumpWidget(
      _pantalla(
        academia: _academia(estado: 'pending'),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comprobar estado'));
    await tester.pumpAndSettle();

    expect(repo.vecesRefrescado, 1);
  });
}
