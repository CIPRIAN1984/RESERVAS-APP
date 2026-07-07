import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../application/profile_providers.dart';
import 'solicitar_cambio_escuela_screen.dart';

class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  final _datosFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _initialized = false;
  bool _savingDatos = false;
  bool _uploadingFoto = false;
  bool _savingPassword = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _guardarDatos(String userId) async {
    if (!(_datosFormKey.currentState?.validate() ?? false)) return;
    setState(() => _savingDatos = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateDatosPersonales(
            userId: userId,
            nombre: _nombreController.text.trim(),
            apellidos: _apellidosController.text.trim(),
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Datos actualizados.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se han podido guardar los cambios.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingDatos = false);
    }
  }

  Future<void> _cambiarFoto(String userId) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _uploadingFoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final extension = picked.name.contains('.')
          ? picked.name.split('.').last
          : 'jpg';
      await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(userId: userId, bytes: bytes, fileExtension: extension);
      ref.invalidate(currentProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido subir la foto.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingFoto = false);
    }
  }

  Future<void> _cambiarContrasena() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    setState(() => _savingPassword = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .changePassword(_passwordController.text);
      _passwordController.clear();
      _passwordConfirmController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se ha podido actualizar la contraseña.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final academiaAsync = ref.watch(currentAcademiaProvider);
    final userId = ref.watch(currentUserIdProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Text(
          'No se ha podido cargar tu perfil.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (profile) {
        if (profile == null || userId == null) {
          return const Center(child: Text('No hay sesión activa.'));
        }

        if (!_initialized) {
          _nombreController.text = profile.nombre;
          _apellidosController.text = profile.apellidos ?? '';
          _initialized = true;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.surfaceElevated,
                        backgroundImage: profile.fotoUrl != null
                            ? CachedNetworkImageProvider(profile.fotoUrl!)
                            : null,
                        child: profile.fotoUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 48,
                                color: AppColors.textSecondary,
                              )
                            : null,
                      ),
                      Material(
                        color: AppColors.accentPrimary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _uploadingFoto
                              ? null
                              : () => _cambiarFoto(userId),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: _uploadingFoto
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Chip(label: Text(profile.rol)),
                      if (profile.cinturon != null)
                        Chip(label: Text('Cinturón ${profile.cinturon}')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  academiaAsync.when(
                    data: (academia) => academia == null
                        ? const SizedBox.shrink()
                        : Text(
                            academia.nombre,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                    loading: () => const SizedBox.shrink(),
                    error: (e, st) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Datos personales',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _datosFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nombreController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Obligatorio'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _apellidosController,
                          decoration: const InputDecoration(
                            labelText: 'Apellidos',
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _savingDatos
                              ? null
                              : () => _guardarDatos(userId),
                          child: _savingDatos
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Guardar cambios'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Cambiar contraseña',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _passwordFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Nueva contraseña',
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Mínimo 6 caracteres'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordConfirmController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contraseña',
                          ),
                          validator: (v) => (v != _passwordController.text)
                              ? 'Las contraseñas no coinciden'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _savingPassword
                              ? null
                              : _cambiarContrasena,
                          child: _savingPassword
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Actualizar contraseña'),
                        ),
                      ],
                    ),
                  ),
                  if (profile.isAlumno && profile.academiaId != null) ...[
                    const SizedBox(height: 32),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SolicitarCambioEscuelaScreen(
                            alumnoId: userId,
                            academiaActualId: profile.academiaId!,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Solicitar cambio de escuela'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
