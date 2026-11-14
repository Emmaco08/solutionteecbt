import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/nav.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/phosphor.g.dart';
import 'challenges_screens.dart' show ChallengeBackdrop, challengeIcon;
import 'compete_data.dart';

// Challenge cards v2 (owner, 14 Nov 2026): a new, better challenge card with LIVE and the number playing back, well
// animated, but clean and calm, not game-like. One look everywhere:
//  • ChallengeLiveCard  – the big Home card for a live challenge
//  • ChallengeSoonCard  – the big Home card when the next one has not started
//  • ChallengeMiniCard  – the small cards in the Home row (live, coming up, ended)
//  • ChallengeListCard  – the rows on Test → Challenges & events
// Motion is purposeful and light: the LIVE dot beats, the number playing counts up, countdown digits slide when they
// change, the time bar fills in, and cards fade in. With "reduce motion" everything stands still.

const _red = Color(0xFFE5484D);
const _sub = Color(0xFFB9C7DE);
const _line = Color(0x1FFFFFFF);

// ---------------------------------------------------------------------------------------------------- pieces

/// Rebuilds once a second (for countdowns).
class _EverySecond extends StatefulWidget {
  const _EverySecond({required this.builder});
  final WidgetBuilder builder;
  @override
  State<_EverySecond> createState() => _EverySecondState();
}

class _EverySecondState extends State<_EverySecond> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// LIVE: a red pill with a beating dot and a soft ring rippling out.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.small = false});
  final bool small;
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    final d = small ? 6.0 : 7.0;
    final dot = Container(
      width: d,
      height: d,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );
    final ring = Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
    );
    return Container(
      height: small ? 22 : 26,
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10),
      decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: d * 2,
            height: d * 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!rm) ring.animate(onPlay: (a) => a.repeat()).scaleXY(begin: 1, end: 2, duration: 1400.ms, curve: Curves.easeOut).fadeOut(duration: 1400.ms),
                dot,
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text('LIVE', style: context.ty.cap.bold.copyWith(letterSpacing: 1, height: 1).col(Colors.white)),
        ],
      ),
    );
  }
}

String _count(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

/// "128 playing" with three small overlapping faces; the number counts up once.
class _Playing extends StatelessWidget {
  const _Playing(this.n, {this.color = _sub, this.strong = Colors.white, this.edge = Palette.navy900});
  final int n;
  final Color color, strong, edge;
  @override
  Widget build(BuildContext context) {
    const faces = [Color(0xFFF2B233), Color(0xFF5887C5), Color(0xFF1FA463)];
    final shown = n.clamp(0, 3);
    Text label(int v) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: _count(v), style: context.ty.sm.bold.tnum.col(strong)),
          TextSpan(text: ' playing', style: context.ty.sm.col(color)),
        ],
      ),
      maxLines: 1,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (shown > 0) ...[
          SizedBox(
            width: 18.0 + 11 * (shown - 1),
            height: 18,
            child: Stack(
              children: [
                for (var i = 0; i < shown; i++)
                  Positioned(
                    left: i * 11.0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: faces[i],
                        shape: BoxShape.circle,
                        border: Border.all(color: edge, width: 1.5),
                      ),
                      child: Icon(PhosphorIcons.user(PhosphorIconsStyle.fill), size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
        context.reduceMotion || n < 2
            ? label(n)
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: n.toDouble()),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => label(v.round()),
              ),
      ],
    );
  }
}

/// CASH PRIZE / EVENT / PRACTICE / JAMB MOCK in small capitals.
(String, Color) _kind(Challenge c) => c.isMock
    ? ('JAMB MOCK', const Color(0xFF7FD8A6))
    : switch (c.kind) {
        'cash' => ('CASH PRIZE', Palette.gold300),
        'event' => ('EVENT', const Color(0xFFB4C6FF)),
        _ => ('PRACTICE', const Color(0xFFA9C4EA)),
      };

/// A countdown like "1d 12h 04m" (or "05h 42m 17s" in the last day); each number slides when it changes.
class _Clock extends StatelessWidget {
  const _Clock({required this.to, this.big = false});
  final DateTime to;
  final bool big;
  @override
  Widget build(BuildContext context) => _EverySecond(
    builder: (context) {
      final s = to.difference(DateTime.now()).inSeconds.clamp(0, 99 * 86400);
      final parts = <(int, String)>[if (s >= 86400) (s ~/ 86400, 'd'), (s % 86400 ~/ 3600, 'h'), (s % 3600 ~/ 60, 'm'), if (s < 86400) (s % 60, 's')];
      final number = (big ? context.ty.h1 : context.ty.h3).bold.tnum.copyWith(height: 1).col(Colors.white);
      final unit = (big ? context.ty.sm : context.ty.cap).bold.copyWith(height: 1).col(_sub);
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          for (final (i, (n, u)) in parts.indexed) ...[
            if (i > 0) SizedBox(width: big ? 10 : 7),
            ClipRect(
              child: AnimatedSwitcher(
                duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
                transitionBuilder: (child, a) => SlideTransition(
                  position: Tween(begin: const Offset(0, .6), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: Text(i == 0 && u == 'd' ? '$n' : n.toString().padLeft(2, '0'), key: ValueKey('$u$n'), style: number),
              ),
            ),
            const SizedBox(width: 2),
            Text(u, style: unit),
          ],
        ],
      );
    },
  );
}

