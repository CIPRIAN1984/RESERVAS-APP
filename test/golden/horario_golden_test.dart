@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/horario/application/horario_providers.dart';
import 'package:itaca/features/horario/data/plantilla_clase.dart';
import 'package:itaca/features/horario/presentation/horario_screen.dart';

import '../golden_archived/ayuda_golden.dart';

/// El horario semanal fijo, mirado de verdad.

PlantillaClase _plantilla({
  required String id,
  required String titulo,
  required int diaSemana,
  required String horaInicio,
  bool activo = true,
}) => PlantillaClase(
  id: id,
  academiaId: 'a1',
  profesorId: 'u1',
  profesorNombre: 'Cipri',
  titulo: titulo,
  diaSemana: diaSemana,
  horaInicio: horaInicio,
  duracionMin: 60,
  aforoMaximo: 15,
  activo: activo,
);

Widget _pantalla(List<PlantillaClase> plantillas) => ProviderScope(
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
    plantillasProvider('a1').overrideWith((ref) async => plantillas),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      appBar: AppBar(title: const Text('Horario semanal')),
      body: const SafeArea(child: HorarioScreen()),
    ),
  ),
);

void main() {
  setUpAll(cargarTipografias);

  testWidgets('Sin ningún horario fijo todavía', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_pantalla(const []));
    await tester.pumpAndSettle();

    await comparaCon(find.byType(MaterialApp), 'goldens/horario_vacio.png');
  });

  testWidgets('Con la semana llena, una pausada', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1300));
    await tester.pumpWidget(
      _pantalla([
        _plantilla(
          id: 'p1',
          titulo: 'BJJ Fundamentals',
          diaSemana: 1,
          horaInicio: '19:00',
        ),
        _plantilla(
          id: 'p2',
          titulo: 'BJJ Avanzado',
          diaSemana: 1,
          horaInicio: '20:30',
        ),
        _plantilla(
          id: 'p3',
          titulo: 'Yoga',
          diaSemana: 3,
          horaInicio: '18:00',
          activo: false,
        ),
        _plantilla(
          id: 'p4',
          titulo: 'Competición',
          diaSemana: 6,
          horaInicio: '10:00',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('PAUSADO'), findsOneWidget);
    await comparaCon(find.byType(MaterialApp), 'goldens/horario_lista.png');
  });
}
