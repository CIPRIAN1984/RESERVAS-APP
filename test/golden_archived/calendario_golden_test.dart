@Tags(['golden'])

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/app_mode.dart';
import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/app/theme/color_tokens.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/calendario/application/clases_providers.dart';
import 'package:itaca/features/calendario/data/clase_resumen.dart';
import 'package:itaca/features/calendario/presentation/calendario_screen.dart';

import 'ayuda_golden.dart';

/// El calendario mensual de puntitos se sustituye por el que pide la skill
/// `diseno-i-plus`: siete pastillas, lunes a domingo, el día seleccionado en
/// amarillo eléctrico. Cipri además pidió quitar los puntos de aviso bajo
/// los días: con clase casi todos los días no distinguían nada.

List<ClaseResumen> _clasesDeLaSemana(DateTime lunes) => [
  for (final (dia, hora, titulo) in [
    (0, 9, 'Iniciación no gi'),
    (2, 18, 'BJJ Fundamentos'),
    (4, 19, 'Competición'),
  ])
    ClaseResumen(
      id: 'c$dia$hora',
      titulo: titulo,
      fechaHoraInicio: lunes.add(Duration(days: dia, hours: hora)),
      fechaHoraFin: lunes.add(Duration(days: dia, hours: hora + 1)),
      aforoMaximo: 20,
      profesorId: 'p1',
      profesorNombre: 'Itaca',
      inscritosCount: 4,
    ),
];

class _ModoFijo extends AppModeNotifier {
  _ModoFijo(this._inicial);
  final AppMode _inicial;
  @override
  AppMode build() => _inicial;
}

Widget _app({
  required String rol,
  required AppMode modo,
  DateTime? seleccionado,
}) {
  final lunes = mondayOf(DateTime.now());
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('a1'),
      currentProfileProvider.overrideWith(
        (ref) async => Profile(
          id: 'a1',
          academiaId: 'ac1',
          rol: rol,
          nombre: 'Riojano',
          apellidos: 'Ejemplo',
          estado: 'activo',
        ),
      ),
      appModeProvider.overrideWith(() => _ModoFijo(modo)),
      visibleWeekProvider.overrideWith((ref) => lunes),
      selectedDayProvider.overrideWith((ref) => seleccionado ?? lunes),
      clasesSemanaProvider.overrideWith(
        (ref) async => _clasesDeLaSemana(lunes),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(body: SafeArea(child: CalendarioScreen())),
    ),
  );
}

void main() {
  setUpAll(cargarTipografias);

  testWidgets(
    'Semana con clases — sin puntos, lunes seleccionado en amarillo',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      await tester.pumpWidget(_app(rol: 'alumno', modo: AppMode.entrenamiento));
      await tester.pumpAndSettle();

      // Los siete días de la semana, ni uno más.
      for (final dia in ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM']) {
        expect(find.text(dia), findsOneWidget);
      }

      await comparaCon(
        find.byType(MaterialApp),
        'goldens/calendario_semana.png',
      );
    },
  );

  testWidgets('Modo Gestor — «Hoy», día sin clases y «Crear clase»', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final lunes = mondayOf(DateTime.now());
    await tester.pumpWidget(
      _app(
        rol: 'dueño',
        modo: AppMode.gestor,
        // Miércoles: en el escenario de arriba no tiene clases.
        seleccionado: lunes.add(const Duration(days: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('No hay clases este día.'), findsOneWidget);
    expect(find.text('Crear clase'), findsOneWidget);

    // El gris «subtle» sobre el amarillo de acento casi no se leía: se vio
    // al mirar la captura, no al correr las pruebas de comportamiento. La
    // etiqueta del día seleccionado tiene que pasar a tinta.
    final etiqueta = tester.widget<Text>(find.text('MAR'));
    expect(etiqueta.style?.color, AppColors.ink);

    await comparaCon(
      find.byType(MaterialApp),
      'goldens/calendario_semana_gestor_vacio.png',
    );
  });
}
