import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/calendario/application/clases_providers.dart';
import 'package:itaca/features/calendario/data/clase_resumen.dart';
import 'package:itaca/features/calendario/data/clases_repository.dart';
import 'package:itaca/features/calendario/presentation/calendario_screen.dart';
import 'package:itaca/features/perfil/application/profile_providers.dart';

/// Reservar clase para un hijo desde el calendario (06/09/2026).
///
/// La base de datos ya lo permitía desde el 03/09. Lo que se prueba aquí es
/// lo que ve y toca el padre: que quien no tiene hijos no note ningún
/// cambio, que quien los tiene pueda apuntarlos, y que la tarjeta enseñe
/// quién de la familia tiene plaza — sin eso el padre apunta al niño y la
/// pantalla no se entera.

class _RepoFalso implements ClasesRepository {
  final List<String> llamadas = [];
  Object? error;

  @override
  Future<String> unirse({required String claseId, String? alumnoId}) async {
    if (error != null) throw error!;
    llamadas.add('unirse($claseId, ${alumnoId ?? 'yo'})');
    return 'inscrito';
  }

  @override
  Future<bool> borrarse({required String claseId, String? alumnoId}) async {
    if (error != null) throw error!;
    llamadas.add('borrarse($claseId, ${alumnoId ?? 'yo'})');
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Profile _perfil({bool entrena = true}) => Profile(
  id: 'u1',
  academiaId: 'a1',
  rol: 'alumno',
  nombre: 'Riojano',
  apellidos: 'Ejemplo',
  estado: 'activo',
  entrena: entrena,
);

Profile _hijo(String id, String nombre) => Profile(
  id: id,
  academiaId: 'a1',
  rol: 'alumno',
  nombre: nombre,
  apellidos: 'Ejemplo',
  estado: 'activo',
);

ClaseResumen _clase({
  String? miEstado,
  List<ReservaFamiliar> reservasFamilia = const [],
  int aforo = 40,
  int inscritos = 3,
}) {
  final hoy = DateTime.now();
  final inicio = DateTime(hoy.year, hoy.month, hoy.day, 17);
  return ClaseResumen(
    id: 'c1',
    titulo: 'Infantil',
    fechaHoraInicio: inicio,
    fechaHoraFin: inicio.add(const Duration(hours: 1)),
    aforoMaximo: aforo,
    profesorId: 'p1',
    profesorNombre: 'Riojano',
    inscritosCount: inscritos,
    miEstado: miEstado,
    reservasFamilia: reservasFamilia,
  );
}

Widget _app(
  _RepoFalso repo, {
  required List<Profile> hijos,
  ClaseResumen? clase,
  bool entrena = true,
}) => ProviderScope(
  overrides: [
    currentUserIdProvider.overrideWithValue('u1'),
    currentProfileProvider.overrideWith(
      (ref) async => _perfil(entrena: entrena),
    ),
    hijosProvider.overrideWith((ref) async => hijos),
    clasesSemanaProvider.overrideWith((ref) async => [clase ?? _clase()]),
    clasesRepositoryProvider.overrideWithValue(repo),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const CalendarioScreen()),
);

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  testWidgets('quien no tiene hijos reserva como siempre, de un solo toque', (
    tester,
  ) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(repo, hijos: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reservar plaza'));
    await tester.pumpAndSettle();

    expect(
      repo.llamadas,
      ['unirse(c1, yo)'],
      reason: 'Sin familia el botón reserva directamente, sin preguntar nada.',
    );
    expect(
      find.text('¿Quién viene?'),
      findsNothing,
      reason: 'Son la inmensa mayoría: no hay por qué añadirles un paso.',
    );
  });

  testWidgets('con hijos, el botón abre la hoja y no reserva de golpe', (
    tester,
  ) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(repo, hijos: [_hijo('h1', 'Nico')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reservar plaza'));
    await tester.pumpAndSettle();

    expect(find.text('¿Quién viene?'), findsOneWidget);
    expect(
      repo.llamadas,
      isEmpty,
      reason: 'Abrir la hoja no reserva nada todavía.',
    );
    expect(find.text('Yo'), findsOneWidget);
    expect(find.text('Nico Ejemplo'), findsOneWidget);
  });

  testWidgets('apuntar a un hijo manda su id al servidor, no el del padre', (
    tester,
  ) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(repo, hijos: [_hijo('h1', 'Nico')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reservar plaza'));
    await tester.pumpAndSettle();

    // El primer «Reservar plaza» de la hoja es el del padre; el segundo, el
    // del hijo.
    await tester.tap(find.text('Reservar plaza').last);
    await tester.pumpAndSettle();

    expect(repo.llamadas, ['unirse(c1, h1)']);
  });

  testWidgets('la hoja no se cierra tras apuntar a uno', (tester) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(repo, hijos: [_hijo('h1', 'Nico'), _hijo('h2', 'Lucía')]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reservar plaza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reservar plaza').last);
    await tester.pumpAndSettle();

    expect(
      find.text('¿Quién viene?'),
      findsOneWidget,
      reason:
          'Con dos hijos se apunta a los dos seguidos; cerrarla obliga a '
          'volver a abrirla.',
    );
  });

  testWidgets('el tutor que no entrena no se ve a sí mismo en la lista', (
    tester,
  ) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(repo, hijos: [_hijo('h1', 'Nico')], entrena: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reservar plaza'));
    await tester.pumpAndSettle();

    expect(
      find.text('Yo'),
      findsNothing,
      reason:
          'El servidor le rechazaría la reserva: sería un botón que no '
          'funciona.',
    );
    expect(find.text('Nico Ejemplo'), findsOneWidget);
  });

  testWidgets('la tarjeta dice qué hijo tiene plaza', (tester) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        repo,
        hijos: [_hijo('h1', 'Nico')],
        clase: _clase(
          reservasFamilia: const [
            ReservaFamiliar(alumnoId: 'h1', estado: 'inscrito'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // La pastilla va en mayúsculas por el sistema de diseño (etiquetas mono).
    expect(
      find.text('NICO'),
      findsOneWidget,
      reason: 'Sin esto el padre apunta al niño y la tarjeta no cambia.',
    );
    expect(find.text('Cambiar quién viene'), findsOneWidget);
  });

  testWidgets(
    'mi propia plaza sale con mi nombre, no como un «inscrito» suelto',
    (tester) async {
      final repo = _RepoFalso();
      await tester.binding.setSurfaceSize(const Size(412, 900));
      await tester.pumpWidget(
        _app(
          repo,
          hijos: [_hijo('h1', 'Nico')],
          clase: _clase(
            miEstado: 'inscrito',
            reservasFamilia: const [
              ReservaFamiliar(alumnoId: 'h1', estado: 'inscrito'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('TÚ'),
        findsOneWidget,
        reason: 'Al lado de «NICO», un «INSCRITO» suelto no dice de quién es.',
      );
      expect(find.text('INSCRITO'), findsNothing);
    },
  );

  testWidgets('la lista de espera de un hijo se distingue de la plaza', (
    tester,
  ) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        repo,
        hijos: [_hijo('h1', 'Nico')],
        clase: _clase(
          reservasFamilia: const [
            ReservaFamiliar(alumnoId: 'h1', estado: 'espera'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NICO · EN ESPERA'), findsOneWidget);
  });

  testWidgets('quitar a un hijo manda su id, y avisa de qué ha pasado', (
    tester,
  ) async {
    final repo = _RepoFalso();
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        repo,
        hijos: [_hijo('h1', 'Nico')],
        clase: _clase(
          reservasFamilia: const [
            ReservaFamiliar(alumnoId: 'h1', estado: 'inscrito'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cambiar quién viene'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar la reserva'));
    await tester.pumpAndSettle();

    expect(repo.llamadas, ['borrarse(c1, h1)']);
    expect(find.text('Reserva cancelada.'), findsOneWidget);
  });

  testWidgets('si el servidor rechaza, se explica con el nombre del hijo', (
    tester,
  ) async {
    final repo = _RepoFalso()
      ..error = Exception('Este alumno tiene marcado que no entrena.');
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(repo, hijos: [_hijo('h1', 'Nico')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reservar plaza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reservar plaza').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Nico está dado de alta como acompañante'),
      findsOneWidget,
      reason:
          'Un error impersonal en una familia de tres no dice a quién le '
          'ha pasado.',
    );
  });
}
