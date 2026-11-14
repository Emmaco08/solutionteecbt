import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../gamezone/gz_avatar.dart';
import '../gamezone/gz_theme.dart' show GzC, gzFont;

// Onboarding scenes for Game Zone, Community and Request a tutor (owner, 14 Nov 2026: "better, very cinematic and very
// animated"). Each is a short film that plays on a loop while its slide is showing: things arrive, act and resolve,
// then the scene resets. Under "reduce motion" (or off-screen) each shows its finished frame. One controller per scene,
// no images, no network.

/// Plays [builder] with t going 0 → 1 every [period] while [run]; otherwise shows the finished frame [rest].
class _Film extends StatefulWidget {
  const _Film({required this.run, required this.period, required this.builder, this.rest = .8});
  final bool run;
  final Duration period;
  final double rest;
  final Widget Function(double t) builder;
  @override
  State<_Film> createState() => _FilmState();
}

class _FilmState extends State<_Film> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Film old) {
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
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    height: 300,
    child: widget.run ? AnimatedBuilder(animation: _c, builder: (_, _) => widget.builder(_c.value)) : widget.builder(widget.rest),
  );
}

/// 0 → 1 between [a] and [b] (eased).
double _seg(double t, double a, double b, [Curve curve = Curves.easeOutCubic]) => curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

/// The whole scene fades out at the very end so the loop restarts cleanly.
double _outro(double t) => 1 - _seg(t, .93, 1, Curves.easeIn);

/// Arrives from [from] (offset in px) with a fade.
Widget _arrive(double p, Offset from, Widget child, {double scaleFrom = 1}) => Opacity(
  opacity: p.clamp(0.0, 1.0),
  child: Transform.translate(
    offset: from * (1 - p),
    child: Transform.scale(scale: scaleFrom + (1 - scaleFrom) * p, child: child),
  ),
);

// ---------------------------------------------------------------------------------------------------- Game Zone

