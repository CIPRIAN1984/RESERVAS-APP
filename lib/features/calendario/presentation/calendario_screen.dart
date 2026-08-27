import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_mode.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../../shared/widgets/pantalla.dart';
import '../application/clases_providers.dart';
import '../data/clase_resumen.dart';
import 'clase_card.dart';
import 'clase_detalle_screen.dart';
import 'crear_clase_screen.dart';

class CalendarioScreen extends ConsumerStatefulWidget {
  const CalendarioScreen({super.key});

  @override
  ConsumerState<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends ConsumerState<CalendarioScreen> {
  String? _accionEnCursoClaseId;

  Future<void> _unirse(ClaseResumen clase) async {
    setState(() => _accionEnCursoClaseId = clase.id);
    try {
      final estado = await ref
          .read(clasesRepositoryProvider)
          .unirse(claseId: clase.id);
      ref.invalidate(clasesSemanaProvider);
      if (mounted && estado == 'espera') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clase completa: estás en la lista de espera.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_mensajeError(e))));
      }
    } finally {
      if (mounted) setState(() => _accionEnCursoClaseId = null);
    }
  }

  Future<void> _borrarse(ClaseResumen clase) async {
    setState(() => _accionEnCursoClaseId = clase.id);
    try {
      final tardia = await ref
          .read(clasesRepositoryProvider)
          .borrarse(claseId: clase.id);
      ref.invalidate(clasesSemanaProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tardia
                  ? 'Reserva cancelada. La cancelación queda registrada como tardía.'
                  : 'Reserva cancelada correctamente.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido completar la acción.')),
        );
      }
    } finally {
      if (mounted) setState(() => _accionEnCursoClaseId = null);
    }
  }

  /// Confirmar todos desde la propia tarjeta del día, sin entrar en el
  /// detalle de la clase (el mismo botón ya existía dentro de
  /// `ClaseDetalleScreen`; esto lo trae también a la vista de día).
  Future<void> _confirmarTodos(ClaseResumen clase) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar la clase entera'),
        content: Text(
          clase.pendientesConfirmar == 1
              ? 'Se confirma la asistencia de 1 alumno.'
              : 'Se confirma la asistencia de ${clase.pendientesConfirmar} alumnos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar todos'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _accionEnCursoClaseId = clase.id);
    try {
      final repo = ref.read(clasesRepositoryProvider);
      // Se manda a todos los inscritos, no solo a los pendientes: al
      // subir de golpe (upsert con ignoreDuplicates), a quien ya estaba
      // validado no le pasa nada.
      final alumnoIds = await repo.listarAlumnosInscritos(clase.id);
      await repo.marcarAsistenciaEnBloque(
        claseId: clase.id,
        alumnoIds: alumnoIds,
        validadoPor: userId,
      );
      ref.invalidate(clasesSemanaProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido confirmar la clase.')),
        );
      }
    } finally {
      if (mounted) setState(() => _accionEnCursoClaseId = null);
    }
  }

  String _mensajeError(Object e) {
    final texto = e.toString();
    if (texto.contains('Aforo completo')) {
      return 'Aforo completo para esta clase.';
    }
    if (texto.contains('cuota activa')) {
      return 'Necesitas una cuota activa para reservar.';
    }
    if (texto.contains('No te quedan clases')) {
      return 'No te quedan clases en tu tarifa este mes. Renueva o compra una clase suelta.';
    }
    if (texto.contains('Ya estás inscrito') ||
        texto.contains('Ya tienes una reserva')) {
      return 'Ya tienes una reserva o plaza de espera para esta clase.';
    }
    if (texto.contains('clases futuras')) {
      return 'Esta clase ya ha comenzado.';
    }
    if (texto.contains('no admite nuevas reservas')) {
      return 'Esta clase está cerrada y no admite nuevas reservas.';
    }
    return 'No se ha podido completar la acción.';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final userId = ref.watch(currentUserIdProvider);
    final academiaId = profile?.academiaId;
    // Por MODO, no por rol: un dueño en modo Entrenamiento viene a apuntarse
    // a clase, no a gestionarlas.
    final gestionando = ref.watch(enModoGestionProvider);

    final selectedDay = ref.watch(selectedDayProvider);
    final visibleWeek = ref.watch(visibleWeekProvider);
    final clasesAsync = ref.watch(clasesSemanaProvider);

    return Scaffold(
      floatingActionButton: (gestionando && academiaId != null)
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CrearClaseScreen(
                      academiaId: academiaId,
                      profesorId: userId!,
                    ),
                  ),
                );
                ref.invalidate(clasesSemanaProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Crear clase'),
            )
          : null,
      body: Column(
        children: [
          // En Entrenamiento manda el saludo; en Gestor, un título de
          // pantalla normal, porque «Hoy» es una herramienta de trabajo.
          if (gestionando)
            const TituloPantalla('Hoy')
          else
            const _CabeceraInicio(),
          _SemanaPildoras(
            semana: visibleWeek,
            selectedDay: selectedDay,
            onSemanaAnterior: () =>
                ref.read(visibleWeekProvider.notifier).state = visibleWeek
                    .subtract(const Duration(days: 7)),
            onSemanaSiguiente: () =>
                ref.read(visibleWeekProvider.notifier).state = nextMonday(
                  visibleWeek,
                ),
            onDiaSeleccionado: (dia) =>
                ref.read(selectedDayProvider.notifier).state = dia,
          ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: clasesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Text(
                  'No se han podido cargar las clases.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              data: (clases) {
                final delDia = clases
                    .where(
                      (c) =>
                          _mismoDia(c.fechaHoraInicio.toLocal(), selectedDay),
                    )
                    .toList();
                if (delDia.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay clases este día.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                    ),
                  );
                }
                return ListView.separated(
                  // En Gestor flota «Crear clase» sobre la lista: hay que
                  // dejarle sitio o tapa la última clase del día.
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    gestionando ? espacioBotonesFlotantes : 16,
                  ),
                  itemCount: delDia.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final clase = delDia[index];
                    final cargando = _accionEnCursoClaseId == clase.id;
                    if (gestionando) {
                      return ClaseCard(
                        clase: clase,
                        confirmandoTodos: cargando,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ClaseDetalleScreen(clase: clase),
                          ),
                        ),
                        onConfirmarTodos: clase.cancelada
                            ? null
                            : () => _confirmarTodos(clase),
                      );
                    }
                    return ClaseCard(
                      clase: clase,
                      loadingAccion: cargando,
                      onUnirse: userId == null ? null : () => _unirse(clase),
                      onBorrarse: userId == null
                          ? null
                          : () => _borrarse(clase),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// El calendario semanal del sistema I+: siete pastillas, lunes a domingo.
/// El día seleccionado va en amarillo eléctrico — es el único sitio, junto a
/// los avisos críticos, donde aparece ese color. Sin puntos de aviso bajo los
/// días: con clases casi todos los días, los puntos no distinguían nada y
/// solo ensuciaban la vista.
class _SemanaPildoras extends StatelessWidget {
  const _SemanaPildoras({
    required this.semana,
    required this.selectedDay,
    required this.onSemanaAnterior,
    required this.onSemanaSiguiente,
    required this.onDiaSeleccionado,
  });

  /// El lunes de la semana visible.
  final DateTime semana;
  final DateTime selectedDay;
  final VoidCallback onSemanaAnterior;
  final VoidCallback onSemanaSiguiente;
  final ValueChanged<DateTime> onDiaSeleccionado;

  static const _diasCorta = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

  @override
  Widget build(BuildContext context) {
    final domingo = semana.add(const Duration(days: 6));
    final hoy = DateTime.now();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: onSemanaAnterior,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Semana anterior',
              ),
              Expanded(
                child: Text(
                  _tituloSemana(semana, domingo),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: onSemanaSiguiente,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Semana siguiente',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _PildoraDia(
                    etiqueta: _diasCorta[i],
                    dia: semana.add(Duration(days: i)),
                    seleccionado: _mismoDia(
                      semana.add(Duration(days: i)),
                      selectedDay,
                    ),
                    hoy: _mismoDia(semana.add(Duration(days: i)), hoy),
                    onTap: () =>
                        onDiaSeleccionado(semana.add(Duration(days: i))),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// «agosto de 2026», o «jul-ago 2026» cuando la semana cruza de mes.
  String _tituloSemana(DateTime lunes, DateTime domingo) {
    if (lunes.month == domingo.month) {
      return DateFormat("MMMM 'de' y", 'es_ES').format(lunes);
    }
    final mesInicio = DateFormat('MMM', 'es_ES').format(lunes);
    final mesFin = DateFormat("MMM 'de' y", 'es_ES').format(domingo);
    return '$mesInicio-$mesFin';
  }
}

class _PildoraDia extends StatelessWidget {
  const _PildoraDia({
    required this.etiqueta,
    required this.dia,
    required this.seleccionado,
    required this.hoy,
    required this.onTap,
  });

  final String etiqueta;
  final DateTime dia;
  final bool seleccionado;
  final bool hoy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: seleccionado,
      label: DateFormat("EEEE d 'de' MMMM", 'es_ES').format(dia),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: seleccionado ? AppColors.acid : Colors.transparent,
            shape: BoxShape.circle,
            border: !seleccionado && hoy
                ? Border.all(color: AppColors.ink, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                etiqueta,
                style: TextStyle(
                  fontFamily: AppTheme.fontMono,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  // El gris subtle sobre el amarillo de acento casi no se
                  // leía: en el día seleccionado la etiqueta pasa a tinta,
                  // igual que el número.
                  color: seleccionado ? AppColors.ink : AppColors.subtle,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${dia.day}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Encabezado del modo Entrenamiento: marca, saludo y check-in rápido.
class _CabeceraInicio extends ConsumerWidget {
  const _CabeceraInicio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre = ref.watch(currentProfileProvider).value?.nombre;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'I+',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nombre == null ? '¡Hola!' : '¡Hola, $nombre!',
              style: Theme.of(context).textTheme.headlineMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => _mostrarQr(context),
            icon: const Icon(Icons.qr_code_2, size: 26),
            tooltip: 'Mostrar mi código de check-in',
            style: IconButton.styleFrom(
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size(48, 48),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarQr(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Check-in rápido',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'Enseña este código en recepción para registrar tu asistencia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subtle),
            ),
            SizedBox(height: 24),
            Icon(Icons.qr_code_2, size: 180),
            SizedBox(height: 12),
            Text(
              'Pendiente de conectar con el lector de recepción',
              style: TextStyle(fontSize: 12, color: AppColors.subtle),
            ),
          ],
        ),
      ),
    );
  }
}
