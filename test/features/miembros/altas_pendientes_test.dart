import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/miembros/application/miembros_providers.dart';
import 'package:itaca/features/miembros/data/miembros_repository.dart';
import 'package:itaca/features/miembros/presentation/miembros_screen.dart';

/// Altas pendientes (17/11/2026): quien se registra no entra hasta que el
/// Dueño lo aprueba desde Miembros.

class _RepoFalso implements MiembrosRepository {
  final List<String> aprobados = [];
  final List<String> rechazados = [];

  @override
  Future<void> aprobar(String miembroId) async => aprobados.add(miembroId);

  @override
  Future<void> rechazar(String miembroId) async => rechazados.add(miembroId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Profile _persona(String id, String nombre, String estado) => Profile(
  id: id,
  academiaId: 'a1',
  rol: 'alumno',
  nombre: nombre,
  apellidos: 'Ejemplo',
  estado: estado,
);

Widget _app({required String rol, MiembrosRepository? repo}) => ProviderScope(
  overrides: [
    if (repo != null) miembrosRepositoryProvider.overrideWithValue(repo),
    currentProfileProvider.overrideWith(
      (ref) async => Profile(
        id: 'u1',
        academiaId: 'a1',
        rol: rol,
        nombre: 'Staff',
        estado: 'activo',
      ),
    ),
    alumnosMiembrosProvider.overrideWith(
      (ref) async => [
        _persona('a', 'Ana', 'activo'),
        _persona('n', 'Nuria', 'pendiente_aprobacion'),
      ],
    ),
    cuotaAlDiaMiembrosProvider.overrideWith((ref) async => {'a'}),
    ultimaAsistenciaMiembrosProvider.overrideWith((ref) async => const {}),
    graduacionMiembrosProvider.overrideWith((ref) async => const <String>{}),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: MiembrosScreen()),
  ),
);

void main() {
  testWidgets('el Dueño ve el aviso y la pendiente no cuenta como alumna', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    await tester.pumpWidget(_app(rol: 'dueño'));
    await tester.pumpAndSettle();

    expect(find.text('1 alta pendiente de aprobar'), findsOneWidget);
    // En la lista solo está la alumna activa.
    expect(find.text('Ana Ejemplo'), findsOneWidget);
    expect(find.text('Nuria Ejemplo'), findsNothing);
  });

  testWidgets('aprobar manda la aprobación al servidor', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    final repo = _RepoFalso();
    await tester.pumpWidget(_app(rol: 'dueño', repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1 alta pendiente de aprobar'));
    await tester.pumpAndSettle();
    expect(find.text('Nuria Ejemplo'), findsOneWidget);

    await tester.tap(find.text('Aprobar a Nuria'));
    await tester.pumpAndSettle();

    expect(repo.aprobados, ['n']);
    expect(repo.rechazados, isEmpty);
  });

  testWidgets('rechazar manda el rechazo, no la aprobación', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    final repo = _RepoFalso();
    await tester.pumpWidget(_app(rol: 'dueño', repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1 alta pendiente de aprobar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();

    expect(repo.rechazados, ['n']);
    expect(repo.aprobados, isEmpty);
  });

  testWidgets('al Profesor no se le ofrece aprobar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    await tester.pumpWidget(_app(rol: 'profesor'));
    await tester.pumpAndSettle();

    expect(find.text('1 alta pendiente de aprobar'), findsNothing);
    expect(find.text('Nuria Ejemplo'), findsNothing);
  });
}
