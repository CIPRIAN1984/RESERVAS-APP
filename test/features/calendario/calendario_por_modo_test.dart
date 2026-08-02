import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/app_mode.dart';
import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/calendario/application/clases_providers.dart';
import 'package:itaca/features/calendario/data/clase_resumen.dart';
import 'package:itaca/features/calendario/presentation/calendario_screen.dart';

/// Un dueño también entrena. Antes se le daba la versión de gestión del
/// calendario en los dos modos, así que no tenía forma de apuntarse a una
/// clase: la tarjeta llevaba a la lista de asistentes y no traía botón.
///
/// El servidor siempre lo permitió (`reservar_clase` acepta alumno, profesor
/// y dueño); el que estorbaba era el cliente.

Profile _perfil({required String rol}) => Profile(
  id: 'u1',
  academiaId: 'a1',
  rol: rol,
  nombre: 'Riojano',
  apellidos: 'Ejemplo',
  estado: 'activo',
);

ClaseResumen _clase() {
  final hoy = DateTime.now();
  final inicio = DateTime(hoy.year, hoy.month, hoy.day, 17);
  return ClaseResumen(
    id: 'c1',
    titulo: 'Iniciación no gi',
    fechaHoraInicio: inicio,
    fechaHoraFin: inicio.add(const Duration(hours: 1)),
    aforoMaximo: 40,
    profesorId: 'u1',
    profesorNombre: 'Riojano',
    inscritosCount: 0,
  );
}

class _ModoFijo extends AppModeNotifier {
  _ModoFijo(this._inicial);
  final AppMode _inicial;
  @override
  AppMode build() => _inicial;
}

Widget _app({required String rol, required AppMode modo}) => ProviderScope(
  overrides: [
    currentUserIdProvider.overrideWithValue('u1'),
    currentProfileProvider.overrideWith((ref) async => _perfil(rol: rol)),
    appModeProvider.overrideWith(() => _ModoFijo(modo)),
    clasesSemanaProvider.overrideWith((ref) async => [_clase()]),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const CalendarioScreen()),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  testWidgets('un dueño en Entrenamiento puede apuntarse a la clase', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(rol: 'dueño', modo: AppMode.entrenamiento));
    await tester.pumpAndSettle();

    expect(find.text('Reservar plaza'), findsOneWidget);
    expect(
      find.text('Crear clase'),
      findsNothing,
      reason: 'Crear clases es gestionar, y aquí está entrenando.',
    );
  });

  testWidgets('un dueño en Gestor administra la clase y no se apunta', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(rol: 'dueño', modo: AppMode.gestor));
    await tester.pumpAndSettle();

    expect(find.text('Crear clase'), findsOneWidget);
    expect(find.text('Reservar plaza'), findsNothing);
  });

  testWidgets('un alumno siempre puede apuntarse y nunca crear clases', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(rol: 'alumno', modo: AppMode.entrenamiento));
    await tester.pumpAndSettle();

    expect(find.text('Reservar plaza'), findsOneWidget);
    expect(find.text('Crear clase'), findsNothing);
  });

  testWidgets('en Entrenamiento manda el saludo del atleta', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(rol: 'dueño', modo: AppMode.entrenamiento));
    await tester.pumpAndSettle();

    expect(find.text('¡Hola, Riojano!'), findsOneWidget);
    expect(find.text('Hoy'), findsNothing);
  });

  testWidgets('en Gestor manda el título «Hoy», no el saludo', (tester) async {
    // El saludo se colaba hasta dentro de Herramientas > Horario.
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(rol: 'dueño', modo: AppMode.gestor));
    await tester.pumpAndSettle();

    expect(find.text('¡Hola, Riojano!'), findsNothing);
    expect(find.text('Hoy'), findsOneWidget);
  });
}
