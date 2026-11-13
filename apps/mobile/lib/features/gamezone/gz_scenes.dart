import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gz_theme.dart';

// Game Zone scenes (D-157). Each background is one CustomPainter that draws once (RepaintBoundary, no blur), and the
// few moving parts (spotlights, lava, neon floor) are separate small painters driven by one controller each.
// Under "reduce motion" nothing moves.

/// Paints in the 390 × 844 design space, covering the box like CSS `slice`.
void _cover(Canvas c, Size s, void Function(Canvas c) draw) {
  final k = math.max(s.width / 390, s.height / 844);
  c.save();
  c.translate((s.width - 390 * k) / 2, (s.height - 844 * k) / 2);
  c.scale(k);
  draw(c);
  c.restore();
}

// ---------------------------------------------------------------- stadium arena at night

class ArenaScene extends StatelessWidget {
  const ArenaScene({super.key, this.top = const Color(0xFF2A0F5C), this.mid = const Color(0xFF10284D), this.glow = GzC.brand, this.beams = true});
  final Color top;
  final Color mid;
  final Color glow;
  final bool beams;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _ArenaPainter(top, mid, glow)),
        if (beams && !context.calm) const _Beams(),
        if (beams && context.calm) CustomPaint(painter: _BeamPainter(null)),
      ],
    ),
  );
}

class _ArenaPainter extends CustomPainter {
  _ArenaPainter(this.top, this.mid, this.glow);
  final Color top;
  final Color mid;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) => _cover(canvas, size, (c) {
    c.drawRect(
      const Rect.fromLTWH(0, 0, 390, 844),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, mid, GzC.ink],
          stops: const [0, .55, 1],
        ).createShader(const Rect.fromLTWH(0, 0, 390, 844)),
    );
    final star = Paint()..color = Colors.white;
    final r = math.Random(7);
    for (var i = 0; i < 26; i++) {
      star.color = Colors.white.withValues(alpha: .3 + r.nextDouble() * .6);
      c.drawCircle(Offset(r.nextDouble() * 390, r.nextDouble() * 230), .8 + r.nextDouble() * 1.2, star);
    }
    // Stands with the crowd.
    c.drawPath(
      Path()
        ..moveTo(0, 330)
        ..cubicTo(60, 300, 120, 292, 195, 292)
        ..cubicTo(270, 292, 330, 300, 390, 330)
        ..lineTo(390, 430)
        ..lineTo(0, 430)
        ..close(),
      Paint()..color = const Color(0xFF0F2347),
    );
    c.drawPath(
      Path()
        ..moveTo(0, 362)
        ..cubicTo(70, 334, 130, 328, 195, 328)
        ..cubicTo(260, 328, 320, 334, 390, 362)
        ..lineTo(390, 450)
        ..lineTo(0, 450)
        ..close(),
      Paint()..color = const Color(0xFF132C57),
    );
    final head = Paint()..color = const Color(0xFF1F3C70);
    final head2 = Paint()..color = const Color(0xFF26477F);
    for (var row = 0; row < 3; row++) {
      for (var i = 0; i < 18; i++) {
        final x = 12.0 + i * 22 + (row.isOdd ? 11 : 0);
        final t = (x - 195) / 195;
        final y = 316 + row * 16 + t * t * 26;
        c.drawCircle(Offset(x, y), 7, row == 1 ? head2 : head);
      }
    }
    final flash = Paint()..color = glow.withValues(alpha: .7);
    for (final o in const [Offset(63, 340), Offset(151, 330), Offset(239, 331), Offset(327, 342), Offset(108, 352), Offset(285, 356)]) {
      c.drawCircle(o, 2, flash);
    }
    // Floor glow and the court.
    c.drawOval(
      const Rect.fromLTWH(-65, 440, 520, 240),
      Paint()..shader = RadialGradient(colors: [glow.withValues(alpha: .5), glow.withValues(alpha: 0)]).createShader(const Rect.fromLTWH(-65, 440, 520, 240)),
    );
    c.drawRect(
      const Rect.fromLTWH(0, 470, 390, 374),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B3A6B), GzC.navy],
        ).createShader(const Rect.fromLTWH(0, 470, 390, 374)),
    );
    final grid = Paint()
      ..color = const Color(0xFF2A5591).withValues(alpha: .55)
      ..strokeWidth = 1.5;
    for (final x in const <double>[-200, 0, 120, 270, 390, 590]) {
      c.drawLine(const Offset(195, 470), Offset(x, 844), grid);
    }
    for (final y in const <double>[500, 545, 610, 700, 820]) {
      c.drawLine(Offset(0, y), Offset(390, y), grid);
    }
    c.drawLine(
      const Offset(0, 470),
      const Offset(390, 470),
      Paint()
        ..color = glow.withValues(alpha: .6)
        ..strokeWidth = 2,
    );
  });

  @override
  bool shouldRepaint(_ArenaPainter o) => o.top != top || o.mid != mid || o.glow != glow;
}

