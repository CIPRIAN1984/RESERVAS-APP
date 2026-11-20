import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/features/pagos/application/pagos_providers.dart';
import 'package:itaca/features/pagos/data/pago_tarjeta.dart';
import 'package:itaca/features/pagos/data/pagos_repository.dart';
import 'package:itaca/features/pagos/presentation/pago_resultado_screen.dart';
import 'package:itaca/features/pagos/presentation/pagos_con_problema_seccion.dart';

/// Pago con tarjeta (17/11/2026), lo que se ve.
///
/// Lo importante: la pantalla a la que se vuelve tras Stripe NUNCA activa
/// nada. Solo pregunta al servidor cómo va el pago y dice la verdad, también
/// cuando no se ha podido comprobar («si has pagado, se activará sola»).

class _Repo implements PagosRepository {
  _Repo(this.respuestas);

  /// Una respuesta por llamada; si es `null`, lanza un error de red.
  final List<String?> respuestas;
  int llamadas = 0;
  List<PagoTarjeta> problemas = const [];

  @override
  Future<String> comprobarPago(String pagoId) async {
    final r = respuestas[llamadas.clamp(0, respuestas.length - 1)];
    llamadas++;
    if (r == null) throw Exception('sin conexión');
    return r;
  }

  @override
  Future<List<PagoTarjeta>> pagosConProblema() async => problemas;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _resultado(
  _Repo repo, {
  bool cancelado = false,
  int intentosMaximos = 3,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: PagoResultadoScreen(
            pagoId: 'p1',
            cancelado: cancelado,
            intervalo: const Duration(milliseconds: 10),
            intentosMaximos: intentosMaximos,
          ),
        ),
      ),
      GoRoute(path: '/inicio', builder: (_, _) => const SizedBox()),
      GoRoute(path: '/perfil', builder: (_, _) => const SizedBox()),
    ],
  );
  return ProviderScope(
    overrides: [pagosRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

PagoTarjeta _pago(String estado, {String? error}) => PagoTarjeta(
  id: 'p$estado',
  estado: estado,
  importeEsperado: 80,
  error: error,
  alumno: 'Nuria Nueva',
  creado: DateTime(2026, 11, 18, 10, 30),
);

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  group('Al volver de la página de pago', () {
    testWidgets('si Stripe ya confirmó, dice que la cuota está activa', (
      tester,
    ) async {
      await tester.pumpWidget(_resultado(_Repo(['pagado'])));
      await tester.pumpAndSettle();
      expect(find.text('Pago recibido'), findsOneWidget);
      expect(find.textContaining('Tu cuota ya está activa'), findsOneWidget);
    });

    testWidgets('mientras no se confirma, sigue preguntando y luego espera', (
      tester,
    ) async {
      final repo = _Repo(['creado', 'creado', 'pagado']);
      await tester.pumpWidget(_resultado(repo));
      await tester.pump();
      expect(find.text('Comprobando tu pago…'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 20));
      expect(repo.llamadas, 3);
      expect(find.text('Pago recibido'), findsOneWidget);
    });

    testWidgets('si no llega la confirmación, no promete lo que no sabe', (
      tester,
    ) async {
      await tester.pumpWidget(_resultado(_Repo(['creado'])));
      await tester.pumpAndSettle(const Duration(milliseconds: 20));
      expect(find.text('Seguimos esperando la confirmación'), findsOneWidget);
      expect(find.textContaining('se activará sola'), findsOneWidget);
      expect(find.text('Comprobar de nuevo'), findsOneWidget);
      expect(find.text('Pago recibido'), findsNothing);
    });

    testWidgets('sin conexión lo dice y deja reintentar', (tester) async {
      final repo = _Repo([null, 'pagado']);
      await tester.pumpWidget(_resultado(repo));
      await tester.pumpAndSettle();
      expect(find.text('No hemos podido comprobar tu pago'), findsOneWidget);
      await tester.tap(find.text('Comprobar de nuevo'));
      await tester.pumpAndSettle();
      expect(find.text('Pago recibido'), findsOneWidget);
    });

    testWidgets('un pago fallido o abandonado dice que no se ha cobrado', (
      tester,
    ) async {
      await tester.pumpWidget(_resultado(_Repo(['expirado'])));
      await tester.pumpAndSettle();
      expect(find.text('El pago no se ha completado'), findsOneWidget);
      expect(find.textContaining('No se te ha cobrado nada'), findsOneWidget);
    });

    testWidgets('cobrado pero sin cuota: pide avisar a la academia', (
      tester,
    ) async {
      await tester.pumpWidget(_resultado(_Repo(['revisar'])));
      await tester.pumpAndSettle();
      expect(find.text('Hay que revisar tu pago'), findsOneWidget);
      expect(find.textContaining('Avisa a tu academia'), findsOneWidget);
    });
  });

  group('Pagos con tarjeta por revisar (Dueño)', () {
    Widget seccion(_Repo repo) => ProviderScope(
      overrides: [pagosRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(child: PagosConProblemaSeccion()),
        ),
      ),
    );

    testWidgets('sin problemas, lo dice', (tester) async {
      await tester.pumpWidget(seccion(_Repo(['x'])));
      await tester.pumpAndSettle();
      expect(find.text('Ningún pago con problemas.'), findsNothing);
      expect(find.textContaining('Ningún pago con problemas'), findsOneWidget);
    });

    testWidgets('enseña quién, cuánto y por qué, sin esperar al alumno', (
      tester,
    ) async {
      final repo = _Repo(['x'])
        ..problemas = [
          _pago(
            'revisar',
            error: 'Cobrado, pero no se ha podido activar la cuota: x',
          ),
          _pago('expirado'),
        ];
      await tester.pumpWidget(seccion(repo));
      await tester.pumpAndSettle();
      expect(find.text('Nuria Nueva'), findsNWidgets(2));
      expect(find.text('COBRADO, SIN CUOTA'), findsOneWidget);
      expect(find.text('ABANDONADO'), findsOneWidget);
      expect(find.textContaining('no se ha podido activar'), findsOneWidget);
    });
  });
}
