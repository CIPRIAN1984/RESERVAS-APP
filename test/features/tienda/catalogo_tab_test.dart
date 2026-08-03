import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/features/tienda/application/tienda_providers.dart';
import 'package:itaca/features/tienda/data/producto.dart';
import 'package:itaca/features/tienda/presentation/catalogo_tab.dart';

/// El botón "Reservar" suelto en la fila del producto se comía todo el
/// ancho (por tema, `minimumSize: Size.fromHeight` lo deja infinito) y
/// tumbaba el nombre del producto en una columna de una letra — el mismo
/// fallo, ya visto tres veces antes, del botón sin acotar dentro de un Row.

const _producto = Producto(
  id: 'p1',
  academiaId: 'a1',
  nombre: 'Kimono',
  precio: 100,
  stock: 10,
  activo: true,
);

void main() {
  testWidgets('el botón «Reservar» no aplasta el nombre del producto', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 800));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productosProvider(true).overrideWith((ref) async => [_producto]),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CatalogoTab(
            puedeGestionar: false,
            academiaId: 'a1',
            alumnoId: 'u1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Aplastado, cada letra de "Kimono" queda en su propio Text: solo
    // encontrarías el texto completo si el nombre se dibuja en una línea.
    expect(find.text('Kimono'), findsOneWidget);

    final boton = tester.getSize(
      find.widgetWithText(ElevatedButton, 'Reservar'),
    );
    expect(
      boton.width,
      lessThan(200),
      reason:
          'El botón se ha quedado sin acotar: se come todo el ancho de la '
          'fila y el nombre del producto se cae en vertical.',
    );
  });
}
