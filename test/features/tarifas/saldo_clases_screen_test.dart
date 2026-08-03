import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('con clases disponibles, enseña cuántas quedan', (tester) async {
    await tester.pumpWidget(
      _app(
        const SaldoClases(
          tieneCuota: true,
          ilimitada: false,
          incluidas: 8,
          gastadas: 2,
          reservadas: 1,
          disponibles: 5,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Te quedan 5 de 8 clases este mes.'), findsOneWidget);
  });

  testWidgets('sin clases disponibles, avisa en rojo', (tester) async {
    await tester.pumpWidget(
      _app(
        const SaldoClases(
          tieneCuota: true,
          ilimitada: false,
          incluidas: 8,
          gastadas: 8,
          reservadas: 0,
          disponibles: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final aviso = tester.widget<Text>(
      find.text(
        'Sin clases disponibles este mes. Renueva o compra una suelta.',
      ),
    );
    expect(aviso.style?.color, AppColors.destructive);
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
