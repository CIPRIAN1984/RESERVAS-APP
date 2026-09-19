import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/features/documentos/application/documentos_providers.dart';
import 'package:itaca/features/documentos/data/documento_alumno.dart';
import 'package:itaca/features/documentos/presentation/documentos_seccion.dart';

/// Certificado médico y descargo de responsabilidad: qué ve un alumno/tutor
/// (solo puede subir) frente a lo que ve el staff (puede subir y quitar), y
/// qué se enseña cuando falta uno de los dos documentos.

DocumentoAlumno _documento(String tipo) => DocumentoAlumno(
  id: 'd1',
  academiaId: 'a1',
  alumnoId: 'alu1',
  tipo: tipo,
  storagePath: 'alu1/$tipo.jpg',
  subidoPor: 'alu1',
  createdAt: DateTime(2026, 9, 1),
);

Widget _app({
  required List<DocumentoAlumno> documentos,
  required bool puedeSubir,
  required bool puedeBorrar,
}) => ProviderScope(
  overrides: [
    documentosDeProvider('alu1').overrideWith((ref) async => documentos),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: SingleChildScrollView(
        child: SeccionDocumentos(
          alumnoId: 'alu1',
          subidoPorId: 'staff1',
          puedeSubir: puedeSubir,
          puedeBorrar: puedeBorrar,
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  testWidgets('sin ningún documento subido, los dos salen como pendientes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(documentos: const [], puedeSubir: true, puedeBorrar: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Certificado médico'), findsOneWidget);
    expect(find.text('Descargo de responsabilidad'), findsOneWidget);
    expect(find.text('Todavía no se ha subido.'), findsNWidgets(2));
    expect(find.text('Subido el 1 sept 2026'), findsNothing);
  });

  testWidgets('con uno de los dos subido, solo ese enseña la fecha', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        documentos: [_documento('certificado_medico')],
        puedeSubir: true,
        puedeBorrar: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Subido el 1 sept 2026'), findsOneWidget);
    expect(find.text('Todavía no se ha subido.'), findsOneWidget);
  });

  testWidgets('un alumno/tutor puede subir pero no puede quitar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        documentos: [_documento('certificado_medico')],
        puedeSubir: true,
        puedeBorrar: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ver'), findsOneWidget);
    expect(find.text('Sustituir'), findsOneWidget);
    expect(find.text('Subir'), findsOneWidget); // el descargo, aún pendiente
    expect(find.text('Quitar'), findsNothing);
  });

  testWidgets('el staff puede subir y también quitar un documento ya subido', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        documentos: [_documento('certificado_medico')],
        puedeSubir: true,
        puedeBorrar: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quitar'), findsOneWidget);
  });

  testWidgets(
    'sin permiso para subir ni para quitar, solo se puede ver lo ya subido',
    (tester) async {
      await tester.pumpWidget(
        _app(
          documentos: [_documento('certificado_medico')],
          puedeSubir: false,
          puedeBorrar: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ver'), findsOneWidget);
      expect(find.text('Subir'), findsNothing);
      expect(find.text('Sustituir'), findsNothing);
      expect(find.text('Quitar'), findsNothing);
    },
  );
}
