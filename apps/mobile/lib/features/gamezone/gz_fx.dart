import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'gz_sound.dart';
import 'gz_theme.dart';

// Game moments (D-157): the timer ring, 3-2-1-GO, score pops, spark bursts, stars, the treasure chest.
// Everything is timed by the server clock passed in as [now] (milliseconds), never by the phone's clock alone.

typedef ServerNow = int Function();

/// Repaints only itself every frame from a Ticker (the rest of the screen does not rebuild).
mixin _Ticking<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final Ticker _ticker;
  void onTick();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => onTick())..start();
    onTick();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// The big round timer: green, then gold, then red; pulses in the last 3 seconds.
class TimerRing extends StatefulWidget {
  const TimerRing({super.key, required this.now, required this.from, required this.to, this.size = 62, this.frozen = false, this.ticks = true});
  final ServerNow now;
  final int from;
  final int to;
  final double size;

  /// Answered or round over: hold still.
  final bool frozen;

  /// Tick sounds in the last 3 seconds.
  final bool ticks;

  @override
  State<TimerRing> createState() => _TimerRingState();
}

class _TimerRingState extends State<TimerRing> with SingleTickerProviderStateMixin, _Ticking {
  final _left = ValueNotifier<double>(1);
  final _secs = ValueNotifier<int>(0);

  @override
  void onTick() {
    if (widget.frozen) return;
    final total = math.max(1, widget.to - widget.from);
    final rem = (widget.to - widget.now()).clamp(0, total);
    _left.value = rem / total;
    final s = (rem / 1000).ceil();
    if (widget.ticks && s != _secs.value && s >= 1 && s <= 3 && _secs.value > s) GzSound.instance.play(GzSfx.tick, volume: .8);
    _secs.value = s;
  }

  @override
  void dispose() {
    _left.dispose();
    _secs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _RingPainter(_left),
        child: Center(
          child: ValueListenableBuilder<int>(
            valueListenable: _secs,
            builder: (_, s, _) {
              final t = Text('$s', style: gzFont(widget.size * .38, color: s <= 3 ? const Color(0xFFFFB3C3) : Colors.white));
              return s <= 3 && s > 0 && !context.calm
                  ? t.animate(key: ValueKey(s)).scale(begin: const Offset(1.45, 1.45), duration: 300.ms, curve: Curves.easeOutBack)
                  : t;
            },
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.left) : super(repaint: left);
  final ValueNotifier<double> left;

  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final center = Offset(r, r);
    c.drawCircle(center + const Offset(0, 3), r - 1, Paint()..color = GzC.ink);
    c.drawCircle(center, r - 1, Paint()..color = GzC.navy);
    c.drawCircle(
      center,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = GzC.ink,
    );
    final v = left.value;
    final col = v > .5 ? GzC.mint : (v > .25 ? GzC.goldLight : GzC.pink);
    c.drawArc(
      Rect.fromCircle(center: center, radius: r - 7),
      -math.pi / 2,
      math.pi * 2 * v,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = col,
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => false;
}

/// A thin bar that empties until [to] (race and Blitz time left).
class TimeBar extends StatefulWidget {
  const TimeBar({super.key, required this.now, required this.from, required this.to, this.height = 14, this.color = GzC.mint});
  final ServerNow now;
  final int from;
  final int to;
  final double height;
  final Color color;
  @override
  State<TimeBar> createState() => _TimeBarState();
}

class _TimeBarState extends State<TimeBar> with SingleTickerProviderStateMixin, _Ticking {
  final _v = ValueNotifier<double>(1);

  @override
  void onTick() {
    final total = math.max(1, widget.to - widget.from);
    _v.value = ((widget.to - widget.now()) / total).clamp(0, 1).toDouble();
  }

  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: GzC.ink,
        borderRadius: BorderRadius.circular(widget.height),
        border: Border.all(color: GzC.line, width: 2),
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: _v,
        builder: (_, v, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: v,
          child: DecoratedBox(
            decoration: BoxDecoration(color: v < .2 ? GzC.pink : widget.color, borderRadius: BorderRadius.circular(widget.height)),
          ),
        ),
      ),
    ),
  );
}

