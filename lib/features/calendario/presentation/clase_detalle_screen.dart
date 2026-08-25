import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/models/profile.dart';
import '../../../shared/widgets/pantalla.dart';
import '../../equipo/presentation/dar_cuota_sheet.dart';
import '../application/clases_providers.dart';
import '../data/clase_resumen.dart';
import '../data/clases_repository.dart';
import '../data/inscrito_alumno.dart';
import 'crear_clase_screen.dart';

/// Profesor/Dueño/Administrador view of a class: confirmed roster, attendance
/// and the FIFO waitlist that the backend promotes automatically.
class ClaseDetalleScreen extends ConsumerStatefulWidget {
  const ClaseDetalleScreen({required this.clase, super.key});

  final ClaseResumen clase;

  @override
  ConsumerState<ClaseDetalleScreen> createState() => _ClaseDetalleScreenState();
}

class _ClaseDetalleScreenState extends ConsumerState<ClaseDetalleScreen> {
  late Future<ParticipantesClase> _future;
  final Set<String> _marcando = {};
  bool _confirmandoTodos = false;
  bool _gestionando = false;
  late ClaseResumen _clase;

  @override
  void initState() {
    super.initState();
    _clase = widget.clase;
    _future = ref
        .read(clasesRepositoryProvider)
        .listarParticipantes(widget.clase.id);
  }

  /// Tras editar/cerrar/reabrir, vuelve a pedir los datos propios de la
  /// clase para no dejar el título, el horario o el estado obsoletos en
  /// esta pantalla mientras el dueño sigue gestionando asistencia.
  Future<void> _recargarClase() async {
    final datos = await ref
        .read(clasesRepositoryProvider)
        .obtenerClase(widget.clase.id);
    if (!mounted) return;
    setState(() {
      _clase = _clase.copyWith(
        titulo: datos['titulo'] as String,
        descripcion: datos['descripcion'] as String?,
        fechaHoraInicio: DateTime.parse(datos['fecha_hora_inicio'] as String),
        fechaHoraFin: DateTime.parse(datos['fecha_hora_fin'] as String),
        aforoMaximo: datos['aforo_maximo'] as int,
        estado: datos['estado'] as String,
      );
    });
    ref.invalidate(clasesSemanaProvider);
  }

