import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/confetti.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../profile/me_extras.dart' show MyAvatar;
import 'xp_screens.dart';

/// Streaks (D-082, plan `docs/plans/xp-streaks.md` §3.5–3.6): one question a day keeps it; the daily claim pop-up,
/// the flame, the week, freezes, repair and milestone celebrations. The server counts everything (`my_streak`).

final myStreakProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const {};
  return cached(ref, 'streak:$uid', (s) => s.rpc('my_streak'), (j) => Map<String, dynamic>.from(j as Map));
});

int _i(Object? v) => (v as num?)?.toInt() ?? 0;
const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// The flame: bigger at 7 / 30 / 100 days, a gentle flicker (still under reduce motion). Drawn with an icon and a
/// gradient, no blur, so it stays smooth on small phones.
class StreakFlame extends StatelessWidget {
  const StreakFlame({super.key, required this.days, this.size = 56, this.lit = true});
  final int days;
  final double size;
  final bool lit;
  @override
  Widget build(BuildContext context) {
    final grow = days >= 100 ? 1.25 : (days >= 30 ? 1.15 : (days >= 7 ? 1.07 : 1.0));
    final s = size * grow;
    final flame = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(
        colors: lit ? const [Color(0xFFFFE08A), Palette.gold500, Color(0xFFE8590C)] : [context.c.textSubtle, context.c.textSubtle],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(r),
      child: Icon(PhosphorIcons.fire(PhosphorIconsStyle.fill), size: s),
    );
    final glow = Container(
      width: s * 1.5,
      height: s * 1.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Palette.gold500.withValues(alpha: lit ? .35 : 0),
            Palette.gold500.withValues(alpha: 0),
          ],
        ),
      ),
    );
    if (context.reduceMotion || !lit) return Stack(alignment: Alignment.center, children: [glow, flame]);
    return Stack(
      alignment: Alignment.center,
      children: [
        glow
            .animate(onPlay: (a) => a.repeat(reverse: true))
            .scale(begin: const Offset(.9, .9), end: const Offset(1.08, 1.08), duration: 1200.ms, curve: Curves.easeInOut),
        flame
            .animate(onPlay: (a) => a.repeat(reverse: true))
            .scaleY(begin: .96, end: 1.04, duration: 700.ms, curve: Curves.easeInOut, alignment: Alignment.bottomCenter)
            .rotate(begin: -.01, end: .01, duration: 900.ms, curve: Curves.easeInOut, alignment: Alignment.bottomCenter),
      ],
    );
  }
}

