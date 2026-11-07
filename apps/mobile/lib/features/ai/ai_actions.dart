import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';

/// Long-press menu for a tutor reply (U3b): a floating reaction bar and the actions Copy, Reply, Ask again, Report.

/// The six reactions the server accepts.
const aiReactions = ['❤️', '👍', '😂', '😮', '🙏', '👎'];

/// The first 120 characters of a reply, on one line, for the quote above the composer.
String aiQuoteOf(String text) {
  final plain = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return plain.length > 120 ? '${plain.substring(0, 120).trimRight()}…' : plain;
}

/// Splits "> quote\n\nmy text" into (quote, my text). The quote is null when the text has none.
(String?, String) aiSplitQuote(String text) {
  if (!text.startsWith('> ')) return (null, text);
  final i = text.indexOf('\n\n');
  if (i < 0) return (null, text);
  final quote = text.substring(2, i).replaceAll(RegExp(r'\n> ?'), ' ').trim();
  return (quote.isEmpty ? null : quote, text.substring(i + 2).trim());
}

/// Shows the menu near [at]. Returns "react:" plus the emoji, "copy", "reply", "again", "report" or null.
Future<String?> showAiActions(BuildContext context, {required Offset at, String? current, bool canReport = true, bool canAskAgain = true}) =>
    showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close menu',
      barrierColor: Colors.black38,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, _) => _AiActions(at: at, current: current, canReport: canReport, canAskAgain: canAskAgain),
    );

class _AiActions extends StatelessWidget {
  const _AiActions({required this.at, required this.current, required this.canReport, required this.canAskAgain});
  final Offset at;
  final String? current;
  final bool canReport, canAskAgain;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final rm = context.reduceMotion;
    final top = (at.dy - 90).clamp(pad.top + 8, (size.height - 330).clamp(pad.top + 8, size.height));
    Widget bar = Material(
      color: c.surface,
      elevation: 6,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(99),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, e) in aiReactions.indexed)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: rm ? 1 : .2, end: 1),
                duration: rm ? Duration.zero : Duration(milliseconds: 260 + i * 45),
                curve: Curves.easeOutBack,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Semantics(
                  button: true,
                  label: 'React $e',
                  child: InkResponse(
                    onTap: () => Navigator.of(context).pop('react:$e'),
                    radius: 24,
                    child: Container(
                      width: 44,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: current == e ? BoxDecoration(color: c.accentSoft, shape: BoxShape.circle) : null,
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (!rm) {
      bar = TweenAnimationBuilder<double>(
        tween: Tween(begin: .6, end: 1),
        duration: Motion.slow,
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.scale(
          scale: v,
          alignment: Alignment.bottomLeft,
          child: Opacity(opacity: v.clamp(0, 1), child: child),
        ),
        child: bar,
      );
    }
    final actions = Material(
      color: c.surface,
      elevation: 6,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(Radii.lg),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 230,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Item(icon: PhosphorIcons.copy(), label: 'Copy', value: 'copy'),
            _Item(icon: PhosphorIcons.quotes(), label: 'Reply', value: 'reply'),
            if (canAskAgain) _Item(icon: PhosphorIcons.arrowClockwise(), label: 'Ask again', value: 'again'),
            if (canReport) _Item(icon: PhosphorIcons.flag(), label: 'Report', value: 'report', danger: true),
          ],
        ),
      ),
    );
    return Stack(
      children: [
        Positioned(
          top: top.toDouble(),
          left: Space.s4,
          right: Space.s4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: bar),
              const Gap(Space.s2),
              actions,
            ],
          ),
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, required this.value, this.danger = false});
  final IconData icon;
  final String label, value;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = danger ? c.error : c.text;
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sizes.tapMin),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: col),
              const Gap(Space.s3),
              Text(label, style: context.ty.body.col(col)),
            ],
          ),
        ),
      ),
    );
  }
}
