import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/auth/auth_state.dart';
import '../../../core/utils/error_messages.dart';

/// Registers a brand-new academia. It's created in `pending` state and the
/// Dueño's profile stays `pendiente_aprobacion` until the platform
/// Administrador approves it — the router redirects there automatically.
class RegistroAcademiaScreen extends ConsumerStatefulWidget {
  const RegistroAcademiaScreen({super.key});

  @override
  ConsumerState<RegistroAcademiaScreen> createState() =>
      _RegistroAcademiaScreenState();
}

class _RegistroAcademiaScreenState
    extends ConsumerState<RegistroAcademiaScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreAcademiaController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailContactoController = TextEditingController();

  final _nombreController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nombreAcademiaController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
    _emailContactoController.dispose();
    _nombreController.dispose();
    _apellidosController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.signUpDueno(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nombreAcademia: _nombreAcademiaController.text.trim(),
        direccion: _direccionController.text.trim(),
        telefono: _telefonoController.text.trim(),
        emailContacto: _emailContactoController.text.trim(),
        nombre: _nombreController.text.trim(),
        apellidos: _apellidosController.text.trim(),
      );
    } on sb.AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(
        () => _error = mensajeErrorAmigable(
          e,
          generico:
              'No se ha podido registrar la academia. Inténtalo de nuevo.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar mi academia')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Datos de la academia',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nombreAcademiaController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la academia',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _direccionController,
                      decoration: const InputDecoration(labelText: 'Dirección'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _telefonoController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailContactoController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email de contacto',
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Tus datos (Dueño)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _apellidosController,
                      decoration: const InputDecoration(labelText: 'Apellidos'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Introduce un email válido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Registrar academia'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
