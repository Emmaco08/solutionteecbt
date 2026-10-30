import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Text with LaTeX: `$...$` inline and `$$...$$` on its own line (KaTeX syntax).
/// A formula that fails to parse is shown as plain source in a highlighted box instead of crashing.
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, this.style, this.textAlign = TextAlign.start, this.bold = false});
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Also turn `**bold**` into bold text (lesson notes).
  final bool bold;

  static final _re = RegExp(r'(\$\$[\s\S]+?\$\$|(?<!\\)\$[^$\n]+?(?<!\\)\$)');

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _re.allMatches(text)) {
      if (m.start > last) spans.addAll(_plain(text.substring(last, m.start)));
      final raw = m.group(0)!;
      final display = raw.startsWith(r'$$');
      final tex = raw.substring(display ? 2 : 1, raw.length - (display ? 2 : 1));
      final math = Math.tex(
        tex,
        mathStyle: display ? MathStyle.display : MathStyle.text,
        textStyle: base,
        onErrorFallback: (err) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(color: const Color(0x22D93A3A), borderRadius: BorderRadius.circular(4)),
          child: Text(
            raw,
            style: base.copyWith(fontFamily: 'monospace', fontSize: (base.fontSize ?? 15) * .9),
          ),
        ),
      );
      spans.add(
        display
            ? WidgetSpan(
                child: SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: math),
                  ),
                ),
              )
            : WidgetSpan(alignment: PlaceholderAlignment.middle, child: math),
      );
      last = m.end;
    }
    if (last < text.length) spans.addAll(_plain(text.substring(last)));
    return Text.rich(
      TextSpan(style: base, children: spans),
      textAlign: textAlign,
    );
  }

  static String _unescape(String s) => s.replaceAll(r'\$', r'$');

  List<InlineSpan> _plain(String s) {
    if (!bold || !s.contains('**')) return [TextSpan(text: _unescape(s))];
    final parts = s.split('**');
    return [
      for (var i = 0; i < parts.length; i++)
        if (parts[i].isNotEmpty)
          TextSpan(
            text: _unescape(parts[i]),
            style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
    ];
  }
}
