import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/router.dart';

/// Al volver de la página de pago de Stripe la app se recarga entera y pasa
/// por la pantalla de carga. El destino tiene que sobrevivir (17/11/2026): se
/// vio en el navegador que acababas siempre en el inicio.
void main() {
  test('la pantalla de carga recuerda a dónde se iba', () {
    final carga = Uri.parse(direccionDeCarga(Uri.parse('/pago?pago=abc')));
    expect(carga.path, '/splash');
    expect(destinoGuardado(carga), '/pago?pago=abc');
  });

  test('sin destino guardado no hay a dónde volver', () {
    expect(destinoGuardado(Uri.parse('/splash')), isNull);
  });

  test('solo se vuelve a rutas propias de la app', () {
    expect(
      destinoGuardado(Uri.parse('/splash?volver=https://otra.web/x')),
      isNull,
    );
    expect(destinoGuardado(Uri.parse('/splash?volver=//otra.web/x')), isNull);
  });

  test('no se vuelve a una pantalla de entrada (haría un bucle)', () {
    for (final entrada in [
      '/login',
      '/splash',
      '/registro',
      '/pendiente-aprobacion',
    ]) {
      expect(
        destinoGuardado(Uri.parse('/splash?volver=$entrada')),
        isNull,
        reason: entrada,
      );
    }
  });
}