/// This week, Monday to Sunday: practised days glow gold with a flame, a freeze shows a snowflake, today pulses.
class StreakWeek extends StatelessWidget {
  const StreakWeek({super.key, required this.week, this.onDark = false});
  final List<Map<String, dynamic>> week;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var k = 0; k < 7; k++)
          Builder(
            builder: (context) {
              final d = k < week.length ? week[k] : const <String, dynamic>{};
              final done = d['done'] == true, saved = d['saved'] != null, today = d['today'] == true;
              Widget dot = Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: done ? const LinearGradient(colors: [Color(0xFFFFD66B), Palette.gold500]) : null,
                  color: done
                      ? null
                      : (saved ? const Color(0xFF2563B3).withValues(alpha: .2) : (onDark ? Colors.white.withValues(alpha: .08) : c.surfaceSunken)),
                  border: today && !done ? Border.all(color: Palette.gold500, width: 2) : null,
                ),
                child: done
                    ? Icon(PhosphorIcons.fire(PhosphorIconsStyle.fill), size: 18, color: Palette.navy900)
                    : saved
                    ? Icon(PhosphorIcons.snowflake(PhosphorIconsStyle.fill), size: 16, color: const Color(0xFF7FB2FF))
                    : null,
              );
              if (!rm) {
                dot = dot
                    .animate(delay: (60 * k).ms)
                    .fadeIn(duration: 250.ms)
                    .scale(begin: const Offset(.6, .6), end: const Offset(1, 1), curve: Curves.easeOutBack);
                if (today && !done) {
                  dot = dot.animate(onPlay: (a) => a.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 800.ms);
                }
              }
              return Column(
                children: [
                  dot,
                  const SizedBox(height: 6),
                  Text(
                    _days[k],
                    style: context.ty.cap.bold
                        .copyWith(fontSize: 11)
                        .col(today ? (onDark ? Colors.white : c.text) : (onDark ? const Color(0xFF8FA0BE) : c.textSubtle)),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// The student's photo in a gold ring (full when today is done), with the flame badge and streak number.
class StreakPhoto extends StatelessWidget {
  const StreakPhoto({super.key, required this.name, required this.days, required this.todayDone, this.size = 112});
  final String name;
  final int days;
  final bool todayDone;
  final double size;
  @override
  Widget build(BuildContext context) {
    final ring = size + 14;
    return SizedBox(
      width: ring + 16,
      height: ring + 10,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: todayDone ? 1 : .12),
            duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => CustomPaint(size: Size(ring, ring), painter: _Ring(v, context.c.surfaceSunken)),
          ),
          MyAvatar(name, size: size),
          Positioned(
            right: 0,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
              decoration: BoxDecoration(
                color: Palette.navy900,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Palette.gold500, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreakFlame(days: days, size: 20, lit: days > 0),
                  Text('$days', style: context.ty.sm.bold.tnum.col(Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends CustomPainter {
  _Ring(this.v, this.track);
  final double v;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = track,
    );
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * v,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(colors: [Palette.gold500, Color(0xFFFFE08A), Palette.gold500]).createShader(r),
    );
  }

  @override
  bool shouldRepaint(_Ring o) => o.v != v || o.track != track;
}

/// A short burst of XP coins (skipped under reduce motion).
class CoinBurst extends StatelessWidget {
  const CoinBurst({super.key, this.count = 12});
  final int count;
  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return const SizedBox.shrink();
    final rnd = math.Random(7);
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var k = 0; k < count; k++)
            Builder(
              builder: (_) {
                final a = (k / count) * math.pi * 2 + rnd.nextDouble() * .4;
                final dist = 70 + rnd.nextDouble() * 60;
                return const XpCoin(size: 22)
                    .animate()
                    .move(begin: Offset.zero, end: Offset(math.cos(a) * dist, math.sin(a) * dist - 40), duration: 700.ms, curve: Curves.easeOutCubic)
                    .then()
                    .move(end: Offset(0, -120), duration: 400.ms, curve: Curves.easeIn)
                    .fadeOut(duration: 400.ms);
              },
            ),
        ],
      ),
    );
  }
}

/// The daily claim pop-up (first app open each day): photo, flame, week, today's XP, the next milestone, Claim.
Future<void> showDailyClaim(BuildContext context, WidgetRef ref, Map<String, dynamic> st) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => DailyClaimSheet(st: st),
);

class DailyClaimSheet extends ConsumerStatefulWidget {
  const DailyClaimSheet({super.key, required this.st});
  final Map<String, dynamic> st;
  @override
  ConsumerState<DailyClaimSheet> createState() => _DailyClaimSheetState();
}

