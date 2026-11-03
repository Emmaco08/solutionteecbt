import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/push.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';

/// Whether notifications are on for this app (refreshed when the app comes back to the front).
final notificationsOnProvider = FutureProvider<bool>((ref) => ref.read(pushProvider).enabled());

/// "Turn on notifications" (D-064): shown when Android no longer shows its own box. "Turn on" opens the phone's
/// notification settings for SolutionTee.
Future<void> showTurnOnNotifications(BuildContext context, WidgetRef ref) => showSheet<void>(
  context,
  builder: (ctx) {
    final c = ctx.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: c.secondarySoft, borderRadius: BorderRadius.circular(28)),
            child: Icon(PhosphorIcons.bellRinging(PhosphorIconsStyle.fill), size: 42, color: c.secondary),
          ).animate(target: ctx.reduceMotion ? 0 : 1).shake(hz: 3, rotation: .06, duration: Motion.slow),
        ),
        const Gap(Space.s4),
        Text('Turn on notifications', style: ctx.ty.h2, textAlign: TextAlign.center),
        const Gap(Space.s2),
        Text(
          'Get your streak reminder, new past questions and challenge results. You choose which ones in Settings.',
          style: ctx.ty.body.col(c.textMuted),
          textAlign: TextAlign.center,
        ),
        const Gap(Space.s5),
        Btn(
          'Turn on',
          block: true,
          leading: PhosphorIcons.bellRinging(PhosphorIconsStyle.fill),
          onPressed: () {
            Navigator.of(ctx).pop();
            ref.read(pushProvider).openSettings();
          },
        ),
        const Gap(Space.s2),
        Btn('Not now', kind: BtnKind.ghost, block: true, onPressed: () => Navigator.of(ctx).pop()),
      ],
    );
  },
);

/// Settings banner while notifications are off on the phone.
class NotificationsOffBanner extends ConsumerWidget {
  const NotificationsOffBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(notificationsOnProvider).value ?? true;
    if (on) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s3),
      child: InfoBanner(
        kind: BannerKind.warn,
        icon: PhosphorIcons.bellSlash(PhosphorIconsStyle.fill),
        child: Row(
          children: [
            const Expanded(child: Text('Notifications are off on this phone.')),
            Btn('Turn on', kind: BtnKind.tonal, sm: true, onPressed: () => ref.read(pushProvider).openSettings()),
          ],
        ),
      ),
    );
  }
}
