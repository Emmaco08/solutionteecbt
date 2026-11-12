import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/theme.dart';

// Game Zone v2 (D-157) look: a real mobile-game style drawn in code (sharp on every phone, almost no download).
// Chunky outlined shapes, 3D buttons that press down, Lilita One for game words, the app font for small text.

abstract final class GzC {
  static const ink = Color(0xFF06132B); // outlines and deep shadows
  static const navy = Color(0xFF0B1F44);
  static const navy2 = Color(0xFF13284F);
  static const line = Color(0xFF2A3F62);
  static const gold = Color(0xFFFFC93C);
  static const goldLight = Color(0xFFFFD465);
  static const goldDeep = Color(0xFFB57D12);
  static const brand = Color(0xFFF2B233);
  static const blue = Color(0xFF2563B3);
  static const sky = Color(0xFF5887C5);
  static const red = Color(0xFFE0335A);
  static const pink = Color(0xFFF43F6B);
  static const green = Color(0xFF1FA463);
  static const mint = Color(0xFF3DDC84);
  static const purple = Color(0xFF7A4FD6);
  static const cyan = Color(0xFF22A6C4);
  static const ice = Color(0xFF8FE3F5);
  static const orange = Color(0xFFFF7A1A);
  static const cream = Color(0xFFFFF7E6);
  static const sub = Color(0xFFA7B4CA);
  static const subLight = Color(0xFFC9D6EA);
  static const wrong = Color(0xFF5A1D2E);

  /// Option colours A, B, C, D (always with white text and an ink outline).
  static const options = [blue, purple, cyan, red];
}

const kGameFont = 'LilitaOne';

/// Lilita One text with the ink drop shadow used everywhere in the Game Zone.
TextStyle gzFont(double size, {Color color = Colors.white, double shadow = 2, double spacing = .5, double? height}) => TextStyle(
  fontFamily: kGameFont,
  fontSize: size,
  color: color,
  letterSpacing: spacing,
  height: height,
  shadows: shadow > 0 ? [Shadow(color: GzC.ink, offset: Offset(0, shadow))] : null,
);

/// Small game-panel text in the app font.
TextStyle gzBody(double size, {Color color = Colors.white, FontWeight weight = FontWeight.w700, double? height}) =>
    TextStyle(fontFamily: kFont, fontSize: size, color: color, fontWeight: weight, height: height);

/// Big title with a thick ink outline ("VICTORY!", "+142 FAST!").
class OutlinedText extends StatelessWidget {
  const OutlinedText(this.text, {super.key, required this.size, this.color = Colors.white, this.stroke = 3, this.align = TextAlign.center, this.shadow = 4});
  final String text;
  final double size;
  final Color color;
  final double stroke;
  final double shadow;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontFamily: kGameFont, fontSize: size, letterSpacing: 1, height: 1.05);
    return Stack(
      children: [
        Transform.translate(
          offset: Offset(0, shadow),
          child: Text(
            text,
            textAlign: align,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = stroke * 2
                ..strokeJoin = StrokeJoin.round
                ..color = GzC.ink,
            ),
          ),
        ),
        Text(
          text,
          textAlign: align,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke * 2
              ..strokeJoin = StrokeJoin.round
              ..color = GzC.ink,
          ),
        ),
        Text(
          text,
          textAlign: align,
          style: base.copyWith(color: color),
        ),
      ],
    );
  }
}