class _DailyClaimSheetState extends ConsumerState<DailyClaimSheet> {
  bool _busy = false;
  int? _got;

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      final g = await claimDailyXp(ref);
      HapticFeedback.mediumImpact();
      ref.invalidate(myStreakProvider);
      if (!mounted) return;
      setState(() => _got = g);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) toast(context, 'Could not claim. Check your internet and try again.', icon: PhosphorIcons.wifiSlash());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    final days = _i(st['current']), todayDone = st['today_done'] == true;
    final xp = st['xp'] is Map ? Map<String, dynamic>.from(st['xp'] as Map) : const <String, dynamic>{};
    final next = st['next'] is Map ? Map<String, dynamic>.from(st['next'] as Map) : null;
    final name = '${st['name'] ?? ''}';
    final first = name.split(' ').first;
    return Container(
      padding: EdgeInsets.fromLTRB(Space.s5, Space.s3, Space.s5, Space.s5 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0B1F44), Color(0xFF07122B)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const Gap(Space.s4),
              StreakPhoto(
                name: name,
                days: days,
                todayDone: todayDone,
                size: 88,
              ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(.85, .85), curve: Curves.easeOutBack),
              const Gap(Space.s3),
              Text(first.isEmpty ? 'Welcome back!' : 'Welcome back, $first!', style: context.ty.h2.col(Colors.white), textAlign: TextAlign.center),
              const Gap(Space.s1),
              Text(
                days > 0
                    ? (todayDone ? '$days-day streak. You practised today!' : '$days-day streak. Answer one question today to make it ${days + 1}.')
                    : 'Answer one question today to start your streak.',
                style: context.ty.sm.col(const Color(0xFFB8C4DA)),
                textAlign: TextAlign.center,
              ),
              const Gap(Space.s4),
              StreakWeek(week: rows(st['week']), onDark: true),
              const Gap(Space.s4),
              if (next != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(Radii.md)),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.target(PhosphorIconsStyle.fill), size: 18, color: Palette.gold500),
                      const Gap(Space.s2),
                      Expanded(
                        child: Text(
                          '${_i(next['left'])} ${_i(next['left']) == 1 ? 'day' : 'days'} to your ${next['days']}-day bonus: +${next['xp']} XP',
                          style: context.ty.cap.col(Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              const Gap(Space.s4),
              if (_got == null)
                Btn(
                  'Claim +${_i(xp['daily_claim'])} XP',
                  kind: BtnKind.accent,
                  block: true,
                  loading: _busy,
                  leading: PhosphorIcons.coins(PhosphorIconsStyle.fill),
                  onPressed: _busy ? null : _claim,
                ).animate(onPlay: (a) => context.reduceMotion ? null : a.repeat()).shimmer(delay: 1200.ms, duration: 1300.ms, color: Colors.white54)
              else
                Text(
                  _got! > 0 ? '+$_got XP' : 'Already claimed today',
                  style: context.ty.display.tnum.col(Palette.gold500),
                ).animate().scale(begin: const Offset(.5, .5), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 700.ms),
              const Gap(Space.s2),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text('Later', style: context.ty.sm.col(const Color(0xFFB8C4DA))),
              ),
            ],
          ),
          if (_got != null && _got! > 0) const Positioned.fill(child: CoinBurst()),
        ],
      ),
    );
  }
}

/// A milestone celebration (3, 7, 14, 30, 60, 100 days): confetti, the flame, the bonus. Shown once.
Future<void> showMilestone(BuildContext context, WidgetRef ref, Map<String, dynamic> cel) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xE607122B),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, _, _) => _Milestone(cel: cel),
  );
  try {
    await ref.read(supabaseProvider).rpc('streak_seen', params: {'p_key': cel['key']});
  } catch (_) {}
  ref.invalidate(myStreakProvider);
}

