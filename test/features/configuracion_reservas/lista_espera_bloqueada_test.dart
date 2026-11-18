import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/configuracion_reservas/application/configuracion_reservas_providers.dart';
import 'package:itaca/features/configuracion_reservas/data/configuracion_reservas.dart';
import 'package:itaca/features/configuracion_reservas/presentation/ajustes_reservas_screen.dart';

/// 17/11/2026: la lista de espera queda apagada en el piloto. El interruptor
/// sale bloqueado y lo explica; el servidor también lo rechaza
/// (`lista_espera_apagada_test.sql`).
void main() {
  testWidgets('el interruptor de la lista de espera está bloqueado', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1400));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) async => Profile(
              id: 'u1',
              academiaId: 'a1',
              rol: 'dueño',
              nombre: 'Dueña',
              estado: 'activo',
            ),
          ),
          configuracionReservasProvider('a1').overrideWith(
            (ref) async => const ConfiguracionReservas(
              listaEsperaActiva: false,
              cancelacionLimiteMinutos: 240,
              zonaHoraria: 'Europe/Madrid',
              exigirCuotaParaReservar: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: AjustesReservasScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lista = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Lista de espera automática'),
    );
    expect(lista.onChanged, isNull);
    expect(
      find.textContaining('No disponible en esta versión'),
      findsOneWidget,
    );

    // El otro interruptor sigue siendo del Dueño.
    final cuota = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Exigir cuota para reservar'),
    );
    expect(cuota.onChanged, isNotNull);
  });
}