/// The chunky 3D game button: ink outline, a solid "depth" under it, a light top edge. It presses down on touch.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.child,
    this.onTap,
    this.color = GzC.gold,
    this.depthColor,
    this.height = 56,
    this.radius = 18,
    this.depth = 6,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.glow,
    this.semantics,
    this.haptic = true,
  });
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color? depthColor;
  final double? height;
  final double radius;
  final double depth;
  final EdgeInsets padding;
  final Color? glow;
  final String? semantics;
  final bool haptic;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    final press = _down ? widget.depth - 2 : 0.0;
    final deep = widget.depthColor ?? Color.lerp(widget.color, GzC.ink, .55)!;
    final r = BorderRadius.circular(widget.radius);
    return Semantics(
      button: true,
      enabled: on,
      label: widget.semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: on
            ? () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        child: Padding(
          padding: EdgeInsets.only(bottom: widget.depth),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            curve: Curves.easeOut,
            height: widget.height,
            transform: Matrix4.translationValues(0, press, 0),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: r,
              border: Border.all(color: GzC.ink, width: 3),
              boxShadow: [
                BoxShadow(color: deep, offset: Offset(0, widget.depth - press)),
                BoxShadow(color: GzC.ink, offset: Offset(0, widget.depth - press), spreadRadius: 1.5),
                if (widget.glow != null) BoxShadow(color: widget.glow!.withValues(alpha: .55), blurRadius: 16),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.radius - 3),
              child: Stack(
                children: [
                  // Light top edge and a soft lower shade give the button its round, glossy look.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 7,
                    child: ColoredBox(color: Colors.white.withValues(alpha: on ? .28 : .14)),
                  ),
                  Positioned(left: 0, right: 0, bottom: 0, height: 6, child: ColoredBox(color: Colors.black.withValues(alpha: .1))),
                  Positioned.fill(
                    child: Padding(
                      padding: widget.padding,
                      child: Center(child: widget.child),
                    ),
                  ),
                  if (!on) Positioned.fill(child: ColoredBox(color: GzC.ink.withValues(alpha: .35))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dark glassy panel (no blur: plain colour, so scrolling stays smooth on 3 GB phones).
class GzPanel extends StatelessWidget {
  const GzPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color,
    this.border = GzC.line,
    this.radius = 18,
    this.shadow = true,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color border;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? GzC.ink.withValues(alpha: .82),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: 2),
      boxShadow: shadow ? const [BoxShadow(color: GzC.ink, offset: Offset(0, 4))] : null,
    ),
    child: child,
  );
}

/// A small label tag ("ROUND 5 · BIOLOGY").
class GzTag extends StatelessWidget {
  const GzTag(this.text, {super.key, this.color = GzC.blue, this.textColor = Colors.white, this.size = 14, this.border = GzC.ink});
  final String text;
  final Color color;
  final Color textColor;
  final Color border;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: size * .8, vertical: size * .22),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: border, width: 2.5),
      boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 3))],
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: gzFont(size, color: textColor, shadow: 0),
    ),
  );
}

// ---------------------------------------------------------------- the seven games

class GzGame {
  const GzGame(this.id, this.name, this.short, this.color, this.blurb, this.players, {this.dark = false});
  final String id;
  final String name;
  final String short;
  final Color color;
  final String blurb;
  final String players;

  /// Text on this card colour is navy (gold card).
  final bool dark;

  bool get isRace => id == 'rush' || id == 'blitz';
  bool get isSync => id == 'duel' || id == 'words' || id == 'survival' || id == 'relay';
  bool get group => id == 'survival' || id == 'relay' || id == 'rush';

  /// Games that use the student's JAMB subjects (the others have their own content).
  bool get needsSubject => id == 'duel' || id == 'survival' || id == 'relay' || id == 'rush';

  static const all = [
    GzGame('duel', 'JAMB Duel', 'JAMB\nDUEL', GzC.blue, 'Same question, same moment. The faster right answer scores more.', '1 v 1'),
    GzGame('rush', 'Speed Rush', 'SPEED\nRUSH', GzC.green, 'Each right answer drives your car on. First to 10 wins.', '2 to 6'),
    GzGame('survival', 'Knowledge Survival', 'SURVIVAL', GzC.red, '3 hearts each. Wrong or late costs a heart. Last one standing wins.', 'Up to 20'),
    GzGame('blitz', 'Maths Blitz', 'MATHS\nBLITZ', GzC.brand, '60 seconds of quick maths. Right answers in a row build your combo.', '1 v 1', dark: true),
    GzGame('words', 'Word War', 'WORD\nWAR', GzC.purple, 'Synonyms, opposites and spelling from JAMB Use of English.', '1 v 1'),
    GzGame('memory', 'Memory Flash', 'MEMORY\nFLASH', GzC.cyan, 'Remember the cards, then match them. Three levels.', '1 v 1'),
    GzGame('relay', 'Team Relay', 'TEAM\nRELAY', Color(0xFFFF7A1A), 'Two teams of 3. Every right answer adds to your team.', '3 v 3'),
  ];

