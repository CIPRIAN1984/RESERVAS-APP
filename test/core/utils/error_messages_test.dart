import 'package:flutter_test/flutter_test.dart';
import 'package:itaca/core/utils/error_messages.dart';

void main() {
  group('mensajeErrorAmigable', () {
    test('traduce errores de red a un mensaje de conexión', () {
      final msg = mensajeErrorAmigable(
        Exception('ClientException with SocketException: Failed host lookup'),
      );
      expect(msg, contains('conexión'));
    });

    test('usa el mensaje genérico para errores no de red', () {
      final msg = mensajeErrorAmigable(
        Exception('algo raro'),
        generico: 'No se pudo guardar.',
      );
      expect(msg, 'No se pudo guardar.');
    });

    test('nunca filtra el texto crudo de la excepción de red', () {
      final msg = mensajeErrorAmigable(
        Exception('Connection refused at 10.0.0.1'),
      );
      expect(msg, isNot(contains('10.0.0.1')));
    });
  });
}
