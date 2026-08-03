import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/academia.dart';
import 'package:itaca/features/academia/presentation/invitar_screen.dart';
import 'package:itaca/shared/widgets/pantalla.dart';

import 'ayuda_golden.dart';

@Tags(['golden'])
void main() {
  setUpAll(cargarTipografias);

  testWidgets('Invitar — QR y enlace de la academia', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 800));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAcademiaProvider.overrideWith(
            (ref) async => const Academia(
              id: 'a1',
              nombre: 'ITACA JIU JITSU',
              estado: 'approved',
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const Scaffold(
            body: SafeArea(
              child: PantallaConTitulo(
                titulo: 'Invitar',
                child: InvitarScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(enlaceInvitacion('a1')), findsOneWidget);
    expect(find.text('Copiar enlace'), findsOneWidget);

    await comparaCon(find.byType(MaterialApp), 'goldens/invitar_academia.png');
  });
}
