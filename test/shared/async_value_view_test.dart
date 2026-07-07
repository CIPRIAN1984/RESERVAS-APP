import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itaca/shared/widgets/async_value_view.dart';

Widget _host(AsyncValue<List<String>> value) => MaterialApp(
  home: Scaffold(
    body: AsyncListView<String>(
      asyncValue: value,
      onRefresh: () async {},
      emptyMessage: 'Nada por aquí.',
      itemBuilder: (_, item) => Text(item),
    ),
  ),
);

void main() {
  testWidgets('muestra los elementos cuando hay datos', (tester) async {
    await tester.pumpWidget(_host(const AsyncData(['uno', 'dos'])));
    expect(find.text('uno'), findsOneWidget);
    expect(find.text('dos'), findsOneWidget);
  });

  testWidgets('muestra el estado vacío cuando la lista está vacía', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AsyncData<List<String>>([])));
    expect(find.text('Nada por aquí.'), findsOneWidget);
  });

  testWidgets('muestra el error con reintento cuando no hay datos previos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(AsyncError(Exception('boom'), StackTrace.empty)),
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
