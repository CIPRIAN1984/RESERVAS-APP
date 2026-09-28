/// Hasta cuándo dura una cuota de [meses] meses que empieza en [desde]:
/// meses de calendario, igual que cuenta el servidor los ciclos
/// (`ciclo_en`), no bloques de 30 días. Antes «1 año» eran 360 días.
///
/// Si el día no existe en el mes de destino se queda en el último día de
/// ese mes: 31 de enero + 1 mes = 28 (o 29) de febrero, no 3 de marzo.
DateTime finDeCuota(DateTime desde, int meses) {
  final mesDestino = desde.month + meses;
  // El día 0 del mes siguiente es el último día de este.
  final ultimoDia = DateTime(desde.year, mesDestino + 1, 0).day;
  return DateTime(
    desde.year,
    mesDestino,
    desde.day > ultimoDia ? ultimoDia : desde.day,
    desde.hour,
    desde.minute,
    desde.second,
  );
}
