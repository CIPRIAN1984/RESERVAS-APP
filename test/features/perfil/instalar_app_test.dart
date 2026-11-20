import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/web/instalacion.dart';
import 'package:itaca/features/perfil/presentation/tarjeta_instalar_app.dart';

class _Falsa implements InstalacionApp {
  _Falsa(this._estado);
  final EstadoInstalacion _estado;
  int instalaciones = 0;

  @override
  EstadoInstalacion estado() => _estado;

  @override
  Future<bool> instalar() async {
    instalaciones++;
    return true;
  }
}

Widget _app(_Falsa falsa) => ProviderScope(
  overrides: [instalacionProvider.overrideWithValue(falsa)],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: TarjetaInstalarApp()),
  ),
);

void main() {
  group('qué se ofrece según el navegador', () {
    test('ya instalada gana a todo', () {
      expect(
        decidirEstado(instalada: true, botonDisponible: true, esIos: true),
        EstadoInstalacion.yaInstalada,
      );
    });
    test('con botón del navegador', () {
      expect(
        decidirEstado(instalada: false, botonDisponible: true, esIos: false),
        EstadoInstalacion.conBoton,
      );
    });
    test('en iPhone, pasos de Safari', () {
      expect(
        decidirEstado(instalada: false, botonDisponible: false, esIos: true),
        EstadoInstalacion.pasosIos,
      );
    });
    test('si no se puede, nada', () {
      expect(
        decidirEstado(instalada: false, botonDisponible: false, esIos: false),
        EstadoInstalacion.noDisponible,
      );
    });
  });

  testWidgets('con botón: se ve y lanza la instalación', (tester) async {
    final falsa = _Falsa(EstadoInstalacion.conBoton);
    await tester.pumpWidget(_app(falsa));
    expect(find.text('Instala la app'), findsOneWidget);
    await tester.tap(find.text('Instalar'));
    await tester.pumpAndSettle();
    expect(falsa.instalaciones, 1);
  });

  testWidgets('en iPhone: pasos y sin botón', (tester) async {
    await tester.pumpWidget(_app(_Falsa(EstadoInstalacion.pasosIos)));
    expect(find.textContaining('Añadir a pantalla de inicio'), findsOneWidget);
    expect(find.text('Instalar'), findsNothing);
  });

  for (final e in [
    EstadoInstalacion.noDisponible,
    EstadoInstalacion.yaInstalada,
  ]) {
    testWidgets('no se muestra nada si es $e', (tester) async {
      await tester.pumpWidget(_app(_Falsa(e)));
      expect(find.text('Instala la app'), findsNothing);
    });
  }
}
