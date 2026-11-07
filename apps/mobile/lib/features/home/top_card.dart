import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// "Continue where you stopped": navy card with the exam logo, a live progress ring, three small stats and a big
/// Continue button. A light sweep crosses the card every 4 s and gold sparks float in the corner (still with reduce motion).
class ResumeHero extends ConsumerWidget {
  const ResumeHero({super.key, required this.a});
  final LocalAttempt a;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = jsonDecode(a.configJson) as Map<String, dynamic>;
    final total = (jsonDecode(a.questionIdsJson) as List).length;
    final done = ref.watch(unfinishedAnsweredProvider(a.id)).value ?? 0;
    // The clock only runs inside the test, so the time left is fixed while the student is on Home.
    final left = a.limitSeconds == 0 ? null : Duration(seconds: a.limitSeconds) - Duration(milliseconds: a.usedMs);
    final title = (cfg['title'] as String?)?.isNotEmpty == true ? cfg['title'] as String : a.examCode;
    // A challenge mock runs on the server's clock: it never pauses, so the card counts down live.
    final deadline = cfg['mock'] != null ? DateTime.tryParse('${cfg['deadline']}') : null;
    if (deadline != null) {
      final skew = Duration(milliseconds: (cfg['skew_ms'] as num?)?.toInt() ?? 0);
      return StreamBuilder<int>(
        stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
        builder: (context, _) {
          final l = deadline.difference(DateTime.now().toUtc().add(skew));
          return _ResumeCard(
            examCode: a.examCode,
            title: title,
            timed: true,
            startedAt: a.startedAt,
            done: done,
            total: total,
            left: l.isNegative ? Duration.zero : l,
            live: true,
            onContinue: () => context.push('/cbt/${a.id}'),
          );
        },
      );
    }
    return _ResumeCard(
      examCode: a.examCode,
      title: title,
      timed: cfg['timed'] != false && a.limitSeconds > 0,
      startedAt: a.startedAt,
      done: done,
      total: total,
      left: left == null ? null : (left.isNegative ? Duration.zero : left),
      onContinue: () => context.push('/cbt/${a.id}'),
    );
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

class _ResumeCard extends StatefulWidget {
  const _ResumeCard({
    required this.examCode,
    required this.title,
    required this.timed,
    required this.startedAt,
    required this.done,
    required this.total,
    required this.left,
    required this.onContinue,
    this.live = false,
  });
  final String examCode, title;
  final bool timed, live;
  final DateTime startedAt;
  final int done, total;
  final Duration? left;
  final VoidCallback onContinue;
  @override
  State<_ResumeCard> createState() => _ResumeCardState();
}

class _ResumeCardState extends State<_ResumeCard> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  void _go() {
    HapticFeedback.lightImpact();
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const ink = Color(0xFFF4F7FC), soft = Color(0xFFAFC0DD);
    final total = widget.total, done = widget.done;
    final frac = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final toGo = (total - done).clamp(0, total);

    // Children enter one after another (60 ms apart); nothing moves with reduce motion.
    Widget st(Widget w, int i) => rm
        ? w
        : w
              .animate(delay: 60.ms * (i + 1))
              .fadeIn(duration: Motion.base)
              .move(begin: const Offset(0, 8), end: Offset.zero, duration: Motion.slow, curve: Motion.out);

