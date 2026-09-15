import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/error_messages.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../shared/widgets/pantalla.dart';
import '../application/agente_providers.dart';
import '../data/clave_agente.dart';

/// Claves de solo lectura para el agente personal del Dueño.
///
/// Esta pantalla la mira alguien que no es informático, así que explica qué
/// es esto antes de enseñar nada: una clave que deja **leer** datos de la
/// academia desde fuera, y que se puede anular en cualquier momento.
class AgenteScreen extends ConsumerWidget {
  const AgenteScreen({super.key});

  static String get direccion => '${AppConfig.supabaseUrl}/functions/v1/agente';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claves = ref.watch(clavesAgenteProvider);
    final t = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(
          'Una clave deja que un asistente como ChatGPT o Claude consulte '
          'los datos de la academia y te responda preguntas: cuánta gente '
          'vino, quién no ha pagado, quién lleva semanas sin aparecer.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: 10),
        Text(
          'Solo puede leer. Por aquí no se puede apuntar a nadie, ni cobrar, '
          'ni cambiar nada. Y se anula cuando quieras.',
          style: t.bodyMedium?.copyWith(color: AppColors.subtle),
        ),
        const SizedBox(height: 22),

        claves.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text(
            mensajeErrorAmigable(
              e,
              generico: 'No se han podido cargar las claves.',
            ),
            style: t.bodyMedium?.copyWith(color: AppColors.destructive),
          ),
          data: (lista) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lista.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.key_outlined,
                        size: 48,
                        color: AppColors.disabled,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Todavía no has dado ninguna clave.',
                        style: t.bodyMedium?.copyWith(color: AppColors.subtle),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                for (final clave in lista) ...[
                  _FilaClave(clave: clave),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => _crear(context, ref),
                child: const Text('Crear una clave'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),
        const Divider(),
        const SizedBox(height: 18),
        Text('Lo que ha leído tu agente', style: t.titleMedium),
        const SizedBox(height: 10),
        const _Registro(),
      ],
    );
  }

  Future<void> _crear(BuildContext context, WidgetRef ref) async {
    final datos = await showDialog<({String nombre, bool contacto})>(
      context: context,
      builder: (_) => const _DialogoNuevaClave(),
    );
    if (datos == null || !context.mounted) return;

    try {
      final clave = await ref
          .read(agenteRepositoryProvider)
          .crearClave(nombre: datos.nombre, incluyeContacto: datos.contacto);
      ref.invalidate(clavesAgenteProvider);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DialogoClaveCreada(clave: clave),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensajeErrorAmigable(
              e,
              generico: 'No se ha podido crear la clave.',
            ),
          ),
        ),
      );
    }
  }
}

class _FilaClave extends ConsumerWidget {
  const _FilaClave({required this.clave});

  final ClaveAgente clave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = StringBuffer('Termina en ${clave.pista}');
    if (clave.consultas > 0) {
      detalle.write(' · ${clave.consultas} consultas');
    }
    if (clave.incluyeContacto) {
      detalle.write(' · puede leer correos');
    }

    return TarjetaFila(
      titulo: clave.nombre,
      detalle: detalle.toString(),
      estado: clave.activa
          ? const PastillaEstado.exito('Activa')
          : const PastillaEstado.error('Anulada'),
      accion: clave.activa
          ? OutlinedButton(
              onPressed: () => _revocar(context, ref),
              child: const Text('Anular esta clave'),
            )
          : null,
    );
  }

  Future<void> _revocar(BuildContext context, WidgetRef ref) async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Anular la clave?'),
        content: Text(
          'Tu agente dejará de poder consultar nada al momento. '
          'No se puede deshacer: si lo quieres de vuelta, hay que darle '
          'una clave nueva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (seguro != true || !context.mounted) return;

    try {
      await ref.read(agenteRepositoryProvider).revocar(clave.id);
      ref.invalidate(clavesAgenteProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensajeErrorAmigable(
              e,
              generico: 'No se ha podido anular la clave.',
            ),
          ),
        ),
      );
    }
  }
}

class _DialogoNuevaClave extends StatefulWidget {
  const _DialogoNuevaClave();

  @override
  State<_DialogoNuevaClave> createState() => _DialogoNuevaClaveState();
}

class _DialogoNuevaClaveState extends State<_DialogoNuevaClave> {
  final _nombre = TextEditingController(text: 'Mi agente');
  bool _contacto = false;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva clave'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nombre,
            decoration: const InputDecoration(
              labelText: 'Para qué es',
              helperText: 'Para reconocerla luego, p. ej. «ChatGPT del móvil».',
            ),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _contacto,
            onChanged: (v) => setState(() => _contacto = v),
            title: const Text('Dejarle leer los correos'),
            subtitle: const Text(
              'El correo de tus alumnos saldría de la app. Si no lo '
              'necesitas, déjalo apagado.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final nombre = _nombre.text.trim();
            if (nombre.isEmpty) return;
            Navigator.of(context).pop((nombre: nombre, contacto: _contacto));
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

class _DialogoClaveCreada extends StatelessWidget {
  const _DialogoClaveCreada({required this.clave});

  final String clave;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Cópiala ahora'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Esta es la única vez que vas a ver la clave entera. Guárdala '
            'donde vayas a pegarla; si la pierdes, anúlala y crea otra.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 16),
          _Copiable(etiqueta: 'La clave', valor: clave),
          const SizedBox(height: 12),
          _Copiable(etiqueta: 'La dirección', valor: AgenteScreen.direccion),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ya la tengo guardada'),
        ),
      ],
    );
  }
}

class _Copiable extends StatelessWidget {
  const _Copiable({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(etiqueta, style: t.labelSmall),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(child: SelectableText(valor, style: t.bodySmall)),
              IconButton(
                tooltip: 'Copiar',
                icon: const Icon(Icons.copy_outlined, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: valor));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Copiado')));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Registro extends ConsumerWidget {
  const _Registro();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return ref
        .watch(consultasAgenteProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => Text(
            'No se ha podido cargar el registro.',
            style: t.bodyMedium?.copyWith(color: AppColors.subtle),
          ),
          data: (consultas) {
            if (consultas.isEmpty) {
              return Text(
                'Tu agente todavía no ha consultado nada.',
                style: t.bodyMedium?.copyWith(color: AppColors.subtle),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in consultas.take(15))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${_cuando(c.cuando)} · ${c.consulta} · ${c.clave}',
                      style: t.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                  ),
              ],
            );
          },
        );
  }

  String _cuando(DateTime d) {
    final l = d.toLocal();
    final dd = l.day.toString().padLeft(2, '0');
    final mm = l.month.toString().padLeft(2, '0');
    final hh = l.hour.toString().padLeft(2, '0');
    final mi = l.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$mi';
  }
}
