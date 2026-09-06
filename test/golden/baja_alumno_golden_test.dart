@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/miembros/application/miembros_providers.dart';
import 'package:itaca/features/miembros/domain/progreso_cinturon.dart';
import 'package:itaca/features/miembros/presentation/ficha_miembro_screen.dart';
import 'package:itaca/features/miembros/presentation/miembros_screen.dart';

import '../golden_archived/ayuda_golden.dart';

/// Dar de baja a un alumno, mirado de verdad.

Profile _alumno(String id, String nombre, String cinturon, {String? estado}) =>
    Profile(
      id: id,
      academiaId: 'a1',
      rol: 'alumno',
      nombre: nombre,
      apellidos: 'Ruiz',
      cinturon: cinturon,
      estado: estado ?? 'activo',
      fechaInicioCinturon: DateTime(2026, 1, 15),
    );

Widget _lista(List<Profile> alumnos) => ProviderScope(
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
    alumnosMiembrosProvider.overrideWith((ref) async => alumnos),
    cuotaAlDiaMiembrosProvider.overrideWith((ref) async => {alumnos.first.id}),
    ultimaAsistenciaMiembrosProvider.overrideWith((ref) async => const {}),
    graduacionMiembrosProvider.overrideWith((ref) async => const <String>{}),
  ],
  // Con el tema de verdad: sin él, el texto se dibuja con la tipografía de
  // relleno del entorno de pruebas y sale todo en cajas negras.
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: MiembrosScreen()),
  ),
);

Widget _ficha(Profile alumno) => ProviderScope(
  overrides: [
    ultimaAsistenciaMiembrosProvider.overrideWith((ref) async => const {}),
    progresoCinturonProvider.overrideWith(
      (ref, arg) async => const ProgresoCinturon(
        asistencias: 42,
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
  setUpAll(cargarTipografias);

  testWidgets('Miembros con dos alumnos de baja', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1100));
    await tester.pumpWidget(
      _lista([
        _alumno('a', 'Marta', 'azul'),
        _alumno('b', 'Nico', 'blanco'),
        _alumno('c', 'Ana', 'morado', estado: 'baja'),
        _alumno('d', 'Luis', 'blanco', estado: 'baja'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('DE BAJA'), findsOneWidget);
    await comparaCon(find.byType(MaterialApp), 'goldens/baja_miembros.png');
  });

  testWidgets('La ficha de un alumno de baja', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(
      _ficha(_alumno('c', 'Ana', 'morado', estado: 'baja')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reactivar al alumno'), findsOneWidget);
    await comparaCon(find.byType(MaterialApp), 'goldens/baja_ficha.png');
  });

  testWidgets('El aviso antes de dar de baja', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1000));
    await tester.pumpWidget(_ficha(_alumno('a', 'Marta', 'azul')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dar de baja'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se borra nada'), findsOneWidget);
    await comparaCon(find.byType(MaterialApp), 'goldens/baja_confirmar.png');
  });
}
