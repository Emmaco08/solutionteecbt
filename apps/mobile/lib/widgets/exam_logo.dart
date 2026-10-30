import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../theme/tokens.g.dart';

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
class ExamLogo extends StatelessWidget {
  const ExamLogo(this.code, {super.key, this.size = LogoSize.md, this.px});
  final String code;
  final LogoSize size;

  /// Override the box size in pixels (keeps the tile style).
  final double? px;

  @override
  Widget build(BuildContext context) {
    final upper = code.toUpperCase();
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
