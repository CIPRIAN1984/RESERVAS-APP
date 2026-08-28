import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/equipo/application/equipo_providers.dart';
import 'package:itaca/features/equipo/presentation/equipo_screen.dart';

/// Reservar plaza exige al Alumno una cuota con el pago activo, y ese estado
/// solo lo enciende el webhook de Stripe. Mientras Stripe no esté conectado,
/// el Dueño necesita ver de un vistazo quién ha pagado y poder registrar un
/// cobro en mano; si no, ningún alumno puede reservar nunca.

Profile _perfil({required String id, required String rol, String? nombre}) =>
    Profile(
      id: id,
      academiaId: 'a1',
      rol: rol,
      nombre: nombre ?? 'Miembro',
      apellidos: 'Ejemplo',
      estado: 'activo',
    );

Widget _app({
  required List<Profile> miembros,
  required Map<
    String,
    ({String id, String tarifa, bool efectivo, String estado})
  >
  cuotas,
}) => ProviderScope(
  overrides: [
    currentUserIdProvider.overrideWithValue('d1'),
    currentProfileProvider.overrideWith(
      (ref) async => _perfil(id: 'd1', rol: 'dueño', nombre: 'Dueño'),
    ),
    miembrosEquipoProvider.overrideWith((ref) async => miembros),
    cuotasActivasProvider.overrideWith((ref) async => cuotas),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: EquipoScreen()),
  ),
);

void main() {
  testWidgets('un alumno sin cuota se marca como tal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        miembros: [_perfil(id: 'a1', rol: 'alumno', nombre: 'Ana')],
        cuotas: const {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SIN CUOTA'), findsOneWidget);
  });

  testWidgets('un alumno con cuota en efectivo se distingue de Stripe', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        miembros: [
          _perfil(id: 'a1', rol: 'alumno', nombre: 'Ana'),
          _perfil(id: 'a2', rol: 'alumno', nombre: 'Beto'),
        ],
        cuotas: const {
          'a1': (id: 's1', tarifa: 'Mensual', efectivo: true, estado: 'activa'),
          'a2': (
            id: 's2',
            tarifa: 'Mensual',
            efectivo: false,
            estado: 'activa',
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EFECTIVO'), findsOneWidget);
    expect(find.text('AL CORRIENTE'), findsOneWidget);
    expect(find.text('SIN CUOTA'), findsNothing);
  });

  testWidgets('a un profesor no se le pide cuota: reserva sin ella', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        miembros: [_perfil(id: 'p1', rol: 'profesor', nombre: 'Pepe')],
        cuotas: const {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SIN CUOTA'), findsNothing);
    expect(find.text('Profesor'), findsOneWidget);
  });

  testWidgets('el menú ofrece registrar el cobro de un alumno sin cuota', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        miembros: [_perfil(id: 'a1', rol: 'alumno', nombre: 'Ana')],
        cuotas: const {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
    await tester.pumpAndSettle();

    expect(find.text('Registrar cobro'), findsOneWidget);
    expect(find.text('Hacer profesor'), findsOneWidget);
    expect(
      find.text('Retirar cuota'),
      findsNothing,
      reason: 'No hay ninguna cuota que retirar.',
    );
  });

  testWidgets('solo se puede retirar una cuota en efectivo, no una de Stripe', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        miembros: [_perfil(id: 'a2', rol: 'alumno', nombre: 'Beto')],
        cuotas: const {
          'a2': (
            id: 's2',
            tarifa: 'Mensual',
            efectivo: false,
            estado: 'activa',
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
    await tester.pumpAndSettle();

    expect(find.text('Renovar cuota'), findsOneWidget);
    expect(
      find.text('Retirar cuota'),
      findsNothing,
      reason: 'Una cuota de Stripe se cancela en Stripe, no aquí.',
    );
  });

  testWidgets('un alumno en prueba se marca como tal, no como al día', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        miembros: [_perfil(id: 'a1', rol: 'alumno', nombre: 'Ana')],
        cuotas: const {
          'a1': (id: 's1', tarifa: 'Mensual', efectivo: true, estado: 'prueba'),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRUEBA'), findsOneWidget);
    expect(find.text('SIN CUOTA'), findsNothing);
    expect(find.text('EFECTIVO'), findsNothing);
  });

  testWidgets('un alumno con cuota pausada se marca como tal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        miembros: [_perfil(id: 'a1', rol: 'alumno', nombre: 'Ana')],
        cuotas: const {
          'a1': (
            id: 's1',
            tarifa: 'Mensual',
            efectivo: true,
            estado: 'pausada',
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PAUSADA'), findsOneWidget);
  });

  testWidgets('sin cuota, el menú ofrece iniciar una prueba', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        miembros: [_perfil(id: 'a1', rol: 'alumno', nombre: 'Ana')],
        cuotas: const {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar prueba (1 día)'), findsOneWidget);
  });

  testWidgets(
    'con la cuota activa y en efectivo, el menú ofrece pausarla; no reanudarla',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      await tester.pumpWidget(
        _app(
          miembros: [_perfil(id: 'a1', rol: 'alumno', nombre: 'Ana')],
          cuotas: const {
            'a1': (
              id: 's1',
              tarifa: 'Mensual',
              efectivo: true,
              estado: 'activa',
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
      await tester.pumpAndSettle();

      expect(find.text('Pausar cuota'), findsOneWidget);
      expect(find.text('Reanudar cuota'), findsNothing);
      expect(
        find.text('Iniciar prueba (1 día)'),
        findsNothing,
        reason: 'Ya tiene cuota: no tiene sentido ofrecerle una prueba.',
      );
    },
  );

  testWidgets(
    'con la cuota pausada, el menú ofrece reanudarla; no pausarla otra vez',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      await tester.pumpWidget(
        _app(
          miembros: [_perfil(id: 'a1', rol: 'alumno', nombre: 'Ana')],
          cuotas: const {
            'a1': (
              id: 's1',
              tarifa: 'Mensual',
              efectivo: true,
              estado: 'pausada',
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
      await tester.pumpAndSettle();

      expect(find.text('Reanudar cuota'), findsOneWidget);
      expect(find.text('Pausar cuota'), findsNothing);
    },
  );

  testWidgets('una cuota de Stripe no se puede pausar ni reanudar desde aquí', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        miembros: [_perfil(id: 'a1', rol: 'alumno', nombre: 'Ana')],
        cuotas: const {
          'a1': (
            id: 's1',
            tarifa: 'Mensual',
            efectivo: false,
            estado: 'activa',
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
    await tester.pumpAndSettle();

    expect(find.text('Pausar cuota'), findsNothing);
    expect(find.text('Reanudar cuota'), findsNothing);
  });
}
