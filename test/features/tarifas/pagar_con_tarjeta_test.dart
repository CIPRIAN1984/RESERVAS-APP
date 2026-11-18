import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/app_mode.dart';
import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/academia.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/pagos/application/pagos_providers.dart';
import 'package:itaca/features/pagos/data/pagos_repository.dart';
import 'package:itaca/features/tarifas/application/tarifas_providers.dart';
import 'package:itaca/features/tarifas/data/saldo_clases.dart';
import 'package:itaca/features/tarifas/data/tarifa.dart';
import 'package:itaca/features/tarifas/presentation/tarifas_screen.dart';

/// Pagar la cuota con tarjeta (17/11/2026), lo que se ve en Tarifas.
///
/// El botón solo aparece si la academia tiene el cobro con tarjeta activado
/// (interruptor del servidor), y un error del servidor —por ejemplo «ya
/// tiene una renovación pendiente»— se le enseña tal cual, no un «ha
/// ocurrido un error».

class _Repo implements PagosRepository {
  _Repo({this.error});

  final String? error;
  final List<String> pedidos = [];

  @override
  Future<({String url, String pagoId})> iniciarPagoCuota({
    required String tarifaId,
    String? alumnoId,
  }) async {
    pedidos.add(tarifaId);
    if (error != null) throw MensajePago(error!);
    return (url: 'https://checkout.stripe.example/x', pagoId: 'p1');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _bono = Tarifa(
  id: 't2',
  academiaId: 'ac1',
  nombre: 'Bono 10 sesiones',
  precio: 80,
  periodicidad: 'trimestral',
  clasesIncluidas: 10,
  activo: true,
);

Widget _app({required bool tarjeta, _Repo? repo}) => ProviderScope(
  overrides: [
    currentUserIdProvider.overrideWithValue('a1'),
    currentProfileProvider.overrideWith(
      (ref) async => Profile(
        id: 'a1',
        academiaId: 'ac1',
        rol: 'alumno',
        nombre: 'Nuria',
        estado: 'activo',
      ),
    ),
    currentAcademiaProvider.overrideWith(
      (ref) async => Academia(
        id: 'ac1',
        nombre: 'Itaca',
        estado: 'approved',
        stripeOnboardingStatus: 'not_started',
        stripeChargesEnabled: tarjeta,
      ),
    ),
    appModeProvider.overrideWith(AppModeNotifier.new),
    suscripcionActivaProvider('a1').overrideWith((ref) async => null),
    clasesRestantesProvider('a1').overrideWith(
      (ref) async => const SaldoClases(tieneCuota: false, ilimitada: false),
    ),
    tarifasProvider(true).overrideWith((ref) async => const [_bono]),
    renovacionProgramadaProvider('a1').overrideWith((ref) async => null),
    if (repo != null) pagosRepositoryProvider.overrideWithValue(repo),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: SafeArea(child: TarifasScreen())),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  testWidgets('con el cobro con tarjeta activado, se ofrece pagar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    await tester.pumpWidget(_app(tarjeta: true));
    await tester.pumpAndSettle();
    expect(find.text('Pagar con tarjeta'), findsOneWidget);
  });

  testWidgets('sin el cobro activado, el botón no existe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    await tester.pumpWidget(_app(tarjeta: false));
    await tester.pumpAndSettle();
    expect(find.text('Pagar con tarjeta'), findsNothing);
    expect(find.text('Bono 10 sesiones'), findsOneWidget);
  });

  testWidgets('un error del servidor se enseña tal cual', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    final repo = _Repo(
      error: 'Ya tiene una renovación pagada pendiente de empezar.',
    );
    await tester.pumpWidget(_app(tarjeta: true, repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pagar con tarjeta'));
    await tester.pumpAndSettle();
    expect(repo.pedidos, ['t2']);
    expect(
      find.text('Ya tiene una renovación pagada pendiente de empezar.'),
      findsOneWidget,
    );
  });
}
