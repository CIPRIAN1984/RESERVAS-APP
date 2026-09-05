import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/routes.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../../shared/widgets/pantalla.dart';
import '../../tarifas/presentation/tarifas_screen.dart';
import '../application/profile_providers.dart';

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
  bool _savingEntrena = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  /// «No entreno, solo traigo a mis hijos». Cambiarlo no da ni quita
  /// permisos: solo decide si sales en la lista de alumnos de la academia
  /// y si puedes reservar plaza para ti.
  Future<void> _guardarEntrena(String userId, bool entrena) async {
    setState(() => _savingEntrena = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .actualizarEntrena(userId: userId, entrena: entrena);
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              entrena
                  ? 'Vuelves a contar como alumno de la academia.'
                  : 'Marcado: solo traes a tus hijos, no entrenas.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido guardar el cambio.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingEntrena = false);
    }
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

  Future<void> _cerrarSesion() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Tendrás que volver a escribir tu correo y contraseña para entrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    await ref.read(authRepositoryProvider).signOut();
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
                        backgroundColor: AppColors.surface,
                        backgroundImage: profile.fotoUrl != null
                            ? CachedNetworkImageProvider(profile.fotoUrl!)
                            : null,
                        child: profile.fotoUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 48,
                                color: AppColors.subtle,
                              )
                            : null,
                      ),
                      Material(
                        color: AppColors.ink,
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
                                ?.copyWith(color: AppColors.subtle),
                          ),
                    loading: () => const SizedBox.shrink(),
                    error: (e, st) => const SizedBox.shrink(),
                  ),
                  // Cuota y tienda viven aquí para el alumno. Antes colgaban
                  // del cajón lateral; al sustituirlo por la barra inferior se
                  // quedaron sin sitio desde el que llegar, y el alumno no
                  // podía ni ver su cuota ni comprar material.
                  if (!profile.isAdministrador) ...[
                    const SizedBox(height: 32),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Mi academia',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TarjetaAcceso(
                      icono: Icons.card_membership_outlined,
                      titulo: 'Mi cuota',
                      descripcion: 'Consulta tu plan, cámbialo o date de baja.',
                      destino: const TarifasScreen(),
                    ),
                    const SizedBox(height: 12),
                    // Mi familia es para todos, no solo para quien ya tiene
                    // hijos: si solo se enseñara a quien los tiene, nadie
                    // podría dar de alta al primero.
                    Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push(Routes.misHijos),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.family_restroom_outlined,
                                size: 26,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mi familia',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Da de alta a tus hijos y gestiónalos '
                                      'desde tu cuenta.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.subtle),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: AppColors.disabled,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InterruptorEntrena(
                      entrena: profile.entrena,
                      guardando: _savingEntrena,
                      onCambio: (valor) => _guardarEntrena(profile.id, valor),
                    ),
                  ],
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
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => context.push(Routes.privacidad),
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Privacidad y protección de datos'),
                  ),

                  // Cerrar sesión vive aquí, en la única pantalla que tienen
                  // TODOS los roles. Estaba solo en Academia, que un alumno no
                  // ve nunca y un Administrador de plataforma tampoco: se
                  // quedaban sin poder salir ni cambiar de usuario.
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _cerrarSesion,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Interruptor de «yo también entreno».
///
/// Se enseña en positivo (activado = entrenas) porque es lo normal: quien
/// solo trae a sus hijos lo apaga, y con eso deja de aparecer en la lista
/// de alumnos y en los contadores de cuotas del Dueño.
class _InterruptorEntrena extends StatelessWidget {
  const _InterruptorEntrena({
    required this.entrena,
    required this.guardando,
    required this.onCambio,
  });

  final bool entrena;
  final bool guardando;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yo también entreno',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entrena
                        ? 'Cuentas como alumno y puedes reservar plaza.'
                        : 'Solo traes a tus hijos: no sales en la lista de '
                              'alumnos ni reservas para ti.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (guardando)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            else
              Switch(value: entrena, onChanged: onCambio),
          ],
        ),
      ),
    );
  }
}
