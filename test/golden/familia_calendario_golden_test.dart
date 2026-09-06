@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/calendario/application/clases_providers.dart';
import 'package:itaca/features/calendario/data/clase_resumen.dart';
import 'package:itaca/features/calendario/presentation/calendario_screen.dart';
import 'package:itaca/features/perfil/application/profile_providers.dart';

import '../golden_archived/ayuda_golden.dart';

/// Reservar por un hijo, mirado de verdad: la tarjeta del calendario con los
/// hijos apuntados y la hoja «¿Quién viene?».

Profile _perfil({bool entrena = true}) => Profile(
  id: 'u1',
  academiaId: 'a1',
  rol: 'alumno',
  nombre: 'Marta',
  apellidos: 'Ruiz',
  cinturon: 'azul',
  estado: 'activo',
  entrena: entrena,
);

Profile _hijo(String id, String nombre, String? cinturon) => Profile(
  id: id,
  academiaId: 'a1',
  rol: 'alumno',
  nombre: nombre,
  apellidos: 'Ruiz',
  cinturon: cinturon,
  estado: 'activo',
);

ClaseResumen _clase({
  required String id,
  required String titulo,
  required int hora,
  String? miEstado,
  List<ReservaFamiliar> reservasFamilia = const [],
  int inscritos = 12,
  int aforo = 24,
}) {
  final hoy = DateTime.now();
  final inicio = DateTime(hoy.year, hoy.month, hoy.day, hora);
  return ClaseResumen(
    id: id,
    titulo: titulo,
    fechaHoraInicio: inicio,
    fechaHoraFin: inicio.add(const Duration(hours: 1)),
    aforoMaximo: aforo,
    profesorId: 'p1',
    profesorNombre: 'Cipri',
    inscritosCount: inscritos,
    miEstado: miEstado,
    reservasFamilia: reservasFamilia,
  );
}

Widget _app({
  required List<Profile> hijos,
  required List<ClaseResumen> clases,
  bool entrena = true,
}) => ProviderScope(
  overrides: [
    currentUserIdProvider.overrideWithValue('u1'),
    currentProfileProvider.overrideWith(
      (ref) async => _perfil(entrena: entrena),
    ),
    hijosProvider.overrideWith((ref) async => hijos),
    clasesSemanaProvider.overrideWith((ref) async => clases),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const CalendarioScreen()),
);

void main() {
  setUpAll(cargarTipografias);

  testWidgets('Calendario de una madre con dos hijos', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        hijos: [
          _hijo('h1', 'Nico', 'gris_blanco'),
          _hijo('h2', 'Lucía', 'amarillo'),
        ],
        clases: [
          _clase(
            id: 'c1',
            titulo: 'Infantil 6-9 años',
            hora: 17,
            reservasFamilia: const [
              ReservaFamiliar(alumnoId: 'h1', estado: 'inscrito'),
              ReservaFamiliar(alumnoId: 'h2', estado: 'espera'),
            ],
          ),
          _clase(
            id: 'c2',
            titulo: 'Adultos no gi',
            hora: 20,
            miEstado: 'inscrito',
            inscritos: 18,
            reservasFamilia: const [],
          ),
          _clase(id: 'c3', titulo: 'Open mat', hora: 21, inscritos: 4),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Infantil 6-9 años'), findsOneWidget);
    await comparaCon(
      find.byType(MaterialApp),
      'goldens/familia_calendario.png',
    );
  });

  testWidgets('La hoja «¿Quién viene?»', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        hijos: [
          _hijo('h1', 'Nico', 'gris_blanco'),
          _hijo('h2', 'Lucía', 'amarillo'),
        ],
        clases: [
          _clase(
            id: 'c1',
            titulo: 'Infantil 6-9 años',
            hora: 17,
            reservasFamilia: const [
              ReservaFamiliar(alumnoId: 'h1', estado: 'inscrito'),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cambiar quién viene'));
    await tester.pumpAndSettle();

    expect(find.text('¿Quién viene?'), findsOneWidget);
    await comparaCon(
      find.byType(MaterialApp),
      'goldens/familia_quien_viene.png',
    );
  });

  testWidgets('La hoja de un tutor que no entrena', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        entrena: false,
        hijos: [_hijo('h1', 'Nico', 'gris_blanco')],
        clases: [_clase(id: 'c1', titulo: 'Infantil 6-9 años', hora: 17)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reservar plaza'));
    await tester.pumpAndSettle();

    expect(find.text('Yo'), findsNothing);
    await comparaCon(
      find.byType(MaterialApp),
      'goldens/familia_solo_tutor.png',
    );
  });
}