/// Game Zone: two players slide in, VS slams down with a shockwave, a question drops, the right answer lights up,
/// "+100" flies up, the score counts and a burst of confetti pops.
class GamesScene extends StatelessWidget {
  const GamesScene({super.key, required this.run});
  final bool run;
  @override
  Widget build(BuildContext context) => _Film(
    run: run,
    period: const Duration(milliseconds: 5600),
    builder: (t) {
      final enter = _seg(t, 0, .12);
      final vs = _seg(t, .10, .22, Curves.easeOutBack);
      final wave = _seg(t, .20, .34);
      final q = _seg(t, .24, .36);
      final right = _seg(t, .58, .64);
      final fly = _seg(t, .62, .84);
      final score = (100 * _seg(t, .62, .74)).round();
      Widget player(String name, GzLook look, int pts, Color ring, {bool flip = false}) => Container(
        width: 108,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF13284F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF06132B), width: 2.5),
          boxShadow: const [BoxShadow(color: Color(0xFF06132B), offset: Offset(0, 4))],
        ),
        child: Column(
          children: [
            GzPortrait(
              face: GzFace(look: look),
              size: 50,
              ring: ring,
              name: name,
            ),
            const SizedBox(height: 4),
            Text(name, style: gzFont(13, shadow: 0)),
            Text('$pts', style: gzFont(16, color: GzC.goldLight, shadow: 0)),
          ],
        ),
      );
      Widget option(String text, int i, {bool ok = false}) {
        final p = _seg(t, .38 + i * .04, .48 + i * .04, Curves.easeOutBack);
        final lit = ok ? right : 0.0;
        return _arrive(
          p,
          const Offset(0, 16),
          Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.lerp(GzC.options[i], GzC.green, lit),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF06132B), width: 2),
              boxShadow: const [BoxShadow(color: Color(0xFF06132B), offset: Offset(0, 3))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(text, style: gzFont(13, shadow: 0)),
                if (ok && lit > 0) ...[
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: lit,
                    child: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
        );
      }

      return Opacity(
        opacity: _outro(t),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 4, top: 8, child: _arrive(enter, const Offset(-140, 0), player('YOU', const GzLook(), score, GzC.gold))),
            Positioned(
              right: 4,
              top: 8,
              child: _arrive(
                enter,
                const Offset(140, 0),
                player('KEMI', const GzLook(hair: 'puffs', skin: Color(0xFF5C3A1E), shirt: GzC.red, bg: Color(0xFFE7A33E)), 0, GzC.cyan),
              ),
            ),
            // Shockwave behind VS.
            Positioned(
              left: 150 - 50,
              top: 64 - 50,
              child: Opacity(
                opacity: (1 - wave) * (wave > 0 ? 1 : 0),
                child: Transform.scale(
                  scale: .4 + 1.8 * wave,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Palette.gold300, width: 4),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 150 - 30,
              top: 64 - 22,
              child: Opacity(
                opacity: vs.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 2.4 - 1.4 * vs,
                  child: Transform.rotate(
                    angle: -.08,
                    child: Container(
                      width: 60,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Palette.gold400,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF06132B), width: 3),
                        boxShadow: const [BoxShadow(color: Color(0xFF06132B), offset: Offset(0, 4))],
                      ),
                      child: Text('VS', style: gzFont(24, color: Palette.navy900, shadow: 0)),
                    ),
                  ),
                ),
              ),
            ),
            // The question.
            Positioned(
              left: 14,
              right: 14,
              top: 156,
              child: _arrive(
                q,
                const Offset(0, -30),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: GzC.cream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF06132B), width: 2.5),
                  ),
                  child: Row(
                    children: [
                      Text('Q3', style: gzFont(14, color: GzC.purple, shadow: 0)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Which of these is a noble gas?',
                          style: context.ty.sm.bold.col(Palette.navy900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              top: 212,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: option('Oxygen', 0)),
                      const SizedBox(width: 8),
                      Expanded(child: option('Neon', 1, ok: true)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: option('Sodium', 2)),
                      const SizedBox(width: 8),
                      Expanded(child: option('Iron', 3)),
                    ],
                  ),
                ],
              ),
            ),
            // +100 flies up from the answer to the score, confetti bursts.
            if (fly > 0 && fly < 1)
              Positioned(
                left: 196 - 120 * fly,
                top: 214 - 150 * fly,
                child: Opacity(
                  opacity: 1 - _seg(fly, .7, 1),
                  child: Transform.scale(
                    scale: .8 + .6 * math.sin(fly * math.pi),
                    child: Text('+100', style: gzFont(22, color: GzC.goldLight)),
                  ),
                ),
              ),
            if (right > 0) Positioned(left: 150, top: 230, child: _Burst(p: _seg(t, .60, .80))),
          ],
        ),
      );
    },
  );
}