class _Beams extends StatefulWidget {
  const _Beams();
  @override
  State<_Beams> createState() => _BeamsState();
}

class _BeamsState extends State<_Beams> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: CustomPaint(painter: _BeamPainter(_c)));
}

/// Two spotlights from the roof that sway slowly over the court.
class _BeamPainter extends CustomPainter {
  _BeamPainter(this.a) : super(repaint: a);
  final Animation<double>? a;

  @override
  void paint(Canvas canvas, Size size) => _cover(canvas, size, (c) {
    final t = Curves.easeInOut.transform(a?.value ?? .5);
    for (final (x, dir) in const [(40.0, 1.0), (350.0, -1.0)]) {
      final sway = (t - .5) * 70 * dir;
      final cx = 195 - (195 - x) * .2 + sway;
      final beam = Path()
        ..moveTo(x - 18, 8)
        ..lineTo(x + 18, 8)
        ..lineTo(cx + 46, 560)
        ..lineTo(cx - 46, 560)
        ..close();
      c.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFFFE7A3).withValues(alpha: .34), const Color(0xFFFFE7A3).withValues(alpha: 0)],
          ).createShader(const Rect.fromLTWH(0, 0, 390, 560)),
      );
      c.drawOval(Rect.fromCenter(center: Offset(cx, 560), width: 120, height: 26), Paint()..color = const Color(0xFFFFE7A3).withValues(alpha: .1));
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 6), width: 56, height: 16), const Radius.circular(5)),
        Paint()..color = const Color(0xFFFFF3C4),
      );
    }
  });

  @override
  bool shouldRepaint(_BeamPainter o) => false;
}

// ---------------------------------------------------------------- VS split

class VersusScene extends StatelessWidget {
  const VersusScene({super.key});
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: CustomPaint(painter: _VersusPainter()));
}

class _VersusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => _cover(canvas, size, (c) {
    c.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(390, 0)
        ..lineTo(390, 330)
        ..lineTo(0, 514)
        ..close(),
      Paint()..shader = const LinearGradient(colors: [GzC.blue, GzC.navy]).createShader(const Rect.fromLTWH(0, 0, 390, 514)),
    );
    c.drawPath(
      Path()
        ..moveTo(0, 514)
        ..lineTo(390, 330)
        ..lineTo(390, 844)
        ..lineTo(0, 844)
        ..close(),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: [GzC.red, Color(0xFF4D0F22)],
        ).createShader(const Rect.fromLTWH(0, 330, 390, 514)),
    );
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: .07)
      ..strokeWidth = 10;
    for (final (a, b) in const [
      (Offset(-40, 120), Offset(200, 0)),
      (Offset(-40, 220), Offset(300, 40)),
      (Offset(-40, 320), Offset(420, 80)),
      (Offset(60, 844), Offset(430, 640)),
      (Offset(-20, 844), Offset(430, 560)),
    ]) {
      c.drawLine(a, b, stripe);
    }
    c.drawPath(
      Path()
        ..moveTo(0, 500)
        ..lineTo(390, 316)
        ..lineTo(390, 344)
        ..lineTo(0, 528)
        ..close(),
      Paint()..color = GzC.goldLight,
    );
  });

  @override
  bool shouldRepaint(_VersusPainter o) => false;
}

// ---------------------------------------------------------------- Speed Rush track

