import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/ai_repo.dart';
import '../../data/db.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/confetti.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/phosphor.g.dart';
import '../cbt/exam_clock.dart';
import 'home_screen.dart';

/// Today's line from the admin's list (Admin → Motivation), cached for offline.
final motivationProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => cached(ref, 'motivation', (s) => s.rpc('today_motivation'), (j) => j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{}),
);

/// The first card on Home: the unfinished test when there is one, else today's motivation and goal.
class HomeTopCard extends ConsumerWidget {
  const HomeTopCard({super.key, required this.unfinished, required this.stats});
  final LocalAttempt? unfinished;
  final PracticeStats stats;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = unfinished;
    return AnimatedSwitcher(
      duration: context.reduceMotion ? Duration.zero : Motion.slow,
      child: a != null ? ResumeHero(key: ValueKey(a.id), a: a) : TodayCard(key: const ValueKey('today'), stats: stats),
    );
  }
}

/// "Continue where you stopped": navy card with the exam logo, how far you got, time left and a big Continue button.
class ResumeHero extends ConsumerWidget {
  const ResumeHero({super.key, required this.a});
  final LocalAttempt a;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rm = context.reduceMotion;
    final cfg = jsonDecode(a.configJson) as Map<String, dynamic>;
    final total = (jsonDecode(a.questionIdsJson) as List).length;
    final done = ref.watch(unfinishedAnsweredProvider(a.id)).value ?? 0;
    final left = a.limitSeconds == 0 ? null : Duration(seconds: a.limitSeconds) - Duration(milliseconds: a.usedMs);
    final title = (cfg['title'] as String?)?.isNotEmpty == true ? cfg['title'] as String : a.examCode;
    final frac = total == 0 ? 0.0 : done / total;
    const ink = Color(0xFFF4F7FC), soft = Color(0xFFAFC0DD);
    return Semantics(
      button: true,
      label: 'Continue your test: $title, $done of $total answered',
      child: GestureDetector(
        onTap: () => context.push('/cbt/${a.id}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.navy900, Color(0xFF16336B)]),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -50,
                  top: -60,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [Color.fromRGBO(37, 99, 179, .55), Color.fromRGBO(37, 99, 179, 0)]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Space.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Palette.gold400.withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _Dot(still: rm),
                                const SizedBox(width: 6),
                                Text('CONTINUE WHERE YOU STOPPED', style: context.ty.over.col(Palette.gold400)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Gap(Space.s3),
                      Row(
                        children: [
                          ExamLogo(a.examCode, px: 44),
                          const Gap(Space.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: context.ty.h3.col(ink), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(
                                  '$done of $total answered${left == null ? '' : ' · ${ExamClock.format(left.isNegative ? Duration.zero : left)} left'}',
                                  style: context.ty.sm.col(soft),
                                ),
                              ],
                            ),
                          ),
                          Ring(
                            value: frac,
                            size: 52,
                            color: Palette.gold400,
                            track: const Color(0x33FFFFFF),
                            label: Text('${(frac * 100).round()}%', style: context.ty.cap.bold.tnum.col(ink)),
                          ),
                        ],
                      ),
                      const Gap(Space.s4),
                      Btn('Continue test', kind: BtnKind.accent, block: true, icon: PhosphorIcons.arrowRight(), onPressed: () => context.push('/cbt/${a.id}')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.still = false});
  final bool still;
  @override
  Widget build(BuildContext context) {
    final d = Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(color: Palette.gold400, shape: BoxShape.circle),
    );
    return still ? d : d.animate(onPlay: (a) => a.repeat(reverse: true)).scaleXY(begin: .7, end: 1.15, duration: 700.ms).fade(begin: .6, end: 1);
  }
}

