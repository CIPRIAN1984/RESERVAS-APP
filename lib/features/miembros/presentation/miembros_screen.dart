import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../core/models/cinturones.dart';
import '../../../core/models/profile.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/pantalla.dart';
import '../../equipo/presentation/dar_cuota_sheet.dart';
import '../application/miembros_providers.dart';
import 'ficha_miembro_screen.dart';

export '../../../core/models/cinturones.dart' show etiquetaCinturon;

/// Alumnos de la academia: buscar, filtrar por cinturón y por estado, y
/// abrir la ficha de cualquiera.
///
/// La pastilla de cuota es binaria a propósito (al día / sin cuota): quien
/// está en prueba o pausada ya cuenta bien en uno u otro lado (ver
/// `alumnosConCuotaAlDia`), y el detalle de los cuatro estados es cosa de
/// gestionar, que vive en Equipo.
///
/// Los nombres de los cinturones se subieron a `core/models/cinturones.dart`
/// cuando la pantalla de familias los necesitó también: se siguen
/// reexportando desde aquí porque la ficha del alumno los importa de este
/// fichero.

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

/// Los cuatro montones en los que se reparte la academia. Son los mismos
/// que ya contaban las tarjetas del resumen: ahora, además, se puede tocar
/// una para quedarse solo con esa gente — que era lo que faltaba para que
/// el resumen sirviera de algo más que de adorno.
enum FiltroEstado {
  alDia('Al día'),
  sinCuota('Sin cuota'),
  inactivos('Inactivos'),
  listos('Listos');

  const FiltroEstado(this.etiqueta);

  final String etiqueta;
}

class MiembrosScreen extends ConsumerStatefulWidget {
  const MiembrosScreen({super.key});

  @override
  ConsumerState<MiembrosScreen> createState() => _MiembrosScreenState();
}

class _MiembrosScreenState extends ConsumerState<MiembrosScreen> {
  String _busqueda = '';
  String? _cinturonElegido;
  FiltroEstado? _estadoElegido;

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

  /// Tocar la tarjeta que ya está elegida la apaga: es el mismo gesto para
  /// poner y quitar el filtro, sin tener que buscar un botón aparte.
  void _alternarEstado(FiltroEstado estado) {
    setState(() => _estadoElegido = _estadoElegido == estado ? null : estado);
  }

