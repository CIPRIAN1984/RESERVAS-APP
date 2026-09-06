import '../../../core/utils/error_messages.dart';

/// Traduce lo que devuelve `reservar_clase` / `cancelar_reserva` a algo que
/// entienda quien lo lee.
///
/// Vive aquí, y no dentro del calendario, porque lo usan dos sitios: la
/// tarjeta de la clase (reservo yo) y la hoja «¿Quién viene?» (reservo por un
/// hijo). Si estuviera duplicado, arreglar un mensaje en uno dejaría el otro
/// como estaba.
///
/// [nombre] es de quién se está hablando cuando no soy yo: con él los
/// mensajes dicen «Nico no tiene plaza» en vez de un impersonal «no hay
/// plaza», que en una familia de tres se lee mal.
String mensajeReserva(Object error, {String? nombre}) {
  final texto = error.toString();
  final quien = nombre ?? 'Tú';

  if (texto.contains('Aforo completo')) {
    return 'Aforo completo para esta clase.';
  }
  if (texto.contains('cuota activa')) {
    return nombre == null
        ? 'Necesitas una cuota activa para reservar.'
        : '$nombre necesita una cuota activa para reservar.';
  }
  if (texto.contains('No te quedan clases')) {
    return nombre == null
        ? 'No te quedan clases en tu tarifa este mes. Renueva o compra una '
              'clase suelta.'
        : 'A $nombre no le quedan clases en su tarifa este mes.';
  }
  if (texto.contains('Ya estás inscrito') ||
      texto.contains('Ya tienes una reserva')) {
    return '$quien ya ${nombre == null ? 'tienes' : 'tiene'} una reserva o '
        'plaza de espera para esta clase.';
  }
  if (texto.contains('clases futuras')) {
    return 'Esta clase ya ha comenzado.';
  }
  if (texto.contains('no admite nuevas reservas')) {
    return 'Esta clase está cerrada y no admite nuevas reservas.';
  }
  // Los dos casos que solo aparecen reservando por otro.
  if (texto.contains('tiene marcado que no entrena')) {
    return '${nombre ?? 'Esta persona'} está dado de alta como acompañante, '
        'no entrena.';
  }
  if (texto.contains('marcado que no entrenas')) {
    return 'Tienes marcado que no entrenas. Cámbialo en tu perfil para '
        'reservar.';
  }
  if (texto.contains('para ti o para tus hijos')) {
    return 'Solo puedes reservar para ti o para tus hijos.';
  }
  return mensajeErrorAmigable(
    error,
    generico: 'No se ha podido completar la acción.',
  );
}
