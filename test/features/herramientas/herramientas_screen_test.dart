import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/features/herramientas/presentation/herramientas_screen.dart';

/// Tienda se descongeló el 19/09/2026 (ver FREEZE.md): el catálogo, los
/// pedidos y los préstamos ya estaban completos y el checkout de Stripe
/// se protege solo cuando la academia no tiene cobros configurados
/// (`catalogo_tab.dart`), así que es seguro exponerlo antes de activar
/// Stripe de verdad.
void main() {
  testWidgets('Herramientas ofrece acceso a la Tienda', (tester) async {
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

    expect(find.text('Tienda y material'), findsOneWidget);
    expect(find.text('Tarifas y planes'), findsOneWidget);
  });
}
