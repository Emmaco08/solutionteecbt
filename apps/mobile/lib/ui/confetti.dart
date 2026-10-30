import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../theme/tokens.g.dart';

/// One-shot confetti burst (prototype `ST.confetti`). Paint only, no package; skip it under reduce motion.
/// Light theme uses brand colours without white pieces; dark theme adds light pieces.
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.delay = Duration.zero, this.pieces = 70});
  final Duration delay;
  final int pieces;
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final _bits = List.generate(widget.pieces, (i) {
    final r = math.Random(i * 7919 + 13);
    return (
      x: r.nextDouble(),
      drift: r.nextDouble() - .5,
      speed: .55 + r.nextDouble() * .7,
      spin: r.nextDouble() * 8,
      size: 6 + r.nextDouble() * 6,
      color: i % 5,
      start: r.nextDouble() * .25,
    );
  });

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _ctl.forward();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = dark
        ? const [Palette.gold400, Color(0xFF7AA0D1), Color(0xFFF4F7FC), Palette.gold500, Color(0xFF4B86D4)]
        : const [Palette.gold400, Color(0xFF2563B3), Palette.navy900, Color(0xFF7AA0D1), Palette.gold500];
    if (context.reduceMotion) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, _) => _ctl.isAnimating ? CustomPaint(size: Size.infinite, painter: _Painter(_ctl.value, _bits, colors)) : const SizedBox.shrink(),
    );
  }
}

class _Painter extends CustomPainter {
  _Painter(this.t, this.bits, this.colors);
  final double t;
  final List<({double x, double drift, double speed, double spin, double size, int color, double start})> bits;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final b in bits) {
      final k = ((t - b.start) / (1 - b.start)).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final y = -20 + (size.height + 40) * (k * b.speed);
      final x = size.width * b.x + b.drift * 90 * k;
      p.color = colors[b.color].withValues(alpha: (1.2 - k).clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * k * math.pi);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * .55), const Radius.circular(1.5)), p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Painter old) => old.t != t;
}
