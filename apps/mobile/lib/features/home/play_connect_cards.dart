import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../gamezone/gz_scenes.dart' show GameIcon;
import '../gamezone/gz_theme.dart' show GzC, gzFont;

// Home, just before News (owner, 13 Nov 2026): Game Zone and Community, each on its own lively card. Light on the phone:
// painted shapes and small looping moves (off with "reduce motion"), no images, no network.

class PlayConnectSection extends StatelessWidget {
  const PlayConnectSection({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [const SectTitle('Play and connect'), const _GameZoneCard(), const Gap(Space.s3), const _CommunityCard()],
  );
}

class _Shell extends StatelessWidget {
  const _Shell({required this.colors, required this.onTap, required this.label, required this.child});
  final List<Color> colors;
  final VoidCallback onTap;
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          height: 172,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class _Cta extends StatelessWidget {
  const _Cta(this.text, {required this.bg, required this.fg});
  final String text;
  final Color bg, fg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: context.ty.label.bold.col(fg)),
        const SizedBox(width: 4),
        Icon(PhosphorIcons.arrowRight(PhosphorIconsStyle.bold), size: 16, color: fg),
      ],
    ),
  );
}

// ---------------------------------------------------------------- Game Zone

class _GameZoneCard extends StatelessWidget {
  const _GameZoneCard();
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    Widget icon(String id, double size, double dx, double dy, int delay, double turn) {
      final i = Transform.rotate(
        angle: turn,
        child: GameIcon(id, size: size),
      );
      return Positioned(
        right: dx,
        top: dy,
        child: rm
            ? i
            : i
                  .animate(onPlay: (c) => c.repeat(reverse: true), delay: delay.ms)
                  .moveY(begin: 0, end: -7, duration: 1600.ms, curve: Curves.easeInOut)
                  .rotate(begin: -.012, end: .012, duration: 1600.ms),
      );
    }

    return _Shell(
      label: 'Game Zone: play live games against students or the bot',
      colors: const [Color(0xFF241552), Color(0xFF13306A)],
      onTap: () => context.push('/games'),
      child: Stack(
        children: [
          // Stage lights.
          Positioned(
            right: -30,
            top: -40,
            child: _Glow(color: GzC.purple, size: 190, still: rm),
          ),
          Positioned(
            right: 60,
            bottom: -60,
            child: _Glow(color: GzC.brand, size: 140, still: rm, delay: 900),
          ),
          icon('duel', 58, 104, 10, 0, -.12),
          icon('reading', 52, 22, 6, 400, .1),
          icon('rush', 50, 70, 70, 800, 0),
          icon('memory', 40, 10, 84, 1200, .14),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, 150, Space.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: GzC.pink, borderRadius: BorderRadius.circular(6)),
                  child: Text('LIVE', style: gzFont(11, shadow: 0)),
                ),
                const SizedBox(height: 6),
                Text('GAME ZONE', style: gzFont(26, color: GzC.goldLight)),
                Expanded(
                  child: Text(
                    '8 games. Beat a student or the bot.',
                    style: context.ty.sm.col(const Color(0xFFDCE4F2)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const _Cta('Play now', bg: GzC.gold, fg: Palette.navy900),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, required this.still, this.delay = 0});
  final Color color;
  final double size;
  final bool still;
  final int delay;
  @override
  Widget build(BuildContext context) {
    final g = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: .45), color.withValues(alpha: 0)]),
      ),
    );
    if (still) return g;
    return g.animate(onPlay: (c) => c.repeat(reverse: true), delay: delay.ms).scaleXY(begin: .85, end: 1.1, duration: 2400.ms, curve: Curves.easeInOut);
  }
}

// ---------------------------------------------------------------- Community

class _CommunityCard extends StatelessWidget {
  const _CommunityCard();
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    Widget bubble(String text, {required bool me, required int delay}) {
      final b = Container(
        constraints: const BoxConstraints(maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: me ? Palette.gold400 : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(me ? 12 : 3),
            bottomRight: Radius.circular(me ? 3 : 12),
          ),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Text(text, style: context.ty.cap.bold.col(Palette.navy900), maxLines: 2),
      );
      if (rm) return b;
      // Each bubble pops in, stays, then fades so the chat feels alive (one loop every 6 seconds).
      return b
          .animate(onPlay: (c) => c.repeat(), delay: delay.ms)
          .fadeIn(duration: 300.ms)
          .scaleXY(begin: .6, end: 1, curve: Curves.easeOutBack, duration: 380.ms)
          .then(delay: 3600.ms)
          .fadeOut(duration: 400.ms)
          .then(delay: 1300.ms);
    }

    return _Shell(
      label: 'Community: ask questions and share tips with other students',
      colors: const [Color(0xFF0E4A8A), Color(0xFF2563B3)],
      onTap: () => context.push('/community'),
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                bubble('Who can explain osmosis? 🤔', me: false, delay: 0),
                const SizedBox(height: 6),
                bubble('@solutiontee answered ✨', me: true, delay: 900),
                const SizedBox(height: 6),
                bubble('Thank you! 🙏', me: false, delay: 1800),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, 170, Space.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Faces(),
                const SizedBox(height: 8),
                Text('Community', style: context.ty.h2.col(Colors.white)),
                Expanded(
                  child: Text('Ask, answer and share tips.', style: context.ty.sm.col(const Color(0xFFDCE4F2)), maxLines: 3, overflow: TextOverflow.ellipsis),
                ),
                const _Cta('Join in', bg: Colors.white, fg: Palette.navy900),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlapping round faces (initials), like a group chat.
class _Faces extends StatelessWidget {
  const _Faces();
  @override
  Widget build(BuildContext context) {
    const people = [('AO', Color(0xFFF2B233)), ('KC', Color(0xFFE0335A)), ('TM', Color(0xFF1FA463)), ('+', Color(0xFF0B1F44))];
    return SizedBox(
      height: 28,
      width: 28.0 + 20 * (people.length - 1),
      child: Stack(
        children: [
          for (final (i, (t, c)) in people.indexed)
            Positioned(
              left: i * 20.0,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(t, style: context.ty.cap.bold.copyWith(fontSize: 10, height: 1).col(c == const Color(0xFFF2B233) ? Palette.navy900 : Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
