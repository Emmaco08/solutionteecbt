import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/theme.dart';
import '../theme/tokens.g.dart';

/// Empty / error / offline states (every screen has them, design-spec §5).
class StateView extends StatelessWidget {
  const StateView({super.key, required this.icon, required this.title, this.message, this.action, this.tone = 'blue'});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final String tone;

  factory StateView.offline({Widget? action}) => StateView(
        icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill),
        title: 'You are offline',
        message: 'Connect to the internet to load this. Tests you already downloaded still work.',
        action: action,
        tone: 'gold',
      );

  factory StateView.error(Object error, {VoidCallback? onRetry}) => StateView(
        icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
        title: 'Something went wrong',
        message: error.toString().replaceFirst('Exception: ', ''),
        action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        tone: 'red',
      );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (tone) {
      'gold' => (c.accentSoft, c.onAccentSoft),
      'red' => (c.errorSoft, c.onErrorSoft),
      'navy' => (c.primarySoft, c.onPrimarySoft),
      _ => (c.secondarySoft, c.onSecondarySoft),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 88, height: 88, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, size: 40, color: fg)),
          const SizedBox(height: Space.s5),
          Text(title, style: context.t.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: Space.s2),
            Text(message!, style: context.t.bodyMedium?.copyWith(color: c.textMuted), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: Space.s5), action!],
        ]),
      ),
    );
  }
}

/// Shimmering placeholder block for loading skeletons. Still (no shimmer) when reduce motion is on.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.height = 16, this.width = double.infinity, this.radius = Radii.md});
  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = Container(width: width, height: height, decoration: BoxDecoration(color: context.c.surfaceSunken, borderRadius: BorderRadius.circular(radius)));
    if (context.reduceMotion) return box;
    return box.animate(onPlay: (a) => a.repeat()).shimmer(duration: 1200.ms, color: context.c.surface.withValues(alpha: .6));
  }
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.items = 5});
  final int items;
  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(Space.s5),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items,
        separatorBuilder: (_, _) => const SizedBox(height: Space.s3),
        itemBuilder: (_, i) => const Skeleton(height: 72, radius: Radii.lg),
      );
}

/// Shows [data] when loaded, a skeleton while loading, and offline/error states otherwise.
Widget asyncView<T>(AsyncValue<T> v, Widget Function(T data) data, {Widget? loading, VoidCallback? onRetry}) => v.when(
      data: data,
      loading: () => loading ?? const ListSkeleton(),
      error: (e, _) => e.toString().contains('internet') || e.toString().contains('SocketException')
          ? StateView.offline(action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: const Text('Try again')))
          : StateView.error(e, onRetry: onRetry),
    );
