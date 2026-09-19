import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/academia.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/academia/presentation/academia_screen.dart';

/// Cambios de escuela sigue congelado para v1 (ver FREEZE.md): no aplica
/// con una sola academia. Antes de aquel cierre, un Dueño veía la fila en
/// Academia aunque llevara a una ruta (`Routes.solicitudesCambioEscuela`)
/// que el router ya no resuelve.
///
/// Cobros (Stripe) **se ha descongelado** (19/09/2026, a petición de
/// Cipri): preparar la conexión, sin activarla con dinero real todavía.
/// Ver `test/features/pagos/conectar_stripe_screen_test.dart` para la
/// pantalla en sí.

const _academia = Academia(
  id: 'a1',
  nombre: 'Itaca Jiu Jitsu',
  estado: 'approved',
);

Profile _dueno() => Profile(
  id: 'u1',
  academiaId: 'a1',
  rol: 'dueño',
  nombre: 'Riojano',
  apellidos: 'Ejemplo',
  estado: 'activo',
);

void main() {
  testWidgets('un dueño ve Cobros pero no Cambios de escuela en Academia', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1600));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAcademiaProvider.overrideWith((ref) async => _academia),
          currentProfileProvider.overrideWith((ref) async => _dueno()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: AcademiaScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cobros'), findsOneWidget);
    expect(find.text('Cambios de escuela'), findsNothing);
    // El resto de Academia sigue en pie.
    expect(find.text('Equipo'), findsOneWidget);
    expect(find.text('Invitar'), findsOneWidget);
  });
}
