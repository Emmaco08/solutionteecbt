import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme.dart';
import '../theme/tokens.g.dart';
import '../ui/kit.dart';
import 'phosphor.g.dart';

/// Empty / error / offline states (prototype `.state`: 112 art tile, title, text, action). Every screen has them.
abstract final class StateView {
  static Widget offline({VoidCallback? onRetry}) => Center(
    child: SingleChildScrollView(
      child: StateBlock(
        icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill),
        tone: Tone.gold,
        title: 'You are offline',
        text: 'Connect to the internet to load this. Tests already on your phone still work.',
        action: onRetry == null ? null : Btn('Try again', leading: PhosphorIcons.arrowClockwise(), onPressed: onRetry),
      ),
    ),
  );

  static Widget error(Object error, {VoidCallback? onRetry}) => Center(
    child: SingleChildScrollView(
      child: StateBlock(
        icon: PhosphorIcons.cloudWarning(PhosphorIconsStyle.fill),
        tone: Tone.red,
        title: 'We could not load this',
        text: error.toString().replaceFirst('Exception: ', ''),
        action: onRetry == null ? null : Btn('Try again', leading: PhosphorIcons.arrowClockwise(), onPressed: onRetry),
      ),
    ),
  );
}

/// Shimmering placeholder block for loading skeletons (`.sk`). Still (no shimmer) when reduce motion is on.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.height = 16, this.width = double.infinity, this.radius = Radii.sm});
  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: context.c.surfaceSunken, borderRadius: BorderRadius.circular(radius)),
    );
    if (context.reduceMotion) return box;
    return box
        .animate(onPlay: (a) => a.repeat())
        .shimmer(
          duration: 1300.ms,
          color: Colors.white.withValues(alpha: context.isDark ? .06 : .45),
        );
  }
}

/// List skeleton: rows of 76 px rounded blocks.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.items = 5});
  final int items;
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s5),
    physics: const NeverScrollableScrollPhysics(),
    itemCount: items,
    separatorBuilder: (_, _) => const SizedBox(height: Space.s3),
    itemBuilder: (_, i) => const Skeleton(height: 76, radius: Radii.lg),
  );
}

/// Shows [data] when loaded, a skeleton while loading, and offline/error states otherwise.
Widget asyncView<T>(AsyncValue<T> v, Widget Function(T data) data, {Widget? loading, VoidCallback? onRetry}) => v.when(
  data: data,
  loading: () => loading ?? const ListSkeleton(),
  error: (e, _) => RegExp('internet|socket|network|connection|host', caseSensitive: false).hasMatch(e.toString())
      ? StateView.offline(onRetry: onRetry)
      : StateView.error(e, onRetry: onRetry),
);
