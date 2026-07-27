import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itaca/features/privacy/presentation/privacy_screen.dart';

void main() {
  testWidgets('muestra la información esencial de privacidad', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));

    expect(find.text('Privacidad y datos'), findsOneWidget);
    expect(find.text('Información de privacidad'), findsOneWidget);
    expect(find.text('Quién gestiona tus datos'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Tus derechos'),
      300,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Tus derechos'), findsOneWidget);
    expect(find.textContaining('Stripe'), findsWidgets);
  });
}
