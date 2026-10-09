import 'dart:math';

final _aleatorio = Random.secure();

/// Un UUID v4 al azar, para identificar una operación ante el servidor.
///
/// Sirve para que un reintento no se duplique: si la conexión se corta
/// después de que el servidor haya guardado, el segundo intento lleva la
/// misma clave y el servidor devuelve lo que ya guardó (ver
/// `activar_cuota_efectivo`, `p_clave`).
String claveUnica() {
  final bytes = List<int>.generate(16, (_) => _aleatorio.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versión 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