/// Whole seconds left until [to] as a game label ("35s").
class SecondsLeft extends StatefulWidget {
  const SecondsLeft({super.key, required this.now, required this.to, this.size = 16});
  final ServerNow now;
  final int to;
  final double size;
  @override
  State<SecondsLeft> createState() => _SecondsLeftState();
}

class _SecondsLeftState extends State<SecondsLeft> with SingleTickerProviderStateMixin, _Ticking {
  final _s = ValueNotifier<int>(0);

  @override
  void onTick() => _s.value = math.max(0, ((widget.to - widget.now()) / 1000).ceil());

  @override
  void dispose() {
    _s.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: _s,
    builder: (_, s, _) => Text('${s}s', style: gzFont(widget.size, color: s <= 10 ? const Color(0xFFFFB3C3) : Colors.white)),
  );
}

/// 3, 2, 1, GO! timed to the match start. Calls [onDone] once it is over.
class StartCountdown extends StatefulWidget {
  const StartCountdown({super.key, required this.now, required this.startsAt});
  final ServerNow now;
  final int startsAt;
  @override
  State<StartCountdown> createState() => _StartCountdownState();
}

class _StartCountdownState extends State<StartCountdown> with SingleTickerProviderStateMixin, _Ticking {
  final _n = ValueNotifier<int>(4);

  @override
  void onTick() {
    final ms = widget.startsAt - widget.now();
    final n = ms <= -700 ? -1 : (ms <= 0 ? 0 : math.min(3, (ms / 1000).ceil()));
    if (n != _n.value && n >= 0 && n <= 3) GzSound.instance.play(n == 0 ? GzSfx.go : GzSfx.count);
    _n.value = n;
  }

  @override
  void dispose() {
    _n.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: _n,
    builder: (_, n, _) {
      if (n < 0 || n > 3) return const SizedBox.shrink();
      final w = OutlinedText(n == 0 ? 'GO!' : '$n', size: n == 0 ? 96 : 120, color: n == 0 ? GzC.mint : GzC.goldLight, stroke: 5, shadow: 8);
      if (context.calm) return Center(child: w);
      return Center(
        child: w
            .animate(key: ValueKey(n))
            .scale(begin: const Offset(2.2, 2.2), end: const Offset(1, 1), duration: 380.ms, curve: Curves.easeOutBack)
            .fadeIn(duration: 120.ms)
            .then(delay: 380.ms)
            .fadeOut(duration: 200.ms),
      );
    },
  );
}

/// "+142 FAST!" floating up from the middle of the screen.
class ScorePop extends StatelessWidget {
  const ScorePop({super.key, required this.text, this.color = GzC.goldLight, this.size = 34});
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final w = OutlinedText(text, size: size, color: color, stroke: 3, shadow: 4);
    if (context.calm) return w;
    return w
        .animate()
        .scale(begin: const Offset(.3, .3), duration: 320.ms, curve: Curves.easeOutBack)
        .moveY(begin: 10, end: -18, duration: 900.ms, curve: Curves.easeOut)
        .then(delay: 300.ms)
        .fadeOut(duration: 300.ms);
  }
}

/// A one-shot spark burst (right answer, win). Paint only; nothing under reduce motion.
class Burst extends StatefulWidget {
  const Burst({super.key, this.colors = const [GzC.goldLight, GzC.mint, Colors.white, GzC.cyan], this.count = 22, this.size = 220});
  final List<Color> colors;
  final int count;
  final double size;
  @override
  State<Burst> createState() => _BurstState();
}

