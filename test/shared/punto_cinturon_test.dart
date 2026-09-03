import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/app/theme/color_tokens.dart';
import 'package:itaca/shared/widgets/pantalla.dart';

/// El punto del cinturón **es el dato**, no decoración: si no se dibuja, la
/// lista de alumnos no dice de qué cinturón es cada uno.
///
/// Los doce cinturones mixtos de niños (gris-blanco, amarillo-negro…) se
/// dibujaban en blanco: dentro de una `Column` el ancho llega suelto y un
/// `ColoredBox` sin hijo se queda con el mínimo, o sea 0 px. Se vio
/// renderizando Miembros con un alumno de cinturón amarillo-negro
/// (03/09/2026).

Widget _app(String cinturon) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: PuntoCinturon(cinturon, tamano: 48))),
);

void main() {
  testWidgets('un cinturón mixto dibuja sus dos colores a todo el ancho', (
    tester,
  ) async {
    await tester.pumpWidget(_app('amarillo_negro'));

    final franjas = find.descendant(
      of: find.byType(PuntoCinturon),
      matching: find.byType(ColoredBox),
    );
    expect(franjas, findsNWidgets(2));

    for (final elemento in franjas.evaluate()) {
      final ancho = tester.getSize(find.byWidget(elemento.widget)).width;
      expect(
        ancho,
        48,
        reason: 'Con ancho 0 el cinturón se ve en blanco, sin color alguno.',
      );
    }

    final colores = franjas
        .evaluate()
        .map((e) => (e.widget as ColoredBox).color)
        .toList();
    expect(colores, [
      AppColors.beltColors['amarillo'],
      AppColors.beltColors['negro'],
    ]);
  });

  testWidgets('un cinturón sólido sigue siendo un círculo de un solo color', (
    tester,
  ) async {
    await tester.pumpWidget(_app('azul'));

    expect(
      find.descendant(
        of: find.byType(PuntoCinturon),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
  });
}
