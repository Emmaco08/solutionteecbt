import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../widgets/r2_image.dart';
import '../../widgets/fit_text.dart';
import 'gz_theme.dart';

// Players in the Game Zone (owner, D-157): the student's real photo when they have one (and allow it), otherwise the
// avatar they built. Bots get their own avatar and a BOT tag.

/// A built avatar (stored in community_profiles.game_avatar).
class GzLook {
  const GzLook({
    this.skin = const Color(0xFF8D5524),
    this.hair = 'afro',
    this.hairColor = const Color(0xFF1A1206),
    this.shirt = GzC.blue,
    this.face = 'grin',
    this.glasses = false,
    this.bg = const Color(0xFF5887C5),
    this.photo = true,
  });

  final Color skin;
  final String hair;
  final Color hairColor;
  final Color shirt;
  final String face;
  final bool glasses;
  final Color bg;

  /// Use the real photo when there is one.
  final bool photo;

  static const skins = [Color(0xFF3B2214), Color(0xFF5C3A1E), Color(0xFF8D5524), Color(0xFFC68642), Color(0xFFE0AC69), Color(0xFFF1C27D)];
  static const hairs = ['afro', 'puffs', 'bun', 'braids', 'low', 'fade', 'cap', 'hijab'];
  static const hairNames = {
    'afro': 'Afro',
    'puffs': 'Puffs',
    'bun': 'Bun',
    'braids': 'Braids',
    'low': 'Low cut',
    'fade': 'Fade',
    'cap': 'Cap',
    'hijab': 'Hijab',
  };
  static const hairColors = [Color(0xFF1A1206), Color(0xFF3B1F0E), Color(0xFF5A3210), Color(0xFF8C5A2B), Color(0xFF7A4FD6), Color(0xFFE0335A)];
  static const shirts = [GzC.blue, GzC.red, GzC.green, GzC.purple, GzC.cyan, GzC.brand, Color(0xFFFF7A1A), GzC.navy];
  static const faces = ['grin', 'smile', 'cool', 'focus'];
  static const faceNames = {'grin': 'Big smile', 'smile': 'Smile', 'cool': 'Cool', 'focus': 'Focused'};
  static const bgs = [Color(0xFF5887C5), Color(0xFF7A4FD6), Color(0xFF1FA463), Color(0xFFE0335A), Color(0xFFF2B233), Color(0xFF22A6C4)];

