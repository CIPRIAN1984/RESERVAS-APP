/// Turns a caught exception into a message safe to show to end users —
/// never the raw exception text (e.g. `ClientException with SocketException:
/// Failed host lookup...`), which is meaningless to a non-technical user.
String mensajeErrorAmigable(
  Object error, {
  String generico = 'Ha ocurrido un error. Inténtalo de nuevo.',
}) {
  final texto = error.toString();
  if (texto.contains('SocketException') ||
      texto.contains('Failed host lookup') ||
      texto.contains('ClientException') ||
      texto.contains('Connection refused') ||
      texto.contains('Connection timed out')) {
    return 'Sin conexión a internet. Comprueba tu conexión e inténtalo de nuevo.';
  }
  return generico;
}