class _Milestone extends StatelessWidget {
  const _Milestone({required this.cel});
  final Map<String, dynamic> cel;
  @override
  Widget build(BuildContext context) {
    final days = _i(cel['days']);
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          if (!context.reduceMotion) const Positioned.fill(child: Confetti(pieces: 90)),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.s6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreakFlame(
                    days: days,
                    size: 110,
                  ).animate().scale(begin: const Offset(.3, .3), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 900.ms),
                  const Gap(Space.s4),
                  Text(
                    '$days-day streak!',
                    style: context.ty.display.col(Colors.white),
                    textAlign: TextAlign.center,
                  ).animate(delay: 250.ms).fadeIn().slideY(begin: .3),
                  const Gap(Space.s2),
                  Text(
                    days >= 30 ? 'You are unstoppable. Keep it burning!' : 'Amazing. Practising every day is how you win your exam.',
                    style: context.ty.body.col(const Color(0xFFB8C4DA)),
                    textAlign: TextAlign.center,
                  ).animate(delay: 400.ms).fadeIn(),
                  const Gap(Space.s4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const XpCoin(size: 32),
                      const Gap(Space.s2),
                      Text('+${cel['xp']} XP', style: context.ty.h1.tnum.col(Palette.gold500)),
                    ],
                  ).animate(delay: 550.ms).fadeIn().scale(begin: const Offset(.6, .6), curve: Curves.easeOutBack),
                  const Gap(Space.s6),
                  Btn('Keep going', kind: BtnKind.accent, block: true, onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Me → Streak: the flame, this week, milestones, freezes and repair.
class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key});
  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> {
  bool _busy = false;

  Future<void> _call(String fn, String done) async {
    setState(() => _busy = true);
    try {
      await ref.read(supabaseProvider).rpc(fn);
      ref.invalidate(myStreakProvider);
      ref.invalidate(myXpProvider);
      HapticFeedback.lightImpact();
      if (mounted) toast(context, done, icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
    } on PostgrestException catch (e) {
      if (mounted) toast(context, e.message, icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
    } catch (_) {
      if (mounted) toast(context, 'Check your internet and try again.', icon: PhosphorIcons.wifiSlash());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(myStreakProvider);
    return Scaffold(
      appBar: const TopBar(title: 'My streak'),
      body: asyncView(
        v,
        (st) {
          final c = context.c;
          final days = _i(st['current']), longest = _i(st['longest']);
          final xpOn = (st['xp'] is Map) && (st['xp'] as Map)['enabled'] == true;
          final repair = st['repair'] is Map ? Map<String, dynamic>.from(st['repair'] as Map) : null;
          final freezes = _i(st['freezes']), fmax = _i(st['freeze_max']), fprice = _i(st['freeze_price']);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myStreakProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
              children: [
                Container(
                  padding: const EdgeInsets.all(Space.s5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Palette.navy900, Color(0xFF13306A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  child: Column(
                    children: [
                      StreakFlame(days: days, size: 72, lit: days > 0),
                      Text('$days', style: context.ty.display.tnum.col(Colors.white)),
                      Text(days == 1 ? 'day in a row' : 'days in a row', style: context.ty.sm.col(const Color(0xFFB8C4DA))),
                      const Gap(Space.s1),
                      Text('Longest: $longest days', style: context.ty.cap.col(Palette.gold500)),
                      const Gap(Space.s4),
                      StreakWeek(week: rows(st['week']), onDark: true),
                      const Gap(Space.s3),
                      Text(
                        st['today_done'] == true
                            ? 'Done for today. Come back tomorrow!'
                            : 'Answer one question today: a test, practice or the question of the day.',
                        style: context.ty.cap.col(Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (repair != null && xpOn) ...[
                  const Gap(Space.s3),
                  AppCard(
                    child: Row(
                      children: [
                        IconTile(PhosphorIcons.wrench(PhosphorIconsStyle.fill), tone: Tone.gold, size: 40, radius: 12),
                        const Gap(Space.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Repair your ${repair['lost']}-day streak', style: context.ty.sm.bold),
                              Text('You missed yesterday. Bring it back today only.', style: context.ty.cap.col(c.textMuted)),
                            ],
                          ),
                        ),
                        Btn(
                          '${repair['price']} XP',
                          kind: BtnKind.accent,
                          sm: true,
                          loading: _busy,
                          onPressed: _busy ? null : () => _call('streak_repair', 'Streak repaired. Keep it going today!'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (xpOn) ...[
                  const Gap(Space.s3),
                  AppCard(
                    child: Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var k = 0; k < fmax; k++)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  PhosphorIcons.snowflake(PhosphorIconsStyle.fill),
                                  size: 26,
                                  color: k < freezes ? const Color(0xFF2563B3) : c.surfaceSunken,
                                ),
                              ),
                          ],
                        ),
                        const Gap(Space.s2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Streak freezes: $freezes of $fmax', style: context.ty.sm.bold),
                              Text('Missed a day? A freeze saves your streak by itself.', style: context.ty.cap.col(c.textMuted)),
                            ],
                          ),
                        ),
                        if (freezes < fmax)
                          Btn(
                            '$fprice XP',
                            kind: BtnKind.tonal,
                            sm: true,
                            loading: _busy,
                            onPressed: _busy ? null : () => _call('streak_buy_freeze', 'Freeze ready. Your streak is safe for one missed day.'),
                          ),
                      ],
                    ),
                  ),
                ],
                const Gap(Space.s3),
                const SectTitle('Streak bonuses'),
                ListCard(
                  children: [
                    for (final m in rows(st['milestones']))
                      Padding(
                        padding: const EdgeInsets.all(Space.s3),
                        child: Row(
                          children: [
                            StreakFlame(days: _i(m['days']), size: 24, lit: m['reached'] == true),
                            const Gap(Space.s3),
                            Expanded(child: Text('${m['days']}-day streak', style: context.ty.sm.bold)),
                            if (xpOn) Text('+${m['xp']} XP', style: context.ty.sm.bold.tnum.col(m['reached'] == true ? c.success : c.textMuted)),
                            if (m['reached'] == true) ...[
                              const Gap(Space.s2),
                              Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 18, color: c.success),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: ListView(
          padding: const EdgeInsets.all(Space.s5),
          children: const [
            Skeleton(height: 280, radius: Radii.lg),
            Gap(Space.s3),
            Skeleton(height: 90, radius: Radii.lg),
          ],
        ),
        onRetry: () => ref.invalidate(myStreakProvider),
      ),
    );
  }
}
