import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/app_mode.dart';
import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/app/theme/color_tokens.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/tarifas/application/tarifas_providers.dart';
import 'package:itaca/features/tarifas/data/saldo_clases.dart';
import 'package:itaca/features/tarifas/data/suscripcion.dart';
import 'package:itaca/features/tarifas/data/tarifa.dart';
import 'package:itaca/features/tarifas/presentation/tarifas_screen.dart';

/// `clases_restantes` existía en el servidor desde el 31/07 pero no lo
/// enseñaba nadie: las tarifas «de 8 clases» eran de boquilla. Aquí se
/// comprueba que «Mi cuota» de verdad muestra el saldo, y que avisa en
/// rojo cuando ya no queda ninguna — la app tiene que decir que no, no
/// dejar reservar en silencio y que el alumno se entere en el tatami.

final _suscripcion = Suscripcion(
  id: 's1',
  alumnoId: 'a1',
  tarifaId: 't1',
  tarifaNombre: '2 días',
  tarifaPrecio: 50,
  tarifaPeriodicidad: 'mensual',
  estado: 'activa',
  paymentStatus: 'active',
  fechaInicio: DateTime.now().subtract(const Duration(days: 3)),
);

Widget _app(SaldoClases saldo) => ProviderScope(
  overrides: [
    currentUserIdProvider.overrideWithValue('a1'),
    currentProfileProvider.overrideWith(
      (ref) async => Profile(
        id: 'a1',
        academiaId: 'ac1',
        rol: 'alumno',
        nombre: 'Riojano',
        apellidos: 'Ejemplo',
        estado: 'activo',
      ),
    ),
    appModeProvider.overrideWith(AppModeNotifier.new),
    suscripcionActivaProvider('a1').overrideWith((ref) async => _suscripcion),
    clasesRestantesProvider('a1').overrideWith((ref) async => saldo),
    tarifasProvider(true).overrideWith((ref) async => const <Tarifa>[]),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const Scaffold(body: SafeArea(child: TarifasScreen())),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  // El ciclo puede ser de 1, 3 o 12 meses: la app dice hasta cuándo, no
  // «este mes», que en una tarifa trimestral sería mentira.
  testWidgets('con clases disponibles, enseña cuántas quedan y hasta cuándo', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SaldoClases(
          tieneCuota: true,
          ilimitada: false,
          incluidas: 8,
          gastadas: 2,
          reservadas: 1,
          disponibles: 5,
          cicloFin: DateTime(2026, 10, 15, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Te quedan 5 de 8 clases hasta el 15 de octubre.'),
      findsOneWidget,
    );
  });

  testWidgets('sin clases disponibles, avisa en rojo', (tester) async {
    await tester.pumpWidget(
      _app(
        SaldoClases(
          tieneCuota: true,
          ilimitada: false,
          incluidas: 8,
          gastadas: 8,
          reservadas: 0,
          disponibles: 0,
          cicloFin: DateTime(2026, 10, 15, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final aviso = tester.widget<Text>(
      find.text(
        'Sin clases disponibles hasta el 15 de octubre. Renueva o compra una '
        'suelta.',
      ),
    );
    expect(aviso.style?.color, AppColors.destructive);
  });

  testWidgets('sin fecha de fin del ciclo, no se inventa una', (tester) async {
    await tester.pumpWidget(
      _app(
        const SaldoClases(
          tieneCuota: true,
          ilimitada: false,
          incluidas: 1,
          gastadas: 0,
          reservadas: 0,
          disponibles: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Te quedan 1 de 1 clases en este periodo.'),
      findsOneWidget,
    );
  });

  test('«infinity» de Postgres no rompe la lectura del saldo', () {
    final saldo = SaldoClases.fromRpc({
      'tiene_cuota': true,
      'ilimitada': false,
      'incluidas': 1,
      'gastadas': 0,
      'reservadas': 0,
      'disponibles': 1,
      'ciclo_fin': 'infinity',
    });
    expect(saldo.cicloFin, isNull);
  });

  testWidgets('con tarifa ilimitada, no enseña ningún número', (tester) async {
    await tester.pumpWidget(
      _app(const SaldoClases(tieneCuota: true, ilimitada: true)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Te quedan'), findsNothing);
    expect(find.textContaining('Sin clases disponibles'), findsNothing);
  });
}
