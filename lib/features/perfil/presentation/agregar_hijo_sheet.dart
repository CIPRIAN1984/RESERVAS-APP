import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/utils/error_messages.dart';
import '../application/profile_providers.dart';

/// Alta de un hijo. Devuelve su nombre si se ha creado, o `null` si el
/// padre cierra la hoja sin guardar.
Future<String?> mostrarAgregarHijoSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (_) => const _AgregarHijoSheet(),
  );
}

class _AgregarHijoSheet extends ConsumerStatefulWidget {
  const _AgregarHijoSheet();

  @override
  ConsumerState<_AgregarHijoSheet> createState() => _AgregarHijoSheetState();
}

class _AgregarHijoSheetState extends ConsumerState<_AgregarHijoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _apellidos.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final nombre = _nombre.text.trim();
    final apellidos = _apellidos.text.trim();

    setState(() => _guardando = true);
    try {
      await ref
          .read(familiaRepositoryProvider)
          .crearHijo(
            nombre: nombre,
            apellidos: apellidos.isEmpty ? null : apellidos,
          );
      if (!mounted) return;
      // OJO con el contexto: la hoja se monta en el navegador raíz y esta
      // pantalla cuelga del anidado del armazón. Usar el de la pantalla
      // cerraría lo que no es y dejaría la hoja pegada — es el fallo que
      // cazó Cipri en Miembros el 02/09/2026.
      Navigator.of(context).pop(nombre);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensajeErrorAmigable(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Añadir hijo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Entrará como alumno de la academia. No tendrá cuenta ni '
                'contraseña: lo gestionas tú.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombre,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El nombre es obligatorio'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apellidos,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Apellidos (opcional)',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Dar de alta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
