import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/models/profile.dart';
import '../../../core/utils/error_messages.dart';
import '../../miembros/application/miembros_providers.dart';
import '../application/clases_providers.dart';

/// Apuntar a quien ha llegado a clase sin reserva (decisión de Cipri,
/// 09/10/2026). El servidor (`apuntar_en_clase`) respeta el aforo, la cuota
/// si la academia la exige y las clases de su tarifa, y deja la asistencia
/// confirmada.
///
/// Devuelve el nombre de quien se ha apuntado, o `null` si no se ha hecho.
Future<String?> mostrarApuntarSinReserva(
  BuildContext context, {
  required String claseId,
  required Set<String> yaEnClase,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useRootNavigator: true,
  builder: (_) => _ApuntarSheet(claseId: claseId, yaEnClase: yaEnClase),
);

/// Lo que dice el servidor al rechazarlo, en palabras de quien da la clase.
/// Los textos de `apuntar_en_clase` ya están escritos para el usuario.
String mensajeApuntar(Object error) {
  final texto = error.toString();
  for (final conocido in const [
    'Aforo completo para esta clase.',
    'No le quedan clases en su tarifa. Cóbrale una clase extra antes de apuntarlo.',
    'No tiene cuota para esta clase. Cóbrasela antes de apuntarlo.',
    'Ya tiene la asistencia confirmada en esta clase.',
    'Ya estaba apuntado: confírmale la asistencia en la lista.',
    'Tiene marcado que no entrena.',
    'Se puede apuntar a quien ha venido desde media hora antes de la clase.',
    'Esta clase está cancelada.',
  ]) {
    if (texto.contains(conocido)) return conocido;
  }
  return mensajeErrorAmigable(error, generico: 'No se ha podido apuntar.');
}

/// Quién se puede elegir: activo, que entrena, que no está ya en la clase
/// y cuyo nombre contiene lo buscado (sin distinguir mayúsculas).
List<Profile> candidatosSinReserva(
  List<Profile> alumnos, {
  required Set<String> yaEnClase,
  required String busqueda,
}) {
  final b = busqueda.trim().toLowerCase();
  return [
    for (final a in alumnos)
      if (!a.deBaja &&
          a.estado == 'activo' &&
          a.entrena &&
          !yaEnClase.contains(a.id) &&
          (b.isEmpty ||
              [
                a.nombre,
                a.apellidos,
              ].whereType<String>().join(' ').toLowerCase().contains(b)))
        a,
  ];
}

class _ApuntarSheet extends ConsumerStatefulWidget {
  const _ApuntarSheet({required this.claseId, required this.yaEnClase});

  final String claseId;
  final Set<String> yaEnClase;

  @override
  ConsumerState<_ApuntarSheet> createState() => _ApuntarSheetState();
}

class _ApuntarSheetState extends ConsumerState<_ApuntarSheet> {
  final _busqueda = TextEditingController();
  String? _apuntando;
  String? _error;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _apuntar(Profile alumno) async {
    setState(() {
      _apuntando = alumno.id;
      _error = null;
    });
    try {
      await ref
          .read(clasesRepositoryProvider)
          .apuntarEnClase(claseId: widget.claseId, alumnoId: alumno.id);
      if (mounted) {
        Navigator.of(
          context,
        ).pop([alumno.nombre, alumno.apellidos].whereType<String>().join(' '));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apuntando = null;
          _error = mensajeApuntar(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final alumnosAsync = ref.watch(alumnosMiembrosProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Apuntar a quien ha venido', style: t.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Queda apuntado y con la asistencia confirmada. Se respetan '
                'el aforo y las clases de su tarifa.',
                style: t.bodyMedium?.copyWith(color: AppColors.subtle),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _busqueda,
                decoration: const InputDecoration(
                  labelText: 'Buscar por nombre',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: t.bodyMedium?.copyWith(color: AppColors.destructive),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: alumnosAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(
                    child: Text(
                      'No se ha podido cargar la lista de alumnos.',
                      style: t.bodyMedium?.copyWith(
                        color: AppColors.destructive,
                      ),
                    ),
                  ),
                  data: (alumnos) {
                    final candidatos = candidatosSinReserva(
                      alumnos,
                      yaEnClase: widget.yaEnClase,
                      busqueda: _busqueda.text,
                    );
                    if (candidatos.isEmpty) {
                      return Center(
                        child: Text(
                          'No hay nadie más a quien apuntar.',
                          style: t.bodyMedium?.copyWith(
                            color: AppColors.subtle,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: candidatos.length,
                      itemBuilder: (context, i) {
                        final alumno = candidatos[i];
                        final nombre = [
                          alumno.nombre,
                          alumno.apellidos,
                        ].whereType<String>().join(' ');
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(nombre),
                          trailing: _apuntando == alumno.id
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1_outlined),
                          onTap: _apuntando == null
                              ? () => _apuntar(alumno)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
