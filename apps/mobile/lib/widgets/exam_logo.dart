import 'package:flutter/material.dart';

import '../core/providers.dart' show examLogosOn;
import '../theme/theme.dart';
import '../theme/tokens.g.dart';
import 'phosphor.g.dart';

/// Visible-content box of each owner-supplied PNG [x, y, w, h, imageW, imageH], measured from the alpha channel
/// (same numbers as prototype/js/core.js). The files keep transparent margins; we crop on screen so the logo
/// fills its slot. Files are never edited or redrawn (CLAUDE.md §1.7).
const _crop = {
  'JAMB': [69, 16, 115, 112, 246, 144],
  'WAEC': [95, 18, 339, 329, 554, 361],
  'NECO': [90, 41, 314, 314, 494, 404],
};

enum LogoSize { sm, md, lg, bare }

/// Exam-body logo slot (`.exam-logo`): white tile with a 1 px border, logo cropped to an inset of 9 %.
/// Sizes: sm 28, md 44, lg 64; [LogoSize.bare] is 60 with no tile (Test hero).
/// The official logos show only when the admin turns on `exam_logos` (after JAMB, WAEC and NECO give written
/// permission, D-111). Until then a SolutionTee badge is shown: an exam icon with the exam's name in plain text.
class ExamLogo extends StatelessWidget {
  const ExamLogo(this.code, {super.key, this.size = LogoSize.md, this.px});
  final String code;
  final LogoSize size;

  /// Override the box size in pixels (keeps the tile style).
  final double? px;

  @override
  Widget build(BuildContext context) {
    final upper = code.toUpperCase();
    if (!examLogosOn) return ExamBadge(upper, size: size, px: px);
    final box =
        px ??
        switch (size) {
          LogoSize.sm => 28.0,
          LogoSize.md => 44.0,
          LogoSize.lg => 64.0,
          LogoSize.bare => 60.0,
        };
    final bare = size == LogoSize.bare;
    final radius = switch (size) {
      LogoSize.sm => 7.0,
      LogoSize.lg => Radii.md,
      _ => Radii.sm,
    };
    final inner = bare ? box : box * .82;
    final crop = _crop[upper];
    final img = Image.asset(
      'assets/brand/exam-bodies/${upper.toLowerCase()}.png',
      semanticLabel: '$upper logo',
      errorBuilder: (_, _, _) => Center(
        child: Text(upper, style: context.t.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
      ),
    );
    Widget logo;
    if (crop == null) {
      logo = SizedBox(
        width: inner,
        height: inner,
        child: FittedBox(child: img),
      );
    } else {
      final [x, y, w, h, imgW, _] = crop;
      final m = (w > h ? w : h).toDouble();
      final scale = inner / m;
      logo = SizedBox(
        width: inner,
        height: inner,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [Positioned(left: (-x + (m - w) / 2) * scale, top: (-y + (m - h) / 2) * scale, width: imgW * scale, child: img)],
          ),
        ),
      );
    }
    if (bare) return logo;
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: context.c.border),
      ),
      child: logo,
    );
  }
}

/// Our own exam badge (no official logo): a coloured tile with an exam icon and the exam's name in plain text.
class ExamBadge extends StatelessWidget {
  const ExamBadge(this.code, {super.key, this.size = LogoSize.md, this.px});
  final String code;
  final LogoSize size;
  final double? px;

  static const _colors = {
    'JAMB': (Color(0xFF0B1F44), Color(0xFFF2B233)),
    'WAEC': (Color(0xFF14532D), Color(0xFFBBF7D0)),
    'NECO': (Color(0xFF2563B3), Color(0xFFFFFFFF)),
  };

  @override
  Widget build(BuildContext context) {
    final box =
        px ??
        switch (size) {
          LogoSize.sm => 28.0,
          LogoSize.md => 44.0,
          LogoSize.lg => 64.0,
          LogoSize.bare => 60.0,
        };
    final (bg, fg) = _colors[code] ?? (context.c.secondary, Colors.white);
    final radius = switch (size) {
      LogoSize.sm => 7.0,
      LogoSize.lg => Radii.md,
      _ => Radii.sm,
    };
    final small = box < 40;
    return Semantics(
      label: code,
      child: Container(
        width: box,
        height: box,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
        padding: EdgeInsets.all(box * .08),
        child: FittedBox(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!small) Icon(PhosphorIcons.graduationCap(PhosphorIconsStyle.fill), color: fg, size: 20),
              Text(
                code,
                style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12, height: 1.1, letterSpacing: .3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
