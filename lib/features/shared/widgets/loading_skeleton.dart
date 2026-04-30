import 'package:flutter/material.dart';

class LoadingSkeletonList extends StatelessWidget {
  const LoadingSkeletonList({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(12),
  });

  final int itemCount;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
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
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final alpha = 0.10 + (_controller.value * 0.12);
        return Container(
          height: 104,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(width: 170, height: 14),
                const SizedBox(height: 10),
                _line(width: 120, height: 10),
                const Spacer(),
                Row(
                  children: [
                    _line(width: 78, height: 10),
                    const SizedBox(width: 8),
                    _line(width: 58, height: 10),
                    const SizedBox(width: 8),
                    _line(width: 70, height: 10),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _line({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
