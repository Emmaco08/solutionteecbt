import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;

import '../core/providers.dart';
import '../theme/theme.dart';
import '../theme/tokens.g.dart';
import '../ui/kit.dart';
import 'phosphor.g.dart';
import 'question_image.dart';

/// A lesson note parsed once into blocks (D-056). Markdown (GitHub style: headings, lists, tables, tip boxes,
/// pictures) plus `$…$` / `$$…$$` maths. Maths is taken out before Markdown runs, so `_` and `*` inside a
/// formula are never read as italics, then put back as KaTeX. Same rule as the admin preview (lib/markdown.ts).
class NoteDoc {
  NoteDoc._(this.blocks, this._maths);
  final List<md.Node> blocks;
  final List<String> _maths;

  static final _math = RegExp(r'(\$\$[\s\S]+?\$\$|(?<!\\)\$[^$\n]+?(?<!\\)\$)');
  static const _open = '', _close = '';
  static final _token = RegExp('$_open(\\d+)$_close');

  /// AI models often write `\[ … \]` and `\( … \)` instead of `$$ … $$` and `$ … $`; both are accepted.
  static String normalizeMath(String s) => s
      .replaceAllMapped(RegExp(r'(?<!\\)\\\[([\s\S]+?)(?<!\\)\\\]'), (m) => '\$\$${m[1]}\$\$')
      .replaceAllMapped(RegExp(r'(?<!\\)\\\(([\s\S]+?)(?<!\\)\\\)'), (m) => '\$${m[1]!.trim()}\$');

  factory NoteDoc.parse(String text) {
    final maths = <String>[];
    final src = normalizeMath(text.replaceAll('\r\n', '\n')).replaceAllMapped(_math, (m) {
      maths.add(m.group(0)!);
      return '$_open${maths.length - 1}$_close';
    });
    final doc = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored, encodeHtml: false);
    return NoteDoc._(doc.parseLines(src.split('\n')), maths);
  }

  String? _onlyMath(String s) {
    final m = _token.firstMatch(s.trim());
    return m != null && m.group(0) == s.trim() ? _maths[int.parse(m.group(1)!)] : null;
  }
}

/// Style for one note: base size scales with the reader's text-size button.
class NoteStyle {
  NoteStyle(BuildContext context, this.scale) : c = context.c, body = context.ty.body.copyWith(fontSize: 16 * scale, height: 27 / 16);
  final AppColors c;
  final double scale;
  final TextStyle body;
  TextStyle get h2 => body.copyWith(fontSize: 19 * scale, height: 26 / 19, fontWeight: kBold);
  TextStyle get h3 => body.copyWith(fontSize: 17 * scale, height: 24 / 17, fontWeight: kBold);
  TextStyle get tip => body.copyWith(fontSize: 15 * scale, height: 23 / 15, color: c.onAccentSoft);
  TextStyle get small => body.copyWith(fontSize: 14 * scale, height: 20 / 14);
}

/// Draws one top-level block of a [NoteDoc]. Used by a lazy list, so off-screen formulas are never laid out.
class NoteBlock extends StatelessWidget {
  const NoteBlock({super.key, required this.doc, required this.node, required this.style, this.first = false});
  final NoteDoc doc;
  final md.Node node;
  final NoteStyle style;
  final bool first;

  @override
  Widget build(BuildContext context) => _block(context, node, style.body, first: first);

