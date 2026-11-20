@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/shared/widgets/pantalla.dart';

import '../golden_archived/ayuda_golden.dart';

/// Los dos modos de color, mirados de verdad con las tipografías reales.
Widget _muestra(ThemeData tema) => MaterialApp(
  theme: tema,
  home: Builder(
    builder: (context) => Scaffold(
      appBar: AppBar(title: const Text('Muestra')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Marta Ruiz',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AZUL · ÚLTIMA CLASE AYER',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 10),
                    const Wrap(
                      spacing: 8,
                      children: [
                        PastillaEstado.exito('Al día'),
                        PastillaEstado.error('Sin cuota'),
                        PastillaEstado.aviso('Pausada'),
                        PastillaEstado.info('Prueba'),
                        PastillaEstado('De baja'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(hintText: 'Buscar')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () {}, child: const Text('Reservar')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () {}, child: const Text('Cancelar')),
            const SizedBox(height: 16),
            const PuntoCinturon('blanco'),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(cargarTipografias);

  for (final (nombre, tema) in [
    ('claro', AppTheme.light),
    ('oscuro', AppTheme.dark),
  ]) {
    testWidgets('Muestra en modo $nombre', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 560));
      await tester.pumpWidget(_muestra(tema));
      await tester.pumpAndSettle();
      await comparaCon(find.byType(MaterialApp), 'goldens/modo_$nombre.png');
    });
  }
}
