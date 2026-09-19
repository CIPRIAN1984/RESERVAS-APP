import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/horario/application/horario_providers.dart';
import 'package:itaca/features/horario/data/horario_repository.dart';
import 'package:itaca/features/horario/data/plantilla_clase.dart';
import 'package:itaca/features/horario/presentation/horario_screen.dart';

/// El horario semanal fijo, por la parte que se ve (19/09/2026).
///
/// Lo que no puede fallar aquí: que **pausar no borre nada** (el hueco
/// sigue en la lista, solo deja de generar clases nuevas), y que tocar el
/// botón de pausar no abra por error la pantalla de editar — son dos
/// gestos superpuestos en la misma tarjeta.

class _RepoFalso implements HorarioRepository {
  _RepoFalso({List<PlantillaClase>? plantillas})
    : _plantillas = plantillas ?? [];

  final List<PlantillaClase> _plantillas;
  final List<String> alternadas = [];
  final List<({String titulo, int diaSemana})> creadas = [];

  @override
  Future<List<PlantillaClase>> listarPlantillas(String academiaId) async =>
      _plantillas;

  @override
  Future<void> alternarActivo(String plantillaId, bool activo) async {
    alternadas.add(plantillaId);
  }

  @override
  Future<void> crearPlantilla({
    required String academiaId,
    required String profesorId,
    required String titulo,
    String? descripcion,
    required int diaSemana,
    required String horaInicio,
    required int duracionMin,
    required int aforoMaximo,
  }) async {
    creadas.add((titulo: titulo, diaSemana: diaSemana));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PlantillaClase _plantilla({
  String id = 'p1',
  String titulo = 'BJJ Fundamentals',
  int diaSemana = 1,
  bool activo = true,
}) => PlantillaClase(
  id: id,
  academiaId: 'a1',
  profesorId: 'u1',
  profesorNombre: 'Cipri',
  titulo: titulo,
  diaSemana: diaSemana,
  horaInicio: '19:00',
  duracionMin: 60,
  aforoMaximo: 15,
  activo: activo,
);

Widget _pantalla({
  required List<PlantillaClase> plantillas,
  HorarioRepository? repo,
}) => ProviderScope(
  overrides: [
    currentProfileProvider.overrideWith(
      (ref) async => Profile(
        id: 'u1',
        academiaId: 'a1',
        rol: 'dueño',
        nombre: 'Cipri',
        estado: 'activo',
      ),
    ),
    currentUserIdProvider.overrideWithValue('u1'),
    if (repo != null) horarioRepositoryProvider.overrideWithValue(repo),
    plantillasProvider('a1').overrideWith((ref) async => plantillas),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: HorarioScreen()),
  ),
);

void main() {
  testWidgets('sin horarios todavía, lo dice y ofrece crear uno', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_pantalla(plantillas: const []));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Todavía no tienes ningún horario fijo'),
      findsOneWidget,
    );
    expect(find.text('Horario fijo'), findsOneWidget);
  });

  testWidgets('enseña el día, la hora, el aforo y quién la imparte', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_pantalla(plantillas: [_plantilla()]));
    await tester.pumpAndSettle();

    expect(find.text('BJJ Fundamentals'), findsOneWidget);
    expect(find.textContaining('Lunes'), findsOneWidget);
    expect(find.textContaining('19:00–20:00'), findsOneWidget);
    expect(find.textContaining('Aforo 15'), findsOneWidget);
    expect(find.textContaining('Cipri'), findsOneWidget);
  });

  testWidgets(
    'la pastilla de pausado sale en la fila que toca, no en cualquiera',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 1000));
      await tester.pumpWidget(
        _pantalla(
          plantillas: [
            _plantilla(id: 'p1', titulo: 'BJJ Fundamentals', activo: true),
            _plantilla(id: 'p2', titulo: 'Yoga', activo: false),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final filaActiva = find.ancestor(
        of: find.text('BJJ Fundamentals'),
        matching: find.byType(Card),
      );
      final filaPausada = find.ancestor(
        of: find.text('Yoga'),
        matching: find.byType(Card),
      );

      expect(
        find.descendant(of: filaActiva, matching: find.text('PAUSADO')),
        findsNothing,
        reason: 'La que está activa no debe llevar la pastilla de pausado',
      );
      expect(
        find.descendant(of: filaActiva, matching: find.text('Pausar')),
        findsOneWidget,
      );

      expect(
        find.descendant(of: filaPausada, matching: find.text('PAUSADO')),
        findsOneWidget,
        reason: 'La que está pausada sí debe llevarla',
      );
      expect(
        find.descendant(of: filaPausada, matching: find.text('Reanudar')),
        findsOneWidget,
      );
    },
  );

  testWidgets('pausar llama al repositorio y no abre la edición', (
    tester,
  ) async {
    final repo = _RepoFalso(plantillas: [_plantilla()]);
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_pantalla(plantillas: [_plantilla()], repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pausar'));
    await tester.pumpAndSettle();

    expect(repo.alternadas, ['p1']);
    // Si hubiera abierto la edición, aparecería el título de esa pantalla.
    expect(find.text('Editar horario fijo'), findsNothing);
  });

  testWidgets('tocar la tarjeta, fuera del botón, abre la edición', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_pantalla(plantillas: [_plantilla()]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('BJJ Fundamentals'));
    await tester.pumpAndSettle();

    expect(find.text('Editar horario fijo'), findsOneWidget);
  });

  group('Crear un horario fijo', () {
    testWidgets('pide nombre y no deja guardar sin él', (tester) async {
      final repo = _RepoFalso();
      await tester.binding.setSurfaceSize(const Size(412, 1200));
      await tester.pumpWidget(_pantalla(plantillas: const [], repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Horario fijo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear horario fijo'));
      await tester.pumpAndSettle();

      expect(find.text('Obligatorio'), findsOneWidget);
      expect(repo.creadas, isEmpty);
    });

    testWidgets('con nombre y día elegido, se crea', (tester) async {
      final repo = _RepoFalso();
      await tester.binding.setSurfaceSize(const Size(412, 1200));
      await tester.pumpWidget(_pantalla(plantillas: const [], repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Horario fijo'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Muay Thai');
      await tester.tap(find.text('MI')); // miércoles
      await tester.tap(find.text('Crear horario fijo'));
      await tester.pumpAndSettle();

      expect(repo.creadas.single.titulo, 'Muay Thai');
      expect(repo.creadas.single.diaSemana, 3);
    });
  });
}
