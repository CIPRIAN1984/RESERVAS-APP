import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/perfil/application/profile_providers.dart';
import 'package:itaca/features/perfil/data/familia_repository.dart';
import 'package:itaca/features/perfil/presentation/mis_hijos_screen.dart';

/// «Mi familia»: la pantalla desde la que un padre da de alta a sus hijos y
/// los ve. Los menores no tienen cuenta propia, así que esta pantalla es su
/// único punto de entrada a la academia.

class _RepoFalso implements FamiliaRepository {
  final List<String> creados = [];
  Object? error;

  @override
  Future<String> crearHijo({required String nombre, String? apellidos}) async {
    if (error != null) throw error!;
    creados.add([nombre, apellidos].whereType<String>().join(' '));
    return 'hijo-nuevo';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Profile _hijo({
  required String id,
  required String nombre,
  String? apellidos = 'Ejemplo',
  String? cinturon,
}) => Profile(
  id: id,
  academiaId: 'a1',
  rol: 'alumno',
  nombre: nombre,
  apellidos: apellidos,
  cinturon: cinturon,
  estado: 'activo',
);

Widget _app({required List<Profile> hijos, FamiliaRepository? repo}) =>
    ProviderScope(
      overrides: [
        hijosProvider.overrideWith((ref) async => hijos),
        if (repo != null) familiaRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: MisHijosScreen()),
    );

void main() {
  testWidgets('sin hijos, invita a dar de alta al primero', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(hijos: const []));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Todavía no has dado de alta a ningún hijo'),
      findsOneWidget,
    );
    expect(find.text('Añadir hijo'), findsOneWidget);
  });

  testWidgets('enseña a los hijos con su cinturón', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        hijos: [
          _hijo(id: 'h1', nombre: 'Nico', cinturon: 'gris_blanco'),
          _hijo(id: 'h2', nombre: 'Lucía'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nico Ejemplo'), findsOneWidget);
    expect(find.text('Lucía Ejemplo'), findsOneWidget);
    expect(find.text('CINTURÓN GRIS-BLANCO'), findsOneWidget);
    // Sin cinturón asignado se enseña como blanco, igual que en Miembros y
    // en la ficha del alumno.
    expect(find.text('CINTURÓN BLANCO'), findsOneWidget);
  });

  testWidgets('avisa de que los hijos no tienen cuenta propia', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        hijos: [_hijo(id: 'h1', nombre: 'Nico')],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no tienen cuenta propia'),
      findsOneWidget,
      reason: 'Es la primera pregunta que hace un padre.',
    );
  });

  testWidgets('dar de alta a un hijo lo manda al servidor', (tester) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(hijos: const [], repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Añadir hijo'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Nico',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Apellidos (opcional)'),
      'Pérez',
    );
    await tester.tap(find.text('Dar de alta'));
    await tester.pumpAndSettle();

    expect(repo.creados, ['Nico Pérez']);
    expect(
      find.text('Dar de alta'),
      findsNothing,
      reason: 'La hoja se cierra sola al guardar.',
    );
  });

  testWidgets('un hijo sin nombre no se envía', (tester) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(hijos: const [], repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Añadir hijo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dar de alta'));
    await tester.pumpAndSettle();

    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(
      repo.creados,
      isEmpty,
      reason: 'La validación tiene que frenar antes de llamar al servidor.',
    );
  });

  testWidgets('si el servidor rechaza el alta, la hoja no se cierra', (
    tester,
  ) async {
    final repo = _RepoFalso()..error = Exception('fallo');
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(hijos: const [], repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Añadir hijo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Nico',
    );
    await tester.tap(find.text('Dar de alta'));
    await tester.pumpAndSettle();

    expect(
      find.text('Dar de alta'),
      findsOneWidget,
      reason: 'Cerrarla borraría lo escrito y el padre no sabría qué pasó.',
    );
  });
}