  Future<void> _editar() async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CrearClaseScreen.editar(claseExistente: _clase),
      ),
    );
    if (guardado == true) await _recargarClase();
  }

  Future<void> _cambiarEstado({required bool cerrar}) async {
    setState(() => _gestionando = true);
    try {
      await ref
          .read(clasesRepositoryProvider)
          .cambiarEstadoClase(claseId: widget.clase.id, cerrar: cerrar);
      await _recargarClase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cerrar
                  ? 'Clase cerrada: ya no admite reservas nuevas.'
                  : 'Clase reabierta.',
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
      if (mounted) setState(() => _gestionando = false);
    }
  }

  Future<void> _cancelar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar esta clase?'),
        content: const Text(
          'Se avisará a todos los apuntados y quedarán liberados de su '
          'plaza. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar la clase'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _gestionando = true);
    try {
      final notificados = await ref
          .read(clasesRepositoryProvider)
          .cancelarClase(widget.clase.id);
      ref.invalidate(clasesSemanaProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              notificados == 0
                  ? 'Clase cancelada.'
                  : notificados == 1
                  ? 'Clase cancelada. Se ha avisado a 1 alumno.'
                  : 'Clase cancelada. Se ha avisado a $notificados alumnos.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido cancelar la clase.')),
        );
      }
    } finally {
      if (mounted) setState(() => _gestionando = false);
    }
  }

  void _recargar() {
    setState(() {
      _future = ref
          .read(clasesRepositoryProvider)
          .listarParticipantes(widget.clase.id);
    });
  }

  Future<void> _marcarAsistencia(
    InscritoAlumno alumno,
    String validadoPor,
  ) async {
    setState(() => _marcando.add(alumno.alumnoId));
    try {
      await ref
          .read(clasesRepositoryProvider)
          .marcarAsistencia(
            claseId: widget.clase.id,
            alumnoId: alumno.alumnoId,
            validadoPor: validadoPor,
          );
      _recargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se ha podido validar la asistencia.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _marcando.remove(alumno.alumnoId));
    }
  }

  /// Pasar lista de golpe: confirma a todos los inscritos que aún no tienen
  /// la asistencia validada. Marca a todo el mundo presente — quien reserva
  /// y no viene pierde la clase igual (regla ya en DECISIONS.md), así que no
  /// hay «ausentes» que marcar aparte.
  Future<void> _confirmarTodos(List<InscritoAlumno> pendientes) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || pendientes.isEmpty) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar la clase entera'),
        content: Text(
          pendientes.length == 1
              ? 'Se confirma la asistencia de 1 alumno.'
              : 'Se confirma la asistencia de ${pendientes.length} alumnos.',
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

    setState(() => _confirmandoTodos = true);
    try {
      await ref
          .read(clasesRepositoryProvider)
          .marcarAsistenciaEnBloque(
            claseId: widget.clase.id,
            alumnoIds: pendientes.map((a) => a.alumnoId).toList(),
            validadoPor: userId,
          );
      _recargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido confirmar la clase.')),
        );
      }
    } finally {
      if (mounted) setState(() => _confirmandoTodos = false);
    }
  }

  /// Cobrar en mano sin salir de la lista de la clase: es el recorrido que
  /// pidió Cipri —ve quién no ha pagado y le cobra ahí mismo—, en vez de
  /// tener que memorizar el nombre e ir a buscarlo a Equipo.
  Future<void> _cobrarEnMano(InscritoAlumno alumno) async {
    // Con `.value` esto se quedaba en null cuando el perfil aún no estaba
    // resuelto y el cobro no llegaba a abrirse: hay que esperarlo. La
    // academia la vuelve a comprobar el servidor de todos modos.
    final academiaId = (await ref.read(
      currentProfileProvider.future,
    ))?.academiaId;
    if (!mounted) return;

    final cobrado = await mostrarDarCuota(
      context,
      Profile(
        id: alumno.alumnoId,
        academiaId: academiaId,
        rol: 'alumno',
        nombre: alumno.nombre,
        apellidos: alumno.apellidos,
        estado: 'activo',
      ),
    );
    if (cobrado) _recargar();
  }

  Widget _buildInscrito(
    BuildContext context,
    InscritoAlumno alumno,
    String? userId,
  ) {
    final marcando = _marcando.contains(alumno.alumnoId);

    // Fila a mano en vez de ListTile: el hueco lateral del ListTile no admite
    // más que texto corto —con la pastilla de impago dentro ni siquiera
    // llegaba a medirse— y el botón «Validar» le comía el ancho al nombre.
    final fila = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.surface,
            backgroundImage: alumno.fotoUrl != null
                ? CachedNetworkImageProvider(alumno.fotoUrl!)
                : null,
            child: alumno.fotoUrl == null
                ? const Icon(Icons.person, color: AppColors.subtle)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alumno.nombreCompleto,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                // La marca de impago manda sobre el cinturón: es lo que hay
                // que hacer algo al respecto.
                if (alumno.sinCuota)
                  const PastillaEstado.error('Sin cuota')
                else if (alumno.cinturon != null)
                  Text(
                    'Cinturón ${alumno.cinturon}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (alumno.asistenciaValidada)
            const Icon(Icons.check_circle, color: AppColors.successFg)
          else if (marcando)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            // Acotado a propósito: por tema, los botones de la app son de
            // ancho completo (`minimumSize: Size.fromHeight`, y eso deja el
            // ancho en infinito). Suelto dentro de una fila, se lo queda
            // todo y deja el nombre en una columna de una letra.
            SizedBox(
              width: 110,
              child: OutlinedButton(
                onPressed: userId == null
                    ? null
                    : () => _marcarAsistencia(alumno, userId),
                child: const Text('Validar'),
              ),
            ),
        ],
      ),
    );

    // Tocar a quien no ha pagado abre el cobro en efectivo.
    if (!alumno.sinCuota) return fila;
    return InkWell(onTap: () => _cobrarEnMano(alumno), child: fila);
  }

  Widget _buildEspera(InscritoAlumno alumno, int posicion) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.surface,
        child: Text('$posicion'),
      ),
      title: Text(alumno.nombreCompleto),
      subtitle: Text(
        alumno.cinturon == null
            ? 'Lista de espera'
            : 'Lista de espera · Cinturón ${alumno.cinturon}',
      ),
      trailing: const Icon(Icons.schedule, color: AppColors.warningFg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final horario =
        '${DateFormat.Hm().format(_clase.fechaHoraInicio.toLocal())} - ${DateFormat.Hm().format(_clase.fechaHoraFin.toLocal())}';

    return Scaffold(
      appBar: AppBar(
        title: Text(_clase.titulo),
        actions: [
          if (_gestionando)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (!_clase.cancelada)
            PopupMenuButton<_AccionClase>(
              icon: const Icon(Icons.more_vert),
              onSelected: (accion) {
                switch (accion) {
                  case _AccionClase.editar:
                    _editar();
                  case _AccionClase.cerrar:
                    _cambiarEstado(cerrar: true);
                  case _AccionClase.reabrir:
                    _cambiarEstado(cerrar: false);
                  case _AccionClase.cancelar:
                    _cancelar();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _AccionClase.editar,
                  child: Text('Editar clase'),
                ),
                PopupMenuItem(
                  value: _clase.cerrada
                      ? _AccionClase.reabrir
                      : _AccionClase.cerrar,
                  child: Text(
                    _clase.cerrada
                        ? 'Reabrir a nuevas reservas'
                        : 'Cerrar a nuevas reservas',
                  ),
                ),
                const PopupMenuItem(
                  value: _AccionClase.cancelar,
                  child: Text('Cancelar la clase'),
                ),
              ],
            ),
        ],
      ),
      body: FutureBuilder<ParticipantesClase>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'No se han podido cargar los participantes.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          final participantes =
              snapshot.data ??
              const ParticipantesClase(inscritos: [], listaEspera: []);
          final inscritos = participantes.inscritos;
          final listaEspera = participantes.listaEspera;
          final sinCuota = inscritos.where((a) => a.sinCuota).length;
          final pendientes = inscritos
              .where((a) => !a.asistenciaValidada)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      horario,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${inscritos.length}/${_clase.aforoMaximo} confirmados · ${listaEspera.length} en espera',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                    ),
                    if (_clase.cerrada) ...[
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: PastillaEstado.aviso(
                          'Cerrada a nuevas reservas',
                          icono: Icons.lock_outline,
                        ),
                      ),
                    ],
                    // Cuántos hay que cobrar, sin tener que repasar la lista.
                    if (sinCuota > 0) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PastillaEstado.error(
                          sinCuota == 1 ? '1 sin cuota' : '$sinCuota sin cuota',
                        ),
                      ),
                    ],
                    if (pendientes.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: _confirmandoTodos
                            ? null
                            : () => _confirmarTodos(pendientes),
                        child: _confirmandoTodos
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                pendientes.length == inscritos.length
                                    ? 'Confirmar todos'
                                    : 'Confirmar los ${pendientes.length} que faltan',
                              ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.line),
              Expanded(
                child: inscritos.isEmpty && listaEspera.isEmpty
                    ? Center(
                        child: Text(
                          'Todavía no hay participantes.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.subtle),
                        ),
                      )
                    : ListView(
                        children: [
                          const _SectionTitle(title: 'Confirmados'),
                          if (inscritos.isEmpty)
                            const ListTile(
                              title: Text('No hay plazas confirmadas.'),
                            )
                          else
                            for (final alumno in inscritos)
                              _buildInscrito(context, alumno, userId),
                          if (listaEspera.isNotEmpty) ...[
                            const Divider(height: 24, color: AppColors.line),
                            const _SectionTitle(title: 'Lista de espera'),
                            for (var i = 0; i < listaEspera.length; i++)
                              _buildEspera(listaEspera[i], i + 1),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _AccionClase { editar, cerrar, reabrir, cancelar }

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.subtle,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