/// "Today": the day's motivation or study tip, plus the daily goal ring and a Practise button.
class TodayCard extends ConsumerWidget {
  const TodayCard({super.key, required this.stats});
  final PracticeStats stats;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final rm = context.reduceMotion;
    final m = ref.watch(motivationProvider).value ?? const {};
    final body = (m['body'] as String?) ?? 'Small steps every day beat one big push the night before the exam.';
    final author = m['author'] as String?;
    final tip = m['kind'] == 'tip';
    final h = DateTime.now().hour;
    final icon = h < 12
        ? PhosphorIcons.sunHorizon(PhosphorIconsStyle.fill)
        : h < 17
        ? PhosphorIcons.sun(PhosphorIconsStyle.fill)
        : PhosphorIcons.moonStars(PhosphorIconsStyle.fill);
    final goal = PracticeStats.dailyGoal;
    final left = (goal - stats.today).clamp(0, goal);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.surface, c.accentSoft.withValues(alpha: .55)]),
      ),
      padding: const EdgeInsets.all(Space.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Palette.gold500),
              const Gap(Space.s2),
              Expanded(child: Text(tip ? 'TODAY\'S STUDY TIP' : 'TODAY\'S MOTIVATION', style: context.ty.over.col(c.textMuted))),
              Icon(tip ? PhosphorIcons.lightbulb(PhosphorIconsStyle.fill) : PhosphorIcons.quotes(PhosphorIconsStyle.fill), size: 22, color: c.accent),
            ],
          ),
          const Gap(Space.s2),
          Text(body, style: context.ty.h3.copyWith(height: 1.3))
              .animate(key: ValueKey(body))
              .fadeIn(duration: rm ? 1.ms : 450.ms)
              .slideY(begin: rm ? 0 : .15, end: 0, duration: rm ? 1.ms : 450.ms, curve: Curves.easeOutCubic),
          if (author != null && author.isNotEmpty) ...[const Gap(Space.s1), Text('— $author', style: context.ty.sm.col(c.textMuted))],
          const TodayPlan(),
          const Gap(Space.s4),
          Container(
            padding: const EdgeInsets.fromLTRB(Space.s3, Space.s2, Space.s2, Space.s2),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                GoalRing(done: stats.today, goal: goal, size: 48),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${stats.today} of $goal questions today', style: context.ty.sm.bold),
                      Text(left == 0 ? 'Goal reached. Great work!' : '$left more to reach today\'s goal', style: context.ty.cap.col(c.textMuted)),
                    ],
                  ),
                ),
                Btn('Practise', kind: BtnKind.tonal, sm: true, onPressed: () => context.push('/test/setup?exam=JAMB&mode=quick')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The daily goal ring: today's count inside while going, and when the goal is reached a gold badge pops in,
/// a check mark draws itself and three sparkles twinkle around it (still with reduce motion).
class GoalRing extends StatefulWidget {
  const GoalRing({super.key, required this.done, required this.goal, this.size = 48});
  final int done, goal;
  final double size;
  @override
  State<GoalRing> createState() => _GoalRingState();
}

class _GoalRingState extends State<GoalRing> with TickerProviderStateMixin {
  late final AnimationController _win = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  bool get _reached => widget.done >= widget.goal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync(first: true));
  }

  @override
  void didUpdateWidget(GoalRing old) {
    super.didUpdateWidget(old);
    if (old.done != widget.done || old.goal != widget.goal) _sync();
  }

  void _sync({bool first = false}) {
    if (!mounted) return;
    final rm = context.reduceMotion;
    if (_reached) {
      if (rm) {
        _win.value = 1;
      } else if (_win.value < 1) {
        _win.forward(from: first ? 0 : _win.value).then((_) {
          if (mounted && !context.reduceMotion) _loop.repeat();
        });
      }
    } else {
      _loop.stop();
      _win.value = 0;
    }
  }

  @override
  void dispose() {
    _win.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = widget.size;
    final frac = widget.goal == 0 ? 0.0 : widget.done / widget.goal;
    return Semantics(
      label: _reached ? 'Daily goal reached' : '${widget.done} of ${widget.goal} questions today',
      excludeSemantics: true,
      child: SizedBox(
        width: s,
        height: s,
        child: AnimatedBuilder(
          animation: Listenable.merge([_win, _loop]),
          builder: (context, _) {
            final w = _win.value;
            final pop = Curves.elasticOut.transform((w / .7).clamp(0.0, 1.0));
            final tick = Curves.easeOutCubic.transform(((w - .35) / .65).clamp(0.0, 1.0));
            final glow = _reached ? (.5 + .5 * math.sin(_loop.value * 2 * math.pi)) : 0.0;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Ring(value: frac, size: s, color: _reached ? Palette.gold400 : c.accent),
                if (!_reached)
                  Text('${widget.done}', style: context.ty.sm.bold.tnum.copyWith(fontSize: s * .3, height: 1))
                else ...[
                  // Gold badge with a soft breathing glow.
                  Transform.scale(
                    scale: .2 + .8 * pop,
                    child: Container(
                      width: s * .62,
                      height: s * .62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE08A), Palette.gold500]),
                        boxShadow: [
                          BoxShadow(
                            color: Palette.gold400.withValues(alpha: .25 + .3 * glow),
                            blurRadius: 6 + 8 * glow,
                            spreadRadius: .5 + 1.5 * glow,
                          ),
                        ],
                      ),
                      child: CustomPaint(painter: _TickPainter(tick, Palette.navy900)),
                    ),
                  ),
                  // Three sparkles that twinkle one after another.
                  for (final (i, (dx, dy, k)) in const [(.46, -.40, 1.0), (-.48, -.30, .8), (.40, .44, .7)].indexed)
                    Positioned(
                      left: s / 2 + dx * s - (s * .1).clamp(5.0, 9.0),
                      top: s / 2 + dy * s - (s * .1).clamp(5.0, 9.0),
                      child: Opacity(
                        opacity: (w < 1 ? tick : (.25 + .75 * (.5 + .5 * math.sin((_loop.value + i / 3) * 2 * math.pi)))).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: k * (w < 1 ? tick : (.7 + .3 * (.5 + .5 * math.sin((_loop.value + i / 3) * 2 * math.pi)))),
                          child: Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), size: (s * .2).clamp(10.0, 18.0), color: Palette.gold400),
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A check mark drawn from left to right as [t] goes 0 → 1.
class _TickPainter extends CustomPainter {
  _TickPainter(this.t, this.color);
  final double t;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final w = size.width;
    final path = Path()
      ..moveTo(w * .28, w * .52)
      ..lineTo(w * .44, w * .67)
      ..lineTo(w * .73, w * .36);
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * t),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.t != t || old.color != color;
}

/// Today's part of the student's study plan, under the motivation: "Day 2 of 7 · Maths · Angles", up to three tasks,
/// a progress bar of days, Start (opens the AI tutor with the day's action) and Done (ticks the day with a small
/// celebration). Hidden when there is no active plan. Reloads when the app comes back.
class TodayPlan extends ConsumerStatefulWidget {
  const TodayPlan({super.key});
  @override
  ConsumerState<TodayPlan> createState() => _TodayPlanState();
}

class _TodayPlanState extends ConsumerState<TodayPlan> with WidgetsBindingObserver {
  bool _justDone = false, _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(todayPlanProvider);
  }

  void _start(Map<String, dynamic> item) {
    final a = item['action'];
    if (a is Map && a['tool'] != null) {
      final q = <String, String>{'tool': '${a['tool']}', 'label': '${a['label'] ?? item['focus'] ?? 'Start'}'};
      if (a['args'] is Map && (a['args'] as Map).isNotEmpty) q['args'] = jsonEncode(a['args']);
      context.go(Uri(path: '/ai', queryParameters: q).toString());
    } else {
      context.go('/ai');
    }
  }

  Future<void> _done(Map<String, dynamic> plan) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(aiRepoProvider).planUpdate('${plan['plan_id']}', doneDay: (plan['day'] as num).toInt());
      if (!mounted) return;
      setState(() => _justDone = true);
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Check your internet.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(todayPlanProvider).value;
    if (plan == null || plan['item'] is! Map) return const SizedBox.shrink();
    final c = context.c;
    final rm = context.reduceMotion;
    final item = Map<String, dynamic>.from(plan['item'] as Map);
    final day = (plan['day'] as num?)?.toInt() ?? 1, of = (plan['of'] as num?)?.toInt() ?? 7;
    final done = plan['done'] == true || _justDone;
    final tasks = [for (final t in (item['tasks'] as List? ?? const [])) '$t'].take(3).toList();
    final focus = '${item['focus'] ?? ''}'.trim();
    final min = (item['minutes'] as num?)?.toInt() ?? 0;
    final card = Container(
      margin: const EdgeInsets.only(top: Space.s4),
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.calendarCheck(PhosphorIconsStyle.fill), size: 18, color: c.secondary),
              const Gap(Space.s2),
              Expanded(child: Text('Day $day of $of${focus.isEmpty ? '' : ' · $focus'}', style: context.ty.sm.bold)),
              if (min > 0) Text('$min min', style: context.ty.cap.col(c.textMuted)),
            ],
          ),
          const Gap(Space.s2),
          for (final t in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      done ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.circle(),
                      size: 16,
                      color: done ? c.success : c.textSubtle,
                    ),
                  ),
                  const Gap(Space.s2),
                  Expanded(child: Text(t, style: context.ty.sm.col(done ? c.textMuted : c.text))),
                ],
              ),
            ),
          const Gap(Space.s2),
          ProgressBar((done ? day : day - 1) / of, color: c.success),
          const Gap(Space.s3),
          AnimatedSwitcher(
            duration: rm ? Duration.zero : Motion.base,
            child: done
                ? Row(
                    key: const ValueKey('done'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      (rm
                          ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 24, color: c.success)
                          : Icon(
                              PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                              size: 24,
                              color: c.success,
                            ).animate().scaleXY(begin: .2, end: 1, duration: Motion.slow, curve: Curves.easeOutBack)),
                      const Gap(Space.s2),
                      Text('Day $day done. Well done!', style: context.ty.sm.bold.col(c.success)),
                    ],
                  )
                : Row(
                    key: const ValueKey('todo'),
                    children: [
                      Expanded(
                        child: Btn('Start', sm: true, block: true, icon: PhosphorIcons.arrowRight(), onPressed: () => _start(item)),
                      ),
                      const Gap(Space.s2),
                      Expanded(
                        child: Btn('Done ✓', sm: true, block: true, kind: BtnKind.tonal, loading: _busy, onPressed: () => _done(plan)),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
    if (!_justDone || rm) return card;
    return Stack(
      children: [
        card,
        Positioned.fill(
          child: IgnorePointer(child: ClipRect(child: Confetti(pieces: 40))),
        ),
      ],
    );
  }
}