  void _quitarFiltros() {
    setState(() {
      _cinturonElegido = null;
      _estadoElegido = null;
    });
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
              if (alumnos.isEmpty) {
                return const EmptyState(
                  icon: Icons.groups_outlined,
                  message: 'Todavía no hay alumnos en la academia.',
                );
              }

              bool enEstado(Profile a) => switch (_estadoElegido) {
                null => true,
                FiltroEstado.alDia => cuotaAlDia.contains(a.id),
                FiltroEstado.sinCuota => !cuotaAlDia.contains(a.id),
                FiltroEstado.inactivos => esInactivo(ultimaAsistencia[a.id]),
                FiltroEstado.listos => listosParaGraduarse.contains(a.id),
              };

              final visibles = alumnos.where((a) {
                // Sin cinturón asignado cuenta como blanco (igual que en la
                // ficha y en el progreso hacia el siguiente): si no, nadie
                // sin dato se veía nunca al filtrar por "Blanco", ni
                // siquiera quienes sí lo son.
                if (_cinturonElegido != null &&
                    (a.cinturon ?? 'blanco') != _cinturonElegido) {
                  return false;
                }
                if (!enEstado(a)) return false;
                if (_busqueda.isEmpty) return true;
                return a.nombreCompleto.toLowerCase().contains(_busqueda);
              }).toList();

              final alDia = alumnos
                  .where((a) => cuotaAlDia.contains(a.id))
                  .length;
              final inactivos = alumnos
                  .where((a) => esInactivo(ultimaAsistencia[a.id]))
                  .length;
              final listos = alumnos
                  .where((a) => listosParaGraduarse.contains(a.id))
                  .length;

              final hayFiltros =
                  _cinturonElegido != null ||
                  _estadoElegido != null ||
                  _busqueda.isNotEmpty;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dos filas de dos: con cuatro tarjetas ya no caben a lo
                  // ancho en un móvil de 412 px sin encogerse demasiado.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _TarjetaResumen(
                                numero: alDia,
                                estado: FiltroEstado.alDia,
                                pastilla: const PastillaEstado.exito('Al día'),
                                seleccionada:
                                    _estadoElegido == FiltroEstado.alDia,
                                onTap: () =>
                                    _alternarEstado(FiltroEstado.alDia),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TarjetaResumen(
                                numero: alumnos.length - alDia,
                                estado: FiltroEstado.sinCuota,
                                pastilla: const PastillaEstado.error(
                                  'Sin cuota',
                                ),
                                seleccionada:
                                    _estadoElegido == FiltroEstado.sinCuota,
                                onTap: () =>
                                    _alternarEstado(FiltroEstado.sinCuota),
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
                                estado: FiltroEstado.inactivos,
                                pastilla: const PastillaEstado.aviso(
                                  'Inactivos',
                                ),
                                seleccionada:
                                    _estadoElegido == FiltroEstado.inactivos,
                                onTap: () =>
                                    _alternarEstado(FiltroEstado.inactivos),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TarjetaResumen(
                                numero: listos,
                                estado: FiltroEstado.listos,
                                pastilla: const PastillaEstado.exito('Listos'),
                                seleccionada:
                                    _estadoElegido == FiltroEstado.listos,
                                onTap: () =>
                                    _alternarEstado(FiltroEstado.listos),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _BarraRecuento(
                    visibles: visibles.length,
                    total: alumnos.length,
                    hayFiltros: hayFiltros,
                    onQuitar: _quitarFiltros,
                  ),
                  if (visibles.isEmpty)
                    Expanded(
                      child: EmptyState(
                        icon: Icons.search_off,
                        message: _estadoElegido == null
                            ? 'Ningún alumno coincide con el filtro.'
                            : 'Ningún alumno en «${_estadoElegido!.etiqueta}» '
                                  'con el resto de filtros.',
                      ),
                    )
                  else
                    Expanded(
                      child: _ListaAlumnos(
                        alumnos: visibles,
                        cuotaAlDia: cuotaAlDia,
                        ultimaAsistencia: ultimaAsistencia,
                        listosParaGraduarse: listosParaGraduarse,
                        onAbrirFicha: _abrirFicha,
                        onCobrar: _darCuota,
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

/// Lista de alumnos agrupada por inicial, como la agenda del móvil y como
/// MAAT. Con 166 alumnos, una lista corrida obliga a leerlo todo para
/// encontrar a alguien; las cabeceras dan una referencia al desplazarse.
class _ListaAlumnos extends StatelessWidget {
  const _ListaAlumnos({
    required this.alumnos,
    required this.cuotaAlDia,
    required this.ultimaAsistencia,
    required this.listosParaGraduarse,
    required this.onAbrirFicha,
    required this.onCobrar,
  });

  final List<Profile> alumnos;
  final Set<String> cuotaAlDia;
  final Map<String, DateTime> ultimaAsistencia;
  final Set<String> listosParaGraduarse;
  final void Function(Profile) onAbrirFicha;
  final void Function(Profile) onCobrar;

  @override
  Widget build(BuildContext context) {
    // La consulta ya devuelve los alumnos ordenados por nombre, así que
    // basta con cortar cada vez que cambia la inicial.
    final elementos = <Object>[];
    String? letraAnterior;
    for (final alumno in alumnos) {
      final nombre = alumno.nombreCompleto;
      final letra = nombre.isEmpty ? '#' : nombre[0].toUpperCase();
      if (letra != letraAnterior) {
        elementos.add(letra);
        letraAnterior = letra;
      }
      elementos.add(alumno);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: elementos.length,
      itemBuilder: (context, index) {
        final elemento = elementos[index];
        if (elemento is String) {
          return _CabeceraLetra(letra: elemento, primera: index == 0);
        }
        final alumno = elemento as Profile;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _FilaAlumno(
            alumno: alumno,
            tieneCuota: cuotaAlDia.contains(alumno.id),
            ultima: ultimaAsistencia[alumno.id],
            listo: listosParaGraduarse.contains(alumno.id),
            onTap: () => onAbrirFicha(alumno),
            onCobrar: cuotaAlDia.contains(alumno.id)
                ? null
                : () => onCobrar(alumno),
          ),
        );
      },
    );
  }
}

class _CabeceraLetra extends StatelessWidget {
  const _CabeceraLetra({required this.letra, required this.primera});

  final String letra;
  final bool primera;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4, top: primera ? 4 : 16, bottom: 10),
      child: Row(
        children: [
          Text(
            letra,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

/// Fila de alumno: foto (o iniciales) con el punto de su cinturón, nombre,
/// una línea de datos en monoespaciada y las pastillas que hagan falta.
///
/// No usa `TarjetaFila` porque esta necesita avatar y un botón de cobro a
/// la derecha, que aquella no contempla.
class _FilaAlumno extends StatelessWidget {
  const _FilaAlumno({
    required this.alumno,
    required this.tieneCuota,
    required this.ultima,
    required this.listo,
    required this.onTap,
    this.onCobrar,
  });

  final Profile alumno;
  final bool tieneCuota;
  final DateTime? ultima;
  final bool listo;
  final VoidCallback onTap;
  final VoidCallback? onCobrar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final inactivo = esInactivo(ultima);
    final cinturon = alumno.cinturon ?? 'blanco';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarAlumno(alumno: alumno),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alumno.nombreCompleto,
                      style: t.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${etiquetaCinturon(cinturon)} · '
                              '${etiquetaInactividad(ultima)}'
                          .toUpperCase(),
                      style: t.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // Wrap y no Row: con nombres largos o pantallas
                    // estrechas, varias pastillas se salían por la derecha
                    // (mismo motivo que en Equipo).
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        tieneCuota
                            ? const PastillaEstado.exito('Al día')
                            : const PastillaEstado.error('Sin cuota'),
                        if (inactivo) const PastillaEstado.aviso('Inactivo'),
                        if (listo)
                          const PastillaEstado.exito('Listo para graduarse'),
                      ],
                    ),
                  ],
                ),
              ),
              if (onCobrar != null) ...[
                const SizedBox(width: 4),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    onPressed: onCobrar,
                    icon: const Icon(Icons.payments_outlined, size: 20),
                    tooltip: 'Registrar cobro en efectivo',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.ground,
                      foregroundColor: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar circular con la foto del alumno (o sus iniciales) y el punto de
/// su cinturón abajo a la derecha, como manda el sistema de diseño.
class _AvatarAlumno extends StatelessWidget {
  const _AvatarAlumno({required this.alumno});

  final Profile alumno;

  @override
  Widget build(BuildContext context) {
    final nombre = alumno.nombre;
    final apellidos = alumno.apellidos ?? '';
    final iniciales = [
      if (nombre.isNotEmpty) nombre[0],
      if (apellidos.isNotEmpty) apellidos[0],
    ].join().toUpperCase();

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: AppColors.surfaceStrong,
            backgroundImage: alumno.fotoUrl != null
                ? CachedNetworkImageProvider(alumno.fotoUrl!)
                : null,
            child: alumno.fotoUrl == null
                ? Text(
                    iniciales.isEmpty ? '?' : iniciales,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.subtle,
                    ),
                  )
                : null,
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              padding: const EdgeInsets.all(2),
              // Anillo blanco, no del color de la tarjeta: sobre el gris de
              // la tarjeta un anillo gris no separa nada y el punto del
              // cinturón se confunde con el avatar.
              decoration: const BoxDecoration(
                color: AppColors.ground,
                shape: BoxShape.circle,
              ),
              child: PuntoCinturon(alumno.cinturon ?? 'blanco', tamano: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuántos alumnos se están viendo de cuántos hay, y el atajo para volver a
/// verlos todos. Sin esto, con un filtro puesto la lista parece vacía sin
/// que nada explique por qué.
class _BarraRecuento extends StatelessWidget {
  const _BarraRecuento({
    required this.visibles,
    required this.total,
    required this.hayFiltros,
    required this.onQuitar,
  });

  final int visibles;
  final int total;
  final bool hayFiltros;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, hayFiltros ? 8 : 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hayFiltros
                  ? '$visibles de $total alumnos'.toUpperCase()
                  : '$total ${total == 1 ? 'alumno' : 'alumnos'}'.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          if (hayFiltros)
            TextButton(onPressed: onQuitar, child: const Text('Ver todos')),
        ],
      ),
    );
  }
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
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 56),
        // Con un cinturón elegido el botón se marca en negro, para que se
        // note de un vistazo que la lista está filtrada.
        side: BorderSide(
          color: cinturon == null ? const Color(0x400A0A0A) : AppColors.ink,
          width: cinturon == null ? 1 : 1.5,
        ),
      ),
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
                for (final cinturon in cinturonesAdultos)
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
                for (final cinturon in cinturonesNinos)
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

/// Tarjeta del resumen. Además de contar, **es el filtro**: tocarla deja en
/// la lista solo a esa gente, y volver a tocarla lo quita. La elegida se
/// marca con borde negro (el mismo recurso que usa MAAT).
class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({
    required this.numero,
    required this.estado,
    required this.pastilla,
    required this.seleccionada,
    required this.onTap,
  });

  final int numero;
  final FiltroEstado estado;
  final PastillaEstado pastilla;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: seleccionada,
      label: '$numero ${estado.etiqueta}',
      child: Card(
        key: ValueKey('resumen-${estado.name}'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: seleccionada
              ? const BorderSide(color: AppColors.ink, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            child: Column(
              children: [
                Text(
                  '$numero',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                // Con cuatro tarjetas, una pastilla larga como «INACTIVOS»
                // no cabe a su tamaño natural en un móvil estrecho; se
                // encoge en vez de desbordar.
                FittedBox(child: pastilla),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
