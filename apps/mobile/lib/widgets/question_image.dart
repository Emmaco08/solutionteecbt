import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'phosphor.g.dart';

import '../core/providers.dart';
import '../theme/theme.dart';
import '../theme/tokens.g.dart';

/// Short-lived signed link for an R2 question image (the server checks access first, D-045).
final _signedImage = FutureProvider.autoDispose.family<String, String>((ref, key) => ref.read(apiProvider).signImage(key));

/// A question diagram. With data saver on, the student taps to load it.
class QuestionImage extends ConsumerStatefulWidget {
  const QuestionImage({super.key, required this.imageKey});
  final String imageKey;
  @override
  ConsumerState<QuestionImage> createState() => _QuestionImageState();
}

class _QuestionImageState extends ConsumerState<QuestionImage> {
  bool _tapped = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget box(Widget child) => Container(
      constraints: const BoxConstraints(minHeight: 120),
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
        TextButton.icon(onPressed: () => setState(() => _tapped = true), icon: Icon(PhosphorIcons.image()), label: const Text('Tap to load the diagram')),
      );
    }
    final link = ref.watch(_signedImage(widget.imageKey));
    return link.when(
      loading: () => box(const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
      error: (e, _) => box(
        TextButton.icon(
          onPressed: () => ref.invalidate(_signedImage(widget.imageKey)),
          icon: Icon(PhosphorIcons.arrowClockwise()),
          label: Text(e.toString().contains('locked') ? 'This diagram is locked' : 'Could not load the diagram. Tap to retry'),
        ),
      ),
      data: (url) => ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: InteractiveViewer(
          maxScale: 4,
          child: Image.network(
            url,
            semanticLabel: 'Question diagram',
            loadingBuilder: (_, child, p) => p == null ? child : box(const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
            errorBuilder: (_, _, _) => box(
              TextButton.icon(
                onPressed: () => ref.invalidate(_signedImage(widget.imageKey)),
                icon: Icon(PhosphorIcons.arrowClockwise()),
                label: const Text('Could not load the diagram. Tap to retry'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
