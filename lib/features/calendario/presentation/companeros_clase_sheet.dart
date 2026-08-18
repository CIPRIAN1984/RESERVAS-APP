import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../shared/widgets/pantalla.dart';
import '../data/clases_repository.dart';
import '../data/inscrito_alumno.dart';

/// Quién más está apuntado a esta clase, para que los alumnos se vean entre
/// ellos —lo que pedían por MAAT—. Solo nombre, foto y cinturón: nada de
/// datos de pago, que ahí no pintan nada.
void mostrarCompanerosClase(
  BuildContext context, {
  required ClasesRepository repositorio,
  required String claseId,
  required String tituloClase,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (_) => _CompanerosClaseSheet(
      repositorio: repositorio,
      claseId: claseId,
      tituloClase: tituloClase,
    ),
  );
}

class _CompanerosClaseSheet extends StatefulWidget {
  const _CompanerosClaseSheet({
    required this.repositorio,
    required this.claseId,
    required this.tituloClase,
  });

  final ClasesRepository repositorio;
  final String claseId;
  final String tituloClase;

  @override
  State<_CompanerosClaseSheet> createState() => _CompanerosClaseSheetState();
}

class _CompanerosClaseSheetState extends State<_CompanerosClaseSheet> {
  late final Future<List<InscritoAlumno>> _future = widget.repositorio
      .listarCompaneros(widget.claseId);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.tituloClase,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(
              'Apuntados a esta clase',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: FutureBuilder<List<InscritoAlumno>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No se ha podido cargar quién está apuntado.',
                        style: TextStyle(color: AppColors.subtle),
                      ),
                    );
                  }
                  final companeros = snapshot.data ?? const [];
                  if (companeros.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Todavía no se ha apuntado nadie.',
                        style: TextStyle(color: AppColors.subtle),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: companeros.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) =>
                        _FilaCompanero(alumno: companeros[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaCompanero extends StatelessWidget {
  const _FilaCompanero({required this.alumno});

  final InscritoAlumno alumno;

  @override
  Widget build(BuildContext context) {
    final iniciales = alumno.nombre.isNotEmpty
        ? alumno.nombre[0].toUpperCase()
        : '?';

    return Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.surfaceStrong,
                backgroundImage: alumno.fotoUrl != null
                    ? CachedNetworkImageProvider(alumno.fotoUrl!)
                    : null,
                child: alumno.fotoUrl == null
                    ? Text(
                        iniciales,
                        style: const TextStyle(
                          fontSize: 16,
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
                  child: PuntoCinturon(alumno.cinturon, tamano: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            alumno.nombreCompleto,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
