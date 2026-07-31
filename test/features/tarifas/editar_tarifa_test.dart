import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/features/tarifas/data/tarifa.dart';
import 'package:itaca/features/tarifas/presentation/crear_tarifa_screen.dart';

/// Las tarifas solo se podían encender y apagar. Sin poder entrar a
/// cambiarlas, las cuatro que ya existen en producción se quedarían para
/// siempre sin número de clases, o sea, ilimitadas.

const _tarifa = Tarifa(
  id: 't1',
  academiaId: 'ac1',
  nombre: 'blue',
  descripcion: 'Dos días por semana',
  precio: 60,
  periodicidad: 'mensual',
  activo: true,
  clasesIncluidas: 8,
);

Widget _app({Tarifa? tarifa}) => ProviderScope(
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: CrearTarifaScreen(academiaId: 'ac1', tarifa: tarifa),
  ),
);

void main() {
  testWidgets('editar una tarifa llega con todo relleno', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    await tester.pumpWidget(_app(tarifa: _tarifa));
    await tester.pumpAndSettle();

    expect(find.text('Editar tarifa'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);

    // Los valores que ya tenía, no un formulario en blanco.
    expect(find.widgetWithText(TextFormField, 'blue'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '60'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '8'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Dos días por semana'),
      findsOneWidget,
    );
  });

  testWidgets('una tarifa ilimitada llega con el interruptor puesto', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    await tester.pumpWidget(
      _app(tarifa: _tarifa.copyWith(clasesIncluidas: null)),
    );
    await tester.pumpAndSettle();

    final interruptor = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(interruptor.value, isTrue);
    // Y entonces no se pregunta cuántas clases.
    expect(find.text('Clases al mes'), findsNothing);
  });

  testWidgets('crear una tarifa parte en blanco', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Nueva tarifa'), findsOneWidget);
    expect(find.text('Crear tarifa'), findsOneWidget);
    expect(find.text('blue'), findsNothing);

    final interruptor = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(
      interruptor.value,
      isFalse,
      reason:
          'Por defecto se pide el número de clases. Si arrancara en '
          'ilimitada, se crearían tarifas sin límite sin querer.',
    );
  });

  testWidgets('no deja guardar sin decir cuántas clases', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre').first,
      'Prueba',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio (€)').first,
      '50',
    );
    await tester.tap(find.text('Crear tarifa'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('cuántas clases'),
      findsOneWidget,
      reason: 'Sin número y sin marcar ilimitada, la tarifa no cuenta nada.',
    );
  });
}
