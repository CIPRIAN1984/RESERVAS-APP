import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../app/routes.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/models/academia.dart';
import '../../../core/utils/error_messages.dart';

/// Self-registration for a student joining an academia that already exists
/// and is approved. Registering as Profesor is not self-service — a Dueño
/// promotes a member to Profesor later (out of scope for this phase).
final _academiasAprobadasProvider = FutureProvider.autoDispose<List<AcademiaOption>>((ref) {
  return ref.watch(authRepositoryProvider).listAcademiasAprobadas();
});

class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({super.key});

  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _academiaId;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_academiaId == null) {
      setState(() => _error = 'Selecciona tu academia.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.signUpAlumno(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        academiaId: _academiaId!,
        nombre: _nombreController.text.trim(),
        apellidos: _apellidosController.text.trim(),
      );
    } on sb.AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = mensajeErrorAmigable(
            e,
            generico: 'No se ha podido completar el registro. Inténtalo de nuevo.',
          ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final academiasAsync = ref.watch(_academiasAprobadasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
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
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Introduce un email válido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Contraseña'),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                    ),
                    const SizedBox(height: 16),
                    academiasAsync.when(
                      data: (academias) => DropdownButtonFormField<String>(
                        initialValue: _academiaId,
                        decoration: const InputDecoration(labelText: 'Tu academia'),
                        items: [
                          for (final a in academias)
                            DropdownMenuItem(value: a.id, child: Text(a.nombre)),
                        ],
                        onChanged: (v) => setState(() => _academiaId = v),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, st) => Text(
                        'No se pudieron cargar las academias.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                          : const Text('Crear cuenta'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _loading ? null : () => context.push(Routes.registroAcademia),
                      child: const Text('¿Eres dueño de un gimnasio? Registra tu academia'),
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
