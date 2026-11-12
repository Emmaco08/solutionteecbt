import 'dart:math' as math;

import 'package:flutter/material.dart';

// Names in full (owner, 13 Nov 2026): a name is shown whole; when it is a little too long it is set slightly smaller
// (down to [minScale]) and only a really long name (three long names, say) still ends with "…". Layouts never break.

double _width(BuildContext context, String text, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final w = tp.width;
  tp.dispose();
  return w;
}

/// One line of text that shrinks a little before it ever cuts.
class FitText extends StatelessWidget {
  const FitText(this.text, {super.key, required this.style, this.minScale = .8, this.textAlign});
  final String text;
  final TextStyle style;
  final double minScale;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        var s = style;
        if (box.maxWidth.isFinite) {
          final w = _width(context, text, style);
          if (w > box.maxWidth && w > 0) {
            final scale = math.max(minScale, box.maxWidth / w * .995);
            s = style.copyWith(fontSize: (style.fontSize ?? 14) * scale);
          }
        }
        return Text(text, style: s, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, textAlign: textAlign);
      },
    );
  }
}

/// A name line for posts and replies: the name gets the room first (whole, or a little smaller), then the badge, the
/// @handle (cut first) and the time (always shown).
class NameLine extends StatelessWidget {
  const NameLine({super.key, required this.name, required this.nameStyle, this.badge, this.handle, this.time, required this.metaStyle, this.onName});
  final String name;
  final TextStyle nameStyle;
  final Widget? badge;
  final String? handle;
  final String? time;
  final TextStyle metaStyle;
  final VoidCallback? onName;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final max = box.maxWidth.isFinite ? box.maxWidth : 400.0;
        final timeText = time == null || time!.isEmpty ? '' : ' · $time';
        final timeW = timeText.isEmpty ? 0.0 : _width(context, timeText, metaStyle) + 1;
        final badgeW = badge == null ? 0.0 : 20.0;
        // The handle keeps at least a short stub ("@em…") when there is room.
        final handleMin = handle == null ? 0.0 : math.min(_width(context, '@$handle', metaStyle), 44.0);
        final nameRoom = math.max(40.0, max - timeW - badgeW - handleMin - 4);
        final nameW = _width(context, name, nameStyle);
        final scale = nameW <= nameRoom ? 1.0 : math.max(.85, nameRoom / nameW * .995);
        final style = scale == 1 ? nameStyle : nameStyle.copyWith(fontSize: (nameStyle.fontSize ?? 15) * scale);
        final shownW = math.min(nameRoom, nameW * scale + 1);
        Widget nameText = SizedBox(
          width: shownW,
          child: Text(name, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
        );
        if (onName != null) nameText = GestureDetector(onTap: onName, child: nameText);
        return Row(
          children: [
            nameText,
            if (badge != null) ...[const SizedBox(width: 4), badge!],
            if (handle != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('@$handle', style: metaStyle, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
                ),
              ),
            if (timeText.isNotEmpty) Text(timeText, style: metaStyle, maxLines: 1, softWrap: false),
          ],
        );
      },
    );
  }
}
