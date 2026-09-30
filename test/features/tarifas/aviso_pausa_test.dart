import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/app_mode.dart';
import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/configuracion_reservas/application/configuracion_reservas_providers.dart';
import 'package:itaca/features/configuracion_reservas/data/configuracion_reservas.dart';
import 'package:itaca/features/tarifas/application/tarifas_providers.dart';
import 'package:itaca/features/tarifas/data/saldo_clases.dart';
import 'package:itaca/features/tarifas/data/suscripcion.dart';
import 'package:itaca/features/tarifas/data/tarifa.dart';
import 'package:itaca/features/tarifas/presentation/tarifas_screen.dart';

/// Auditoría del 30/09/2026: con la cuota pausada, «Mi cuota» decía siempre
/// «No puedes reservar», y en ITACA —que no exige cuota para reservar— era
/// falso. El aviso tiene que decir lo que de verdad pasa en cada academia.

final _pausada = Suscripcion(
  id: 's1',
  alumnoId: 'a1',
  tarifaId: 't1',
  tarifaNombre: '2 días',
  tarifaPrecio: 50,
  tarifaPeriodicidad: 'mensual',
  estado: 'pausada',
  paymentStatus: 'active',
  fechaInicio: DateTime(2026, 9, 1),
  proveedorPago: 'efectivo',
);

Widget _app({required bool exigeCuota}) => ProviderScope(
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
    suscripcionActivaProvider('a1').overrideWith((ref) async => _pausada),
    clasesRestantesProvider('a1').overrideWith(
      (ref) async => const SaldoClases(tieneCuota: false, ilimitada: false),
    ),
    tarifasProvider(true).overrideWith((ref) async => const <Tarifa>[]),
    configuracionReservasProvider('ac1').overrideWith(
      (ref) async => ConfiguracionReservas(
        listaEsperaActiva: true,
        cancelacionLimiteMinutos: 120,
        zonaHoraria: 'Europe/Madrid',
        exigirCuotaParaReservar: exigeCuota,
      ),
    ),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const Scaffold(body: SafeArea(child: TarifasScreen())),
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  testWidgets('si la academia no exige cuota, dice que se puede reservar', (
    tester,
  ) async {
    await tester.pumpWidget(_app(exigeCuota: false));
    await tester.pumpAndSettle();

    expect(find.textContaining('Puedes seguir reservando'), findsOneWidget);
    expect(find.textContaining('No puedes reservar'), findsNothing);
  });

  testWidgets('si la academia exige cuota, dice que no se puede', (
    tester,
  ) async {
    await tester.pumpWidget(_app(exigeCuota: true));
    await tester.pumpAndSettle();

    expect(find.textContaining('No puedes reservar'), findsOneWidget);
    expect(find.textContaining('Puedes seguir reservando'), findsNothing);
  });
}
