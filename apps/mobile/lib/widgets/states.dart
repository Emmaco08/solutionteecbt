import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/connectivity.dart';

import '../theme/theme.dart';
import '../theme/tokens.g.dart';
import '../ui/kit.dart';
import 'phosphor.g.dart';

/// Empty / error / offline states (prototype `.state`: 112 art tile, title, text, action). Every screen has them.
abstract final class StateView {
  static Widget offline({VoidCallback? onRetry}) => OfflineView(onRetry: onRetry);

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

/// No internet (owner, 14 Nov 2026: a better no-internet mode): a gently floating wifi badge, what still works, a link
/// to downloaded tests, and it reloads by itself the moment the internet is back.
class OfflineView extends ConsumerWidget {
  const OfflineView({super.key, this.onRetry});
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(onlineProvider, (prev, next) {
      if (prev?.value == false && next.value == true) onRetry?.call();
    });
    final c = context.c;
    Widget badge = Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(28)),
      child: Icon(PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill), size: 44, color: Palette.gold500),
    );
    if (!context.reduceMotion) {
      badge = badge.animate(onPlay: (a) => a.repeat(reverse: true)).moveY(begin: 3, end: -4, duration: 1600.ms, curve: Curves.easeInOut);
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge,
            const Gap(Space.s4),
            Text('No internet right now', style: context.ty.h2, textAlign: TextAlign.center),
            const Gap(Space.s2),
            Text(
              'Check your data or Wi-Fi. This page loads by itself when you are back online.',
              style: context.ty.sm.col(c.textMuted),
              textAlign: TextAlign.center,
            ),
            const Gap(Space.s4),
            Container(
              padding: const EdgeInsets.all(Space.s3),
              decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Still works offline', style: context.ty.cap.bold.col(c.textMuted)),
                  const SizedBox(height: 6),
                  for (final t in const ['Tests you downloaded', 'Saved videos and notes', 'Your bookmarks', 'Finished tests are sent when you are back'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 16, color: c.success),
                          const SizedBox(width: 8),
                          Expanded(child: Text(t, style: context.ty.sm)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Gap(Space.s4),
            Wrap(
              spacing: Space.s2,
              runSpacing: Space.s2,
              alignment: WrapAlignment.center,
              children: [
                if (onRetry != null) Btn('Try again', leading: PhosphorIcons.arrowClockwise(), onPressed: onRetry),
                Btn('My downloads', kind: BtnKind.outline, leading: PhosphorIcons.downloadSimple(), onPressed: () => GoRouter.of(context).push('/downloads')),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
