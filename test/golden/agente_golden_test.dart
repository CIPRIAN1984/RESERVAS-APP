@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/features/agente/application/agente_providers.dart';
import 'package:itaca/features/agente/data/clave_agente.dart';
import 'package:itaca/features/agente/presentation/agente_screen.dart';

import '../golden_archived/ayuda_golden.dart';

/// Las claves del agente, miradas de verdad.

Widget _pantalla({
  required List<ClaveAgente> claves,
  List<ConsultaAgente> consultas = const [],
}) => ProviderScope(
  overrides: [
    clavesAgenteProvider.overrideWith((ref) async => claves),
    consultasAgenteProvider.overrideWith((ref) async => consultas),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      appBar: AppBar(title: const Text('Claves para tu agente')),
      body: const SafeArea(child: AgenteScreen()),
    ),
  ),
);

void main() {
  setUpAll(cargarTipografias);

  testWidgets('Sin ninguna clave todavía', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_pantalla(claves: const []));
    await tester.pumpAndSettle();

    await comparaCon(find.byType(MaterialApp), 'goldens/agente_vacio.png');
  });

  testWidgets('Con una clave viva y otra anulada', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1100));
    await tester.pumpWidget(
      _pantalla(
        claves: [
          ClaveAgente(
            id: 'k1',
            nombre: 'ChatGPT del móvil',
            pista: 'ab12',
            incluyeContacto: true,
            creada: DateTime(2026, 9, 10),
            consultas: 34,
          ),
          ClaveAgente(
            id: 'k2',
            nombre: 'Prueba de septiembre',
            pista: '9f0c',
            incluyeContacto: false,
            creada: DateTime(2026, 9, 2),
            revocada: DateTime(2026, 9, 9),
            consultas: 3,
          ),
        ],
        consultas: [
          ConsultaAgente(
            cuando: DateTime(2026, 9, 14, 19, 5),
            clave: 'ChatGPT del móvil',
            consulta: 'avisos',
          ),
          ConsultaAgente(
            cuando: DateTime(2026, 9, 14, 9, 12),
            clave: 'ChatGPT del móvil',
            consulta: 'resumen',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ACTIVA'), findsOneWidget);
    expect(find.text('ANULADA'), findsOneWidget);
    await comparaCon(find.byType(MaterialApp), 'goldens/agente_claves.png');
  });
}
