import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/models/profile.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/pantalla.dart';
import '../../equipo/presentation/dar_cuota_sheet.dart';
import '../application/miembros_providers.dart';
import 'ficha_miembro_screen.dart';

/// Alumnos de la academia, buscables y filtrables por cinturón — lo que
/// pidió Cipri mirando MAAT. La pastilla de cuota sigue siendo binaria
/// (al día/sin cuota) a propósito: quien está en prueba o pausada ya
/// cuenta bien en uno u otro lado (ver `alumnosConCuotaAlDia`), y el
/// detalle de los cuatro estados es cosa de gestionar, que vive en
/// Equipo. Con inactividad y listo para graduarse, ya está todo lo que
/// se pidió para esta pantalla.
const _etiquetasCinturon = {
  'blanco': 'Blanco',
  'azul': 'Azul',
  'morado': 'Morado',
  'marron': 'Marrón',
  'negro': 'Negro',
  'gris_blanco': 'Gris-Blanco',
  'gris': 'Gris',
  'gris_negro': 'Gris-Negro',
  'amarillo_blanco': 'Amarillo-Blanco',
  'amarillo': 'Amarillo',
  'amarillo_negro': 'Amarillo-Negro',
  'naranja_blanco': 'Naranja-Blanco',
  'naranja': 'Naranja',
  'naranja_negro': 'Naranja-Negro',
  'verde_blanco': 'Verde-Blanco',
  'verde': 'Verde',
  'verde_negro': 'Verde-Negro',
};

const _cinturonesAdultos = ['blanco', 'azul', 'morado', 'marron', 'negro'];

/// El blanco de niño es el mismo color que el de adulto (no hay entrada
/// separada: filtrar por "Blanco" ya trae a todos, niños incluidos).
const _cinturonesNinos = [
  'gris_blanco',
  'gris',
  'gris_negro',
  'amarillo_blanco',
  'amarillo',
  'amarillo_negro',
  'naranja_blanco',
  'naranja',
  'naranja_negro',
  'verde_blanco',
  'verde',
  'verde_negro',
];

String etiquetaCinturon(String cinturon) =>
    _etiquetasCinturon[cinturon] ?? cinturon;

/// A partir de cuántos días sin entrenar se marca a un alumno como
/// inactivo. Es un número de producto, no técnico — 14 días es un primer
/// valor razonable (una ausencia de dos semanas ya destaca en un deporte
/// que se entrena 2-3 veces por semana); si a Cipri no le encaja, es un
/// único número que cambiar aquí.
const diasInactividad = 14;

/// `null` en el mapa de última asistencia = nunca ha venido a clase, que
/// cuenta como inactivo igual que llevar muchos días sin aparecer.
bool esInactivo(DateTime? ultimaAsistencia) {
  if (ultimaAsistencia == null) return true;
  return DateTime.now().difference(ultimaAsistencia).inDays >= diasInactividad;
}

String etiquetaInactividad(DateTime? ultimaAsistencia) {
  if (ultimaAsistencia == null) return 'Nunca ha venido';
  final dias = DateTime.now().difference(ultimaAsistencia).inDays;
  return dias == 1 ? 'Hace 1 día' : 'Hace $dias días';
}

class MiembrosScreen extends ConsumerStatefulWidget {
  const MiembrosScreen({super.key});

  @override
  ConsumerState<MiembrosScreen> createState() => _MiembrosScreenState();
}

class _MiembrosScreenState extends ConsumerState<MiembrosScreen> {
  String _busqueda = '';
  String? _cinturonElegido;

