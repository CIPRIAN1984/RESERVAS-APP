import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/app_mode.dart';
import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/tarifas/application/tarifas_providers.dart';
import 'package:itaca/features/tarifas/data/saldo_clases.dart';
import 'package:itaca/features/tarifas/data/suscripcion.dart';
import 'package:itaca/features/tarifas/data/tarifa.dart';
import 'package:itaca/features/tarifas/presentation/tarifas_screen.dart';

/// Auditoría del 23/09/2026: «Cancelar suscripción» salía también en las
/// cuotas cobradas en mano, llamaba a Stripe y el alumno veía un error. Una
/// cuota en efectivo no se cancela desde la app: se habla con la academia.

Suscripcion _suscripcion(String proveedor) => Suscripcion(
  id: 's1',
  alumnoId: 'a1',
  tarifaId: 't1',
  tarifaNombre: '2 días',
  tarifaPrecio: 50,
  tarifaPeriodicidad: 'mensual',
  estado: 'activa',
  paymentStatus: 'active',
  fechaInicio: DateTime(2026, 9, 1),
  fechaFin: DateTime(2026, 10, 1, 12),
  proveedorPago: proveedor,
);

Widget _app(Suscripcion suscripcion) => ProviderScope(
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
    suscripcionActivaProvider('a1').overrideWith((ref) async => suscripcion),
    clasesRestantesProvider('a1').overrideWith(
      (ref) async => const SaldoClases(tieneCuota: true, ilimitada: true),
    ),
    tarifasProvider(true).overrideWith((ref) async => const <Tarifa>[]),
    renovacionProgramadaProvider('a1').overrideWith((ref) async => null),
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

  testWidgets('cuota en efectivo: sin botón de cancelar, y dice hasta cuándo', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_suscripcion('efectivo')));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar suscripción'), findsNothing);
    expect(
      find.text(
        'Pagada en la academia hasta el 1 de octubre de 2026. Para renovarla '
        'o darte de baja, habla con tu academia.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cuota domiciliada con Stripe: sí se puede cancelar', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_suscripcion('stripe')));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar suscripción'), findsOneWidget);
    expect(find.textContaining('Pagada en la academia'), findsNothing);
  });

  test('lee el proveedor de pago de la fila', () {
    final s = Suscripcion.fromRow({
      'id': 's1',
      'alumno_id': 'a1',
      'tarifa_id': 't1',
      'estado': 'activa',
      'payment_status': 'active',
      'fecha_inicio': '2026-09-01T00:00:00Z',
      'fecha_fin': null,
      'proveedor_pago': 'efectivo',
    });
    expect(s.proveedorPago, 'efectivo');
  });
}