class RushTrack extends StatelessWidget {
  const RushTrack({super.key, required this.lanes});
  final List<RushLane> lanes;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final n = math.max(lanes.length, 2);
      final top = 36.0, bottom = 22.0;
      final laneH = (box.maxHeight - top - bottom) / n;
      final start = 54.0, finish = box.maxWidth - 46;
      final carW = math.min(64.0, laneH * 1.5);
      return Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(child: CustomPaint(painter: _TrackPainter(n, top, bottom, start, finish))),
          ),
          for (var i = 0; i < lanes.length; i++)
            AnimatedPositioned(
              duration: context.calm ? Duration.zero : const Duration(milliseconds: 650),
              curve: Curves.easeOutBack,
              left: start - carW * .7 + (finish - start) * lanes[i].progress.clamp(0, 1),
              top: top + laneH * i + (laneH - carW * .6) / 2,
              width: carW,
              height: carW * .6,
              child: _Car(lane: lanes[i]),
            ),
          for (var i = 0; i < lanes.length; i++)
            Positioned(
              left: 4,
              top: top + laneH * i + laneH / 2 - 9,
              child: Container(
                width: 44,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: GzC.ink.withValues(alpha: .75), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  lanes[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: gzFont(11, color: lanes[i].me ? GzC.goldLight : Colors.white, shadow: 0),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class RushLane {
  const RushLane({required this.label, required this.color, required this.progress, this.me = false, this.nitro = false, this.spin = false, this.done = false});
  final String label;
  final Color color;
  final double progress;
  final bool me;
  final bool nitro;
  final bool spin;
  final bool done;
}

class _Car extends StatelessWidget {
  const _Car({required this.lane});
  final RushLane lane;

  @override
  Widget build(BuildContext context) {
    Widget car = CustomPaint(painter: _CarPainter(lane.color, lane.nitro, lane.me));
    if (lane.spin) {
      car = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        builder: (_, t, child) => Transform.rotate(angle: context.calm ? 0 : t * math.pi * 2, child: child),
        child: car,
      );
    }
    return car;
  }
}

class _CarPainter extends CustomPainter {
  _CarPainter(this.color, this.nitro, this.me);
  final Color color;
  final bool nitro;
  final bool me;

  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / 80;
    canvas.save();
    canvas.scale(k, s.height / 48);
    if (nitro) {
      final flame = Path()
        ..moveTo(10, 30)
        ..lineTo(-14, 26)
        ..lineTo(-4, 33)
        ..lineTo(-16, 40)
        ..lineTo(10, 38)
        ..close();
      canvas.drawPath(flame, Paint()..color = GzC.orange);
      canvas.drawPath(
        Path()
          ..moveTo(10, 31)
          ..lineTo(-4, 30)
          ..lineTo(2, 34)
          ..lineTo(-6, 38)
          ..lineTo(10, 37)
          ..close(),
        Paint()..color = GzC.goldLight,
      );
    }
    final ink = Paint()
      ..color = GzC.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    final body = Path()
      ..moveTo(14, 30)
      ..lineTo(20, 16)
      ..cubicTo(22, 12, 26, 10, 30, 10)
      ..lineTo(52, 10)
      ..cubicTo(56, 10, 59, 12, 61, 16)
      ..lineTo(66, 26)
      ..lineTo(72, 28)
      ..cubicTo(75, 29, 76, 31, 76, 34)
      ..lineTo(76, 37)
      ..lineTo(10, 37)
      ..lineTo(10, 34)
      ..cubicTo(10, 32, 12, 30, 14, 30)
      ..close();
    canvas.drawPath(body, Paint()..color = color);
    canvas.drawPath(body, ink);
    final glass = Path()
      ..moveTo(28, 14)
      ..lineTo(50, 14)
      ..lineTo(56, 24)
      ..lineTo(24, 24)
      ..close();
    canvas.drawPath(glass, Paint()..color = GzC.ice);
    canvas.drawPath(glass, ink..strokeWidth = 2.5);
    canvas.drawRect(const Rect.fromLTWH(14, 30, 58, 3), Paint()..color = Colors.white.withValues(alpha: .35));
    for (final x in const [24.0, 62.0]) {
      canvas.drawCircle(Offset(x, 38), 8, Paint()..color = GzC.ink);
      canvas.drawCircle(Offset(x, 38), 3, Paint()..color = GzC.sub);
    }
    if (me) canvas.drawCircle(const Offset(40, 4), 4, Paint()..color = GzC.goldLight);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CarPainter o) => o.color != color || o.nitro != nitro || o.me != me;
}

class _TrackPainter extends CustomPainter {
  _TrackPainter(this.lanes, this.top, this.bottom, this.start, this.finish);
  final int lanes;
  final double top;
  final double bottom;
  final double start;
  final double finish;

  @override
  void paint(Canvas c, Size s) {
    // Grass with mowing stripes.
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF3FA64F));
    final stripe = Paint()..color = const Color(0xFF38994A);
    for (var y = 0.0; y < s.height; y += 40) {
      c.drawRect(Rect.fromLTWH(0, y, s.width, 20), stripe);
    }
    final road = Rect.fromLTRB(0, top - 8, s.width, s.height - bottom + 8);
    c.drawRect(road, Paint()..color = const Color(0xFF3B4250));
    // Kerbs.
    for (final y in [road.top - 8, road.bottom]) {
      for (var x = 0.0; x < s.width; x += 16) {
        c.drawRect(Rect.fromLTWH(x, y, 8, 8), Paint()..color = GzC.pink);
        c.drawRect(Rect.fromLTWH(x + 8, y, 8, 8), Paint()..color = Colors.white);
      }
    }
    final laneH = (s.height - top - bottom) / lanes;
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: .55)
      ..strokeWidth = 2.5;
    for (var i = 1; i < lanes; i++) {
      final y = top + laneH * i;
      for (var x = start; x < finish; x += 22) {
        c.drawLine(Offset(x, y), Offset(math.min(x + 12, finish), y), dash);
      }
    }
    c.drawLine(
      Offset(start, road.top),
      Offset(start, road.bottom),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3,
    );
    // Chequered finish.
    const sq = 8.0;
    for (var y = road.top, row = 0; y < road.bottom; y += sq, row++) {
      for (var col = 0; col < 3; col++) {
        c.drawRect(Rect.fromLTWH(finish + col * sq, y, sq, math.min(sq, road.bottom - y)), Paint()..color = (row + col).isEven ? Colors.white : GzC.ink);
      }
    }
    // Trees on the verge.
    final tree = Paint()..color = const Color(0xFF2E8B3E);
    final dark = Paint()..color = const Color(0xFF256F32);
    for (var x = 30.0; x < s.width; x += 70) {
      c.drawCircle(Offset(x, 12), 11, dark);
      c.drawCircle(Offset(x - 3, 9), 8, tree);
    }
  }

  @override
  bool shouldRepaint(_TrackPainter o) => o.lanes != lanes || o.top != top || o.bottom != bottom;
}