class _BurstState extends State<Burst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.calm) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(painter: _BurstPainter(_c, widget.colors, widget.count)),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.a, this.colors, this.count) : super(repaint: a);
  final Animation<double> a;
  final List<Color> colors;
  final int count;

  @override
  void paint(Canvas c, Size s) {
    final t = Curves.easeOut.transform(a.value);
    if (a.value >= 1) return;
    final center = s.center(Offset.zero);
    final r = math.Random(count);
    for (var i = 0; i < count; i++) {
      final ang = i / count * math.pi * 2 + r.nextDouble() * .3;
      final dist = s.width * .5 * t * (.55 + r.nextDouble() * .45);
      final p = center + Offset(math.cos(ang), math.sin(ang)) * dist;
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: 1 - a.value);
      if (i.isEven) {
        _star(c, p, 6 * (1 - a.value * .5), paint);
      } else {
        c.drawCircle(p, 3.5 * (1 - a.value * .6), paint);
      }
    }
  }

  void _star(Canvas c, Offset p, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final rr = i.isEven ? r : r * .4;
      final a = i * math.pi / 4;
      final o = p + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    c.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(_BurstPainter o) => false;
}

/// A chunky gold star (results).
class GzStar extends StatelessWidget {
  const GzStar({super.key, this.size = 48, this.on = true});
  final double size;
  final bool on;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _StarPainter(on)),
  );
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.on);
  final bool on;
  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 24;
    final p = Path()
      ..moveTo(12 * k, 2 * k)
      ..lineTo(15 * k, 8 * k)
      ..lineTo(21 * k, 8.9 * k)
      ..lineTo(16.5 * k, 13.2 * k)
      ..lineTo(17.5 * k, 19.5 * k)
      ..lineTo(12 * k, 16.8 * k)
      ..lineTo(6.5 * k, 19.5 * k)
      ..lineTo(7.5 * k, 13.2 * k)
      ..lineTo(3 * k, 8.9 * k)
      ..lineTo(9 * k, 8 * k)
      ..close();
    c.drawPath(p, Paint()..color = on ? GzC.goldLight : GzC.navy2);
    if (on) c.drawCircle(Offset(10 * k, 9.5 * k), 1.6 * k, Paint()..color = Colors.white.withValues(alpha: .8));
    c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * k
        ..strokeJoin = StrokeJoin.round
        ..color = GzC.ink,
    );
  }

  @override
  bool shouldRepaint(_StarPainter o) => o.on != on;
}

/// The treasure chest: the lid opens and XP coins rise out.
class TreasureChest extends StatefulWidget {
  const TreasureChest({super.key, this.size = 170, this.delay = const Duration(milliseconds: 600)});
  final double size;
  final Duration delay;
  @override
  State<TreasureChest> createState() => _TreasureChestState();
}

class _TreasureChestState extends State<TreasureChest> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.calm) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Treasure chest with XP coins',
    image: true,
    child: RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size * 150 / 170,
        child: CustomPaint(painter: _ChestPainter(_c)),
      ),
    ),
  );
}

class _ChestPainter extends CustomPainter {
  _ChestPainter(this.a) : super(repaint: a);
  final Animation<double> a;

  @override
  void paint(Canvas canvas, Size s) {
    final open = Curves.easeOutBack.transform(a.value.clamp(0, 1).toDouble());
    canvas.save();
    canvas.scale(s.width / 170, s.height / 150);
    final c = canvas;
    final ink = Paint()
      ..color = GzC.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;
    // Glow and coins.
    if (open > .05) {
      c.drawOval(
        Rect.fromCenter(center: const Offset(85, 70), width: 116 * open, height: 24 * open),
        Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: .9),
      );
      for (final (x, y, r) in const [(60.0, 52.0, 13.0), (92.0, 40.0, 15.0), (120.0, 56.0, 12.0)]) {
        final cy = 70 - (70 - y) * open;
        c.drawCircle(Offset(x, cy), r, Paint()..color = GzC.brand);
        c.drawCircle(Offset(x, cy), r, ink..strokeWidth = 3);
        c.drawCircle(Offset(x - r * .3, cy - r * .3), r * .22, Paint()..color = Colors.white.withValues(alpha: .7));
      }
      ink.strokeWidth = 4;
    }
    // Box.
    final box = Path()..addRect(const Rect.fromLTWH(20, 70, 130, 70));
    c.drawPath(box, Paint()..color = const Color(0xFF9A4F1E));
    c.drawRect(const Rect.fromLTWH(20, 70, 130, 10), Paint()..color = Colors.black.withValues(alpha: .18));
    c.drawPath(box, ink);
    c.drawLine(const Offset(20, 96), const Offset(150, 96), ink);
    for (final x in const [36.0, 134.0]) {
      c.drawLine(Offset(x, 70), Offset(x, 140), ink..strokeWidth = 3);
    }
    ink.strokeWidth = 4;
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(74, 88, 22, 24), const Radius.circular(4)), Paint()..color = GzC.goldLight);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(74, 88, 22, 24), const Radius.circular(4)), ink..strokeWidth = 3);
    // Lid on a hinge at the back left.
    c.save();
    c.translate(20, 70);
    c.rotate(-.55 * open);
    final lid = Path()
      ..moveTo(-6, 0)
      ..cubicTo(-6, -36, 136, -36, 136, 0)
      ..close();
    c.drawPath(lid, Paint()..color = const Color(0xFFB8642A));
    c.drawPath(lid, ink..strokeWidth = 4);
    c.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChestPainter o) => false;
}

