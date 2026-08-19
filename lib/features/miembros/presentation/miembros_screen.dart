import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/profile.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/pantalla.dart';
import '../../equipo/presentation/dar_cuota_sheet.dart';
import '../application/miembros_providers.dart';

/// Alumnos de la academia, buscables y filtrables por cinturón — lo que
/// pidió Cipri mirando MAAT. Primera versión: nombre, cinturón y si la
/// cuota está al día. Lo que exige datos que la base de datos todavía no
/// tiene (cinturones de niños, prueba/pausada, listo para graduarse,
/// inactividad) queda para una tanda futura, decisión de Cipri.
const _cinturones = ['Todos', 'Blanco', 'Azul', 'Morado', 'Marrón', 'Negro'];
const _valoresCinturon = [null, 'blanco', 'azul', 'morado', 'marron', 'negro'];

class MiembrosScreen extends ConsumerStatefulWidget {
  const MiembrosScreen({super.key});

  @override
  ConsumerState<MiembrosScreen> createState() => _MiembrosScreenState();
}

class _MiembrosScreenState extends ConsumerState<MiembrosScreen> {
  String _busqueda = '';
  int _filtroCinturon = 0;

  Future<void> _darCuota(Profile alumno) async {
    final hecho = await mostrarDarCuota(context, alumno);
    if (hecho && mounted) {
      ref.invalidate(cuotaAlDiaMiembrosProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cuota registrada para ${alumno.nombre}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alumnosAsync = ref.watch(alumnosMiembrosProvider);
    final cuotaAlDia = ref.watch(cuotaAlDiaMiembrosProvider).value ?? const {};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar por nombre',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    setState(() => _busqueda = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),
              PestanasPildora(
                valor: _filtroCinturon,
                etiquetas: _cinturones,
                onCambio: (i) => setState(() => _filtroCinturon = i),
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
              final cinturonElegido = _valoresCinturon[_filtroCinturon];
              final visibles = alumnos.where((a) {
                if (cinturonElegido != null && a.cinturon != cinturonElegido) {
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TarjetaResumen(
                            numero: alDia,
                            pastilla: const PastillaEstado.exito('Al día'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TarjetaResumen(
                            numero: alumnos.length - alDia,
                            pastilla: const PastillaEstado.error('Sin cuota'),
                          ),
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
                          return TarjetaFila(
                            titulo: alumno.nombreCompleto,
                            detalle: alumno.cinturon == null
                                ? null
                                : 'Cinturón ${alumno.cinturon}',
                            estado: tieneCuota
                                ? const PastillaEstado.exito('Al día')
                                : const PastillaEstado.error('Sin cuota'),
                            onTap: tieneCuota ? null : () => _darCuota(alumno),
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

class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({required this.numero, required this.pastilla});

  final int numero;
  final PastillaEstado pastilla;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text('$numero', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            pastilla,
          ],
        ),
      ),
    );
  }
}
