import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/features/herramientas/presentation/herramientas_screen.dart';

/// Tienda está congelada para v1 (ver FREEZE.md). Antes de este cierre,
/// la tarjeta "Tienda y material" en Herramientas saltaba directamente a
/// TiendaScreen con Navigator.push, sin pasar por el router.
void main() {
  testWidgets('Herramientas no ofrece acceso a la Tienda', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: HerramientasScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tienda y material'), findsNothing);
    expect(find.text('Tarifas y planes'), findsOneWidget);
  });
}
