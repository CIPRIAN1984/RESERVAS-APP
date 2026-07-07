import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';

void main() {
  testWidgets('Dark theme renders without throwing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: Center(child: Text('ITACA'))),
      ),
    );

    expect(find.text('ITACA'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('ITACA'))).brightness,
      Brightness.dark,
    );
  });
}
