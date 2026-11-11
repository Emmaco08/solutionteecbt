import 'dart:convert';

import 'package:drift/drift.dart' show BooleanExpressionOperators, OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/offline_files.dart';
import '../../data/study_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import 'study_widgets.dart';

typedef _Paper = ({int exam, int subject, int year, int count, int bytes});

/// Videos, PDFs (saved with "Save for offline", D-139) and past papers on this phone. Downloads are a Premium feature;
/// the hub opens the paywall for Free. Papers are saved as you open them; this screen shows and removes them.
final _papersProvider = FutureProvider.autoDispose<List<_Paper>>((ref) async {
  final db = ref.watch(dbProvider);
  final rows = await (db.select(db.cachedQuestions)..orderBy([(q) => OrderingTerm.desc(q.year)])).get();
  final by = <String, _Paper>{};
  for (final q in rows) {
    final k = '${q.examId}/${q.subjectId}/${q.year}';
    final size =
        utf8.encode(q.body).length + utf8.encode(q.optionsJson).length + utf8.encode(q.explanation ?? '').length + utf8.encode(q.passageBody ?? '').length;
    final p = by[k];
    by[k] = (exam: q.examId, subject: q.subjectId, year: q.year, count: (p?.count ?? 0) + 1, bytes: (p?.bytes ?? 0) + size);
  }
  return by.values.toList();
});

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  Future<void> _remove(BuildContext context, WidgetRef ref, _Paper p) async {
    final db = ref.read(dbProvider);
    // Keep questions an unfinished test still needs.
    final open = await db.unfinishedAttempt();
    final keep = open == null ? <String>{} : (jsonDecode(open.questionIdsJson) as List).cast<String>().toSet();
    await (db.delete(
      db.cachedQuestions,
    )..where((q) => q.examId.equals(p.exam) & q.subjectId.equals(p.subject) & q.year.equals(p.year) & q.id.isNotIn(keep))).go();
    ref.invalidate(_papersProvider);
    if (context.mounted) toast(context, 'Removed from this phone', icon: PhosphorIcons.trash(PhosphorIconsStyle.fill));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(_papersProvider);
    final papers = async.value ?? const <_Paper>[];
    final files = ref.watch(offlineFilesProvider).values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final jobs = ref.watch(offlineJobsProvider);
    final exams = ref.watch(examsProvider).value ?? const [];
    String code(int id) => '${firstOr(exams, (e) => e['id'] == id)['code']}';
    final total = papers.fold<int>(0, (a, p) => a + p.bytes) + files.fold<int>(0, (a, f) => a + f.bytes);
    return Scaffold(
      appBar: const TopBar(title: 'Downloads'),
      body: async.hasError
          ? StateView.error(async.error!, onRetry: () => ref.invalidate(_papersProvider))
          : async.isLoading
          ? const ListSkeleton()
          : papers.isEmpty && files.isEmpty && jobs.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: StateBlock(
                  icon: PhosphorIcons.cloudCheck(PhosphorIconsStyle.fill),
                  tone: Tone.green,
                  title: 'Nothing on this phone yet',
                  text: 'Past papers you open are saved here. Tap the download button on a video or PDF to keep it too, and study without data.',
                  action: Btn('Browse past questions', onPressed: () => context.push('/study/pq')),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
              children: [
                Row(
                  children: [
                    Expanded(child: Text('On this phone', style: context.ty.label)),
                    Text('${(total / 1024 / 1024).toStringAsFixed(1)} MB used', style: context.ty.cap.col(c.textMuted)),
                  ],
                ),
                if (files.isNotEmpty || jobs.isNotEmpty) ...[
                  const Gap(Space.s4),
                  Text('VIDEOS AND PDFS', style: context.ty.over.col(c.textMuted)),
                  const Gap(Space.s2),
                  ListCard(
                    children: [
                      for (final id in jobs.keys)
                        ListRow(
                          lead: SizedBox(
                            width: 40,
                            height: 40,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: CircularProgressIndicator(value: jobs[id]! < 0 ? null : jobs[id], strokeWidth: 3, color: c.secondary),
                            ),
                          ),
                          title: 'Saving…',
                          caption: jobs[id]! < 0 ? 'Starting' : '${(jobs[id]! * 100).round()}%',
                          caret: false,
                          trailing: IconBtn(PhosphorIcons.x(), label: 'Stop', onPressed: () => ref.read(offlineJobsProvider.notifier).cancel(id)),
                        ),
                      for (final f in files)
                        ListRow(
                          lead: IconTile(
                            f.isVideo ? PhosphorIcons.playCircle(PhosphorIconsStyle.fill) : PhosphorIcons.filePdf(PhosphorIconsStyle.fill),
                            tone: f.isVideo ? Tone.blue : Tone.red,
                          ),
                          title: plainTitle(f.title),
                          caption: [
                            if (f.isVideo) f.file == '720' ? 'HD video' : 'Video' else 'PDF',
                            fileSize(f.bytes),
                            if (!openableOffline(f, DateTime.now())) 'connect once to open',
                          ].join(' · '),
                          onTap: () => context.push(f.isVideo ? '/study/video/${f.id}' : '/study/doc/${f.id}'),
                          trailing: IconBtn(
                            PhosphorIcons.trash(),
                            label: 'Remove download',
                            onPressed: () async {
                              await ref.read(offlineFilesProvider.notifier).remove(f.id);
                              if (context.mounted) toast(context, 'Removed from this phone', icon: PhosphorIcons.trash(PhosphorIconsStyle.fill));
                            },
                          ),
                        ),
                    ],
                  ),
                ],
                if (papers.isNotEmpty) ...[
                  const Gap(Space.s4),
                  Text('PAST PAPERS', style: context.ty.over.col(c.textMuted)),
                  const Gap(Space.s2),
                  ListCard(
                    children: [
                      for (final p in papers)
                        ListRow(
                          lead: IconTile(PhosphorIcons.cloudCheck(PhosphorIconsStyle.fill), tone: Tone.green),
                          title: '${code(p.exam)} ${p.year} ${subjectName(ref, p.subject)}',
                          caption: '${p.count} questions · ${(p.bytes / 1024).ceil()} KB',
                          onTap: () => context.push('/study/pq/${p.exam}/${p.subject}/${p.year}'),
                          trailing: IconBtn(PhosphorIcons.trash(), label: 'Remove download', onPressed: () => _remove(context, ref, p)),
                        ),
                    ],
                  ),
                ],
                const Gap(Space.s4),
                Text(
                  'Saved files stay inside the app. Premium files open without data for 30 days after the app last checked your plan online.',
                  style: context.ty.cap.col(c.textMuted),
                ),
              ],
            ),
    );
  }
}