/// How much of the challenge time has gone; fills in when the card appears.
class _TimeBar extends StatelessWidget {
  const _TimeBar(this.c);
  final Challenge c;
  @override
  Widget build(BuildContext context) {
    final total = c.endsAt.difference(c.startsAt).inSeconds;
    final f = total <= 0 ? 1.0 : (DateTime.now().difference(c.startsAt).inSeconds / total).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Container(color: _line),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: context.reduceMotion ? f : 0, end: f),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Palette.gold500, Palette.gold300])),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The call to action: the app's gold button (navy text) or a white outline, with an arrow that nudges gently.
class _Cta extends StatelessWidget {
  const _Cta(this.text, {required this.onTap, this.outline = false, this.off = false});
  final String text;
  final VoidCallback? onTap;
  final bool outline, off;
  @override
  Widget build(BuildContext context) {
    final fg = off ? const Color(0xFF9FB0CC) : (outline ? Colors.white : Palette.navy900);
    Widget arrow = Icon(PhosphorIcons.arrowRight(PhosphorIconsStyle.bold), size: 16, color: fg);
    if (!context.reduceMotion && !off) {
      arrow = arrow.animate(onPlay: (a) => a.repeat(reverse: true)).moveX(begin: 0, end: 3, duration: 700.ms, curve: Curves.easeInOut);
    }
    return Semantics(
      button: true,
      enabled: !off,
      child: GestureDetector(
        onTap: off ? null : onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
          decoration: BoxDecoration(
            color: off ? Colors.white.withValues(alpha: .10) : (outline ? Colors.transparent : Palette.gold400),
            borderRadius: BorderRadius.circular(12),
            border: outline ? Border.all(color: Colors.white.withValues(alpha: .4)) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: context.ty.label.bold.col(fg)),
              if (!off) ...[const SizedBox(width: 6), arrow],
            ],
          ),
        ),
      ),
    );
  }
}

/// "You took part · #3" / "Disqualified" / "You are writing".
Widget? _mineNote(BuildContext context, Challenge c, {bool dark = true}) {
  final m = c.mine;
  if (m == null) return null;
  final status = '${m['status']}';
  final rank = (m['rank'] as num?)?.toInt();
  final cc = context.c;
  final (text, color, icon) = switch (status) {
    'disqualified' => ('Disqualified', dark ? const Color(0xFFFF8A8E) : cc.error, PhosphorIcons.shieldWarning(PhosphorIconsStyle.fill)),
    'playing' => ('You are writing', dark ? Palette.gold300 : Palette.gold500, PhosphorIcons.pencilSimple(PhosphorIconsStyle.fill)),
    _ => (
      rank != null ? 'You took part · #$rank' : 'You took part',
      dark ? const Color(0xFF6EDBA4) : cc.success,
      PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
    ),
  };
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 5),
      Text(text, style: context.ty.sm.bold.col(dark ? Colors.white : cc.text)),
    ],
  );
}

void _open(BuildContext context, Challenge c) => openRoute(context, '/test/challenges/${c.id}');
String _meta(Challenge c) => [
  c.isMock ? '${c.durationMinutes} min' : '${c.questions} questions',
  if (!c.isMock) '${c.seconds}s each',
  c.xpFee > 0 ? '${c.xpFee} XP to join' : 'Free to join',
].join(' · ');

/// The small square badge: the exam logo for JAMB/WAEC/NECO challenges, else the challenge icon.
class _Badge extends StatelessWidget {
  const _Badge(this.c, {this.size = 44, this.onDark = true});
  final Challenge c;
  final double size;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final code = c.isMock ? 'jamb' : c.exam;
    if (code != null) return ExamLogo(code, px: size);
    final cc = context.c;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: onDark ? Colors.white.withValues(alpha: .12) : cc.secondarySoft, borderRadius: BorderRadius.circular(size * .3)),
      alignment: Alignment.center,
      child: Icon(challengeIcon(c.icon), size: size * .5, color: onDark ? Palette.gold300 : cc.onSecondarySoft),
    );
  }
}

