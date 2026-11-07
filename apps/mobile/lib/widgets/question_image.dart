import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'phosphor.g.dart';

import '../core/image_cache.dart';

import '../core/providers.dart';
import '../theme/theme.dart';
import '../theme/tokens.g.dart';

/// Short-lived signed link for an R2 image (question diagram or news picture; the server checks access first, D-045).
final signedImageProvider = FutureProvider.autoDispose.family<String, String>((ref, key) => ref.read(apiProvider).signImage(key));

/// The picture saved on the phone before the test (big update 2, A12), if any.
final savedImageProvider = FutureProvider.autoDispose.family((ref, String key) => QuestionImageCache.file(key));

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
    final saved = ref.watch(savedImageProvider(widget.imageKey));
    if (saved.isLoading) return box(const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)));
    final file = saved.value;
    if (file != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: InteractiveViewer(
          maxScale: 4,
          child: Image.file(file, semanticLabel: 'Question diagram', errorBuilder: (_, _, _) => box(Icon(PhosphorIcons.image()))),
        ),
      );
    }
    if (ref.watch(settingsProvider).dataSaver && !_tapped) {
      return box(
        TextButton.icon(onPressed: () => setState(() => _tapped = true), icon: Icon(PhosphorIcons.image()), label: const Text('Tap to load the diagram')),
      );
    }
    final link = ref.watch(signedImageProvider(widget.imageKey));
    return link.when(
      loading: () => box(const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
      error: (e, _) => box(
        TextButton.icon(
          onPressed: () => ref.invalidate(signedImageProvider(widget.imageKey)),
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
                onPressed: () => ref.invalidate(signedImageProvider(widget.imageKey)),
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
