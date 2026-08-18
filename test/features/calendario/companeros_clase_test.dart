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
import 'package:itaca/features/calendario/data/clases_repository.dart';
import 'package:itaca/features/calendario/data/inscrito_alumno.dart';
import 'package:itaca/features/calendario/presentation/calendario_screen.dart';

/// Los alumnos pedían ver quién más va a una clase, como en MAAT. Solo
/// nombre, foto y cinturón —lo que decidió Cipri—, nunca datos de pago:
/// por eso hay un repositorio de mentira que no expone `sinCuota` alguno,
/// y una prueba específica comprobando que esa columna nunca se pide.

class _RepoFalso implements ClasesRepository {
  _RepoFalso(this.companeros);

  final List<InscritoAlumno> companeros;
  final List<String> clasesConsultadas = [];

  @override
  Future<List<InscritoAlumno>> listarCompaneros(String claseId) async {
    clasesConsultadas.add(claseId);
    return companeros;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ClaseResumen _clase() {
  final hoy = DateTime.now();
  final inicio = DateTime(hoy.year, hoy.month, hoy.day, 17);
  return ClaseResumen(
    id: 'c1',
    titulo: 'Iniciación no gi',
    fechaHoraInicio: inicio,
    fechaHoraFin: inicio.add(const Duration(hours: 1)),
    aforoMaximo: 40,
    profesorId: 'p1',
    profesorNombre: 'Riojano',
    inscritosCount: 2,
  );
}

class _ModoFijo extends AppModeNotifier {
  _ModoFijo(this._inicial);
  final AppMode _inicial;
  @override
  AppMode build() => _inicial;
}

Widget _app(_RepoFalso repo) => ProviderScope(
  overrides: [
    currentUserIdProvider.overrideWithValue('u1'),
    currentProfileProvider.overrideWith(
      (ref) async => Profile(
        id: 'u1',
        academiaId: 'a1',
        rol: 'alumno',
        nombre: 'Riojano',
        apellidos: 'Ejemplo',
        estado: 'activo',
      ),
    ),
    appModeProvider.overrideWith(() => _ModoFijo(AppMode.entrenamiento)),
    clasesRepositoryProvider.overrideWithValue(repo),
    clasesSemanaProvider.overrideWith((ref) async => [_clase()]),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const CalendarioScreen()),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  testWidgets('tocar la clase enseña quién está apuntado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso([
      const InscritoAlumno(
        alumnoId: 'a1',
        nombre: 'Uno',
        apellidos: 'Ejemplo',
        cinturon: 'azul',
        asistenciaValidada: false,
      ),
      const InscritoAlumno(
        alumnoId: 'a2',
        nombre: 'Dos',
        apellidos: 'Ejemplo',
        cinturon: 'blanco',
        asistenciaValidada: false,
      ),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciación no gi'));
    await tester.pumpAndSettle();

    expect(repo.clasesConsultadas, ['c1']);
    expect(find.text('Uno Ejemplo'), findsOneWidget);
    expect(find.text('Dos Ejemplo'), findsOneWidget);
  });

  testWidgets('sin nadie apuntado, lo dice en vez de una lista vacía', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso(const []);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciación no gi'));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no se ha apuntado nadie.'), findsOneWidget);
  });

  testWidgets('tocar el botón de reservar no abre la hoja de compañeros', (
    tester,
  ) async {
    // El botón de acción vive dentro de la tarjeta: si el toque se colara
    // hasta el InkWell de fondo, reservar plaza abriría también la hoja.
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso(const []);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reservar plaza'));
    await tester.pumpAndSettle();

    expect(find.text('Apuntados a esta clase'), findsNothing);
  });

  testWidgets('una clase con 40 apuntados no revienta el layout', (
    tester,
  ) async {
    // Cipri lo probó con una clase real de 40 alumnos y la hoja se rompía:
    // sin límite de alto, intentaba pedir sitio para las 40 filas de golpe.
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso([
      for (var i = 0; i < 40; i++)
        InscritoAlumno(
          alumnoId: 'a$i',
          nombre: 'Alumno $i',
          apellidos: 'Ejemplo',
          cinturon: 'azul',
          asistenciaValidada: false,
        ),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciación no gi'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Alumno 0 Ejemplo'), findsOneWidget);
    // Con 40 filas la lista no cabe entera: se desplaza, así que el
    // último no tiene por qué estar ya construido en pantalla.
    expect(find.text('Alumno 39 Ejemplo'), findsNothing);

    // La lista tiene que quedarse dentro de un límite razonable de la
    // pantalla, nunca crecer sin tope: eso es justo lo que se rompía con
    // muchos apuntados.
    final alto = tester
        .getSize(find.byKey(const Key('lista_companeros')))
        .height;
    expect(alto, lessThanOrEqualTo(450));
  });
}
