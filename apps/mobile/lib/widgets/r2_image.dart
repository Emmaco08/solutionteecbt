import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/api.dart';
import '../core/providers.dart';

typedef R2Ref = ({String key, String? itemId});

/// Bytes of a picture stored in R2 (study thumbnails and covers, news pictures). Data-light (D-057):
/// downloaded once through a short signed link, then kept in the phone's cache folder by its key (keys never
/// change: a new picture gets a new key), so lists never download the same picture twice.
/// Thumbnails and covers are signed through the study item ([itemId]); news pictures by key.
final r2BytesProvider = FutureProvider.family<Uint8List, R2Ref>((ref, a) async {
  final dir = await getApplicationCacheDirectory();
  final f = File('${dir.path}${Platform.pathSeparator}r2${Platform.pathSeparator}${a.key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}');
  if (await f.exists()) return f.readAsBytes();
  final api = ref.read(apiProvider);
  final url = a.itemId != null ? await api.studyFile(a.itemId!, 'cover') : await api.signImage(a.key);
  final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 40));
  if (r.statusCode != 200) throw ApiError('Could not load the picture.');
  await f.parent.create(recursive: true);
  await f.writeAsBytes(r.bodyBytes, flush: true);
  return r.bodyBytes;
});

/// Draws an R2 picture once it is ready (nothing while loading or on failure, so the gradient behind shows).
class R2Image extends ConsumerWidget {
  const R2Image({super.key, required this.imageKey, this.itemId, this.fit = BoxFit.cover, this.semanticLabel, this.decodeWidth = 720});
  final String imageKey;
  final String? itemId;
  final BoxFit fit;
  final String? semanticLabel;

  /// Decode at most this many pixels wide (saves memory on 3 GB phones).
  final int decodeWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(r2BytesProvider((key: imageKey, itemId: itemId))).value;
    if (bytes == null) return const SizedBox.shrink();
    return Image.memory(
      bytes,
      fit: fit,
      gaplessPlayback: true,
      cacheWidth: decodeWidth,
      semanticLabel: semanticLabel,
      frameBuilder: (_, child, frame, sync) =>
          sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 250), child: child),
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
