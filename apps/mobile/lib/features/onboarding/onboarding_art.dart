import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/math_text.dart';
import '../../widgets/phosphor.g.dart';
import 'onboarding_scenes.dart';

/// Onboarding pictures, ported from prototype/js/screens-onboard.js (slides[].art) and the
/// "Onboarding art motion" keyframes in prototype/css/app.css:
/// - layers l1/l2/l3 slide in from +40/+80/+120 px with 0/60/120 ms delays when the slide becomes current;
/// - looping ambient motion (fx-*) runs only on the current slide;
/// - under reduce motion everything shows the finished picture, with no loops.
class SlideArt extends StatelessWidget {
  const SlideArt({super.key, required this.kind, required this.current});
  final String kind;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final run = current && !context.reduceMotion;
    final (Tone disc, List<Widget> layers) = switch (kind) {
      'trophy' => (Tone.gold, _trophy(context, run)),
      'study' => (Tone.blue, _study(context, run)),
      'ai' => (Tone.gold, _ai(context, run)),
      'progress' => (Tone.navy, _progress(context, run)),
      'classes' => (Tone.blue, _classes(context, run)),
      'games' => (Tone.navy, _games(context, run)),
      'community' => (Tone.blue, _community(context, run)),
      'tutor' => (Tone.gold, _tutor(context, run)),
      _ => (Tone.navy, _cbt(context, run)),
    };
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          _Breathe(
            run: run,
            child: ArtDisc(tone: disc, breathe: false),
          ),
          ...layers,
        ],
      ),
    );
  }

  /// A parallax layer: slides in from the right by [n] × 40 px when its slide becomes current.
  Widget _layer(BuildContext context, int n, Widget child) => _Layer(n: n, current: current, child: child);

  // ---- slide 1: a real CBT experience (WAEC, JAMB, NECO floating; ticking exam timer)
  List<Widget> _cbt(BuildContext context, bool run) {
    final c = context.c;
    return [
      Positioned(
        left: 40,
        top: 70,
        child: _layer(
          context,
          1,
          _Float(
            run: run,
            rotate: -8,
            child: const Mini(child: ExamLogo('WAEC', size: LogoSize.lg)),
          ),
        ),
      ),
      _layer(
        context,
        2,
        _Float(
          run: run,
          delay: -1.3,
          child: const Mini(child: ExamLogo('JAMB', size: LogoSize.lg)),
        ),
      ),
      Positioned(
        right: 40,
        top: 70,
        child: _layer(
          context,
          3,
          _Float(
            run: run,
            rotate: 8,
            delay: -2.6,
            child: const Mini(child: ExamLogo('NECO', size: LogoSize.lg)),
          ),
        ),
      ),
      Positioned(
        bottom: 56,
        left: 70,
        child: _layer(
          context,
          2,
          Mini(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(99)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Tick(
                    run: run,
                    child: Icon(PhosphorIcons.timer(PhosphorIconsStyle.fill), size: 16, color: c.onPrimarySoft),
                  ),
                  const SizedBox(width: 6),
                  _Countdown(run: run, style: context.ty.sm.bold.copyWith(fontSize: 14).tnum.col(c.onPrimarySoft)),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  // ---- slide 2: weekly challenge (trophy card, pulsing prize, leaderboard rows rising, live pill)
  List<Widget> _trophy(BuildContext context, bool run) {
    final c = context.c, ty = context.ty;
    const rows = [('1', 'Chiamaka O.', '10/10'), ('2', 'You', '10/10'), ('3', 'Abdullahi M.', '9/10')];
    return [
      Positioned(
        top: 58,
        child: _layer(
          context,
          1,
          _Float(
            run: run,
            rotate: -3,
            child: Mini(
              width: 230,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: Palette.gold400, shape: BoxShape.circle),
                    child: Icon(PhosphorIcons.trophy(PhosphorIconsStyle.fill), size: 30, color: Palette.navy900),
                  ),
                  const SizedBox(height: Space.s2),
                  Text('Weekly Challenge', style: ty.cap.bold.col(c.textMuted)),
                  _Pulse(
                    run: run,
                    child: Text('Win ₦20,000', style: ty.h2.copyWith(fontSize: 22).col(c.onAccentSoft)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 58,
        left: 28,
        child: _layer(
          context,
          2,
          Mini(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              children: [
                for (var k = 0; k < rows.length; k++)
                  _Rise(
                    current: current,
                    delay: Duration(milliseconds: 350 + k * 180),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(width: 14, child: Text(rows[k].$1, style: ty.cap.bold)),
                          const SizedBox(width: Space.s2),
                          Expanded(child: Text(rows[k].$2, style: rows[k].$2 == 'You' ? ty.cap.bold : ty.cap)),
                          Text(rows[k].$3, style: ty.cap.bold.tnum),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        right: 24,
        bottom: 150,
        child: _layer(context, 3, LivePill(run: run, detail: '1,284 playing')),
      ),
    ];
  }

  // ---- slide 3: past questions, videos and notes (play ripple, lesson bar filling, tick popping)
  List<Widget> _study(BuildContext context, bool run) {
    final c = context.c, ty = context.ty;
    return [
      Positioned(
        top: 60,
        child: _layer(
          context,
          1,
          Mini(
            width: 220,
            padding: const EdgeInsets.all(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.md),
                  gradient: const LinearGradient(colors: [Palette.navy800, Palette.blue600], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _Ripple(
                      run: run,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), shape: BoxShape.circle, boxShadow: context.shadow(2)),
                        child: Icon(PhosphorIcons.play(PhosphorIconsStyle.fill), size: 20, color: Palette.navy900),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color.fromRGBO(6, 19, 43, .78), borderRadius: BorderRadius.circular(6)),
                        child: Text('6:12', style: ty.cap.bold.copyWith(fontSize: 11).col(Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 60,
        left: 30,
        child: _layer(
          context,
          2,
          Mini(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quadratic equations', style: ty.sm.bold),
                Text('Lesson note · 8 min read', style: ty.cap.col(c.textMuted)),
                const SizedBox(height: Space.s2),
                _Cycle(
                  run: run,
                  period: const Duration(milliseconds: 3600),
                  rest: 1,
                  builder: (t) => _Bar(value: .64 * Curves.easeOut.transform((t / .55).clamp(0, 1))),
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        right: 28,
        bottom: 120,
        child: _layer(
          context,
          3,
          _Cycle(
            run: run,
            period: const Duration(milliseconds: 3600),
            rest: .8,
            builder: (t) {
              // fx-check: hidden until 55 %, pops to 1.15 at 64 %, settles, fades at the end
              final (o, s) = t < .55
                  ? (0.0, .4)
                  : t < .64
                  ? ((t - .55) / .09, .4 + .75 * (t - .55) / .09)
                  : t < .7
                  ? (1.0, 1.15 - .15 * (t - .64) / .06)
                  : t < .9
                  ? (1.0, 1.0)
                  : (1 - (t - .9) / .1, 1 - .2 * (t - .9) / .1);
              return Opacity(
                opacity: o.clamp(0, 1),
                child: Transform.scale(
                  scale: s,
                  child: Mini(
                    padding: const EdgeInsets.all(10),
                    child: Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 28, color: c.success),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ];
  }

  // ---- slide 4: AI tutor (question → typing dots → answer → "Step by step" chip, looping every 7 s)
  List<Widget> _ai(BuildContext context, bool run) {
    final c = context.c, ty = context.ty;
    double fade(double t, double a, double b, double c2, double d) =>
        t < a ? 0 : (t < b ? (t - a) / (b - a) : (t < c2 ? 1 : (t < d ? 1 - (t - c2) / (d - c2) : 0)));
    Widget seq(double Function(double t) opacity, double Function(double t) dy, Widget child) => _Cycle(
      run: run,
      period: const Duration(seconds: 7),
      rest: .6,
      builder: (t) => Opacity(
        opacity: opacity(t).clamp(0, 1),
        child: Transform.translate(offset: Offset(0, dy(t)), child: child),
      ),
    );
    return [
      Positioned(
        top: 66,
        right: 36,
        child: _layer(
          context,
          1,
          seq(
            (t) => fade(t, 0, .06, .88, .96),
            (t) => t < .06 ? 10 * (1 - t / .06) : 0,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: MathText(r'Solve $x^2-5x+6=0$', style: ty.body.col(c.onPrimary)),
            ),
          ),
        ),
      ),
      Positioned(
        top: 126,
        left: 30,
        child: _layer(
          context,
          2,
          run
              ? seq(
                  (t) => t < .12 ? 0 : (t < .15 ? (t - .12) / .03 : (t < .30 ? 1 : (t < .33 ? 1 - (t - .30) / .03 : 0))),
                  (_) => 0,
                  _Bubble(child: _TypingDots(run: run)),
                )
              : const SizedBox(),
        ),
      ),
      Positioned(
        top: 126,
        left: 30,
        child: _layer(
          context,
          2,
          seq(
            (t) => fade(t, .32, .38, .88, .96),
            (t) => t < .32 ? 12 : (t < .38 ? 12 * (1 - (t - .32) / .06) : 0),
            SizedBox(
              width: 250,
              child: _Bubble(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MathText(r'Find two numbers that multiply to $6$ and add to $-5$: that is $-2$ and $-3$.', style: ty.body),
                    const SizedBox(height: Space.s2),
                    MathText(r'So $x=2$ or $x=3$.', style: ty.body),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 56,
        right: 50,
        child: _layer(
          context,
          3,
          _Cycle(
            run: run,
            period: const Duration(seconds: 7),
            rest: .6,
            builder: (t) {
              final o = fade(t, .42, .47, .88, .96);
              final s = t < .42 ? .8 : (t < .47 ? .8 + .28 * (t - .42) / .05 : (t < .5 ? 1.08 - .08 * (t - .47) / .03 : 1.0));
              return Opacity(
                opacity: o.clamp(0, 1),
                child: Transform.scale(
                  scale: s,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(99)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), size: 14, color: c.onAccentSoft),
                        const SizedBox(width: 6),
                        Text('Step by step', style: ty.cap.bold.col(c.onAccentSoft)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ];
  }

  // ---- slide 5: progress (score line draws, gold dot pops, +38 badge pops, weak-topic ring fills)
  List<Widget> _progress(BuildContext context, bool run) {
    final c = context.c, ty = context.ty;
    const period = Duration(milliseconds: 4500);
    return [
      Positioned(
        top: 70,
        child: _layer(
          context,
          1,
          Mini(
            width: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('JAMB score trend', style: ty.sm.bold)),
                    _Cycle(
                      run: run,
                      period: period,
                      rest: 1,
                      builder: (t) {
                        final o = t < .4 ? 0.0 : (t < .5 ? (t - .4) / .1 : 1.0);
                        final s = t < .4 ? .5 : (t < .5 ? .5 + .65 * (t - .4) / .1 : (t < .56 ? 1.15 - .15 * (t - .5) / .06 : 1.0));
                        return Opacity(
                          opacity: o,
                          child: Transform.scale(
                            scale: s,
                            child: const Pill('+38', kind: BadgeKind.success),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: Space.s2),
                SizedBox(
                  height: 64,
                  child: _Cycle(
                    run: run,
                    period: period,
                    rest: 1,
                    builder: (t) {
                      final draw = Curves.easeOut.transform((t / .4).clamp(0, 1));
                      final dot = t < .38
                          ? 0.0
                          : t < .46
                          ? 1.5 * (t - .38) / .08
                          : t < .52
                          ? 1.5 - .5 * (t - .46) / .06
                          : t < .70
                          ? 1.0
                          : t < .78
                          ? 1 + .3 * (t - .70) / .08
                          : t < .86
                          ? 1.3 - .3 * (t - .78) / .08
                          : 1.0;
                      return CustomPaint(
                        painter: _TrendPainter(line: c.secondary, dot: c.accent, draw: draw, dotScale: dot),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 60,
        left: 36,
        child: _layer(
          context,
          2,
          Mini(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: _Cycle(
                          run: run,
                          period: period,
                          rest: 1,
                          builder: (t) => CircularProgressIndicator(
                            value: .7 * Curves.easeOut.transform((t / .45).clamp(0, 1)),
                            strokeWidth: 5.6,
                            color: c.accent,
                            backgroundColor: c.surfaceSunken,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                      ),
                      Text('70%', style: ty.cap.bold),
                    ],
                  ),
                ),
                const SizedBox(width: Space.s3),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weak topic', style: ty.sm.bold),
                    Text('Organic chemistry', style: ty.cap.col(c.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  // ---- slide 6: live classes (live pill, pulsing Join button, student count ticking up)
  List<Widget> _classes(BuildContext context, bool run) {
    final c = context.c, ty = context.ty;
    return [
      Positioned(
        top: 80,
        child: _layer(
          context,
          1,
          Mini(
            width: 250,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconTile(PhosphorIcons.videoCamera(PhosphorIconsStyle.fill), tone: Tone.blue, size: 44, radius: 12),
                    const SizedBox(width: Space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Physics: Waves', style: ty.sm.bold),
                          Text('Today · 4:00 PM', style: ty.cap.col(c.textMuted)),
                        ],
                      ),
                    ),
                    LivePill(run: run),
                  ],
                ),
                const SizedBox(height: Space.s3),
                IgnorePointer(
                  child: _Pulse(
                    run: run,
                    child: Btn('Join class', kind: BtnKind.accent, sm: true, block: true, onPressed: () {}),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 70,
        left: 46,
        child: _layer(
          context,
          2,
          _Float(
            run: run,
            delay: -1,
            child: Mini(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.usersThree(PhosphorIconsStyle.fill), size: 16, color: c.text),
                  const SizedBox(width: 6),
                  _Students(run: run, style: ty.cap.bold.tnum),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  // ---- Game Zone, Community, Request a tutor: short looping films (owner, 14 Nov 2026: "very cinematic and very
  // animated"); see onboarding_scenes.dart.
  Widget _scene(BuildContext context, Widget film) => Positioned.fill(
    child: FittedBox(fit: BoxFit.scaleDown, child: _layer(context, 1, film)),
  );
  List<Widget> _games(BuildContext context, bool run) => [_scene(context, GamesScene(run: run))];
  List<Widget> _community(BuildContext context, bool run) => [_scene(context, CommunityScene(run: run))];
  List<Widget> _tutor(BuildContext context, bool run) => [_scene(context, TutorScene(run: run))];
}

// ---------------------------------------------------------------- motion helpers

/// Runs [builder] with t ∈ [0, 1) repeating every [period] while [run] is true; otherwise shows t = [rest].
class _Cycle extends StatefulWidget {
  const _Cycle({required this.run, required this.period, required this.builder, this.rest = 1, this.offset = 0});
  final bool run;
  final Duration period;
  final double rest, offset;
  final Widget Function(double t) builder;
  @override
  State<_Cycle> createState() => _CycleState();
}

class _CycleState extends State<_Cycle> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Cycle old) {
    super.didUpdateWidget(old);
    if (old.run != widget.run) _sync();
  }

  void _sync() {
    if (widget.run) {
      _c
        ..value = 0
        ..repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.run ? AnimatedBuilder(animation: _c, builder: (_, _) => widget.builder(((_c.value + widget.offset) % 1 + 1) % 1)) : widget.builder(widget.rest);
}

double _ease(double t) => Curves.easeInOut.transform(t);

/// `.fx-float`: up 8 px and back over 4.5 s, with a fixed tilt.
class _Float extends StatelessWidget {
  const _Float({required this.run, required this.child, this.rotate = 0, this.delay = 0});
  final bool run;
  final Widget child;
  final double rotate, delay;
  @override
  Widget build(BuildContext context) {
    final tilted = Transform.rotate(angle: rotate * math.pi / 180, child: child);
    return _Cycle(
      run: run,
      period: const Duration(milliseconds: 4500),
      offset: -delay / 4.5,
      rest: 0,
      builder: (t) => Transform.translate(offset: Offset(0, -8 * _ease(1 - (t * 2 - 1).abs())), child: tilted),
    );
  }
}

/// `.fx-breathe`: the disc grows 5 % and back over 6 s.
class _Breathe extends StatelessWidget {
  const _Breathe({required this.run, required this.child});
  final bool run;
  final Widget child;
  @override
  Widget build(BuildContext context) => _Cycle(
    run: run,
    period: const Duration(seconds: 6),
    rest: 0,
    builder: (t) => Transform.scale(scale: 1 + .05 * _ease(1 - (t * 2 - 1).abs()), child: child),
  );
}

/// `.fx-pulse`: scale 1 → 1.04 → 1 over 2.4 s.
class _Pulse extends StatelessWidget {
  const _Pulse({required this.run, required this.child});
  final bool run;
  final Widget child;
  @override
  Widget build(BuildContext context) => _Cycle(
    run: run,
    period: const Duration(milliseconds: 2400),
    rest: 0,
    builder: (t) => Transform.scale(scale: 1 + .04 * _ease(1 - (t * 2 - 1).abs()), child: child),
  );
}

/// `.fx-tick`: the timer icon wiggles once a second.
class _Tick extends StatelessWidget {
  const _Tick({required this.run, required this.child});
  final bool run;
  final Widget child;
  @override
  Widget build(BuildContext context) => _Cycle(
    run: run,
    period: const Duration(seconds: 1),
    rest: 1,
    builder: (t) {
      final deg = t < .12 ? -14 * t / .12 : (t < .24 ? -14 + 24 * (t - .12) / .12 : (t < .36 ? 10 - 10 * (t - .24) / .12 : 0.0));
      return Transform.rotate(angle: deg * math.pi / 180, child: child);
    },
  );
}

/// `.fx-ripple`: a white ring grows from the play button and fades, every 1.8 s.
class _Ripple extends StatelessWidget {
  const _Ripple({required this.run, required this.child});
  final bool run;
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (run)
          _Cycle(
            run: run,
            period: const Duration(milliseconds: 1800),
            builder: (t) {
              final k = Curves.easeOut.transform(t);
              return Transform.scale(
                scale: 1 + .9 * k,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: .9 * (1 - k)), width: 2),
                  ),
                ),
              );
            },
          ),
        child,
      ],
    ),
  );
}

/// Rows that rise in one after another when the slide becomes current (`.ob-row`).
class _Rise extends StatelessWidget {
  const _Rise({required this.current, required this.delay, required this.child});
  final bool current;
  final Duration delay;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    return _Entrance(key: ValueKey(current), active: current, delay: delay, from: const Offset(0, 14), child: child);
  }
}

/// A one-shot entrance (offset + fade) that replays each time [active] turns on.
class _Entrance extends StatefulWidget {
  const _Entrance({super.key, required this.active, required this.child, this.delay = Duration.zero, this.from = Offset.zero});
  final bool active;
  final Duration delay;
  final Offset from;
  final Widget child;
  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.slow);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _t = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      final k = Motion.out.transform(_c.value);
      return Opacity(
        opacity: widget.active ? k : 0,
        child: Transform.translate(offset: widget.from * (1 - k), child: child),
      );
    },
    child: widget.child,
  );
}

/// Parallax layer (`.layer.l1|l2|l3`): from +40/80/120 px and transparent to in place, 400 ms ease-out,
/// delayed 0/60/120 ms, whenever the slide becomes current.
class _Layer extends StatelessWidget {
  const _Layer({required this.n, required this.current, required this.child});
  final int n;
  final bool current;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    return _Entrance(
      key: ValueKey(current),
      active: current,
      delay: Duration(milliseconds: 60 * (n - 1)),
      from: Offset(40.0 * n, 0),
      child: child,
    );
  }
}

/// `.bar` with a value.
class _Bar extends StatelessWidget {
  const _Bar({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: Container(
      height: 8,
      color: context.c.surfaceSunken,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0, 1),
        child: Container(color: context.c.secondary),
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: context.c.surface,
      border: Border.all(color: context.c.border),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(18),
        bottomRight: Radius.circular(18),
        bottomLeft: Radius.circular(6),
      ),
    ),
    child: child,
  );
}

/// Three blinking dots (`.typing`).
class _TypingDots extends StatelessWidget {
  const _TypingDots({required this.run});
  final bool run;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 15,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _Cycle(
            run: run,
            period: const Duration(seconds: 1),
            offset: -i * .2,
            builder: (t) => Opacity(
              opacity: (t - .5).abs() < .25 ? 0.2 : 1,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: context.c.textSubtle, shape: BoxShape.circle),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// LIVE broadcast pill (`.live-pill`): red dot with a ring that grows and fades, blinking while current.
class LivePill extends StatelessWidget {
  const LivePill({super.key, this.detail, this.run = false});
  final String? detail;
  final bool run;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const red = Color(0xFFE5484D);
    return Container(
      height: 26,
      padding: const EdgeInsets.fromLTRB(9, 0, 11, 0),
      decoration: BoxDecoration(
        color: c.errorSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.error.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 8,
            height: 8,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (run)
                  _Cycle(
                    run: run,
                    period: const Duration(milliseconds: 1800),
                    builder: (t) {
                      final k = Curves.easeOut.transform(t);
                      return Transform.scale(
                        scale: .45 + .9 * k,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: red.withValues(alpha: .9 * (1 - k)), width: 1.5),
                          ),
                        ),
                      );
                    },
                  ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: red, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          _Cycle(
            run: run,
            period: const Duration(milliseconds: 1200),
            rest: 0,
            builder: (t) => Opacity(
              opacity: t < .5 ? 1 : .35,
              child: Text('LIVE', style: context.ty.cap.bold.copyWith(fontSize: 11, letterSpacing: 1.5).col(c.onErrorSoft)),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(width: 7),
            Container(width: 1, height: 12, color: c.onErrorSoft.withValues(alpha: .3)),
            const SizedBox(width: 7),
            Text(detail!, style: context.ty.cap.bold.copyWith(fontSize: 11).tnum.col(c.onErrorSoft)),
          ],
        ],
      ),
    );
  }
}

/// Exam countdown on slide 1 (ticks each second while current).
class _Countdown extends StatefulWidget {
  const _Countdown({required this.run, required this.style});
  final bool run;
  final TextStyle style;
  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  int _left = 1 * 3600 + 58 * 60 + 34;
  late final Timer _t = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted && widget.run) setState(() => _left--);
  });

  @override
  void initState() {
    super.initState();
    _t;
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    return Text('${two(_left ~/ 3600)}:${two(_left % 3600 ~/ 60)}:${two(_left % 60)}', style: widget.style);
  }
}

/// "214 students" that sometimes ticks up while the slide is current.
class _Students extends StatefulWidget {
  const _Students({required this.run, required this.style});
  final bool run;
  final TextStyle style;
  @override
  State<_Students> createState() => _StudentsState();
}

class _StudentsState extends State<_Students> {
  int _n = 214;
  final _rnd = math.Random(7);
  late final Timer _t = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted && widget.run && _rnd.nextDouble() < .35) setState(() => _n++);
  });

  @override
  void initState() {
    super.initState();
    _t;
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('$_n students', style: widget.style);
}

/// Score trend line that draws itself, with the gold end dot.
class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.line, required this.dot, required this.draw, required this.dotScale});
  final Color line, dot;
  final double draw, dotScale;
  @override
  void paint(Canvas canvas, Size size) {
    const pts = [(0, 52), (40, 46), (80, 48), (120, 32), (160, 26), (200, 12)];
    final sx = size.width / 200, sy = size.height / 64;
    final path = Path()..moveTo(0, pts.first.$2 * sy);
    for (final (x, y) in pts.skip(1)) {
      path.lineTo(x * sx, y * sy);
    }
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * draw.clamp(0, 1)),
      Paint()
        ..color = line
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (dotScale > 0) canvas.drawCircle(Offset(200 * sx, 12 * sy), 5 * dotScale, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.draw != draw || old.dotScale != dotScale || old.line != line;
}