    Widget stat(IconData icon, String text) => Row(
      children: [
        Icon(icon, size: 16, color: Palette.gold400),
        const Gap(Space.s2),
        Expanded(
          child: Text(text, style: context.ty.sm.bold.tnum.col(ink), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    final logo = ExamLogo(widget.examCode, px: 48);
    final card = Semantics(
      container: true,
      label: 'Continue your test: ${widget.title}, $done of $total answered',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: dark ? Border.all(color: const Color(0x1AFFFFFF)) : null,
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.navy900, Color(0xFF16336B)]),
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
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: RepaintBoundary(
                      child: CustomPaint(painter: _SparkPainter(_loop, still: rm)),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    st(
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Palette.gold400.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Dot(still: rm),
                              const Gap(Space.s2),
                              Flexible(
                                child: Text(
                                  widget.live
                                      ? (widget.left == Duration.zero ? 'Time is up · tap to see your result' : 'Live mock · the clock is running')
                                      : 'Paused · started ${_ago(widget.startedAt)}',
                                  style: context.ty.cap.bold.col(Palette.gold300),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      0,
                    ),
                    const Gap(Space.s3),
                    st(
                      Row(
                        children: [
                          rm ? logo : logo.animate(onPlay: (a) => a.repeat(reverse: true)).moveY(begin: 0, end: -3, duration: 1500.ms, curve: Curves.easeInOut),
                          const Gap(Space.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.title, style: context.ty.h3.col(ink), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(
                                  '$total questions · ${widget.timed ? 'Timed' : 'No time limit'}',
                                  style: context.ty.sm.col(soft),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      1,
                    ),
                    const Gap(Space.s4),
                    st(
                      Row(
                        children: [
                          _ResumeRing(frac: frac, size: 72, still: rm, label: '$done/$total', ink: ink),
                          const Gap(Space.s4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                stat(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), '$done answered'),
                                const Gap(Space.s2),
                                stat(
                                  PhosphorIcons.hourglassMedium(PhosphorIconsStyle.fill),
                                  widget.left == null ? 'No time limit' : '${ExamClock.format(widget.left!)} left',
                                ),
                                const Gap(Space.s2),
                                stat(PhosphorIcons.flagCheckered(PhosphorIconsStyle.fill), '$toGo to go'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      2,
                    ),
                    const Gap(Space.s4),
                    st(
                      Semantics(
                        button: true,
                        label: 'Continue test',
                        excludeSemantics: true,
                        child: Pressable(
                          onTap: _go,
                          scale: Motion.pressScale,
                          borderRadius: BorderRadius.circular(Radii.md),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: Sizes.tapMin),
                            padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
                            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(Radii.md), boxShadow: context.shadow(1)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text('Continue test', style: context.ty.label.bold.col(c.onAccent), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                const Gap(Space.s2),
                                () {
                                  final arrow = Icon(PhosphorIcons.arrowRight(PhosphorIconsStyle.bold), size: 20, color: c.onAccent);
                                  return rm
                                      ? arrow
                                      : arrow
                                            .animate(onPlay: (a) => a.repeat(reverse: true))
                                            .moveX(begin: 0, end: 5, duration: 800.ms, curve: Curves.easeInOut);
                                }(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      3,
                    ),
                  ],
                ),
              ),
              // The light sweep goes over everything and never takes a tap.
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: RepaintBoundary(
                      child: CustomPaint(painter: _SweepPainter(_loop, still: rm)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return rm
        ? card
        : card.animate().fadeIn(duration: Motion.slow).move(begin: const Offset(0, 16), end: Offset.zero, duration: Motion.slow, curve: Motion.out);
  }
}

/// Progress ring that fills from 0 to [frac] on first show (900 ms), gold-to-amber stroke and a glowing head dot.
class _ResumeRing extends StatelessWidget {
  const _ResumeRing({required this.frac, required this.size, required this.still, required this.label, required this.ink});
  final double frac, size;
  final bool still;
  final String label;
  final Color ink;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: frac),
        duration: still ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOut,
        builder: (context, v, child) => CustomPaint(painter: _RingPainter(v), child: child),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: context.ty.sm.bold.tnum.col(ink)),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v);
  final double v;
  static const _stroke = 7.0;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = (size.shortestSide - _stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = const Color(0x26FFFFFF),
    );
    if (v <= 0) return;
    final sweep = 2 * math.pi * v;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.max(sweep, .01),
          colors: const [Palette.gold300, Palette.gold400, Color(0xFFFF9F1C)],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
    final a = -math.pi / 2 + sweep;
    final head = center + Offset(math.cos(a), math.sin(a)) * r;
    canvas.drawCircle(
      head,
      7,
      Paint()
        ..color = const Color(0x55F2B233)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(head, 3, Paint()..color = const Color(0xFFFFF4D6));
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v;
}

/// A soft diagonal band of light that crosses the card in the first third of every 4 s cycle.
class _SweepPainter extends CustomPainter {
  _SweepPainter(this.t, {required this.still}) : super(repaint: t);
  final Animation<double> t;
  final bool still;
  @override
  void paint(Canvas canvas, Size size) {
    if (still) return;
    final p = (t.value / .35).clamp(0.0, 1.0);
    if (p <= 0 || p >= 1) return;
    final e = Curves.easeInOut.transform(p);
    const band = 90.0;
    final x = -band + (size.width + band * 2) * e;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(x, 0);
    canvas.transform(Matrix4.skewX(-.45).storage);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, band, size.height),
      Paint()
        ..shader = const LinearGradient(colors: [Color(0x00FFFFFF), Color(0x1AFFFFFF), Color(0x00FFFFFF)]).createShader(Rect.fromLTWH(0, 0, band, size.height)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.still != still;
}

/// Seven tiny gold sparks that drift up and twinkle in the top-right corner.
class _SparkPainter extends CustomPainter {
  _SparkPainter(this.t, {required this.still}) : super(repaint: t);
  final Animation<double> t;
  final bool still;
  // x (0..1 of a 120 px wide corner), phase, size, speed
  static const _p = [(.15, .0, 1.6, 1), (.35, .3, 1.2, 1), (.55, .6, 2.0, 1), (.75, .15, 1.4, 1), (.9, .8, 1.8, 1), (.25, .5, 1.2, 1), (.65, .95, 1.5, 1)];
  @override
  void paint(Canvas canvas, Size size) {
    const w = 120.0, h = 90.0;
    final paint = Paint();
    for (final (x, ph, r, _) in _p) {
      final f = still ? ph : (t.value + ph) % 1;
      final y = h * (1 - f) + 6;
      final a = still ? .5 : math.sin(f * math.pi);
      paint.color = Palette.gold400.withValues(alpha: .65 * a);
      canvas.drawCircle(Offset(size.width - w + x * (w - 12) + 6, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.still != still;
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
