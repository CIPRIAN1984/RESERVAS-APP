import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/features/miembros/domain/progreso_cinturon.dart';

void main() {
  group('secuencia de cinturones', () {
    test('un adulto sigue blanco→azul→morado→marrón→negro', () {
      expect(proximoCinturon('blanco', false), 'azul');
      expect(proximoCinturon('azul', false), 'morado');
      expect(proximoCinturon('morado', false), 'marron');
      expect(proximoCinturon('marron', false), 'negro');
      expect(proximoCinturon('negro', false), isNull);
    });

    test('un niño sigue la escala IBJJF de trece pasos', () {
      expect(proximoCinturon('blanco', true), 'gris_blanco');
      expect(proximoCinturon('gris_blanco', true), 'gris');
      expect(proximoCinturon('verde', true), 'verde_negro');
      expect(
        proximoCinturon('verde_negro', true),
        isNull,
        reason: 'Es el tope de la escala IBJJF que gestiona la app.',
      );
    });

    test('un cinturón sin dato se trata como blanco', () {
      expect(proximoCinturon(null, false), 'azul');
      expect(proximoCinturon(null, true), 'gris_blanco');
    });
  });

  group('ritmo exigido', () {
    test('niños: 6 meses (26 semanas) por cinturón, a 3 entrenos/semana', () {
      expect(semanasRequeridas(true), 26);
      expect(asistenciasRequeridas(true), 78);
    });

    test('adultos: 2 años (104 semanas) por cinturón, a 3 entrenos/semana', () {
      expect(semanasRequeridas(false), 104);
      expect(asistenciasRequeridas(false), 312);
    });
  });

  group('ProgresoCinturon', () {
    test('la fracción se calcula sobre lo requerido', () {
      const progreso = ProgresoCinturon(
        asistencias: 39,
        requeridas: 78,
        proximoCinturon: 'gris',
      );
      expect(progreso.fraccion, 0.5);
    });

    test('la fracción no supera 1 aunque se pasen del mínimo', () {
      const progreso = ProgresoCinturon(
        asistencias: 400,
        requeridas: 312,
        proximoCinturon: 'azul',
      );
      expect(progreso.fraccion, 1.0);
    });

    test('sin próximo cinturón no hay fracción que mostrar', () {
      const progreso = ProgresoCinturon(
        asistencias: 500,
        requeridas: 312,
        proximoCinturon: null,
      );
      expect(progreso.fraccion, isNull);
    });
  });
}