  static GzGame of(String? id) => all.firstWhere((g) => g.id == id, orElse: () => all.first);
}

// ---------------------------------------------------------------- ranks

class GzRank {
  const GzRank(this.name, this.division, this.color, this.toNext, this.next, this.progress);
  final String name;
  final int division; // 3, 2, 1 (0 for Diamond)
  final Color color;
  final int toNext;
  final String next;
  final double progress;

  String get label => division == 0 ? name.toUpperCase() : '${name.toUpperCase()} ${['', 'I', 'II', 'III'][division]}';

  static const _tiers = [
    ('Bronze', 900, Color(0xFFCD7F4A)),
    ('Silver', 1100, Color(0xFFC9D6EA)),
    ('Gold', 1250, GzC.gold),
    ('Platinum', 1400, Color(0xFF6FE3D0)),
    ('Diamond', 1600, Color(0xFF8FB8FF)),
  ];

  static GzRank of(int rating) {
    var t = 0;
    for (var i = 0; i < _tiers.length; i++) {
      if (rating >= _tiers[i].$2) t = i;
    }
    final (name, start, color) = _tiers[t];
    if (t == _tiers.length - 1) return GzRank(name, 0, color, 0, '', 1);
    final end = _tiers[t + 1].$2;
    final width = (end - start) / 3;
    final r = math.max(rating, start);
    final step = ((r - start) / width).floor().clamp(0, 2);
    final division = 3 - step;
    final nextAt = division == 1 ? end : (start + width * (step + 1)).round();
    final next = division == 1 ? '${_tiers[t + 1].$1.toUpperCase()} III' : '${name.toUpperCase()} ${['', 'I', 'II', 'III'][division - 1]}';
    final lo = start + width * step;
    return GzRank(name, division, color, math.max(0, nextAt - rating), next, ((rating - lo) / width).clamp(0, 1).toDouble());
  }
}

/// A rank shield (tier colour, ink outline) with text inside, like the hub's level badge.
class RankShield extends StatelessWidget {
  const RankShield({super.key, required this.color, this.text = '', this.size = 50});
  final Color color;
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 1.12,
    child: CustomPaint(
      painter: _ShieldPainter(color),
      child: Padding(
        padding: EdgeInsets.only(bottom: size * .1),
        child: Center(
          child: FittedBox(
            child: Text(text, style: gzFont(size * .38, color: GzC.navy, shadow: 0)),
          ),
        ),
      ),
    ),
  );
}

class _ShieldPainter extends CustomPainter {
  _ShieldPainter(this.color);
  final Color color;

  Path _shield(Size s, double inset) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w / 2, inset)
      ..lineTo(w - inset, h * .17 + inset * .4)
      ..lineTo(w - inset * 1.4, h * .6)
      ..cubicTo(w * .86, h * .8, w * .68, h * .92, w / 2, h - inset)
      ..cubicTo(w * .32, h * .92, w * .14, h * .8, inset * 1.4, h * .6)
      ..lineTo(inset, h * .17 + inset * .4)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = _shield(size, 2);
    canvas.drawPath(outer, Paint()..color = color);
    canvas.drawPath(_shield(size, size.width * .14), Paint()..color = Color.lerp(color, Colors.white, .35)!);
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = GzC.ink,
    );
  }

  @override
  bool shouldRepaint(_ShieldPainter o) => o.color != color;
}

// ---------------------------------------------------------------- small helpers

String gzNum(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$b';
}

/// Haptics that follow the game moments (no sounds: they are off by default).
abstract final class GzFeel {
  static void tap() => HapticFeedback.selectionClick();
  static void right() => HapticFeedback.mediumImpact();
  static void wrong() => HapticFeedback.heavyImpact();
  static void win() => HapticFeedback.heavyImpact();
}

extension GzMotion on BuildContext {
  bool get calm => reduceMotion;
}
