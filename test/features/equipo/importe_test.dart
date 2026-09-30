import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/features/equipo/domain/importe.dart';

void main() {
  test('propone precio por meses, con coma decimal', () {
    expect(importeSugerido(50, 1), '50,00');
    expect(importeSugerido(49.9, 3), '149,70');
  });

  test('lee importes con coma o con punto', () {
    expect(leerImporte('45,50'), 45.5);
    expect(leerImporte('45.50'), 45.5);
    expect(leerImporte(' 50 '), 50);
    expect(leerImporte('0'), 0);
  });

  test('rechaza lo que no es un importe válido', () {
    expect(leerImporte(''), isNull);
    expect(leerImporte('cincuenta'), isNull);
    expect(leerImporte('-5'), isNull);
  });
}
