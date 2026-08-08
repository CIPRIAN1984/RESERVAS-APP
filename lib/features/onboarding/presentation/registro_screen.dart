import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../app/routes.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/academia.dart';
import '../../../core/utils/error_messages.dart';
import '../../../l10n/app_localizations.dart';

/// Self-registration for a student joining an academia that already exists
/// and is approved. Registering as Profesor is not self-service — a Dueño
/// promotes a member to Profesor later (out of scope for this phase).
final academiasAprobadasProvider =
    FutureProvider.autoDispose<List<AcademiaOption>>((ref) {
      return ref.watch(authRepositoryProvider).listAcademiasAprobadas();
    });

class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({this.academiaId, super.key});

  /// Viene del enlace de invitación (`/registro?academia=<id>`) que un dueño
  /// comparte desde `InvitarScreen`. Con esto puesto, quien se registra no
  /// elige de la lista abierta de academias: ya trae la suya fijada.
  final String? academiaId;

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
  void initState() {
    super.initState();
    // Para v1 (academia única), siempre usa ITACA. El parámetro academiaId
    // se ignora (puede venir de un enlace antiguo de invitación multi-academia).
    _academiaId = AppConfig.itacaAcademiaId.isNotEmpty
        ? AppConfig.itacaAcademiaId
        : widget.academiaId;
  }

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
      setState(
        () => _error = AppLocalizations.of(context).registerSelectAcademy,
      );
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
      setState(
        () => _error = mensajeErrorAmigable(
          e,
          generico:
              'No se ha podido completar el registro. Inténtalo de nuevo.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final academiasAsync = ref.watch(academiasAprobadasProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.actionCreateAccount)),
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
                      decoration: InputDecoration(labelText: l10n.registerName),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l10n.commonRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _apellidosController,
                      decoration: InputDecoration(
                        labelText: l10n.registerLastName,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: l10n.authEmail),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? l10n.authEmailInvalid
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: l10n.authPassword),
                      validator: (v) => (v == null || v.length < 6)
                          ? l10n.authPasswordTooShort
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // Para v1 (academia única), muestra solo ITACA. El provider
                    // de academias se mantiene por compatibilidad futura con
                    // multi-academia.
                    academiasAsync.when(
                      data: (academias) {
                        final itaca = academias
                            .where((a) => a.id == AppConfig.itacaAcademiaId)
                            .firstOrNull;
                        // ITACA debería estar siempre en la lista de aprobadas.
                        if (itaca == null) {
                          return Text(
                            'Error de configuración: ITACA no está en la lista de academias aprobadas.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          );
                        }
                        return _AcademiaFija(nombre: itaca.nombre);
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, st) => Text(
                        l10n.registerAcademiesLoadError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
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
                          : Text(l10n.actionCreateAccount),
                    ),
                    // CONGELADO: Crear nueva academia (v1 es academia única)
                    // const SizedBox(height: 16),
                    // TextButton(
                    //   onPressed: _loading
                    //       ? null
                    //       : () => context.push(Routes.registroAcademia),
                    //   child: Text(l10n.registerOwnerCta),
                    // ),
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

/// Academia ya fijada por el enlace de invitación: se enseña, no se elige.
class _AcademiaFija extends StatelessWidget {
  const _AcademiaFija({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.ink, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nombre,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