  Widget _block(BuildContext context, md.Node n, TextStyle base, {bool first = false}) {
    final s = style;
    if (n is md.Text) return _rich(context, [n], base);
    if (n is! md.Element) return const SizedBox.shrink();
    final kids = n.children ?? const <md.Node>[];
    switch (n.tag) {
      case 'h1' || 'h2':
        return Padding(
          padding: EdgeInsets.only(top: first ? 0 : Space.s6, bottom: Space.s2),
          child: _rich(context, kids, s.h2),
        );
      case 'h3' || 'h4' || 'h5' || 'h6':
        return Padding(
          padding: EdgeInsets.only(top: first ? 0 : Space.s4, bottom: Space.s2),
          child: _rich(context, kids, s.h3),
        );
      case 'p':
        // A paragraph that is only a picture or only a $$…$$ formula is drawn as a block.
        if (kids.length == 1 && kids.first is md.Element && (kids.first as md.Element).tag == 'img') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s2),
            child: _image(context, kids.first as md.Element),
          );
        }
        final only = kids.length == 1 && kids.first is md.Text ? doc._onlyMath((kids.first as md.Text).text) : null;
        if (only != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Space.s3),
            child: _displayMath(only, base),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: Space.s3),
          child: _rich(context, kids, base),
        );
      case 'blockquote':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: Space.s4),
          padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
          decoration: BoxDecoration(color: s.c.accentSoft, borderRadius: BorderRadius.circular(Radii.md)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final k in kids) _strip(_block(context, k, s.tip))]),
        );
      case 'ul' || 'ol':
        return Padding(
          padding: const EdgeInsets.only(bottom: Space.s3),
          child: _list(context, n, base, 0),
        );
      case 'table':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.s3),
          child: _table(context, n),
        );
      case 'pre':
        return Container(
          margin: const EdgeInsets.only(bottom: Space.s3),
          padding: const EdgeInsets.all(Space.s3),
          decoration: BoxDecoration(color: s.c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.md)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(n.textContent.trimRight(), style: s.small.copyWith(fontFamily: 'monospace')),
          ),
        );
      case 'hr':
        return Divider(height: Space.s6, color: s.c.border);
      case 'img':
        return _image(context, n);
      default:
        return _rich(context, kids, base);
    }
  }

  /// Removes the bottom gap of the last paragraph inside a tip box.
  Widget _strip(Widget w) => w is Padding && w.padding == const EdgeInsets.only(bottom: Space.s3) ? w.child! : w;

  Widget _list(BuildContext context, md.Element list, TextStyle base, int depth) {
    final ordered = list.tag == 'ol';
    final start = int.tryParse(list.attributes['start'] ?? '') ?? 1;
    final items = [
      for (final k in list.children ?? const <md.Node>[])
        if (k is md.Element && k.tag == 'li') k,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, li) in items.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 6, left: 4.0 + depth * 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: ordered ? 26 * style.scale : 18,
                  child: ordered
                      ? Text('${start + i}.', style: base.copyWith(fontWeight: kBold))
                      : Padding(
                          padding: EdgeInsets.only(top: 11 * style.scale),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: style.c.textMuted, shape: depth == 0 ? BoxShape.circle : BoxShape.rectangle),
                          ),
                        ),
                ),
                Expanded(child: _listItem(context, li, base, depth)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _listItem(BuildContext context, md.Element li, TextStyle base, int depth) {
    final kids = li.children ?? const <md.Node>[];
    final inline = <md.Node>[];
    final parts = <Widget>[];
    void flush() {
      if (inline.isNotEmpty) parts.add(_rich(context, List.of(inline), base));
      inline.clear();
    }

    for (final k in kids) {
      if (k is md.Element && (k.tag == 'ul' || k.tag == 'ol')) {
        flush();
        parts.add(Padding(padding: const EdgeInsets.only(top: 6), child: _list(context, k, base, depth + 1)));
      } else if (k is md.Element && k.tag == 'p') {
        flush();
        parts.add(_rich(context, k.children ?? const [], base));
      } else {
        inline.add(k);
      }
    }
    flush();
    return parts.length == 1 ? parts.first : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: parts);
  }

  Widget _table(BuildContext context, md.Element table) {
    final s = style;
    final rows = <List<md.Element>>[];
    final header = <int>{};
    for (final section in table.children ?? const <md.Node>[]) {
      if (section is! md.Element) continue;
      for (final tr in section.children ?? const <md.Node>[]) {
        if (tr is md.Element && tr.tag == 'tr') {
          if (section.tag == 'thead') header.add(rows.length);
          rows.add([
            for (final c in tr.children ?? const <md.Node>[])
              if (c is md.Element) c,
          ]);
        }
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - Space.s5 * 2),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder(
            horizontalInside: BorderSide(color: s.c.border),
            bottom: BorderSide(color: s.c.border),
          ),
          children: [
            for (final (i, r) in rows.indexed)
              TableRow(
                decoration: header.contains(i) ? BoxDecoration(color: s.c.surfaceSunken) : null,
                children: [
                  for (var c = 0; c < cols; c++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: c < r.length
                          ? ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: _rich(context, r[c].children ?? const [], header.contains(i) ? s.small.copyWith(fontWeight: kBold) : s.small),
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _image(BuildContext context, md.Element img) {
    final src = img.attributes['src'] ?? '';
    final alt = img.attributes['alt'] ?? '';
    if (!src.startsWith('n/')) return const SizedBox.shrink(); // only our own stored pictures
    return NoteImage(imageKey: src, alt: alt);
  }

  Widget _displayMath(String raw, TextStyle base) {
    final tex = raw.startsWith(r'$$') ? raw.substring(2, raw.length - 2) : raw.substring(1, raw.length - 1);
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(tex, mathStyle: MathStyle.display, textStyle: base, onErrorFallback: (_) => _mathError(raw, base)),
        ),
      ),
    );
  }

  Widget _mathError(String raw, TextStyle base) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(color: const Color(0x22D93A3A), borderRadius: BorderRadius.circular(4)),
    child: Text(
      raw,
      style: base.copyWith(fontFamily: 'monospace', fontSize: (base.fontSize ?? 15) * .9),
    ),
  );

  Widget _rich(BuildContext context, List<md.Node> nodes, TextStyle base) =>
      Text.rich(TextSpan(style: base, children: [for (final n in nodes) ..._spans(context, n, base)]));

  List<InlineSpan> _spans(BuildContext context, md.Node n, TextStyle st) {
    if (n is md.Text) return _textWithMath(n.text, st);
    if (n is! md.Element) return const [];
    final kids = n.children ?? const <md.Node>[];
    List<InlineSpan> all(TextStyle t) => [for (final k in kids) ..._spans(context, k, t)];
    return switch (n.tag) {
      'strong' => [
        TextSpan(
          style: const TextStyle(fontWeight: kBold),
          children: all(st.copyWith(fontWeight: kBold)),
        ),
      ],
      'em' => [
        TextSpan(
          style: const TextStyle(fontStyle: FontStyle.italic),
          children: all(st.copyWith(fontStyle: FontStyle.italic)),
        ),
      ],
      'del' => [
        TextSpan(
          style: const TextStyle(decoration: TextDecoration.lineThrough),
          children: all(st),
        ),
      ],
      'code' => [
        TextSpan(
          text: n.textContent,
          style: TextStyle(fontFamily: 'monospace', fontSize: (st.fontSize ?? 16) * .88, backgroundColor: style.c.surfaceSunken),
        ),
      ],
      'a' => [
        TextSpan(
          style: TextStyle(color: style.c.link),
          children: all(st),
        ),
      ],
      'br' => [const TextSpan(text: '\n')],
      'img' => [WidgetSpan(child: _image(context, n))],
      _ => all(st),
    };
  }

  /// Plain text with the maths placeholders turned back into KaTeX.
  List<InlineSpan> _textWithMath(String text, TextStyle st) {
    final out = <InlineSpan>[];
    var last = 0;
    for (final m in NoteDoc._token.allMatches(text)) {
      if (m.start > last) out.add(TextSpan(text: text.substring(last, m.start)));
      final raw = doc._maths[int.parse(m.group(1)!)];
      final display = raw.startsWith(r'$$');
      final tex = raw.substring(display ? 2 : 1, raw.length - (display ? 2 : 1));
      out.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(tex, mathStyle: display ? MathStyle.display : MathStyle.text, textStyle: st, onErrorFallback: (_) => _mathError(raw, st)),
        ),
      );
      last = m.end;
    }
    if (last < text.length) out.add(TextSpan(text: text.substring(last)));
    return out;
  }
}