// ---------------------------------------------------------------- Survival: islands over rising lava

class LavaScene extends StatelessWidget {
  const LavaScene({super.key, required this.level});

  /// 0 (low) to 1 (high): the lava rises as rounds go on.
  final double level;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _DuskPainter()),
        TweenAnimationBuilder<double>(
          tween: Tween(end: level),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => context.calm ? CustomPaint(painter: _LavaPainter(null, v)) : _LavaWaves(level: v),
        ),
      ],
    ),
  );
}

class _DuskPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A0F5C), Color(0xFF7A1F5C), Color(0xFFC2410C), Color(0xFFF2B233)],
          stops: [0, .35, .7, 1],
        ).createShader(r),
    );
    c.drawCircle(Offset(s.width * .78, s.height * .18), s.width * .1, Paint()..color = const Color(0xFFFFD465).withValues(alpha: .85));
    final hill = Paint()..color = const Color(0xFF3A1446);
    c.drawPath(
      Path()
        ..moveTo(0, s.height * .62)
        ..lineTo(s.width * .18, s.height * .44)
        ..lineTo(s.width * .34, s.height * .58)
        ..lineTo(s.width * .55, s.height * .4)
        ..lineTo(s.width * .76, s.height * .56)
        ..lineTo(s.width * .9, s.height * .46)
        ..lineTo(s.width, s.height * .54)
        ..lineTo(s.width, s.height)
        ..lineTo(0, s.height)
        ..close(),
      hill,
    );
    c.drawPath(
      Path()
        ..moveTo(0, s.height * .72)
        ..lineTo(s.width * .25, s.height * .58)
        ..lineTo(s.width * .45, s.height * .7)
        ..lineTo(s.width * .7, s.height * .56)
        ..lineTo(s.width, s.height * .68)
        ..lineTo(s.width, s.height)
        ..lineTo(0, s.height)
        ..close(),
      Paint()..color = const Color(0xFF241030),
    );
  }

  @override
  bool shouldRepaint(_DuskPainter o) => false;
}

