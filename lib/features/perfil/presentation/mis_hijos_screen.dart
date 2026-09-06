import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../core/models/cinturones.dart';
import '../../../core/models/profile.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/pantalla.dart';
import '../application/profile_providers.dart';
import 'agregar_hijo_sheet.dart';

/// Mi familia: los hijos que un padre o tutor tiene dados de alta.
///
/// Los menores no tienen cuenta propia — no pueden iniciar sesión nunca —
/// pero por dentro son alumnos normales: se les cobra la cuota, se les pasa
/// lista, salen en el ranking y se les gradúa como a cualquiera.
class MisHijosScreen extends ConsumerStatefulWidget {
  const MisHijosScreen({super.key});

  @override
  ConsumerState<MisHijosScreen> createState() => _MisHijosScreenState();
}

class _MisHijosScreenState extends ConsumerState<MisHijosScreen> {
  Future<void> _agregar() async {
    final nombre = await mostrarAgregarHijoSheet(context);
    if (nombre == null || !mounted) return;
    ref.invalidate(hijosProvider);
    ref.invalidate(hijosBorrablesProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$nombre ya está dado de alta en la academia.')),
    );
  }

  /// Deshacer un alta recién hecha.
  ///
  /// No es «dar de baja»: el botón solo aparece mientras el niño no tenga
  /// nada (ni una clase, ni una asistencia, ni una cuota). En cuanto empieza,
  /// la baja pasa a ser cosa de la academia — decisión de Cipri del
  /// 06/09/2026, porque un alumno que se da de baja solo es justo el
  /// descontrol que quiere evitar.
  Future<void> _borrar(Profile hijo) async {
    final nombre = [hijo.nombre, hijo.apellidos].whereType<String>().join(' ');

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar el alta'),
        content: Text(
          'Se borra a $nombre de la academia. Todavía no ha empezado, así '
          'que no se pierde nada: ni clases, ni asistencias, ni cuotas.',
        ),
        // Los dos a ancho completo, uno debajo del otro. Con las acciones
        // sueltas de un diálogo normal, el tema (que hace los botones de
        // ancho completo) dejaba «Borrar» rojo y enorme y «Cancelar» como un
        // enlace pequeñito encima: la opción peligrosa acababa siendo la
        // más fácil de pulsar sin querer.
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.destructive,
                ),
                child: const Text('Borrar'),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      await ref.read(familiaRepositoryProvider).borrarHijo(hijo.id);
      if (!mounted) return;
      ref.invalidate(hijosProvider);
      ref.invalidate(hijosBorrablesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$nombre ya no está dado de alta.')),
      );
    } catch (e) {
      if (!mounted) return;
      // Se recarga igualmente: si el servidor lo ha rechazado es porque el
      // niño ya ha empezado, y entonces el botón sobra de la pantalla.
      ref.invalidate(hijosBorrablesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensajeErrorAmigable(
              e,
              generico: _motivo(e) ?? 'No se ha podido borrar el alta.',
            ),
          ),
        ),
      );
    }
  }

  /// Los mensajes que manda el servidor ya están escritos para el padre
  /// («Nico ya ha empezado en la academia…»), así que se aprovechan en vez
  /// de taparlos con un genérico.
  String? _motivo(Object e) {
    final texto = e.toString();
    for (final trozo in const [
      'ya ha empezado en la academia',
      'tiene una cuota registrada',
      'su propia cuenta',
      'tus propios hijos',
    ]) {
      final i = texto.indexOf(trozo);
      if (i == -1) continue;
      // El texto viene envuelto en el error de Postgres; se recorta la frase.
      final desde = texto.lastIndexOf(RegExp(r'[:>]\s'), i);
      final hasta = texto.indexOf('.', i);
      if (hasta == -1) continue;
      return texto.substring(desde == -1 ? 0 : desde + 2, hasta + 1).trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hijosAsync = ref.watch(hijosProvider);
    // Mientras no se sepa, no se enseña ningún botón de borrar: mejor que no
    // esté a que aparezca y desaparezca al terminar de cargar.
    final borrables =
        ref.watch(hijosBorrablesProvider).value ?? const <String>{};

    return Scaffold(
      backgroundColor: AppColors.ground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.add),
        label: const Text('Añadir hijo'),
      ),
      body: hijosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const EmptyState(
          icon: Icons.family_restroom_outlined,
          message: 'No se ha podido cargar tu familia.',
        ),
        data: (hijos) {
          if (hijos.isEmpty) {
            return const EmptyState(
              icon: Icons.family_restroom_outlined,
              message:
                  'Todavía no has dado de alta a ningún hijo.\n'
                  'Añádelos y podrás gestionarlos desde aquí.',
            );
          }

          return ListView.separated(
            // Hueco al final porque esta pantalla sí tiene botón flotante:
            // sin él, el último hijo queda debajo y no se puede pulsar
            // ninguno de los dos.
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              espacioBotonesFlotantes,
            ),
            itemCount: hijos.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == hijos.length) return const _NotaSinCuenta();
              final hijo = hijos[index];
              return _FilaHijo(
                hijo: hijo,
                onBorrar: borrables.contains(hijo.id)
                    ? () => _borrar(hijo)
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

/// Lo que un padre pregunta siempre: «¿y mi hijo entra con qué usuario?».
/// Mejor contestarlo en la propia pantalla que por WhatsApp.
class _NotaSinCuenta extends StatelessWidget {
  const _NotaSinCuenta();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        'Tus hijos no tienen cuenta propia ni pueden entrar en la app: los '
        'gestionas tú desde aquí. Su cinturón lo pone la academia.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
      ),
    );
  }
}

class _FilaHijo extends StatelessWidget {
  const _FilaHijo({required this.hijo, this.onBorrar});

  final Profile hijo;

  /// Solo se pasa mientras el alta se pueda deshacer. Cuando el niño ya ha
  /// empezado llega `null` y el botón no existe: enseñar uno que va a fallar
  /// es peor que no enseñarlo.
  final VoidCallback? onBorrar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cinturon = hijo.cinturon ?? 'blanco';
    final nombre = [hijo.nombre, hijo.apellidos].whereType<String>().join(' ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _AvatarHijo(hijo: hijo),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: t.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cinturón ${etiquetaCinturon(cinturon)}'.toUpperCase(),
                    style: t.labelSmall,
                  ),
                ],
              ),
            ),
            if (onBorrar != null) ...[
              const SizedBox(width: 4),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  onPressed: onBorrar,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Borrar el alta de $nombre',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.ground,
                    foregroundColor: AppColors.destructive,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mismo avatar que en Miembros: iniciales y el punto del cinturón abajo a
/// la derecha, con anillo blanco para que se despegue de la tarjeta.
class _AvatarHijo extends StatelessWidget {
  const _AvatarHijo({required this.hijo});

  final Profile hijo;

  @override
  Widget build(BuildContext context) {
    final apellidos = hijo.apellidos ?? '';
    final iniciales = [
      if (hijo.nombre.isNotEmpty) hijo.nombre[0],
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
            backgroundImage: hijo.fotoUrl != null
                ? CachedNetworkImageProvider(hijo.fotoUrl!)
                : null,
            child: hijo.fotoUrl == null
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
              decoration: const BoxDecoration(
                color: AppColors.ground,
                shape: BoxShape.circle,
              ),
              child: PuntoCinturon(hijo.cinturon ?? 'blanco', tamano: 12),
            ),
          ),
        ],
      ),
    );
  }
}
