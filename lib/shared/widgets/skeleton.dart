import 'package:flutter/material.dart';

/// A pulsing placeholder block used to build skeleton loading states. Pure
/// Flutter (no shimmer package): a subtle opacity pulse over a themed surface,
/// which reads as "loading" without a heavy dependency.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.08, end: 0.20).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// A card-shaped skeleton approximating a list item, for list loading states.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Skeleton(width: 180, height: 18),
            SizedBox(height: 12),
            Skeleton(height: 12),
            SizedBox(height: 8),
            Skeleton(width: 240, height: 12),
            SizedBox(height: 16),
            Skeleton(width: 120, height: 10),
          ],
        ),
      ),
    );
  }
}

/// A vertical list of [SkeletonCard]s, matching the padding/spacing of the
/// real list it stands in for.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const SkeletonCard(),
    );
  }
}
