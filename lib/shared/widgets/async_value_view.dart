import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import 'empty_state.dart';
import 'skeleton.dart';

/// Standardizes how a Riverpod `AsyncValue<List<E>>` is rendered across
/// screens: a skeleton while loading, a retry-able error state, an empty
/// state, and the data list with pull-to-refresh.
///
/// Offline resilience: if a refresh fails but the provider still holds the
/// previous data, the stale data stays on screen with a "sin conexión" banner
/// instead of blanking out — the app remains usable on a flaky connection.
class AsyncListView<E> extends StatelessWidget {
  const AsyncListView({
    super.key,
    required this.asyncValue,
    required this.onRefresh,
    required this.itemBuilder,
    required this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.separator = const SizedBox(height: 12),
    this.padding = const EdgeInsets.all(16),
  });

  final AsyncValue<List<E>> asyncValue;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, E item) itemBuilder;
  final String emptyMessage;
  final IconData emptyIcon;
  final Widget separator;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      skipLoadingOnReload: true,
      data: (items) => _data(context, items, stale: false),
      error: (error, _) => asyncValue.hasValue
          ? _data(context, asyncValue.requireValue, stale: true)
          : _ErrorState(message: mensajeErrorAmigable(error), onRetry: onRefresh),
      loading: () => const SkeletonList(),
    );
  }

  Widget _data(BuildContext context, List<E> items, {required bool stale}) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.22),
            EmptyState(icon: emptyIcon, message: emptyMessage),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (stale) const _OfflineBanner(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.separated(
              padding: padding,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => separator,
              itemBuilder: (context, index) => itemBuilder(context, items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 16, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Text(
              'Sin conexión · mostrando datos guardados',
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