  static Color? _hex(Object? v) {
    final s = '${v ?? ''}';
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(s)) return null;
    return Color(int.parse('FF${s.substring(1)}', radix: 16));
  }

  static String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  factory GzLook.from(Object? json) {
    final j = json is Map ? json : const {};
    return GzLook(
      skin: _hex(j['skin']) ?? const Color(0xFF8D5524),
      hair: hairs.contains(j['hair']) ? '${j['hair']}' : 'afro',
      hairColor: _hex(j['hairColor']) ?? const Color(0xFF1A1206),
      shirt: _hex(j['shirt']) ?? GzC.blue,
      face: faces.contains(j['face']) ? '${j['face']}' : 'grin',
      glasses: j['glasses'] == true,
      bg: _hex(j['bg']) ?? const Color(0xFF5887C5),
      photo: j['photo'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'skin': hex(skin),
    'hair': hair,
    'hairColor': hex(hairColor),
    'shirt': hex(shirt),
    'face': face,
    'glasses': glasses,
    'bg': hex(bg),
    'photo': photo,
  };

  GzLook copyWith({Color? skin, String? hair, Color? hairColor, Color? shirt, String? face, bool? glasses, Color? bg, bool? photo}) => GzLook(
    skin: skin ?? this.skin,
    hair: hair ?? this.hair,
    hairColor: hairColor ?? this.hairColor,
    shirt: shirt ?? this.shirt,
    face: face ?? this.face,
    glasses: glasses ?? this.glasses,
    bg: bg ?? this.bg,
    photo: photo ?? this.photo,
  );

  @override
  bool operator ==(Object other) => other is GzLook && other.toJson().toString() == toJson().toString();

  @override
  int get hashCode => toJson().toString().hashCode;
}

/// A player's picture as the server sends it: {photo, preset, has_photo}.
class GzFace {
  const GzFace({this.photo, this.look = const GzLook(), this.hasPhoto = false});
  final String? photo;
  final GzLook look;
  final bool hasPhoto;

  factory GzFace.from(Object? json) {
    final j = json is Map ? json : const {};
    final p = '${j['photo'] ?? ''}';
    return GzFace(photo: p.isEmpty ? null : p, look: GzLook.from(j['preset']), hasPhoto: j['has_photo'] == true);
  }
}

/// The round game portrait: a thick ring, an ink outline and a light rim, the photo or the avatar inside.
class GzPortrait extends StatelessWidget {
  const GzPortrait({super.key, required this.face, this.size = 64, this.ring = GzC.gold, this.name = '', this.bot = false, this.dim = false, this.mood});
  final GzFace face;
  final double size;
  final Color ring;
  final String name;
  final bool bot;

  /// Knocked out / left: drawn grey.
  final bool dim;

  /// Overrides the avatar's face for game moments ("grin" after a right answer, "focus" while thinking).
  final String? mood;

  @override
  Widget build(BuildContext context) {
    final ringW = (size * .07).clamp(2.5, 7.0);
    final inner = size - ringW * 2 - 4;
    Widget pic = face.photo != null
        ? Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: CartoonPainter(face.look, mood: mood)),
              R2Image.face(imageKey: face.photo!, decodeWidth: (size * 2.5).round(), semanticLabel: name),
            ],
          )
        : CustomPaint(painter: CartoonPainter(face.look, mood: mood));
    if (dim) {
      pic = ColorFiltered(colorFilter: const ColorFilter.matrix([.33, .33, .33, 0, 0, .33, .33, .33, 0, 0, .33, .33, .33, 0, 0, 0, 0, 0, .7, 0]), child: pic);
    }
    return Semantics(
      label: name.isEmpty ? null : (bot ? '$name, SolutionTee Bot' : name),
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GzC.ink,
                boxShadow: [BoxShadow(color: GzC.ink, offset: Offset(0, size * .05))],
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: dim ? GzC.sub : ring),
                padding: EdgeInsets.all(ringW),
                child: Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: GzC.ink),
                  padding: const EdgeInsets.all(1.5),
                  child: ClipOval(
                    child: SizedBox(width: inner, height: inner, child: pic),
                  ),
                ),
              ),
            ),
            if (bot)
              Positioned(
                bottom: -size * .06,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: size * .08, vertical: 1),
                    decoration: BoxDecoration(
                      color: GzC.cyan,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: GzC.ink, width: 2),
                    ),
                    child: Text('BOT', style: gzFont((size * .17).clamp(9, 14), shadow: 0)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The avatar, head and shoulders, drawn from the approved character art (viewBox 120 × 130).
class CartoonPainter extends CustomPainter {
  CartoonPainter(this.look, {this.mood});
  final GzLook look;
  final String? mood;

  static const ink = GzC.ink;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -.3),
          radius: .9,
          colors: [Color.lerp(look.bg, Colors.white, .25)!, look.bg, Color.lerp(look.bg, GzC.ink, .35)!],
          stops: const [0, .6, 1],
        ).createShader(rect),
    );
    final k = size.width / 120;
    canvas.save();
    canvas.scale(k, size.height / 120);
    canvas.translate(0, 8);
    _draw(canvas);
    canvas.restore();
  }

  Paint _fill(Color c) => Paint()..color = c;
  Paint _line([double w = 3]) => Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _shape(Canvas c, Path p, Color color, [double w = 3]) {
    c.drawPath(p, _fill(color));
    c.drawPath(p, _line(w));
  }

  void _draw(Canvas c) {
    final skin = look.skin;
    final hair = look.hairColor;
    final face = mood ?? look.face;

    // Hair behind the head.
    switch (look.hair) {
      case 'afro':
        c.drawCircle(const Offset(60, 40), 35, _fill(hair));
        c.drawCircle(const Offset(60, 40), 35, _line());
        for (final o in const [Offset(34, 30), Offset(86, 30), Offset(60, 9)]) {
          c.drawCircle(o, 9.5, _fill(hair));
        }
      case 'puffs':
        for (final o in const [Offset(26, 26), Offset(94, 26)]) {
          c.drawCircle(o, 16, _fill(hair));
          c.drawCircle(o, 16, _line());
        }
        _shape(c, Path()..addOval(Rect.fromCenter(center: const Offset(60, 38), width: 62, height: 52)), hair);
      case 'bun':
        c.drawCircle(const Offset(60, 10), 12.5, _fill(hair));
        c.drawCircle(const Offset(60, 10), 12.5, _line());
        _shape(
          c,
          Path()
            ..moveTo(28, 50)
            ..cubicTo(26, 22, 44, 14, 60, 14)
            ..cubicTo(76, 14, 94, 22, 92, 50)
            ..close(),
          hair,
        );
      case 'braids':
        for (final x in const [(30.0, 24.0), (90.0, 96.0)]) {
          c.drawLine(Offset(x.$1, 46), Offset(x.$2, 100), _line(10));
          final dash = Paint()
            ..color = hair
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round;
          for (var t = 0.0; t < 1; t += .16) {
            final a = Offset.lerp(Offset(x.$1, 46), Offset(x.$2, 100), t)!;
            final b = Offset.lerp(Offset(x.$1, 46), Offset(x.$2, 100), t + .09)!;
            c.drawLine(a, b, dash);
          }
        }
        _shape(
          c,
          Path()
            ..moveTo(28, 50)
            ..cubicTo(26, 22, 44, 12, 60, 12)
            ..cubicTo(76, 12, 94, 22, 92, 50)
            ..close(),
          hair,
        );
      case 'hijab':
        _shape(
          c,
          Path()
            ..moveTo(18, 128)
            ..cubicTo(16, 96, 22, 18, 60, 14)
            ..cubicTo(98, 18, 104, 96, 102, 128)
            ..close(),
          hair,
        );
      case 'low':
      case 'fade':
      case 'cap':
        _shape(
          c,
          Path()
            ..moveTo(30, 46)
            ..cubicTo(30, 22, 44, 16, 60, 16)
            ..cubicTo(76, 16, 90, 22, 90, 46)
            ..close(),
          look.hair == 'cap' ? GzC.navy : hair,
        );
    }

    // Shoulders, shirt, collar, tie, neck.
    final shirt = look.shirt;
    _shape(
      c,
      Path()
        ..moveTo(18, 134)
        ..cubicTo(18, 106, 34, 92, 60, 92)
        ..cubicTo(86, 92, 102, 106, 102, 134)
        ..close(),
      look.hair == 'hijab' ? Color.lerp(shirt, GzC.ink, .1)! : shirt,
    );
    if (look.hair != 'hijab') {
      _shape(
        c,
        Path()
          ..moveTo(42, 97)
          ..cubicTo(48, 104, 72, 104, 78, 97)
          ..lineTo(72, 112)
          ..lineTo(60, 104)
          ..lineTo(48, 112)
          ..close(),
        Colors.white,
        2.5,
      );
      _shape(
        c,
        Path()
          ..moveTo(56, 106)
          ..lineTo(64, 106)
          ..lineTo(66, 126)
          ..lineTo(60, 132)
          ..lineTo(54, 126)
          ..close(),
        shirt == GzC.brand ? GzC.navy : GzC.brand,
        2.5,
      );
    }
    c.drawLine(
      const Offset(30, 118),
      const Offset(40, 126),
      Paint()
        ..color = Colors.black.withValues(alpha: .16)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    _shape(c, Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(52, 80, 16, 16), const Radius.circular(6))), skin);

    // Ears and head.
    if (look.hair != 'hijab') {
      for (final x in const [31.0, 89.0]) {
        _shape(c, Path()..addOval(Rect.fromCenter(center: Offset(x, 58), width: 10, height: 14)), skin);
      }
    }
    _shape(c, Path()..addOval(Rect.fromCenter(center: const Offset(60, 54), width: 58, height: 62)), skin);

    // Hair in front of the head.
    switch (look.hair) {
      case 'low':
        c.drawPath(
          Path()
            ..moveTo(33, 40)
            ..cubicTo(38, 28, 50, 24, 60, 24)
            ..cubicTo(70, 24, 82, 28, 87, 40)
            ..cubicTo(78, 34, 70, 33, 60, 33)
            ..cubicTo(50, 33, 42, 34, 33, 40)
            ..close(),
          _fill(hair),
        );
      case 'fade':
        _shape(
          c,
          Path()
            ..moveTo(32, 42)
            ..cubicTo(32, 26, 44, 20, 60, 20)
            ..cubicTo(76, 20, 88, 26, 88, 42)
            ..cubicTo(80, 34, 70, 32, 60, 32)
            ..cubicTo(50, 32, 40, 34, 32, 42)
            ..close(),
          hair,
          2.5,
        );
      case 'cap':
        _shape(
          c,
          Path()
            ..moveTo(30, 40)
            ..cubicTo(32, 18, 48, 12, 62, 12)
            ..cubicTo(78, 12, 90, 20, 90, 38)
            ..close(),
          GzC.navy,
        );
        _shape(
          c,
          Path()
            ..moveTo(56, 34)
            ..cubicTo(72, 30, 92, 32, 104, 40)
            ..cubicTo(90, 44, 70, 42, 56, 40)
            ..close(),
          GzC.navy2,
        );
        c.drawCircle(const Offset(60, 22), 5, _fill(GzC.brand));
      case 'afro':
      case 'puffs':
        c.drawPath(
          Path()
            ..moveTo(34, 40)
            ..cubicTo(38, 26, 50, 22, 60, 22)
            ..cubicTo(70, 22, 82, 26, 86, 40)
            ..cubicTo(76, 32, 66, 30, 60, 31)
            ..cubicTo(52, 30, 42, 33, 34, 40)
            ..close(),
          _fill(hair),
        );
      case 'hijab':
        c.drawPath(
          Path()
            ..addOval(Rect.fromCenter(center: const Offset(60, 54), width: 64, height: 68))
            ..addOval(Rect.fromCenter(center: const Offset(60, 56), width: 54, height: 58))
            ..fillType = PathFillType.evenOdd,
          _fill(hair),
        );
        c.drawOval(Rect.fromCenter(center: const Offset(60, 56), width: 54, height: 58), _line(2.5));
    }

    // Face.
    // Brows: soft arches; "focus" sets them level and a little lower (determined, not cross).
    if (face == 'focus') {
      c.drawLine(const Offset(42, 41), const Offset(53, 40), _line(3.5));
      c.drawLine(const Offset(78, 41), const Offset(67, 40), _line(3.5));
    } else {
      c.drawPath(
        Path()
          ..moveTo(41, 41)
          ..quadraticBezierTo(47, 35, 53, 39),
        _line(3.5),
      );
      c.drawPath(
        Path()
          ..moveTo(79, 41)
          ..quadraticBezierTo(73, 35, 67, 39),
        _line(3.5),
      );
    }
    for (final x in const [48.0, 72.0]) {
      final eye = Rect.fromCenter(center: Offset(x, 54), width: 14, height: face == 'cool' ? 11 : 17);
      c.drawOval(eye, _fill(Colors.white));
      c.drawOval(eye, _line(2.5));
      c.drawCircle(Offset(x + 1.5, 55.5), 4.2, _fill(const Color(0xFF1A1206)));
      c.drawCircle(Offset(x + 3, 53.5), 1.6, _fill(Colors.white));
      if (face == 'cool') c.drawLine(Offset(x - 7, 50), Offset(x + 7, 50), _line(2.5));
    }
    if (look.glasses) {
      c.drawCircle(const Offset(48, 54), 11, _line());
      c.drawCircle(const Offset(72, 54), 11, _line());
      c.drawLine(const Offset(59, 54), const Offset(61, 54), _line());
    }
    final blush = _fill(const Color(0xFFF43F6B).withValues(alpha: .35));
    c.drawOval(Rect.fromCenter(center: const Offset(40, 66), width: 10, height: 6), blush);
    c.drawOval(Rect.fromCenter(center: const Offset(80, 66), width: 10, height: 6), blush);
    switch (face) {
      case 'grin':
        _shape(
          c,
          Path()
            ..moveTo(48, 68)
            ..cubicTo(52, 78, 68, 78, 72, 68)
            ..close(),
          const Color(0xFF7A1F2B),
          2.5,
        );
        c.drawPath(
          Path()
            ..moveTo(51, 69)
            ..lineTo(69, 69)
            ..lineTo(68, 72)
            ..lineTo(52, 72)
            ..close(),
          _fill(Colors.white),
        );
      case 'smile':
        c.drawPath(
          Path()
            ..moveTo(50, 69)
            ..quadraticBezierTo(60, 77, 70, 69),
          _line(3),
        );
      case 'cool':
        c.drawPath(
          Path()
            ..moveTo(52, 71)
            ..quadraticBezierTo(62, 74, 70, 67),
          _line(3),
        );
      default:
        // Focused: a small, sure smile.
        c.drawPath(
          Path()
            ..moveTo(53, 70)
            ..quadraticBezierTo(60, 73, 67, 69),
          _line(3),
        );
    }
    // Shine.
    c.drawPath(
      Path()
        ..moveTo(38, 38)
        ..cubicTo(44, 30, 54, 28, 60, 28),
      Paint()
        ..color = Colors.white.withValues(alpha: .25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(CartoonPainter o) => o.look != look || o.mood != mood;
}

/// A portrait with its name plate under it (VS screen, lobby, results).
class GzPlayerBadge extends StatelessWidget {
  const GzPlayerBadge({
    super.key,
    required this.face,
    required this.name,
    this.size = 72,
    this.ring = GzC.gold,
    this.bot = false,
    this.sub,
    this.dim = false,
    this.mood,
  });
  final GzFace face;
  final String name;
  final double size;
  final Color ring;
  final bool bot;
  final String? sub;
  final bool dim;
  final String? mood;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      GzPortrait(face: face, size: size, ring: ring, name: name, bot: bot, dim: dim, mood: mood),
      SizedBox(height: bot ? 10 : 6),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: size * 1.6),
        child: FitText(name.toUpperCase(), textAlign: TextAlign.center, style: gzFont((size * .2).clamp(11, 22)), minScale: .7),
      ),
      if (sub != null)
        Text(
          sub!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: gzBody(11, color: GzC.subLight),
        ),
    ],
  );
}

/// Pops a portrait in (lobby joins, VS screen).
extension GzPop on Widget {
  Widget popIn({Duration delay = Duration.zero, bool calm = false}) =>
      calm ? this : animate(delay: delay).scale(begin: const Offset(.4, .4), duration: 420.ms, curve: Curves.elasticOut).fadeIn(duration: 160.ms);
}