/// The dark surface of the big cards: the admin's picture when there is one, else a deep navy-to-blue gradient with
/// the challenge icon drawn very faintly on the right.
class _Surface extends StatelessWidget {
  const _Surface({required this.c, required this.colors, required this.child});
  final Challenge c;
  final List<Color> colors;
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(Radii.lg + 4),
    child: ChallengeBackdrop(
      c: c,
      fallback: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      child: Stack(
        children: [
          Positioned(right: -28, top: 18, child: Icon(challengeIcon(c.icon), size: 170, color: Colors.white.withValues(alpha: .05))),
          child,
        ],
      ),
    ),
  );
}

Widget _enter(BuildContext context, Widget w, {int delay = 0, bool sideways = false}) {
  if (context.reduceMotion) return w;
  final a = w.animate(delay: delay.ms).fadeIn(duration: 320.ms);
  return sideways ? a.slideX(begin: .08, end: 0, curve: Curves.easeOutCubic) : a.slideY(begin: .05, end: 0, curve: Curves.easeOutCubic);
}

// ---------------------------------------------------------------------------------------------------- live card

/// The big Home card for a live challenge.
class ChallengeLiveCard extends StatelessWidget {
  const ChallengeLiveCard({super.key, required this.c});
  final Challenge c;
  @override
  Widget build(BuildContext context) {
    final mine = c.mine;
    final note = _mineNote(context, c);
    final writing = mine != null && mine['status'] == 'playing';
    final cta = mine != null ? (writing ? 'Continue' : 'See result') : (c.full ? 'Full' : 'Play now');
    final left = c.placesLeft;
    final (kind, kindColor) = _kind(c);
    final hasPrize = c.prizes.isNotEmpty || c.reward != null;
    return _enter(
      context,
      Pressable(
        onTap: () => _open(context, c),
        child: _Surface(
          c: c,
          colors: const [Palette.navy900, Color(0xFF13306A)],
          child: Padding(
            padding: const EdgeInsets.all(Space.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const LiveBadge(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(fit: BoxFit.scaleDown, child: _Playing(c.joined)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(kind, style: context.ty.cap.bold.copyWith(letterSpacing: 1.2).col(kindColor)),
                  ],
                ),
                const Gap(Space.s4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasPrize) Text(c.title, style: context.ty.sm.bold.col(_sub), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            hasPrize ? (c.prizes.isNotEmpty ? 'Win ${nairaWhole(c.prizes.first)}' : c.reward!) : c.title,
                            style: context.ty.h1.col(hasPrize ? Palette.gold300 : Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(_meta(c), style: context.ty.sm.col(_sub)),
                          if (left != null && mine == null && left > 0 && left <= 50) ...[
                            const SizedBox(height: 4),
                            Text('Only $left places left', style: context.ty.sm.bold.col(const Color(0xFFFFB86B))),
                          ],
                        ],
                      ),
                    ),
                    if (c.isMock || c.exam != null) ...[const Gap(Space.s3), _Badge(c, size: 44)],
                  ],
                ),
                if (note != null) ...[const Gap(Space.s3), note],
                const Gap(Space.s4),
                Container(height: 1, color: _line),
                const Gap(Space.s3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.kind == 'practice' ? 'Ends in' : 'Winners in', style: context.ty.cap.col(_sub)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _Clock(to: c.endsAt),
                          ),
                        ],
                      ),
                    ),
                    const Gap(Space.s2),
                    _Cta(cta, off: c.full && mine == null, onTap: () => _open(context, c)),
                  ],
                ),
                const Gap(Space.s3),
                _TimeBar(c),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------- coming-up card

