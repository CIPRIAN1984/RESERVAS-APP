import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/app/theme/color_tokens.dart';

void main() {
  group('Tema I+', () {
    testWidgets('es claro y se pinta sobre fondo blanco', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Center(child: Text('I+'))),
        ),
      );

      final theme = Theme.of(tester.element(find.text('I+')));
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppColors.ground);
      expect(theme.colorScheme.primary, AppColors.ink);
    });

    testWidgets('usa las tipografías incrustadas, no la del sistema', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Center(child: Text('I+'))),
        ),
      );

      // Se comprueba sobre el texto realmente pintado, no sobre la
      // configuración: es lo que ve el usuario.
      final parrafo = tester.renderObject<RenderParagraph>(find.text('I+'));
      expect(parrafo.text.style?.fontFamily, AppTheme.fontSans);

      // Las etiquetas pequeñas van en monoespaciada.
      final theme = Theme.of(tester.element(find.text('I+')));
      expect(theme.textTheme.labelSmall?.fontFamily, AppTheme.fontMono);
    });

    test('el amarillo eléctrico es el único acento de marca', () {
      expect(AppTheme.light.colorScheme.secondary, AppColors.acid);
    });
  });

  group('Cinturones', () {
    test('los cinco de adultos conservan su color', () {
      expect(AppColors.belt('azul'), const Color(0xFF1D8FEF));
      expect(AppColors.belt('morado'), const Color(0xFF8B2FE0));
      expect(AppColors.belt('marron'), const Color(0xFF8A4B22));
      expect(AppColors.belt('negro'), const Color(0xFF111111));
    });

    test('un cinturón desconocido cae en blanco en vez de romper', () {
      expect(AppColors.belt('inventado'), AppColors.beltColors['blanco']);
      expect(AppColors.belt(null), AppColors.beltColors['blanco']);
    });

    test('solo el blanco necesita borde para verse sobre fondo claro', () {
      expect(AppColors.beltNeedsBorder('blanco'), isTrue);
      expect(AppColors.beltNeedsBorder('negro'), isFalse);
    });

    test('los cuatro colores base de niño tienen su propio tono', () {
      expect(AppColors.belt('gris'), const Color(0xFF9CA3AF));
      expect(AppColors.belt('amarillo'), const Color(0xFFF5C518));
      expect(AppColors.belt('naranja'), const Color(0xFFF97316));
      expect(AppColors.belt('verde'), const Color(0xFF16A34A));
    });

    test('un cinturón mixto de niño resuelve el color base y la franja', () {
      expect(AppColors.esCinturonMixto('amarillo_negro'), isTrue);
      expect(AppColors.belt('amarillo_negro'), AppColors.belt('amarillo'));
      expect(
        AppColors.franjaCinturon('amarillo_negro'),
        AppColors.belt('negro'),
      );

      expect(AppColors.esCinturonMixto('gris_blanco'), isTrue);
      expect(AppColors.belt('gris_blanco'), AppColors.belt('gris'));
      expect(AppColors.franjaCinturon('gris_blanco'), AppColors.belt('blanco'));
    });

    test('un cinturón sólido no se confunde con uno mixto', () {
      expect(AppColors.esCinturonMixto('azul'), isFalse);
      expect(AppColors.esCinturonMixto('verde'), isFalse);
    });
  });
}
