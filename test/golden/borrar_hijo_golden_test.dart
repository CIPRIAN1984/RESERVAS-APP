@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/perfil/application/profile_providers.dart';
import 'package:itaca/features/perfil/presentation/mis_hijos_screen.dart';
import 'package:itaca/features/tarifas/application/tarifas_providers.dart';
import 'package:itaca/features/tarifas/data/saldo_clases.dart';
import 'package:itaca/features/tarifas/data/suscripcion.dart';

import '../golden_archived/ayuda_golden.dart';

/// «Mi familia» con el botón de deshacer el alta, mirado de verdad.

Profile _hijo(String id, String nombre, String? cinturon) => Profile(
  id: id,
  academiaId: 'a1',
  rol: 'alumno',
  nombre: nombre,
  apellidos: 'Ruiz',
  cinturon: cinturon,
  estado: 'activo',
);

Widget _app({required List<Profile> hijos, required Set<String> borrables}) =>
    ProviderScope(
      overrides: [
        hijosProvider.overrideWith((ref) async => hijos),
        hijosBorrablesProvider.overrideWith((ref) async => borrables),
        // La cuota de cada hijo, como en la app de verdad. Sin esto la carga
        // falla en la prueba y, desde el 09/10/2026, se dibuja el aviso de
        // «No se ha podido cargar su cuota» en vez de la pantalla real.
        suscripcionActivaProvider('h1').overrideWith(
          (ref) async => Suscripcion(
            id: 's1',
            alumnoId: 'h1',
            tarifaId: 't1',
            tarifaNombre: 'Infantil 2 días',
            estado: 'activa',
            paymentStatus: 'active',
            fechaInicio: DateTime(2026, 10, 1),
            fechaFin: DateTime(2030, 11, 1),
          ),
        ),
        clasesRestantesProvider('h1').overrideWith(
          (ref) async => const SaldoClases(
            tieneCuota: true,
            ilimitada: false,
            incluidas: 8,
            gastadas: 2,
            reservadas: 1,
            disponibles: 5,
          ),
        ),
        suscripcionActivaProvider('h2').overrideWith((ref) async => null),
        clasesRestantesProvider('h2').overrideWith(
          (ref) async => const SaldoClases(tieneCuota: false, ilimitada: false),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const MisHijosScreen()),
    );

void main() {
  setUpAll(cargarTipografias);

  testWidgets('Mi familia: uno ya entrena, el otro se acaba de dar de alta', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        hijos: [_hijo('h1', 'Nico', 'gris_blanco'), _hijo('h2', 'Lucía', null)],
        borrables: const {'h2'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    await comparaCon(find.byType(MaterialApp), 'goldens/familia_borrar.png');
  });

  testWidgets('La confirmación antes de borrar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(hijos: [_hijo('h2', 'Lucía', null)], borrables: const {'h2'}),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Borrar el alta'), findsOneWidget);
    await comparaCon(
      find.byType(MaterialApp),
      'goldens/familia_borrar_confirmar.png',
    );
  });
}
