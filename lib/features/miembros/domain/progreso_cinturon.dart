/// Cuánto le falta a un alumno para el siguiente cinturón — reglas
/// confirmadas por Cipri (agosto 2026):
///
/// - Solo cuentan los cambios de color (los grados/rayas de blanco los
///   sigue llevando Cipri a mano, la app no los rastrea).
/// - El reloj arranca en la fecha de alta y se reinicia con cada promoción.
/// - Lo que importa es el total acumulado de entrenos, no un mínimo semanal
///   estricto: 3 entrenos/semana de media.
/// - Niños (sistema IBJJF): 6 meses por cinturón, para cada uno de los doce
///   pasos. Adultos: 2 años por cinturón, igual para las cuatro transiciones
///   (blanco→azul→morado→marrón→negro).
library;

/// Progresión de adulto. El blanco es el mismo cinturón de entrada que el
/// de niños — ver [secuenciaNinos].
const secuenciaAdultos = ['blanco', 'azul', 'morado', 'marron', 'negro'];

/// Progresión infantil IBJJF. El blanco de niño es el mismo color que el
/// de adulto: no hay una entrada infantil separada para él.
const secuenciaNinos = [
  'blanco',
  'gris_blanco',
  'gris',
  'gris_negro',
  'amarillo_blanco',
  'amarillo',
  'amarillo_negro',
  'naranja_blanco',
  'naranja',
  'naranja_negro',
  'verde_blanco',
  'verde',
  'verde_negro',
];

List<String> secuenciaCinturon(bool esMenor) =>
    esMenor ? secuenciaNinos : secuenciaAdultos;

/// El cinturón que sigue a [actual] en la progresión que corresponda, o
/// `null` si ya está en el más alto que gestiona la app (negro para
/// adultos; verde-negra para niños, donde termina la escala IBJJF que
/// seguimos aquí).
String? proximoCinturon(String? actual, bool esMenor) {
  final secuencia = secuenciaCinturon(esMenor);
  final indice = secuencia.indexOf(actual ?? 'blanco');
  if (indice == -1 || indice == secuencia.length - 1) return null;
  return secuencia[indice + 1];
}

int semanasRequeridas(bool esMenor) => esMenor ? 26 : 104;

/// A 3 entrenos/semana, el total acumulado que hace falta para el siguiente
/// cinturón.
int asistenciasRequeridas(bool esMenor) => semanasRequeridas(esMenor) * 3;

/// Progreso de un alumno hacia su siguiente cinturón.
class ProgresoCinturon {
  const ProgresoCinturon({
    required this.asistencias,
    required this.requeridas,
    required this.proximoCinturon,
  });

  final int asistencias;
  final int requeridas;
  final String? proximoCinturon;

  /// `null` cuando ya no hay siguiente cinturón que gestionar (tope de la
  /// progresión).
  double? get fraccion {
    if (proximoCinturon == null || requeridas == 0) return null;
    final valor = asistencias / requeridas;
    return valor > 1 ? 1 : valor;
  }
}
