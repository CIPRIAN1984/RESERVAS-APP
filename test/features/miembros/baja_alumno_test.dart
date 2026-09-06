import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/miembros/application/miembros_providers.dart';
import 'package:itaca/features/miembros/data/miembros_repository.dart';
import 'package:itaca/features/miembros/domain/progreso_cinturon.dart';
import 'package:itaca/features/miembros/presentation/ficha_miembro_screen.dart';
import 'package:itaca/features/miembros/presentation/miembros_screen.dart';

/// Dar de baja a un alumno, por la parte que se ve (06/09/2026).
///
/// Lo que más importa no es que el botón funcione: es que **un alumno dado de
/// baja deje de aparecer donde no debe**. Si sigue saliendo en la lista o
/// sumando en los recuentos, darle de baja no habrá servido de nada y Cipri
/// se entera cuando le cuadran mal los números.

class _RepoFalso implements MiembrosRepository {
  final List<String> bajas = [];
  final List<String> reactivados = [];

  @override
  Future<void> darDeBaja(String alumnoId) async => bajas.add(alumnoId);

  @override
  Future<void> reactivar(String alumnoId) async => reactivados.add(alumnoId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Profile _alumno({
  required String id,
  required String nombre,
  String estado = 'activo',
}) => Profile(
  id: id,
  academiaId: 'a1',
  rol: 'alumno',
  nombre: nombre,
  apellidos: 'Ejemplo',
  cinturon: 'azul',
  estado: estado,
);

Widget _lista({required List<Profile> alumnos}) => ProviderScope(
  overrides: [
    currentProfileProvider.overrideWith(
      (ref) async => Profile(
        id: 'u1',
        academiaId: 'a1',
        rol: 'dueño',
        nombre: 'Dueña',
        estado: 'activo',
      ),
    ),
    alumnosMiembrosProvider.overrideWith((ref) async => alumnos),
    cuotaAlDiaMiembrosProvider.overrideWith(
      (ref) async => alumnos.map((a) => a.id).toSet(),
    ),
    ultimaAsistenciaMiembrosProvider.overrideWith((ref) async => const {}),
    graduacionMiembrosProvider.overrideWith((ref) async => const <String>{}),
  ],
  child: const MaterialApp(home: Scaffold(body: MiembrosScreen())),
);

Widget _ficha({required Profile alumno, MiembrosRepository? repo}) =>
    ProviderScope(
      overrides: [
        if (repo != null) miembrosRepositoryProvider.overrideWithValue(repo),
        ultimaAsistenciaMiembrosProvider.overrideWith((ref) async => const {}),
        progresoCinturonProvider.overrideWith(
          (ref, arg) async => const ProgresoCinturon(
            asistencias: 10,
            requeridas: 100,
            proximoCinturon: 'morado',
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: FichaMiembroScreen(alumno: alumno),
      ),
    );

void main() {
  group('La lista de Miembros', () {
    testWidgets('no enseña a los alumnos de baja', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 1200));
      await tester.pumpWidget(
        _lista(
          alumnos: [
            _alumno(id: 'a', nombre: 'Activa'),
            _alumno(id: 'b', nombre: 'Ida', estado: 'baja'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Activa Ejemplo'), findsOneWidget);
      expect(
        find.text('Ida Ejemplo'),
        findsNothing,
        reason:
            'Si saliera mezclada, dar de baja no cambiaría nada de lo que '
            'ves.',
      );
    });

    testWidgets('los enseña al filtrar por «De baja»', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 1200));
      await tester.pumpWidget(
        _lista(
          alumnos: [
            _alumno(id: 'a', nombre: 'Activa'),
            _alumno(id: 'b', nombre: 'Ida', estado: 'baja'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('DE BAJA'));
      await tester.pumpAndSettle();

      expect(find.text('Ida Ejemplo'), findsOneWidget);
      expect(find.text('Activa Ejemplo'), findsNothing);
    });

    testWidgets('la tarjeta «De baja» no sale si no hay ninguna', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 1200));
      await tester.pumpWidget(
        _lista(
          alumnos: [_alumno(id: 'a', nombre: 'Activa')],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('DE BAJA'),
        findsNothing,
        reason: 'Una tarjeta con un cero no dice nada.',
      );
    });

    testWidgets('el recuento de abajo cuadra con lo que se enseña', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 1200));
      await tester.pumpWidget(
        _lista(
          alumnos: [
            _alumno(id: 'a', nombre: 'Activa'),
            _alumno(id: 'b', nombre: 'Ida', estado: 'baja'),
            _alumno(id: 'c', nombre: 'Otra', estado: 'baja'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Decía «3 ALUMNOS» enseñando uno solo.
      expect(find.text('1 ALUMNO'), findsOneWidget);
      expect(find.text('3 ALUMNOS'), findsNothing);
    });

    testWidgets('los de baja no suman en los recuentos de arriba', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 1200));
      await tester.pumpWidget(
        _lista(
          alumnos: [
            _alumno(id: 'a', nombre: 'Activa'),
            _alumno(id: 'b', nombre: 'Ida', estado: 'baja'),
            _alumno(id: 'c', nombre: 'Otra', estado: 'baja'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Las tres tienen cuota «al día» en este montaje, pero solo una está
      // activa: si «Al día» dijera 3, no cuadraría con la lista de abajo.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('resumen-alDia')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('resumen-deBaja')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });
  });

  group('La ficha del alumno', () {
    testWidgets('ofrece dar de baja a quien está activo', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      await tester.pumpWidget(
        _ficha(
          alumno: _alumno(id: 'a', nombre: 'Ana'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dar de baja'), findsOneWidget);
      expect(find.text('Reactivar al alumno'), findsNothing);
    });

    testWidgets('a quien está de baja le ofrece volver, no irse otra vez', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      await tester.pumpWidget(
        _ficha(
          alumno: _alumno(id: 'a', nombre: 'Ana', estado: 'baja'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reactivar al alumno'), findsOneWidget);
      expect(find.text('Dar de baja'), findsNothing);
    });

    testWidgets('de baja no se le ofrece promover de cinturón', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      await tester.pumpWidget(
        _ficha(
          alumno: _alumno(id: 'a', nombre: 'Ana', estado: 'baja'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Promover a un nuevo cinturón'),
        findsNothing,
        reason: 'No se gradúa a quien ya no viene.',
      );
      expect(find.text('DE BAJA'), findsOneWidget);
    });

    testWidgets('el aviso dice lo que de verdad va a pasar', (tester) async {
      final repo = _RepoFalso();
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      await tester.pumpWidget(
        _ficha(
          alumno: _alumno(id: 'a', nombre: 'Ana'),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dar de baja'));
      await tester.pumpAndSettle();

      // Son tres cosas a la vez y ninguna es obvia: un «¿Seguro?» aquí sería
      // mentir por omisión.
      expect(find.textContaining('libera'), findsOneWidget);
      expect(find.textContaining('cierra la cuota'), findsOneWidget);
      expect(find.textContaining('No se borra nada'), findsOneWidget);
      expect(repo.bajas, isEmpty);
    });

    testWidgets('cancelar no da de baja a nadie', (tester) async {
      final repo = _RepoFalso();
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      await tester.pumpWidget(
        _ficha(
          alumno: _alumno(id: 'a', nombre: 'Ana'),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dar de baja'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.bajas, isEmpty);
    });

    testWidgets('confirmar sí lo manda al servidor', (tester) async {
      final repo = _RepoFalso();
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      await tester.pumpWidget(
        _ficha(
          alumno: _alumno(id: 'a', nombre: 'Ana'),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dar de baja'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Dar de baja'));
      await tester.pumpAndSettle();

      expect(repo.bajas, ['a']);
      expect(repo.reactivados, isEmpty);
    });

    testWidgets('reactivar llama a reactivar, no a dar de baja', (
      tester,
    ) async {
      final repo = _RepoFalso();
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      await tester.pumpWidget(
        _ficha(
          alumno: _alumno(id: 'a', nombre: 'Ana', estado: 'baja'),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reactivar al alumno'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reactivar'));
      await tester.pumpAndSettle();

      expect(repo.reactivados, ['a']);
      expect(repo.bajas, isEmpty);
    });
  });
}
