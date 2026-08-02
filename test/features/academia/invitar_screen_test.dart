import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/academia.dart';
import 'package:itaca/features/academia/presentation/invitar_screen.dart';

const _academia = Academia(
  id: 'a1',
  nombre: 'Itaca Jiu Jitsu',
  estado: 'approved',
);

void main() {
  testWidgets('enseña el enlace de invitación y lo copia al portapapeles', (
    tester,
  ) async {
    final copiado = <ClipboardData>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiado.add(ClipboardData(text: call.arguments['text'] as String));
        }
        return null;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAcademiaProvider.overrideWith((ref) async => _academia),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: InvitarScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final enlace = enlaceInvitacion('a1');
    expect(find.text(enlace), findsOneWidget);

    await tester.tap(find.text('Copiar enlace'));
    await tester.pumpAndSettle();

    expect(copiado.single.text, enlace);
  });
}
