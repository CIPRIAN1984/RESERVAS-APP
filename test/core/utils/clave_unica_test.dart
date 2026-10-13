import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/core/utils/clave_unica.dart';

void main() {
  test('es un UUID v4 que acepta Postgres', () {
    final clave = claveUnica();
    expect(
      clave,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('no se repite', () {
    final claves = {for (var i = 0; i < 1000; i++) claveUnica()};
    expect(claves, hasLength(1000));
  });
}