/// The ribbon banner behind "VICTORY!" / "GOOD GAME".
class RibbonBanner extends StatelessWidget {
  const RibbonBanner({super.key, required this.text, this.color = GzC.brand, this.width = 300});
  final String text;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width * 80 / 300,
    child: CustomPaint(
      painter: _RibbonPainter(color),
      child: Align(
        alignment: const Alignment(0, -.12),
        child: SizedBox(
          height: width * .13,
          child: FittedBox(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: width * .14),
              child: Text(text, style: gzFont(width * .12, color: GzC.navy, shadow: 0, spacing: 2, height: 1)),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    canvas.save();
    canvas.scale(s.width / 300, s.height / 80);
    final c = canvas;
    final ink = Paint()
      ..color = GzC.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    final deep = Color.lerp(color, GzC.ink, .3)!;
    for (final p in [
      Path()
        ..moveTo(10, 30)
        ..lineTo(40, 30)
        ..lineTo(40, 66)
        ..lineTo(24, 56)
        ..lineTo(10, 66)
        ..close(),
      Path()
        ..moveTo(290, 30)
        ..lineTo(260, 30)
        ..lineTo(260, 66)
        ..lineTo(276, 56)
        ..lineTo(290, 66)
        ..close(),
    ]) {
      c.drawPath(p, Paint()..color = deep);
      c.drawPath(p, ink);
    }
    final band = Path()..addRect(const Rect.fromLTWH(30, 14, 240, 44));
    c.drawPath(band, Paint()..color = color);
    c.drawRect(const Rect.fromLTWH(30, 14, 240, 10), Paint()..color = Colors.white.withValues(alpha: .35));
    c.drawPath(band, ink..strokeWidth = 3.5);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RibbonPainter o) => o.color != color;
}

/// Gold rays turning slowly behind the winner.
class SunRays extends StatefulWidget {
  const SunRays({super.key, this.color = GzC.goldLight, this.size = 420});
  final Color color;
  final double size;
  @override
  State<SunRays> createState() => _SunRaysState();
}

class _SunRaysState extends State<SunRays> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: _RaysPainter(context.calm ? null : _c, widget.color)),
      ),
    ),
  );
}

class _RaysPainter extends CustomPainter {
  _RaysPainter(this.a, this.color) : super(repaint: a);
  final Animation<double>? a;
  final Color color;
  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero);
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate((a?.value ?? 0) * math.pi * 2);
    final r = s.width / 2;
    final paint = Paint()
      ..shader = RadialGradient(colors: [color.withValues(alpha: .45), color.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    for (var i = 0; i < 12; i++) {
      c.save();
      c.rotate(i * math.pi / 6);
      c.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(-r * .12, -r)
          ..lineTo(r * .12, -r)
          ..close(),
        paint,
      );
      c.restore();
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_RaysPainter o) => o.color != color;
}