  void _abrirFicha(Profile alumno) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FichaMiembroScreen(alumno: alumno)),
    );
  }

  Future<void> _darCuota(Profile alumno) async {
    final hecho = await mostrarDarCuota(context, alumno);
    if (hecho && mounted) {
      ref.invalidate(cuotaAlDiaMiembrosProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cuota registrada para ${alumno.nombre}.')),
      );
    }
  }

  Future<void> _elegirCinturon() async {
    final elegido = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (_) => _FiltroCinturonSheet(actual: _cinturonElegido),
    );
    // `elegido` distingue "canceló la hoja" (sin tocar nada, `context.mounted`
    // sigue vivo pero no hay valor) de "eligió Todos" (String? nulo explícito
    // devuelto a propósito) gracias a que el sheet siempre hace `pop` con un
    // valor: solo llega aquí `null` de verdad cuando se cierra deslizando.
    if (!mounted) return;
    setState(() => _cinturonElegido = elegido);
  }

  @override
  Widget build(BuildContext context) {
    final alumnosAsync = ref.watch(alumnosMiembrosProvider);
    final cuotaAlDia = ref.watch(cuotaAlDiaMiembrosProvider).value ?? const {};
    final ultimaAsistencia =
        ref.watch(ultimaAsistenciaMiembrosProvider).value ?? const {};
    final listosParaGraduarse =
        ref.watch(graduacionMiembrosProvider).value ?? const {};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nombre',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => _busqueda = value.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              _BotonCinturon(
                cinturon: _cinturonElegido,
                onTap: _elegirCinturon,
              ),
            ],
          ),
        ),
        Expanded(
          child: alumnosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => const EmptyState(
              icon: Icons.groups_outlined,
              message: 'No se han podido cargar los alumnos.',
            ),
            data: (alumnos) {
              final visibles = alumnos.where((a) {
                // Sin cinturón asignado cuenta como blanco (igual que en la
                // ficha y en el progreso hacia el siguiente): si no, nadie
                // sin dato se veía nunca al filtrar por "Blanco", ni
                // siquiera quienes sí lo son.
                if (_cinturonElegido != null &&
                    (a.cinturon ?? 'blanco') != _cinturonElegido) {
                  return false;
                }
                if (_busqueda.isEmpty) return true;
                return a.nombreCompleto.toLowerCase().contains(_busqueda);
              }).toList();

              if (alumnos.isEmpty) {
                return const EmptyState(
                  icon: Icons.groups_outlined,
                  message: 'Todavía no hay alumnos en la academia.',
                );
              }

              final alDia = alumnos
                  .where((a) => cuotaAlDia.contains(a.id))
                  .length;
              final inactivos = alumnos
                  .where((a) => esInactivo(ultimaAsistencia[a.id]))
                  .length;
              final listos = alumnos
                  .where((a) => listosParaGraduarse.contains(a.id))
                  .length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dos filas de dos: con cuatro tarjetas ya no caben a lo
                  // ancho en un móvil de 412 px sin encogerse demasiado.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _TarjetaResumen(
                                numero: alDia,
                                pastilla: const PastillaEstado.exito('Al día'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TarjetaResumen(
                                numero: alumnos.length - alDia,
                                pastilla: const PastillaEstado.error(
                                  'Sin cuota',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _TarjetaResumen(
                                numero: inactivos,
                                pastilla: const PastillaEstado.aviso(
                                  'Inactivos',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TarjetaResumen(
                                numero: listos,
                                pastilla: const PastillaEstado.exito('Listos'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (visibles.isEmpty)
                    const Expanded(
                      child: EmptyState(
                        icon: Icons.search_off,
                        message: 'Ningún alumno coincide con el filtro.',
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: visibles.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final alumno = visibles[index];
                          final tieneCuota = cuotaAlDia.contains(alumno.id);
                          final ultima = ultimaAsistencia[alumno.id];
                          final inactivo = esInactivo(ultima);
                          final listo = listosParaGraduarse.contains(alumno.id);
                          return TarjetaFila(
                            titulo: alumno.nombreCompleto,
                            detalle:
                                'Cinturón '
                                '${etiquetaCinturon(alumno.cinturon ?? 'blanco')}',
                            // Wrap y no Row: con nombres largos o pantallas
                            // estrechas, varias pastillas se salían por la
                            // derecha (mismo motivo que en Equipo).
                            estado: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                tieneCuota
                                    ? const PastillaEstado.exito('Al día')
                                    : const PastillaEstado.error('Sin cuota'),
                                if (inactivo)
                                  PastillaEstado.aviso(
                                    etiquetaInactividad(ultima),
                                  ),
                                if (listo)
                                  const PastillaEstado.exito(
                                    'Listo para graduarse',
                                  ),
                              ],
                            ),
                            onTap: tieneCuota
                                ? () => _abrirFicha(alumno)
                                : () => _darCuota(alumno),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

extension on Profile {
  String get nombreCompleto =>
      [nombre, apellidos].whereType<String>().join(' ');
}

class _BotonCinturon extends StatelessWidget {
  const _BotonCinturon({required this.cinturon, required this.onTap});

  final String? cinturon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: cinturon == null
          ? const Icon(Icons.filter_list, size: 18)
          : PuntoCinturon(cinturon, tamano: 14),
      label: Text(cinturon == null ? 'Cinturón' : etiquetaCinturon(cinturon!)),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
    );
  }
}

class _FiltroCinturonSheet extends StatelessWidget {
  const _FiltroCinturonSheet({required this.actual});

  final String? actual;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtrar por cinturón',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CinturonChip(
                  texto: 'Todos',
                  seleccionado: actual == null,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Adultos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cinturon in _cinturonesAdultos)
                  _CinturonChip(
                    texto: etiquetaCinturon(cinturon),
                    cinturon: cinturon,
                    seleccionado: actual == cinturon,
                    onTap: () => Navigator.of(context).pop(cinturon),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Niños', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cinturon in _cinturonesNinos)
                  _CinturonChip(
                    texto: etiquetaCinturon(cinturon),
                    cinturon: cinturon,
                    seleccionado: actual == cinturon,
                    onTap: () => Navigator.of(context).pop(cinturon),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CinturonChip extends StatelessWidget {
  const _CinturonChip({
    required this.texto,
    required this.seleccionado,
    required this.onTap,
    this.cinturon,
  });

  final String texto;
  final String? cinturon;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cinturon != null) ...[
              PuntoCinturon(cinturon, tamano: 14),
              const SizedBox(width: 8),
            ],
            Text(
              texto.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: seleccionado ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({required this.numero, required this.pastilla});

  final int numero;
  final PastillaEstado pastilla;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Column(
          children: [
            Text('$numero', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            // Con tres tarjetas por fila (antes eran dos) una pastilla larga
            // como «INACTIVOS» ya no cabe a su tamaño natural en un móvil
            // estrecho; se encoge en vez de desbordar.
            FittedBox(child: pastilla),
          ],
        ),
      ),
    );
  }
}