class _LavaWaves extends StatefulWidget {
  const _LavaWaves({required this.level});
  final double level;
  @override
  State<_LavaWaves> createState() => _LavaWavesState();
}

class _LavaWavesState extends State<_LavaWaves> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _LavaPainter(_c, widget.level));
}

class _LavaPainter extends CustomPainter {
  _LavaPainter(this.a, this.level) : super(repaint: a);
  final Animation<double>? a;
  final double level;

  @override
  void paint(Canvas c, Size s) {
    final t = (a?.value ?? 0) * math.pi * 2;
    final y0 = s.height * (.86 - .26 * level);
    final wave = Path()..moveTo(0, s.height);
    for (var x = 0.0; x <= s.width + 8; x += 8) {
      wave.lineTo(x, y0 + math.sin(x / 26 + t) * 5 + math.sin(x / 11 - t * 2) * 2);
    }
    wave
      ..lineTo(s.width, s.height)
      ..close();
    final r = Rect.fromLTRB(0, y0 - 10, s.width, s.height);
    c.drawPath(
      wave,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFB020), GzC.orange, Color(0xFFB91C1C)],
          stops: [0, .2, 1],
        ).createShader(r),
    );
    final bubble = Paint()..color = const Color(0xFFFFD465).withValues(alpha: .8);
    for (var i = 0; i < 7; i++) {
      final ph = (t / (math.pi * 2) + i / 7) % 1;
      final x = s.width * ((i * .137 + .07) % 1);
      c.drawCircle(Offset(x, y0 + 14 + (1 - ph) * 30), 2 + 3 * math.sin(ph * math.pi), bubble);
    }
  }

  @override
  bool shouldRepaint(_LavaPainter o) => o.level != level;
}

/// A floating island a Survival player stands on.
class IslandPainter extends CustomPainter {
  IslandPainter({this.cracked = false});
  final bool cracked;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final ink = Paint()
      ..color = GzC.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    final rock = Path()
      ..moveTo(0, h * .28)
      ..lineTo(w, h * .28)
      ..lineTo(w * .78, h * .7)
      ..lineTo(w * .55, h)
      ..lineTo(w * .36, h * .78)
      ..lineTo(w * .18, h * .7)
      ..close();
    c.drawPath(rock, Paint()..color = const Color(0xFF6B4A3A));
    c.drawPath(rock, ink);
    final grass = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h * .34), Radius.circular(h * .16));
    c.drawRRect(grass, Paint()..color = cracked ? const Color(0xFF8C7A6B) : GzC.mint);
    c.drawRRect(grass, ink);
    if (cracked) {
      c.drawPath(
        Path()
          ..moveTo(w * .5, h * .05)
          ..lineTo(w * .44, h * .4)
          ..lineTo(w * .56, h * .55)
          ..lineTo(w * .48, h * .9),
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(IslandPainter o) => o.cracked != cracked;
}

// ---------------------------------------------------------------- Maths Blitz neon arcade

class NeonScene extends StatelessWidget {
  const NeonScene({super.key});
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: context.calm ? CustomPaint(painter: _NeonPainter(null)) : const _NeonMove());
}

class _NeonMove extends StatefulWidget {
  const _NeonMove();
  @override
  State<_NeonMove> createState() => _NeonMoveState();
}

class _NeonMoveState extends State<_NeonMove> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _NeonPainter(_c));
}

