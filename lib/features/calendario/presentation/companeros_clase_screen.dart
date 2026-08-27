import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/pantalla.dart';
import '../data/clase_resumen.dart';
import '../data/clases_repository.dart';
import '../data/inscrito_alumno.dart';

/// Quién más está apuntado a esta clase, para que los alumnos se vean entre
/// ellos —lo que pedían por MAAT—. Solo nombre, foto y cinturón: nada de
/// datos de pago, que ahí no pintan nada.
///
/// Pantalla completa al entrar en la clase, no una hoja emergente: en MAAT
/// los apuntados se ven al abrir la clase, no desde la vista del día — así
/// lo pidió Cipri después de ver la primera versión con una hoja inferior.
class CompanerosClaseScreen extends StatefulWidget {
  const CompanerosClaseScreen({
    required this.clase,
    required this.repositorio,
    super.key,
  });

  final ClaseResumen clase;
  final ClasesRepository repositorio;

  @override
  State<CompanerosClaseScreen> createState() => _CompanerosClaseScreenState();
}

class _CompanerosClaseScreenState extends State<CompanerosClaseScreen> {
  late final Future<List<InscritoAlumno>> _future = widget.repositorio
      .listarCompaneros(widget.clase.id);

  @override
  Widget build(BuildContext context) {
    final horario =
        '${DateFormat.Hm().format(widget.clase.fechaHoraInicio.toLocal())} - ${DateFormat.Hm().format(widget.clase.fechaHoraFin.toLocal())}';

    return Scaffold(
      appBar: AppBar(title: Text(widget.clase.titulo)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '$horario · ${widget.clase.profesorNombre}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: FutureBuilder<List<InscritoAlumno>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.groups_outlined,
                    message: 'No se ha podido cargar quién está apuntado.',
                  );
                }
                final companeros = snapshot.data ?? const [];
                if (companeros.isEmpty) {
                  return const EmptyState(
                    icon: Icons.groups_outlined,
                    message: 'Todavía no se ha apuntado nadie.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
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
