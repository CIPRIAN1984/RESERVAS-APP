import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/features/equipo/domain/fin_de_cuota.dart';

/// Auditoría del 23/09/2026: «1 año» en el cobro en efectivo eran 360 días
/// (12 × 30), y «1 mes» desde el 31 de enero caía en marzo. Una cuota dura
/// meses de calendario, como los ciclos que cuenta el servidor.
void main() {
  test('1 año son 12 meses de calendario, no 360 días', () {
    final desde = DateTime(2026, 9, 26, 18, 30);
    expect(finDeCuota(desde, 12), DateTime(2027, 9, 26, 18, 30));
    expect(finDeCuota(desde, 12).difference(desde).inDays, 365);
  });

  test('1 mes desde el 31 de enero acaba el último día de febrero', () {
    expect(finDeCuota(DateTime(2027, 1, 31), 1), DateTime(2027, 2, 28));
    expect(finDeCuota(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
  });

  test('cruzar el cambio de año con 3 y 6 meses', () {
    expect(finDeCuota(DateTime(2026, 11, 30), 3), DateTime(2027, 2, 28));
    expect(finDeCuota(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
    expect(finDeCuota(DateTime(2026, 10, 15), 3), DateTime(2027, 1, 15));
  });
}
