import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/features/calendario/application/clases_providers.dart';
import 'package:itaca/features/calendario/data/clases_repository.dart';
import 'package:itaca/features/calendario/presentation/crear_clase_screen.dart';

/// Auditoría del 09/10/2026, punto 5: «Clase periódica» era un bucle de
/// inserciones desde la app. Si fallaba a mitad quedaban las primeras y al
/// repetir salían duplicadas; y sumar 7 días exactos movía la clase una
/// hora al cruzar el cambio de hora. Ahora es una sola llamada, con la
/// fecha y la hora de la pared (el servidor pone la zona horaria).

class _RepoFalso implements ClasesRepository {
  final List<Map<String, Object?>> llamadas = [];

  @override
  Future<int> crearClases({
    required String titulo,
    String? descripcion,
    required DateTime fecha,
    required ({int hora, int minuto}) inicio,
    required ({int hora, int minuto}) fin,
    required int aforoMaximo,
    int semanas = 1,
  }) async {
    llamadas.add({
      'titulo': titulo,
      'fecha': fecha,
      'inicio': inicio,
      'fin': fin,
      'semanas': semanas,
    });
    return semanas;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  test('manda fecha y horas de la pared, sin zona horaria', () {
    final params = paramsCrearClases(
      titulo: 'BJJ',
      fecha: DateTime(2027, 10, 26),
      inicio: (hora: 9, minuto: 5),
      fin: (hora: 10, minuto: 0),
      aforoMaximo: 15,
      semanas: 3,
    );
    expect(params['p_fecha'], '2027-10-26');
    expect(params['p_hora_inicio'], '09:05');
    expect(params['p_hora_fin'], '10:00');
    expect(params['p_semanas'], 3);
  });

  testWidgets('una clase periódica de 4 semanas es una sola llamada', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    final repo = _RepoFalso();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clasesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CrearClaseScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título'),
      'BJJ martes',
    );
    await tester.tap(find.text('Clase periódica'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear clases'));
    await tester.tap(find.text('Crear clases'));
    await tester.pumpAndSettle();

    expect(repo.llamadas, hasLength(1));
    expect(repo.llamadas.single['semanas'], 4);
    expect(repo.llamadas.single['inicio'], (hora: 19, minuto: 0));
    expect(repo.llamadas.single['fin'], (hora: 20, minuto: 0));
  });
}