/// A picture in a note: signed link from the website (it checks the student may open that note).
/// With data saver on, the student taps to load it.
class NoteImage extends ConsumerStatefulWidget {
  const NoteImage({super.key, required this.imageKey, this.alt = ''});
  final String imageKey, alt;
  @override
  ConsumerState<NoteImage> createState() => _NoteImageState();
}

class _NoteImageState extends ConsumerState<NoteImage> {
  bool _tapped = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget box(Widget child) => Container(
      constraints: const BoxConstraints(minHeight: 140),
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
    if (ref.watch(settingsProvider).dataSaver && !_tapped) {
      return box(
        TextButton.icon(onPressed: () => setState(() => _tapped = true), icon: Icon(PhosphorIcons.image()), label: const Text('Tap to load the picture')),
      );
    }
    final link = ref.watch(signedImageProvider(widget.imageKey));
    return link.when(
      loading: () => box(const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
      error: (e, _) => box(
        TextButton.icon(
          onPressed: () => ref.invalidate(signedImageProvider(widget.imageKey)),
          icon: Icon(PhosphorIcons.arrowClockwise()),
          label: const Text('Could not load the picture. Tap to retry'),
        ),
      ),
      data: (url) => ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: InteractiveViewer(
          maxScale: 4,
          child: Image.network(
            url,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            semanticLabel: widget.alt.isEmpty ? 'Picture' : widget.alt,
            loadingBuilder: (_, child, p) => p == null ? child : box(const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
            errorBuilder: (_, _, _) => box(
              TextButton.icon(
                onPressed: () => ref.invalidate(signedImageProvider(widget.imageKey)),
                icon: Icon(PhosphorIcons.arrowClockwise()),
                label: const Text('Could not load the picture. Tap to retry'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
