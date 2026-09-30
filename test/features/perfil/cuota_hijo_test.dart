import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/features/perfil/domain/cuota_hijo.dart';
import 'package:itaca/features/tarifas/data/saldo_clases.dart';
import 'package:itaca/features/tarifas/data/suscripcion.dart';

/// Auditoría del 30/09/2026: el tutor no podía ver la cuota ni las clases
/// que le quedan a su hijo. Esto es lo que lee en «Mi familia».

final _ahora = DateTime(2026, 10, 1, 12);

Suscripcion _cuota({String estado = 'activa', DateTime? fin}) => Suscripcion(
  id: 's1',
  alumnoId: 'h1',
  tarifaId: 't1',
  tarifaNombre: 'Infantil 2 días',
  estado: estado,
  paymentStatus: 'active',
  fechaInicio: DateTime(2026, 9, 15),
  fechaFin: fin ?? DateTime(2026, 10, 15),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  test('con clases: tarifa y cuántas le quedan hasta cuándo', () {
    final r = resumenCuotaHijo(
      _cuota(),
      SaldoClases(
        tieneCuota: true,
        ilimitada: false,
        incluidas: 8,
        gastadas: 3,
        reservadas: 1,
        disponibles: 4,
        cicloFin: DateTime(2026, 10, 15),
      ),
      ahora: _ahora,
    );
    expect(
      r.texto,
      'Infantil 2 días · le quedan 4 de 8 clases hasta el 15 de octubre',
    );
    expect(r.aviso, isFalse);
  });

  test('sin clases disponibles avisa', () {
    final r = resumenCuotaHijo(
      _cuota(),
      SaldoClases(
        tieneCuota: true,
        ilimitada: false,
        incluidas: 8,
        gastadas: 8,
        reservadas: 0,
        disponibles: 0,
        cicloFin: DateTime(2026, 10, 15),
      ),
      ahora: _ahora,
    );
    expect(
      r.texto,
      'Infantil 2 días · sin clases disponibles hasta el 15 de octubre',
    );
    expect(r.aviso, isTrue);
  });

  test('sin cuota, pausada o caducada: avisa', () {
    expect(resumenCuotaHijo(null, null, ahora: _ahora), (
      texto: 'Sin cuota',
      aviso: true,
    ));
    expect(resumenCuotaHijo(_cuota(estado: 'pausada'), null, ahora: _ahora), (
      texto: 'Cuota pausada',
      aviso: true,
    ));
    expect(
      resumenCuotaHijo(_cuota(fin: DateTime(2026, 9, 30)), null, ahora: _ahora),
      (texto: 'Cuota caducada', aviso: true),
    );
  });

  test('ilimitada: sin número de clases', () {
    final r = resumenCuotaHijo(
      _cuota(),
      const SaldoClases(tieneCuota: true, ilimitada: true),
      ahora: _ahora,
    );
    expect(
      r.texto,
      'Infantil 2 días · clases ilimitadas hasta el 15 de octubre',
    );
  });
}
