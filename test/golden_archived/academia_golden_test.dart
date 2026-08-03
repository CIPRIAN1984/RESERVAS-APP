import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:itaca/app/routes.dart';
import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/academia.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/academia/presentation/academia_screen.dart';
import 'package:itaca/shared/widgets/pantalla.dart';

import 'ayuda_golden.dart';

/// En el navegador de un portátil la pantalla se estiraba de lado a lado: las
/// tarjetas de Equipo y Cobros ocupaban toda la anchura y los galones de las
/// filas quedaban descolgados a un palmo del texto. Aquí se dibuja al ancho
/// real de un móvil, que es como se usa.

Widget _app({required String rol}) {
  final router = GoRouter(
    initialLocation: Routes.academia,
    routes: [
      GoRoute(
        path: Routes.academia,
        builder: (_, _) => const Scaffold(
          body: SafeArea(
            child: PantallaConTitulo(
              titulo: 'Academia',
              child: AcademiaScreen(),
            ),
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      currentProfileProvider.overrideWith(
        (ref) async => Profile(
          id: 'u1',
          academiaId: 'a1',
          rol: rol,
          nombre: 'Riojano',
          apellidos: 'Dumitru',
          estado: 'activo',
        ),
      ),
      currentAcademiaProvider.overrideWith(
        (ref) async => const Academia(
          id: 'a1',
          nombre: 'ITACA JIU JITSU',
          direccion: 'Logroño',
          estado: 'approved',
        ),
      ),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
}

@Tags(['golden'])
void main() {
  setUpAll(cargarTipografias);

  testWidgets('Academia — vista del dueño', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 760));
    await tester.pumpWidget(_app(rol: 'dueño'));
    await tester.pumpAndSettle();

    expect(find.text('ITACA JIU JITSU'), findsOneWidget);
    expect(find.text('Equipo'), findsOneWidget);
    expect(find.text('Cobros'), findsOneWidget);
    expect(find.text('Ajustes de reservas'), findsOneWidget);
    // Cerrar sesión vive en Perfil, que lo tienen todos los roles.
    expect(find.text('Cerrar sesión'), findsNothing);

    await comparaCon(find.byType(MaterialApp), 'goldens/academia_dueno.png');
  });

  testWidgets('Un profesor no ve los ajustes que solo toca el dueño', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 760));
    await tester.pumpWidget(_app(rol: 'profesor'));
    await tester.pumpAndSettle();

    expect(find.text('ITACA JIU JITSU'), findsOneWidget);
    expect(find.text('Ajustes de reservas'), findsNothing);
    expect(find.text('Cobros'), findsNothing);
    // Privacidad sí, que es de cualquiera.
    expect(find.text('Privacidad y protección de datos'), findsOneWidget);
  });
}