class _NeonPainter extends CustomPainter {
  _NeonPainter(this.a) : super(repaint: a);
  final Animation<double>? a;

  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0620), Color(0xFF1B0A3D), Color(0xFF3A0E5C)],
          stops: [0, .5, 1],
        ).createShader(r),
    );
    final horizon = s.height * .52;
    c.drawCircle(
      Offset(s.width / 2, horizon),
      s.width * .32,
      Paint()
        ..shader = RadialGradient(colors: [GzC.brand.withValues(alpha: .28), GzC.brand.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: Offset(s.width / 2, horizon), radius: s.width * .32)),
    );
    final line = Paint()
      ..color = GzC.pink.withValues(alpha: .4)
      ..strokeWidth = 1.5;
    for (var i = -6; i <= 6; i++) {
      c.drawLine(Offset(s.width / 2, horizon), Offset(s.width / 2 + i * s.width * .28, s.height), line);
    }
    final t = a?.value ?? 0;
    for (var i = 0; i < 8; i++) {
      final p = ((i + t) / 8);
      final y = horizon + (s.height - horizon) * p * p;
      line.color = GzC.pink.withValues(alpha: .15 + .4 * p);
      c.drawLine(Offset(0, y), Offset(s.width, y), line);
    }
    c.drawLine(
      Offset(0, horizon),
      Offset(s.width, horizon),
      Paint()
        ..color = GzC.cyan.withValues(alpha: .7)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_NeonPainter o) => false;
}

// ---------------------------------------------------------------- Word War castle

class CastleScene extends StatelessWidget {
  const CastleScene({super.key});
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: CustomPaint(painter: _CastlePainter()));
}

class _CastlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => _cover(canvas, size, (c) {
    const r = Rect.fromLTWH(0, 0, 390, 844);
    c.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A1F5C), Color(0xFF1A0B2E), Color(0xFF0A0620)],
        ).createShader(r),
    );
    c.drawCircle(const Offset(300, 90), 34, Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: .9));
    c.drawCircle(const Offset(314, 82), 30, Paint()..color = const Color(0xFF3A1F5C));
    final star = Paint()..color = Colors.white.withValues(alpha: .6);
    final rnd = math.Random(3);
    for (var i = 0; i < 20; i++) {
      c.drawCircle(Offset(rnd.nextDouble() * 390, rnd.nextDouble() * 220), 1 + rnd.nextDouble(), star);
    }
    final wall = Paint()..color = const Color(0xFF45245A);
    final ink = Paint()
      ..color = GzC.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final (x, flag) in const [(0.0, GzC.blue), (298.0, GzC.red)]) {
      final tower = Path()
        ..moveTo(x, 360)
        ..lineTo(x, 200)
        ..lineTo(x + 20, 200)
        ..lineTo(x + 20, 184)
        ..lineTo(x + 36, 184)
        ..lineTo(x + 36, 200)
        ..lineTo(x + 56, 200)
        ..lineTo(x + 56, 184)
        ..lineTo(x + 72, 184)
        ..lineTo(x + 72, 200)
        ..lineTo(x + 92, 200)
        ..lineTo(x + 92, 360)
        ..close();
      c.drawPath(tower, wall);
      c.drawPath(tower, ink);
      final fx = x + 46;
      c.drawLine(Offset(fx, 120), Offset(fx, 184), ink);
      final left = x == 0;
      final f = Path()
        ..moveTo(fx, 122)
        ..lineTo(fx + (left ? 30 : -30), 132)
        ..lineTo(fx, 142)
        ..close();
      c.drawPath(f, Paint()..color = flag);
      c.drawPath(f, ink..strokeWidth = 2);
      ink.strokeWidth = 3;
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x + 36, 240, 20, 28), const Radius.circular(10)),
        Paint()..color = const Color(0xFFFFD465).withValues(alpha: .8),
      );
    }
    c.drawRect(const Rect.fromLTWH(0, 360, 390, 484), Paint()..color = const Color(0xFF2A1440));
    final brick = Paint()
      ..color = const Color(0xFF3A1F5C)
      ..strokeWidth = 2;
    for (var y = 380.0; y < 844; y += 36) {
      c.drawLine(Offset(0, y), Offset(390, y), brick);
    }
  });

  @override
  bool shouldRepaint(_CastlePainter o) => false;
}

