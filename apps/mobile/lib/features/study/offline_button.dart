import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../data/offline_files.dart';
import '../../data/study_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../premium/paywall.dart';

/// Top-bar button on a video or PDF (A4, D-139): save it on this phone, see the progress (tap to stop), or remove it.
class OfflineButton extends ConsumerWidget {
  const OfflineButton({super.key, required this.item});
  final Map<String, dynamic> item;

  String get _id => '${item['id']}';
  bool get _pdf => item['kind'] == 'doc' || ((item['files'] as Map?)?['360'] != true && (item['files'] as Map?)?['pdf'] == true);

  int? _size(String file) => ((item['sizes'] as Map?)?[file] as num?)?.toInt();

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    if (!featureOn(ref, 'offline')) return showPaywall(context, reason: 'offline');
    final files = Map<String, dynamic>.from((item['files'] as Map?) ?? const {});
    String? file;
    if (_pdf) {
      file = 'pdf';
    } else if (files['720'] == true) {
      file = await showSheet<String>(
        context,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Save this video', style: context.ty.h3),
              const Gap(Space.s1),
              Text('It plays without data once saved.', style: context.ty.sm.col(context.c.textMuted)),
              const Gap(Space.s4),
              ListCard(
                children: [
                  for (final (q, label) in const [('360', 'Standard (360p)'), ('720', 'HD (720p)')])
                    ListRow(
                      icon: PhosphorIcons.downloadSimple(PhosphorIconsStyle.fill),
                      tone: q == '720' ? Tone.blue : Tone.green,
                      title: label,
                      caption: [if (q == '360') 'Uses less space', if (_size(q) != null) fileSize(_size(q)!)].join(' · '),
                      onTap: () => Navigator.of(context).pop(q),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      file = '360';
    }
    if (file == null || !context.mounted) return;
    // On mobile data, say how big it is first.
    final net = await Connectivity().checkConnectivity();
    if (!context.mounted) return;
    final wifi = net.contains(ConnectivityResult.wifi) || net.contains(ConnectivityResult.ethernet);
    final size = _size(file);
    if (!wifi && net.contains(ConnectivityResult.mobile)) {
      final ok = await showAppDialog<bool>(
        context,
        title: 'Use mobile data?',
        body: size == null ? 'This file may be large. Save it on Wi-Fi to save data.' : 'This file is ${fileSize(size)}. Save it on Wi-Fi to save data.',
        icon: PhosphorIcons.cellSignalLow(PhosphorIconsStyle.fill),
        actions: [
          Builder(
            builder: (ctx) => Btn('Not now', kind: BtnKind.ghost, onPressed: () => Navigator.pop(ctx, false)),
          ),
          Builder(builder: (ctx) => Btn('Save anyway', onPressed: () => Navigator.pop(ctx, true))),
        ],
      );
      if (ok != true || !context.mounted) return;
    }
    toast(context, 'Saving. You can keep studying while it downloads.', icon: PhosphorIcons.downloadSimple(PhosphorIconsStyle.fill));
    try {
      await ref.read(offlineFilesProvider.notifier).save(item, file);
      if (context.mounted && ref.read(offlineFilesProvider).containsKey(_id)) {
        toast(context, 'Saved. It now opens without data.', icon: PhosphorIcons.cloudCheck(PhosphorIconsStyle.fill));
      }
    } on ApiError catch (e) {
      if (!context.mounted) return;
      if (e.status == 402) return showPaywall(context, reason: 'offline');
      toast(context, e.message, icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
    }
  }

  Future<void> _manage(BuildContext context, WidgetRef ref, SavedFile s) async {
    final remove = await showSheet<bool>(
      context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconTile(PhosphorIcons.cloudCheck(PhosphorIconsStyle.fill), tone: Tone.green),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saved on this phone', style: context.ty.body.bold),
                      Text(
                        [if (s.isVideo) s.file == '720' ? 'HD video' : 'Video' else 'PDF', fileSize(s.bytes)].join(' · '),
                        style: context.ty.cap.col(context.c.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(Space.s5),
            Btn('Remove from phone', kind: BtnKind.outline, block: true, leading: PhosphorIcons.trash(), onPressed: () => Navigator.of(context).pop(true)),
          ],
        ),
      ),
    );
    if (remove != true) return;
    await ref.read(offlineFilesProvider.notifier).remove(s.id);
    if (context.mounted) toast(context, 'Removed from this phone', icon: PhosphorIcons.trash(PhosphorIconsStyle.fill));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final saved = ref.watch(offlineFilesProvider)[_id];
    final job = ref.watch(offlineJobsProvider)[_id];
    final files = (item['files'] as Map?) ?? const {};
    if (files['360'] != true && files['pdf'] != true) return const SizedBox.shrink();
    if (job != null) {
      return Semantics(
        button: true,
        label: 'Saving, ${job < 0 ? 'starting' : '${(job * 100).round()} percent'}. Tap to stop.',
        child: InkResponse(
          onTap: () => ref.read(offlineJobsProvider.notifier).cancel(_id),
          radius: 24,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(value: job < 0 ? null : job, strokeWidth: 2.5, color: c.secondary, backgroundColor: c.surfaceSunken),
                    Icon(PhosphorIcons.x(), size: 11, color: c.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (saved != null) {
      return IconBtn(PhosphorIcons.cloudCheck(PhosphorIconsStyle.fill), label: 'Saved on this phone', onPressed: () => _manage(context, ref, saved));
    }
    return IconBtn(PhosphorIcons.downloadSimple(), label: 'Save for offline', onPressed: () => _start(context, ref));
  }
}
