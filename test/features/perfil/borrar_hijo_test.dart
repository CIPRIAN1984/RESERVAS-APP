import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/perfil/application/profile_providers.dart';
import 'package:itaca/features/perfil/data/familia_repository.dart';
import 'package:itaca/features/perfil/presentation/mis_hijos_screen.dart';

/// Deshacer el alta de un hijo (06/09/2026).
///
/// La regla la puso Cipri: **el alumno nunca se da de baja solo**. Así que
/// esto no es «dar de baja», es corregir un alta recién hecha. El botón solo
/// existe mientras el niño no tenga nada; en cuanto empieza, desaparece.
///
/// Lo que más importa probar es justamente eso: que el botón NO esté cuando
/// no debe. Si aparece de más, un padre borra a un niño que ya paga y el
/// registro del cobro se va con él.

class _RepoFalso implements FamiliaRepository {
  final List<String> borrados = [];
  Object? error;

  @override
  Future<void> borrarHijo(String hijoId) async {
    if (error != null) throw error!;
    borrados.add(hijoId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Profile _hijo({required String id, required String nombre}) => Profile(
  id: id,
  academiaId: 'a1',
  rol: 'alumno',
  nombre: nombre,
  apellidos: 'Ejemplo',
  estado: 'activo',
);

Widget _app({
  required List<Profile> hijos,
  required Set<String> borrables,
  FamiliaRepository? repo,
}) => ProviderScope(
  overrides: [
    hijosProvider.overrideWith((ref) async => hijos),
    hijosBorrablesProvider.overrideWith((ref) async => borrables),
    if (repo != null) familiaRepositoryProvider.overrideWithValue(repo),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const MisHijosScreen()),
);

void main() {
  testWidgets('un hijo que ya ha empezado no se puede borrar desde la app', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        hijos: [_hijo(id: 'h1', nombre: 'Nico')],
        borrables: const {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nico Ejemplo'), findsOneWidget);
    expect(
      find.byIcon(Icons.delete_outline),
      findsNothing,
      reason: 'La baja de un alumno que ya entrena es cosa de la academia.',
    );
  });

  testWidgets('un alta recién hecha sí se puede deshacer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        hijos: [_hijo(id: 'h1', nombre: 'Nico')],
        borrables: const {'h1'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('con dos hijos, el botón sale solo en el que toca', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        hijos: [
          _hijo(id: 'h1', nombre: 'Nico'),
          _hijo(id: 'h2', nombre: 'Lucía'),
        ],
        borrables: const {'h2'},
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.delete_outline),
      findsOneWidget,
      reason: 'Nico ya ha empezado; Lucía se dio de alta hace un momento.',
    );
  });

  testWidgets('borrar pide confirmación antes de tocar nada', (tester) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        hijos: [_hijo(id: 'h1', nombre: 'Nico')],
        borrables: const {'h1'},
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Borrar el alta'), findsOneWidget);
    expect(
      find.textContaining('no se pierde nada'),
      findsOneWidget,
      reason: 'El padre tiene que saber que esto no borra ningún historial.',
    );
    expect(repo.borrados, isEmpty);
  });

  testWidgets('cancelar la confirmación no borra a nadie', (tester) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        hijos: [_hijo(id: 'h1', nombre: 'Nico')],
        borrables: const {'h1'},
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repo.borrados, isEmpty);
    expect(find.text('Nico Ejemplo'), findsOneWidget);
  });

  testWidgets('confirmar sí lo manda al servidor', (tester) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        hijos: [_hijo(id: 'h1', nombre: 'Nico')],
        borrables: const {'h1'},
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();

    expect(repo.borrados, ['h1']);
    expect(find.textContaining('ya no está dado de alta'), findsOneWidget);
  });

  testWidgets('el título del diálogo usa la tipografía de la app', (
    tester,
  ) async {
    // No es un capricho: el estilo del título de los diálogos se definía sin
    // decir la tipografía, y Flutter solo aplica la del tema al texto
    // normal, no a los estilos que se pasan sueltos a un componente. El
    // resultado era que TODOS los diálogos de la app salían con la letra del
    // sistema. Se vio mirando una captura, no compilando.
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        hijos: [_hijo(id: 'h1', nombre: 'Nico')],
        borrables: const {'h1'},
        repo: _RepoFalso(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    final titulo = tester.widget<Text>(find.text('Borrar el alta'));
    final estilo =
        titulo.style ??
        Theme.of(
          tester.element(find.text('Borrar el alta')),
        ).dialogTheme.titleTextStyle;
    expect(
      estilo?.fontFamily,
      AppTheme.fontSans,
      reason: 'Sin esto el título sale con la letra del sistema.',
    );
  });

  testWidgets('si el servidor lo rechaza, se dice el motivo de verdad', (
    tester,
  ) async {
    // El servidor manda un mensaje ya escrito para el padre. Taparlo con un
    // «no se ha podido» deja al padre sin saber por qué ni qué hacer.
    final repo = _RepoFalso()
      ..error = Exception(
        'PostgrestException(message: Nico ya ha empezado en la academia. '
        'Habla con tu profesor para darle de baja., code: P0001)',
      );
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        hijos: [_hijo(id: 'h1', nombre: 'Nico')],
        borrables: const {'h1'},
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ya ha empezado en la academia'),
      findsOneWidget,
    );
  });
}