// ---------------------------------------------------------------- Memory Flash card table

class FeltScene extends StatelessWidget {
  const FeltScene({super.key});
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: CustomPaint(painter: _FeltPainter()));
}

class _FeltPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(r, Paint()..color = const Color(0xFF5A3210));
    final felt = r.deflate(10);
    c.drawRRect(
      RRect.fromRectAndRadius(felt, const Radius.circular(28)),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.1),
          radius: .9,
          colors: [Color(0xFF1B7A8C), Color(0xFF0E3B47), Color(0xFF0A2E38)],
          stops: [0, .7, 1],
        ).createShader(felt),
    );
    final d = Paint()
      ..color = Colors.white.withValues(alpha: .04)
      ..strokeWidth = 1;
    for (var x = -s.height; x < s.width; x += 28) {
      c.drawLine(Offset(x, 0), Offset(x + s.height, s.height), d);
      c.drawLine(Offset(x + s.height, 0), Offset(x, s.height), d);
    }
    c.drawRRect(
      RRect.fromRectAndRadius(felt, const Radius.circular(28)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF8C5A2B),
    );
  }

  @override
  bool shouldRepaint(_FeltPainter o) => false;
}

// ---------------------------------------------------------------- game card icons

class GameIcon extends StatelessWidget {
  const GameIcon(this.id, {super.key, this.size = 64});
  final String id;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * .8,
    child: CustomPaint(painter: _IconPainter(id)),
  );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.id);
  final String id;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.save();
    canvas.scale(s.width / 80, s.height / 64);
    final c = canvas;
    final ink = Paint()
      ..color = GzC.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    void shape(Path p, Color col, [double w = 3]) {
      c.drawPath(p, Paint()..color = col);
      c.drawPath(p, ink..strokeWidth = w);
    }

    switch (id) {
      case 'duel':
        c.drawCircle(const Offset(40, 34), 26, Paint()..color = Colors.white.withValues(alpha: .22));
        shape(
          Path()
            ..moveTo(18, 52)
            ..lineTo(50, 14)
            ..lineTo(56, 18)
            ..lineTo(24, 56)
            ..close(),
          GzC.goldLight,
        );
        shape(
          Path()
            ..moveTo(62, 52)
            ..lineTo(30, 14)
            ..lineTo(24, 18)
            ..lineTo(56, 56)
            ..close(),
          Colors.white,
        );
        shape(Path()..addOval(Rect.fromCircle(center: const Offset(40, 34), radius: 9)), GzC.pink);
      case 'rush':
        c.drawLine(
          const Offset(6, 50),
          const Offset(74, 50),
          Paint()
            ..color = GzC.ink
            ..strokeWidth = 4,
        );
        canvas.save();
        canvas.translate(0, 6);
        _CarPainter(GzC.pink, true, false).paint(canvas, const Size(80, 48));
        canvas.restore();
      case 'survival':
        shape(
          Path()
            ..moveTo(40, 6)
            ..lineTo(64, 14)
            ..lineTo(62, 36)
            ..cubicTo(60, 48, 50, 56, 40, 60)
            ..cubicTo(30, 56, 20, 48, 18, 36)
            ..lineTo(16, 14)
            ..close(),
          Colors.white,
        );
        shape(_heart(const Offset(40, 33), 15), GzC.pink);
      case 'blitz':
        shape(Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(16, 6, 48, 54), const Radius.circular(8))), Colors.white);
        shape(Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(22, 12, 36, 12), const Radius.circular(3))), GzC.mint, 2);
        for (var r = 0; r < 2; r++) {
          for (var k = 0; k < 3; k++) {
            c.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(22.0 + k * 13, 30.0 + r * 13, 9, 9), const Radius.circular(2)),
              Paint()..color = r == 1 && k == 2 ? GzC.pink : GzC.navy,
            );
          }
        }
      case 'words':
        shape(Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(12, 12, 56, 42), const Radius.circular(6))), GzC.cream);
        c.drawLine(const Offset(40, 14), const Offset(40, 52), ink..strokeWidth = 2.5);
        for (final y in const <double>[24, 32, 40]) {
          c.drawLine(
            Offset(18, y),
            Offset(34, y),
            Paint()
              ..color = GzC.purple
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round,
          );
          c.drawLine(
            Offset(46, y),
            Offset(62, y),
            Paint()
              ..color = GzC.sub
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round,
          );
        }
        shape(
          Path()
            ..moveTo(52, 6)
            ..lineTo(70, 16)
            ..lineTo(60, 20)
            ..close(),
          GzC.red,
          2,
        );
      case 'memory':
        for (final (dx, rot, col) in const [(-12.0, -.22, GzC.blue), (0.0, 0.0, Colors.white), (12.0, .22, GzC.pink)]) {
          c.save();
          c.translate(40 + dx, 36);
          c.rotate(rot);
          shape(Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -18, 24, 34), const Radius.circular(5))), col);
          if (col == Colors.white) c.drawCircle(Offset.zero, 6, Paint()..color = GzC.brand);
          c.restore();
        }
      case 'reading':
        // An open book with a magnifying glass.
        shape(
          Path()
            ..moveTo(40, 16)
            ..cubicTo(32, 10, 18, 10, 8, 14)
            ..lineTo(8, 52)
            ..cubicTo(18, 48, 32, 48, 40, 54)
            ..close(),
          GzC.cream,
        );
        shape(
          Path()
            ..moveTo(40, 16)
            ..cubicTo(48, 10, 62, 10, 72, 14)
            ..lineTo(72, 52)
            ..cubicTo(62, 48, 48, 48, 40, 54)
            ..close(),
          Colors.white,
        );
        for (final y in const <double>[24, 31, 38]) {
          c.drawLine(
            Offset(15, y),
            Offset(33, y - 1),
            Paint()
              ..color = GzC.sub
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round,
          );
        }
        c.drawLine(const Offset(62, 50), const Offset(74, 62), ink..strokeWidth = 6);
        c.drawLine(
          const Offset(62, 50),
          const Offset(74, 62),
          Paint()
            ..color = GzC.goldDeep
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
        shape(Path()..addOval(Rect.fromCircle(center: const Offset(54, 38), radius: 12)), GzC.ice.withValues(alpha: .9));
        c.drawCircle(
          const Offset(54, 38),
          12,
          Paint()
            ..color = GzC.goldLight
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      case 'relay':
        c.save();
        c.translate(40, 34);
        c.rotate(-.6);
        shape(Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-28, -7, 56, 14), const Radius.circular(7))), GzC.goldLight);
        c.drawRect(const Rect.fromLTWH(-6, -7, 12, 14), Paint()..color = GzC.red);
        c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-28, -7, 56, 14), const Radius.circular(7)), ink);
        c.restore();
        for (final o in const [Offset(14, 14), Offset(66, 54)]) {
          c.drawCircle(o, 4, Paint()..color = Colors.white);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter o) => o.id != id;
}

