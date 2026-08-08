import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/models/profile.dart';
import '../application/profile_providers.dart';
import 'agregar_hijo_sheet.dart';

/// Pantalla para que un padre vea y gestione a sus hijos.
class MisHijosScreen extends ConsumerWidget {
  const MisHijosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hijosAsync = ref.watch(hijosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis hijos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarAgregarHijoSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Agregar hijo'),
      ),
      body: hijosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'Error al cargar los hijos',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        data: (hijos) {
          if (hijos.isEmpty) {
            return Center(
              child: Text(
                'No tienes hijos registrados todavía.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: hijos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final hijo = hijos[index];
              return _HijoTile(hijo: hijo);
            },
          );
        },
      ),
    );
  }
}

class _HijoTile extends StatelessWidget {
  const _HijoTile({required this.hijo});

  final Profile hijo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.surface,
          child: const Icon(Icons.person, color: AppColors.subtle),
        ),
        title: Text(hijo.nombre),
        subtitle: hijo.cinturon != null
            ? Text('Cinturón ${hijo.cinturon}')
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: abrir detalle/edición del hijo
        },
      ),
    );
  }
}