/// A ring of confetti bits flying out and fading.
class _Burst extends StatelessWidget {
  const _Burst({required this.p});
  final double p;
  @override
  Widget build(BuildContext context) {
    const colors = [GzC.gold, GzC.pink, GzC.cyan, GzC.mint, GzC.purple, GzC.orange];
    return SizedBox(
      width: 0,
      height: 0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < 12; i++)
            Positioned(
              left: math.cos(i * math.pi / 6) * 90 * p - 4,
              top: math.sin(i * math.pi / 6) * 70 * p - 4 + 40 * p * p,
              child: Opacity(
                opacity: 1 - p,
                child: Transform.rotate(
                  angle: p * 6 + i,
                  child: Container(width: 8, height: 5, color: colors[i % colors.length]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------- Community

/// Community: a question types itself out, hearts float up as people like it, SolutionTee AI is typing… then answers,
/// and a classmate says thank you. Students online pulse at the bottom.
class CommunityScene extends StatelessWidget {
  const CommunityScene({super.key, required this.run});
  final bool run;
  @override
  Widget build(BuildContext context) => _Film(
    run: run,
    period: const Duration(milliseconds: 6400),
    rest: .86,
    builder: (t) {
      final c = context.c, ty = context.ty;
      const question = 'How do I find the gradient of a line? 🤔';
      final typed = (question.characters.length * _seg(t, .06, .28, Curves.linear)).round();
      final like = _seg(t, .30, .36, Curves.easeOutBack);
      final dots = t > .40 && t < .54;
      final answer = _seg(t, .54, .64);
      final thanks = _seg(t, .70, .80, Curves.easeOutBack);
      final pulse = (math.sin(t * math.pi * 8) + 1) / 2;
      Widget face(String l, Color bg, {double r = 13, Widget? icon}) => CircleAvatar(
        radius: r,
        backgroundColor: bg,
        child: icon ?? Text(l, style: ty.cap.bold.col(Colors.white)),
      );
      return Opacity(
        opacity: _outro(t),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The post.
            Positioned(
              left: 8,
              right: 8,
              top: 4,
              child: _arrive(
                _seg(t, 0, .06),
                const Offset(0, 20),
                Mini(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          face('K', Palette.blue600),
                          const SizedBox(width: 8),
                          Text('Kemi', style: ty.sm.bold),
                          Text('  @kemi · now', style: ty.cap.col(c.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 36,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: question.characters.take(typed).toString(), style: ty.sm),
                              if (typed < question.characters.length) TextSpan(text: '|', style: ty.sm.bold.col(Palette.blue600)),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(PhosphorIcons.chatCircle(), size: 16, color: c.textMuted),
                          const SizedBox(width: 4),
                          Text(answer > 0 ? (thanks > 0 ? '2' : '1') : '0', style: ty.cap.col(c.textMuted)),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Transform.scale(
                                  scale: 1 + .5 * math.sin(like * math.pi),
                                  child: Icon(
                                    like > .5 ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.heart(),
                                    size: 16,
                                    color: like > .5 ? const Color(0xFFF43F6B) : c.textMuted,
                                  ),
                                ),
                                for (var i = 0; i < 3; i++)
                                  if (t > .32 && t < .58)
                                    Positioned(
                                      left: -2 + i * 7.0,
                                      top: -50 * _seg(t, .32 + i * .03, .52 + i * .03),
                                      child: Opacity(
                                        opacity: 1 - _seg(t, .32 + i * .03, .52 + i * .03),
                                        child: Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill), size: 10 + i * 2.0, color: const Color(0xFFF43F6B)),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${12 + (like > .5 ? 1 : 0) + (thanks > .5 ? 1 : 0)}',
                            style: ty.cap.bold.tnum.col(like > .5 ? const Color(0xFFF43F6B) : c.textMuted),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: c.secondarySoft, borderRadius: BorderRadius.circular(99)),
                            child: Text('#Maths', style: ty.cap.bold.col(c.onSecondarySoft)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // SolutionTee AI typing, then the answer.
            Positioned(
              left: 30,
              right: 8,
              top: 128,
              child: dots
                  ? Mini(
                      width: 120,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          face('', Palette.gold400, r: 10, icon: Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), size: 11, color: Palette.navy900)),
                          const SizedBox(width: 8),
                          for (var i = 0; i < 3; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Opacity(
                                opacity: .3 + .7 * ((math.sin(t * 60 - i) + 1) / 2),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(color: c.textMuted, shape: BoxShape.circle),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : _arrive(
                      answer,
                      const Offset(-24, 0),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Palette.gold400, width: 1.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            face('', Palette.gold400, icon: Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), size: 13, color: Palette.navy900)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('SolutionTee AI', style: ty.cap.bold.col(Palette.gold600)),
                                  Text('Gradient = rise ÷ run. For (1, 2) and (4, 8): 6 ÷ 3 = 2 ✅', style: ty.cap.col(c.text)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            // Thank-you reply.
            Positioned(
              right: 8,
              top: 204,
              child: _arrive(
                thanks,
                const Offset(30, 0),
                Mini(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      face('M', Palette.green500, r: 11),
                      const SizedBox(width: 8),
                      Text('Thanks! That helped 🙌', style: ty.cap.bold),
                    ],
                  ),
                ),
                scaleFrom: .7,
              ),
            ),
            // Students online.
            Positioned(
              left: 0,
              right: 0,
              bottom: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
                  decoration: BoxDecoration(color: Palette.navy900, borderRadius: BorderRadius.circular(99)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 22,
                        child: Stack(
                          children: [
                            for (final (i, col) in [Palette.gold400, Palette.blue500, Palette.green500].indexed)
                              Positioned(
                                left: i * 14.0,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: col,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Palette.navy900, width: 2),
                                  ),
                                  child: Icon(PhosphorIcons.user(PhosphorIconsStyle.fill), size: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: Color.lerp(Palette.green300, Palette.green500, pulse), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text('2.4k students here now', style: ty.cap.bold.col(Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------------------------------- Request a tutor

/// Request a tutor: a live one-to-one session. The tutor writes the steps of a quadratic on the board one line at a
/// time (with a pen following the ink), a tick lands on the answer, and the student replies "Now I get it!".
class TutorScene extends StatelessWidget {
  const TutorScene({super.key, required this.run});
  final bool run;
  @override
  Widget build(BuildContext context) => _Film(
    run: run,
    period: const Duration(milliseconds: 6800),
    rest: .86,
    builder: (t) {
      final c = context.c, ty = context.ty;
      final pulse = (math.sin(t * math.pi * 10) + 1) / 2;
      const lines = ['x² − 5x + 6 = 0', '(x − 2)(x − 3) = 0', 'x = 2  or  x = 3'];
      const spans = [(.12, .26), (.30, .44), (.48, .60)];
      final tick = _seg(t, .62, .70, Curves.easeOutBack);
      final reply = _seg(t, .70, .80, Curves.easeOutBack);
      final board = _seg(t, .04, .12);
      // The line being written now, for the pen.
      var penLine = -1;
      var penX = 0.0;
      for (final (i, (a, b)) in spans.indexed) {
        if (t >= a && t <= b) {
          penLine = i;
          penX = _seg(t, a, b, Curves.linear);
        }
      }
      return Opacity(
        opacity: _outro(t),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The tutor, live.
            Positioned(
              left: 8,
              right: 8,
              top: 4,
              child: _arrive(
                _seg(t, 0, .07),
                const Offset(0, -20),
                Mini(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Palette.gold400,
                            child: Icon(PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill), size: 22, color: Palette.navy900),
                          ),
                          Positioned(
                            right: -1,
                            bottom: -1,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Palette.green500,
                                shape: BoxShape.circle,
                                border: Border.all(color: c.surface, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Palette.green500.withValues(alpha: .6 * pulse),
                                    blurRadius: 8,
                                    spreadRadius: 2 * pulse,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mr Ade · Mathematics', style: ty.sm.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('Live with you · 1-to-1', style: ty.cap.col(c.success)),
                          ],
                        ),
                      ),
                      Icon(PhosphorIcons.microphone(PhosphorIconsStyle.fill), size: 18, color: c.textMuted),
                      const SizedBox(width: 8),
                      Icon(PhosphorIcons.videoCamera(PhosphorIconsStyle.fill), size: 18, color: c.textMuted),
                    ],
                  ),
                ),
              ),
            ),
            // The board.
            Positioned(
              left: 8,
              right: 8,
              top: 72,
              child: _arrive(
                board,
                const Offset(0, 24),
                Container(
                  height: 136,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF123B2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF8C600F), width: 5),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 6))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, line) in lines.indexed)
                        SizedBox(
                          height: 34,
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipRect(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: _seg(t, spans[i].$1, spans[i].$2, Curves.linear),
                                      child: Text(
                                        line,
                                        style: ty.h3.copyWith(fontWeight: FontWeight.w600, height: 1.2).col(i == 2 ? Palette.gold300 : const Color(0xFFF4F1E8)),
                                      ),
                                    ),
                                  ),
                                  if (penLine == i)
                                    Positioned(
                                      left: _textWidth(context, line) * penX - 2,
                                      top: -10,
                                      child: Transform.rotate(
                                        angle: -.5,
                                        child: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.fill), size: 20, color: Palette.gold300),
                                      ),
                                    ),
                                ],
                              ),
                              if (i == 2 && tick > 0) ...[
                                const SizedBox(width: 8),
                                Transform.scale(
                                  scale: tick,
                                  child: Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 24, color: Palette.green300),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // The student.
            Positioned(
              right: 8,
              top: 222,
              child: _arrive(
                reply,
                const Offset(0, 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: const BoxDecoration(
                    color: Palette.blue600,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text('Now I get it! Thank you 🎉', style: ty.sm.bold.col(Colors.white)),
                ),
                scaleFrom: .6,
              ),
            ),
            Positioned(
              left: 8,
              top: 272,
              child: Opacity(
                opacity: board,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: c.successSoft, borderRadius: BorderRadius.circular(99)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIcons.clock(PhosphorIconsStyle.fill), size: 13, color: c.success),
                      const SizedBox(width: 4),
                      Text('At your pace', style: ty.cap.bold.col(c.success)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  static double _textWidth(BuildContext context, String s) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: context.ty.h3.copyWith(fontWeight: FontWeight.w600, height: 1.2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }
}