/// The big Home card for the next challenge that has not started yet.
class ChallengeSoonCard extends StatelessWidget {
  const ChallengeSoonCard({super.key, required this.c});
  final Challenge c;
  @override
  Widget build(BuildContext context) {
    final (kind, _) = _kind(c);
    const soft = Color(0xFFD6E4F7);
    return _enter(
      context,
      Pressable(
        onTap: () => _open(context, c),
        child: _Surface(
          c: c,
          colors: const [Color(0xFF13386B), Color(0xFF2563B3)],
          child: Padding(
            padding: const EdgeInsets.all(Space.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIcons.calendarBlank(PhosphorIconsStyle.fill), size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('COMING UP', style: context.ty.cap.bold.copyWith(letterSpacing: 1, height: 1).col(Colors.white)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(kind, style: context.ty.cap.bold.copyWith(letterSpacing: 1.2).col(soft)),
                  ],
                ),
                const Gap(Space.s4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: context.ty.h2.col(Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('${c.rewardText} · ${c.entryText}', style: context.ty.sm.col(soft), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (c.isMock || c.exam != null) ...[const Gap(Space.s3), _Badge(c, size: 44)],
                  ],
                ),
                const Gap(Space.s4),
                Container(height: 1, color: _line),
                const Gap(Space.s3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Starts in', style: context.ty.cap.col(soft)),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _Clock(to: c.startsAt, big: true),
                          ),
                        ],
                      ),
                    ),
                    const Gap(Space.s2),
                    _Cta('Details', outline: true, onTap: () => _open(context, c)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------- mini card

/// The small card in the Home row, on the normal card surface: a LIVE / "in 2h" / "Ended" pill, the title, players or
/// winners, then Prize and Entry.
class ChallengeMiniCard extends StatelessWidget {
  const ChallengeMiniCard({super.key, required this.c, this.index = 0});
  final Challenge c;
  final int index;
  @override
  Widget build(BuildContext context) {
    final cc = context.c;
    final Widget status = c.live
        ? const LiveBadge(small: true)
        : c.upcoming
        ? _EverySecond(builder: (_) => Pill('in ${untilShort(c.startsAt)}', icon: PhosphorIcons.clock(PhosphorIconsStyle.fill)))
        : const Pill('Ended', kind: BadgeKind.neutral);
    return _enter(
      context,
      AppCard(
        onTap: () => openRoute(context, c.ended ? '/test/challenges/${c.id}/winners' : '/test/challenges/${c.id}'),
        pad: false,
        clip: true,
        child: ChallengeBackdrop(
          c: c,
          strong: false,
          padding: const EdgeInsets.all(Space.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [_Badge(c, size: 34, onDark: false), const Spacer(), status]),
              const Gap(Space.s2),
              Text(c.title, style: context.ty.sm.bold, maxLines: 2, overflow: TextOverflow.ellipsis),
              const Spacer(),
              if (c.live)
                _Playing(c.joined, color: cc.textMuted, strong: cc.text, edge: cc.surface)
              else if (c.ended)
                Text('${c.joined} took part · See winners', style: context.ty.cap.col(cc.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              Divider(height: Space.s3, color: cc.border),
              Row(
                children: [
                  Expanded(child: _MiniStat('Prize', c.prizes.isNotEmpty ? nairaWhole(c.prizes.first) : (c.reward != null ? 'Reward' : 'Practice'))),
                  Expanded(child: _MiniStat('Entry', c.xpFee > 0 ? '${c.xpFee} XP' : 'Free')),
                ],
              ),
            ],
          ),
        ),
      ),
      delay: 70 * index,
      sideways: true,
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: context.ty.cap.col(context.c.textMuted)),
      Text(value, style: context.ty.sm.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
    ],
  );
}

// ---------------------------------------------------------------------------------------------------- list card

/// A row on Test → Challenges & events, on the normal card surface with a thin status edge.
class ChallengeListCard extends StatelessWidget {
  const ChallengeListCard({super.key, required this.c, this.index = 0});
  final Challenge c;
  final int index;
  @override
  Widget build(BuildContext context) {
    final cc = context.c;
    final note = _mineNote(context, c, dark: false);
    final (kind, _) = _kind(c);
    return _enter(
      context,
      AppCard(
        onTap: () => _open(context, c),
        pad: false,
        clip: true,
        child: ChallengeBackdrop(
          c: c,
          strong: false,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.s3),
                    child: Row(
                      children: [
                        _Badge(c, size: 48, onDark: false),
                        const Gap(Space.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (c.live)
                                    const LiveBadge(small: true)
                                  else
                                    _EverySecond(
                                      builder: (_) => Pill('Starts in ${untilShort(c.startsAt)}', icon: PhosphorIcons.clock(PhosphorIconsStyle.fill)),
                                    ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      kind,
                                      style: context.ty.cap.bold.copyWith(letterSpacing: 1).col(cc.textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(c.title, style: context.ty.body.bold, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (c.live) '${_count(c.joined)} playing',
                                  if (c.mode == 'subject' && c.subject != null) c.subject!,
                                  if (c.mode == 'mixed') 'Your JAMB subjects',
                                  c.isMock ? '${c.durationMinutes} min' : '${c.questions} questions',
                                  c.xpFee > 0 ? '${c.xpFee} XP' : 'Free',
                                ].join(' · '),
                                style: context.ty.cap.col(cc.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (note != null) ...[const SizedBox(height: 6), note],
                            ],
                          ),
                        ),
                        const Gap(Space.s2),
                        if (c.prizes.isNotEmpty)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Win', style: context.ty.cap.col(cc.textMuted)),
                              Text(nairaWhole(c.prizes.first), style: context.ty.body.bold),
                            ],
                          )
                        else
                          Icon(PhosphorIcons.caretRight(), size: 18, color: cc.textSubtle),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      delay: 60 * index,
    );
  }
}
