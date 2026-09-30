import 'package:intl/intl.dart';

import '../../tarifas/data/saldo_clases.dart';
import '../../tarifas/data/suscripcion.dart';

/// Una línea para el tutor: qué cuota tiene su hijo y cuántas clases le
/// quedan (auditoría del 30/09/2026: el tutor no podía verlo). [aviso]
/// marca lo que pide hacer algo —pagar, renovar, reanudar—.
({String texto, bool aviso}) resumenCuotaHijo(
  Suscripcion? cuota,
  SaldoClases? saldo, {
  DateTime? ahora,
}) {
  final hoy = ahora ?? DateTime.now();
  String fecha(DateTime d) =>
      DateFormat("d 'de' MMMM", 'es_ES').format(d.toLocal());

  if (cuota == null) return (texto: 'Sin cuota', aviso: true);
  if (cuota.estado == 'pendiente_pago') {
    return (texto: 'Pago en proceso', aviso: false);
  }
  if (cuota.estado == 'pausada') {
    return (texto: 'Cuota pausada', aviso: true);
  }
  final fin = cuota.fechaFin;
  if (fin != null && !fin.isAfter(hoy)) {
    return (texto: 'Cuota caducada', aviso: true);
  }
  if (cuota.estado == 'prueba') {
    return (
      texto: fin == null ? 'En prueba' : 'En prueba hasta el ${fecha(fin)}',
      aviso: false,
    );
  }

  final tarifa = cuota.tarifaNombre ?? 'Cuota';
  if (saldo == null || !saldo.tieneCuota) {
    return (texto: tarifa, aviso: false);
  }
  if (saldo.ilimitada) {
    return (
      texto: fin == null
          ? '$tarifa · clases ilimitadas'
          : '$tarifa · clases ilimitadas hasta el ${fecha(fin)}',
      aviso: false,
    );
  }
  final disponibles = saldo.disponibles ?? 0;
  final plazo = saldo.cicloFin == null
      ? 'en este periodo'
      : 'hasta el ${fecha(saldo.cicloFin!)}';
  if (disponibles <= 0) {
    return (texto: '$tarifa · sin clases disponibles $plazo', aviso: true);
  }
  return (
    texto:
        '$tarifa · le quedan $disponibles de ${saldo.incluidas} clases $plazo',
    aviso: false,
  );
}
