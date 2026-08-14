@Tags(['golden'])
library tarifas_golden_test;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/app_mode.dart';
import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/tarifas/application/tarifas_providers.dart';
import 'package:itaca/features/tarifas/data/tarifa.dart';
import 'package:itaca/features/tarifas/presentation/tarifas_screen.dart';

import 'ayuda_golden.dart';

/// El botón «Suscribirse» iba en el hueco lateral del ListTile y se comía
/// todo el ancho: el nombre de la tarifa salía en vertical, una letra por
/// línea. Con un nombre largo, que es el caso que lo destapó.

Widget _app() => ProviderScope(
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
    suscripcionActivaProvider('a1').overrideWith((ref) async => null),
    tarifasProvider(true).overrideWith(
      (ref) async => [
        const Tarifa(
          id: 't1',
          academiaId: 'ac1',
          nombre: 'white 50.00 € al mes 2 dias por semana',
          precio: 50,
          periodicidad: 'mensual',
          activo: true,
        ),
      ],
    ),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    // Sin el tema, la imagen sale con las tipografías del sistema y los
    // colores por defecto: no comprueba nada del diseño real.
    theme: AppTheme.light,
    home: const Scaffold(body: SafeArea(child: TarifasScreen())),
  ),
);

void main() {
  setUpAll(cargarTipografias);

  testWidgets('Mi cuota — el nombre largo no se parte en vertical', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 760));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // El botón «Suscribirse» que originalmente apretaba el nombre está
    // congelado (ver FREEZE.md): ya no aparece. El resto de la prueba se
    // conserva porque el mismo ListTile sigue mostrando el nombre de la
    // tarifa con el mismo ancho disponible.
    expect(find.text('Suscribirse'), findsNothing);

    // La prueba de verdad: el nombre ocupa una franja ancha y baja, no una
    // columna estrecha y altísima de una letra por línea.
    final nombre = tester.getSize(
      find.text('white 50.00 € al mes 2 dias por semana'),
    );
    expect(
      nombre.width,
      greaterThan(200),
      reason: 'Si el ancho se estrecha, el texto vuelve a caer en vertical.',
    );
    expect(nombre.height, lessThan(120));

    await comparaCon(find.byType(MaterialApp), 'goldens/tarifas_alumno.png');
  });
}
