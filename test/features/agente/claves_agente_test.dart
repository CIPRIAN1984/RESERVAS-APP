import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/features/agente/application/agente_providers.dart';
import 'package:itaca/features/agente/data/agente_repository.dart';
import 'package:itaca/features/agente/data/clave_agente.dart';
import 'package:itaca/features/agente/presentation/agente_screen.dart';

/// Las claves de solo lectura del agente, por la parte que se ve (14/09/2026).
///
/// Lo que no puede fallar aquí es el lado seguro de cada decisión: que el
/// interruptor de los correos venga **apagado** de fábrica, que anular avise
/// de que no tiene vuelta, y que una clave ya anulada no vuelva a ofrecerse
/// para anular. Lo demás es presentación.

class _RepoFalso implements AgenteRepository {
  _RepoFalso({this.claveDevuelta = 'itc_abcdef'});

  final String claveDevuelta;
  final List<String> revocadas = [];
  final List<({String nombre, bool contacto})> creadas = [];

  @override
  Future<String> crearClave({
    required String nombre,
    required bool incluyeContacto,
  }) async {
    creadas.add((nombre: nombre, contacto: incluyeContacto));
    return claveDevuelta;
  }

  @override
  Future<void> revocar(String claveId) async => revocadas.add(claveId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ClaveAgente _clave({
  String id = 'k1',
  String nombre = 'ChatGPT del móvil',
  String pista = 'ab12',
  bool contacto = false,
  bool anulada = false,
  int consultas = 0,
}) => ClaveAgente(
  id: id,
  nombre: nombre,
  pista: pista,
  incluyeContacto: contacto,
  creada: DateTime(2026, 9, 14),
  revocada: anulada ? DateTime(2026, 9, 15) : null,
  consultas: consultas,
);

Widget _pantalla({
  required List<ClaveAgente> claves,
  AgenteRepository? repo,
  List<ConsultaAgente> consultas = const [],
}) => ProviderScope(
  overrides: [
    if (repo != null) agenteRepositoryProvider.overrideWithValue(repo),
    clavesAgenteProvider.overrideWith((ref) async => claves),
    consultasAgenteProvider.overrideWith((ref) async => consultas),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: AgenteScreen()),
  ),
);

void main() {
  testWidgets('sin claves, lo dice y ofrece crear una', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_pantalla(claves: const []));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no has dado ninguna clave.'), findsOneWidget);
    expect(find.text('Crear una clave'), findsOneWidget);
  });

  testWidgets('una clave activa se puede anular', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_pantalla(claves: [_clave(consultas: 7)]));
    await tester.pumpAndSettle();

    expect(find.text('ChatGPT del móvil'), findsOneWidget);
    expect(find.textContaining('Termina en ab12'), findsOneWidget);
    expect(find.textContaining('7 consultas'), findsOneWidget);
    expect(find.text('ACTIVA'), findsOneWidget);
    expect(find.text('Anular esta clave'), findsOneWidget);
  });

  testWidgets('una clave anulada no se ofrece para anular otra vez', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_pantalla(claves: [_clave(anulada: true)]));
    await tester.pumpAndSettle();

    expect(find.text('ANULADA'), findsOneWidget);
    expect(find.text('Anular esta clave'), findsNothing);
  });

  testWidgets('se ve de un vistazo cuál puede leer los correos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_pantalla(claves: [_clave(contacto: true)]));
    await tester.pumpAndSettle();

    expect(find.textContaining('puede leer correos'), findsOneWidget);
  });

  testWidgets('cancelar el aviso no anula nada', (tester) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_pantalla(claves: [_clave()], repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anular esta clave'));
    await tester.pumpAndSettle();

    // El aviso tiene que decir que no hay vuelta atrás.
    expect(find.textContaining('No se puede deshacer'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.revocadas, isEmpty);
  });

  testWidgets('confirmar sí anula', (tester) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_pantalla(claves: [_clave()], repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anular esta clave'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Anular'));
    await tester.pumpAndSettle();

    expect(repo.revocadas, ['k1']);
  });

  testWidgets('el permiso de correos viene apagado de fábrica', (tester) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_pantalla(claves: const [], repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear una clave'));
    await tester.pumpAndSettle();

    // Lo más importante de esta pantalla: quien no lea la letra pequeña no
    // debe acabar mandando los correos de 166 personas a ninguna parte.
    final interruptor = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(interruptor.value, isFalse);

    await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
    await tester.pumpAndSettle();

    expect(repo.creadas.single.contacto, isFalse);
  });

  testWidgets('la clave recién creada se enseña una sola vez, con aviso', (
    tester,
  ) async {
    final repo = _RepoFalso(claveDevuelta: 'itc_0123456789');
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_pantalla(claves: const [], repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear una clave'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
    await tester.pumpAndSettle();

    expect(find.text('itc_0123456789'), findsOneWidget);
    expect(find.textContaining('única vez'), findsOneWidget);
  });

  testWidgets('el registro dice cuándo no hay nada que enseñar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_pantalla(claves: [_clave()]));
    await tester.pumpAndSettle();

    expect(
      find.text('Tu agente todavía no ha consultado nada.'),
      findsOneWidget,
    );
  });

  testWidgets('el registro enseña lo que el agente ha leído', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(
      _pantalla(
        claves: [_clave()],
        consultas: [
          ConsultaAgente(
            cuando: DateTime(2026, 9, 14, 18, 30),
            clave: 'ChatGPT del móvil',
            consulta: 'avisos',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('avisos'), findsOneWidget);
  });
}
