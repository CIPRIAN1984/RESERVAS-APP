import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/features/tarifas/data/tarifa.dart';

/// Antes, «2 días por semana» iba metido en el nombre de la tarifa. Así no
/// había forma de contar nada con ello, y además reventaba la pantalla: el
/// nombre salía en vertical. Ahora es un número aparte.

void main() {
  group('clasesIncluidas viaja en el JSON', () {
    test('un número se lee tal cual', () {
      final tarifa = Tarifa.fromJson(const {
        'id': 't1',
        'academia_id': 'a1',
        'nombre': '2 días',
        'precio': 50,
        'periodicidad': 'mensual',
        'activo': true,
        'clases_incluidas': 8,
      });
      expect(tarifa.clasesIncluidas, 8);
    });

    test('sin el campo se entiende como ilimitada', () {
      final tarifa = Tarifa.fromJson(const {
        'id': 't2',
        'academia_id': 'a1',
        'nombre': 'Libre',
        'precio': 80,
        'periodicidad': 'mensual',
        'activo': true,
      });
      expect(
        tarifa.clasesIncluidas,
        isNull,
        reason:
            'Las tarifas que ya existían no tienen el campo. Si esto fallara, '
            'la app reventaría con los datos de producción.',
      );
    });
  });

  group('etiquetaClasesIncluidas', () {
    test('sin número dice que es ilimitada', () {
      expect(etiquetaClasesIncluidas(null), 'Clases ilimitadas');
    });

    test('una sola clase va en singular', () {
      expect(etiquetaClasesIncluidas(1), '1 clase al mes');
    });

    test('varias van en plural', () {
      expect(etiquetaClasesIncluidas(8), '8 clases al mes');
      expect(etiquetaClasesIncluidas(12), '12 clases al mes');
    });
  });

  test('la periodicidad «suelta» tiene su etiqueta', () {
    expect(etiquetasPeriodicidad['suelta'], 'pago único');
    // Y no se ha perdido ninguna de las que ya había.
    expect(etiquetasPeriodicidad['mensual'], 'al mes');
    expect(etiquetasPeriodicidad['trimestral'], 'al trimestre');
    expect(etiquetasPeriodicidad['anual'], 'al año');
  });
}
