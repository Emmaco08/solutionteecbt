import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Exam-body logo from /brand/exam-bodies (copied unchanged into assets/brand). Never redrawn (CLAUDE.md §1.7).
/// [bare] shows the logo without the white tile (Test hero, D-014).
class ExamLogo extends StatelessWidget {
  const ExamLogo(this.code, {super.key, this.size = 44, this.bare = false});
  final String code;
  final double size;
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final file = 'assets/brand/exam-bodies/${code.toLowerCase()}.png';
    final img = Image.asset(file, fit: BoxFit.contain, semanticLabel: '$code logo',
        errorBuilder: (_, _, _) => Center(child: Text(code, style: context.t.labelSmall?.copyWith(fontWeight: FontWeight.w700))));
    if (bare) return SizedBox(width: size, height: size, child: img);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .1),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * .25), border: Border.all(color: context.c.border)),
      child: img,
    );
  }
}