Path _heart(Offset c, double r) => Path()
  ..moveTo(c.dx, c.dy + r * .95)
  ..cubicTo(c.dx - r * 1.3, c.dy + r * .1, c.dx - r * .9, c.dy - r * .95, c.dx, c.dy - r * .35)
  ..cubicTo(c.dx + r * .9, c.dy - r * .95, c.dx + r * 1.3, c.dy + r * .1, c.dx, c.dy + r * .95)
  ..close();

/// A heart for Survival (full or lost).
class HeartIcon2 extends StatelessWidget {
  const HeartIcon2({super.key, this.full = true, this.size = 22});
  final bool full;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _HeartPainter(full)),
  );
}

class _HeartPainter extends CustomPainter {
  _HeartPainter(this.full);
  final bool full;
  @override
  void paint(Canvas c, Size s) {
    final p = _heart(Offset(s.width / 2, s.height / 2), s.width * .42);
    c.drawPath(p, Paint()..color = full ? GzC.pink : GzC.ink.withValues(alpha: .6));
    if (full) c.drawCircle(Offset(s.width * .34, s.height * .36), s.width * .08, Paint()..color = Colors.white.withValues(alpha: .7));
    c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = full ? GzC.ink : GzC.line,
    );
  }

  @override
  bool shouldRepaint(_HeartPainter o) => o.full != full;
}
