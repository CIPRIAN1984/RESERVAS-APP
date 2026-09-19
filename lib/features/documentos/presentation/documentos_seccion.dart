import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/utils/error_messages.dart';
import '../application/documentos_providers.dart';
import '../data/documento_alumno.dart';

/// Certificado médico y descargo de responsabilidad de un alumno: quién lo
/// ha subido, cuándo, y verlo. Se usa tanto en la pantalla del propio
/// alumno/tutor como en la ficha que ve el staff — un único sitio para no
/// mantener dos veces la misma lógica de subida.
class SeccionDocumentos extends ConsumerWidget {
  const SeccionDocumentos({
    required this.alumnoId,
    required this.subidoPorId,
    required this.puedeSubir,
    required this.puedeBorrar,
    super.key,
  });

  final String alumnoId;

  /// Quién queda registrado como autor de la subida: el propio usuario que
  /// tiene la sesión abierta (él mismo, su tutor, o el staff).
  final String subidoPorId;
  final bool puedeSubir;
  final bool puedeBorrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentosAsync = ref.watch(documentosDeProvider(alumnoId));

    return documentosAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Text(
        'No se han podido cargar los documentos.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      data: (documentos) {
        final porTipo = {for (final d in documentos) d.tipo: d};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final tipo in tiposDocumentoAlumno) ...[
              _FilaDocumento(
                alumnoId: alumnoId,
                subidoPorId: subidoPorId,
                tipo: tipo,
                documento: porTipo[tipo],
                puedeSubir: puedeSubir,
                puedeBorrar: puedeBorrar,
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _FilaDocumento extends ConsumerStatefulWidget {
  const _FilaDocumento({
    required this.alumnoId,
    required this.subidoPorId,
    required this.tipo,
    required this.documento,
    required this.puedeSubir,
    required this.puedeBorrar,
  });

  final String alumnoId;
  final String subidoPorId;
  final String tipo;
  final DocumentoAlumno? documento;
  final bool puedeSubir;
  final bool puedeBorrar;

  @override
  ConsumerState<_FilaDocumento> createState() => _FilaDocumentoState();
}

class _FilaDocumentoState extends ConsumerState<_FilaDocumento> {
  bool _procesando = false;

  Future<void> _elegirYSubir() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (contextoHoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Hacer una foto'),
              onTap: () => Navigator.of(contextoHoja).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(contextoHoja).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null || !mounted) return;

    final foto = await ImagePicker().pickImage(
      source: origen,
      imageQuality: 85,
    );
    if (foto == null || !mounted) return;

    setState(() => _procesando = true);
    try {
      final bytes = await foto.readAsBytes();
      final extension = foto.name.contains('.')
          ? foto.name.split('.').last
          : 'jpg';
      await ref
          .read(documentosRepositoryProvider)
          .subir(
            alumnoId: widget.alumnoId,
            tipo: widget.tipo,
            subidoPor: widget.subidoPorId,
            bytes: bytes,
            fileExtension: extension,
          );
      ref.invalidate(documentosDeProvider(widget.alumnoId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${etiquetaTipoDocumento(widget.tipo)} subido correctamente.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorAmigable(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _ver() async {
    final documento = widget.documento;
    if (documento == null) return;
    try {
      final url = await ref
          .read(documentosRepositoryProvider)
          .urlFirmada(documento.storagePath);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorAmigable(e))),
        );
      }
    }
  }

  Future<void> _borrar() async {
    final documento = widget.documento;
    if (documento == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: const Text('Quitar el documento'),
        content: Text(
          'Se borra ${etiquetaTipoDocumento(widget.tipo)}. Quien lo subió '
          'tendrá que volver a hacerlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contextoDialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () => Navigator.of(contextoDialogo).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _procesando = true);
    try {
      await ref
          .read(documentosRepositoryProvider)
          .borrar(
            alumnoId: widget.alumnoId,
            tipo: widget.tipo,
            storagePath: documento.storagePath,
          );
      ref.invalidate(documentosDeProvider(widget.alumnoId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorAmigable(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documento = widget.documento;
    final subido = documento != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  subido
                      ? Icons.check_circle_outline
                      : Icons.error_outline_outlined,
                  size: 20,
                  color: subido ? AppColors.successFg : AppColors.subtle,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    etiquetaTipoDocumento(widget.tipo),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subido
                  ? 'Subido el ${DateFormat('d MMM yyyy', 'es_ES').format(documento.createdAt.toLocal())}'
                  : 'Todavía no se ha subido.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
            ),
            if (_procesando) ...[
              const SizedBox(height: 12),
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            ] else if (subido || widget.puedeSubir) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (subido)
                    OutlinedButton(onPressed: _ver, child: const Text('Ver')),
                  if (widget.puedeSubir)
                    OutlinedButton(
                      onPressed: _elegirYSubir,
                      child: Text(subido ? 'Sustituir' : 'Subir'),
                    ),
                  if (subido && widget.puedeBorrar)
                    OutlinedButton(
                      onPressed: _borrar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.destructive,
                      ),
                      child: const Text('Quitar'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
