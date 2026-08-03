import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/app/theme/color_tokens.dart';
import 'package:itaca/features/calendario/data/clase_resumen.dart';
import 'package:itaca/features/calendario/presentation/clase_card.dart';
import 'package:itaca/shared/widgets/empty_state.dart';
import 'package:itaca/shared/widgets/pantalla.dart';

import 'ayuda_golden.dart';

/// Muestrario visual de los componentes que se repiten por toda la app.
/// Sirve para revisar el diseño de un vistazo y para detectar si un cambio
/// futuro rompe alguno sin querer.
///
/// Regenerar: `flutter test --update-goldens test/golden`.
ClaseResumen _clase({
  String titulo = 'BJJ/Gi FUNDAMENTOS',
  int inscritos = 12,
  int aforo = 30,
  String? miEstado,
}) => ClaseResumen(
  id: 'c1',
  titulo: titulo,
  fechaHoraInicio: DateTime(2026, 7, 29, 19),
  fechaHoraFin: DateTime(2026, 7, 29, 20),
  aforoMaximo: aforo,
  profesorId: 'p1',
  profesorNombre: 'Instructor A',
  inscritosCount: inscritos,
  miEstado: miEstado,
);

Widget _lienzo(List<Widget> hijos) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final h in hijos) ...[h, const SizedBox(height: 14)],
        ],
      ),
    ),
  ),
);

@Tags(['golden'])
void main() {
  setUpAll(cargarTipografias);

  testWidgets('Tarjeta de clase en sus cuatro estados', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1180));
    await tester.pumpWidget(
      _lienzo([
        ClaseCard(clase: _clase(), onUnirse: () {}),
        ClaseCard(
          clase: _clase(miEstado: 'inscrito'),
          onBorrarse: () {},
        ),
        ClaseCard(
          clase: _clase(inscritos: 30, titulo: 'NOGI FUNDAMENTOS'),
          onUnirse: () {},
        ),
        ClaseCard(
          clase: _clase(miEstado: 'espera'),
          onBorrarse: () {},
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await comparaCon(find.byType(MaterialApp), 'goldens/componentes_clase.png');
  });

  testWidgets('Pastillas, pestañas, cinturones y estado vacío', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 700));
    await tester.pumpWidget(
      _lienzo([
        const PestanasPildora(
          valor: 0,
          etiquetas: ['Horario', 'Productos'],
          onCambio: _nada,
        ),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PastillaEstado.exito('Pagando', icono: Icons.check),
            PastillaEstado.error('Impagado'),
            PastillaEstado.info('Prueba'),
            PastillaEstado('Sin membresía'),
            PastillaEstado.aviso('Pausada'),
          ],
        ),
        const Row(
          children: [
            PuntoCinturon('blanco', tamano: 26),
            SizedBox(width: 10),
            PuntoCinturon('azul', tamano: 26),
            SizedBox(width: 10),
            PuntoCinturon('morado', tamano: 26),
            SizedBox(width: 10),
            PuntoCinturon('marron', tamano: 26),
            SizedBox(width: 10),
            PuntoCinturon('negro', tamano: 26),
          ],
        ),
        ElevatedButton(onPressed: _nada2, child: const Text('Reservar plaza')),
        OutlinedButton(
          onPressed: _nada2,
          child: const Text('Cancelar reserva'),
        ),
        const SizedBox(
          height: 200,
          child: EmptyState(
            icon: Icons.event_busy_outlined,
            message: 'No hay clases este día.',
          ),
        ),
        Container(height: 1, color: AppColors.line),
      ]),
    );
    await tester.pumpAndSettle();

    await comparaCon(
      find.byType(MaterialApp),
      'goldens/componentes_sistema.png',
    );
  });
}

void _nada(int _) {}
void _nada2() {}
