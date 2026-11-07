import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads.dart';
import '../../core/api.dart';
import '../../data/study_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import 'note_screens.dart' show NoteBody;
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../premium/content_offer.dart';
import 'study_widgets.dart';

/// Recommended novels (prototype `novels`): a featured text, then a grid of covers.
class NovelsScreen extends ConsumerWidget {
  const NovelsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studyCatalogProvider('novel'));
    final all = async.value ?? const [];
    final progress = ref.watch(studyProgressProvider).value ?? const [];
    final rm = context.reduceMotion;
    double done(Object? id) => ((firstOr(progress, (p) => p['item_id'] == id)['progress'] as num?) ?? 0).toDouble();
    return Scaffold(
      appBar: const TopBar(title: 'Recommended novels'),
      body: async.hasError && all.isEmpty
          ? StateView.error(async.error!, onRetry: () => ref.invalidate(studyCatalogProvider('novel')))
          : async.isLoading && all.isEmpty
          ? const ListSkeleton(items: 3)
          : all.isEmpty
          ? Center(
              child: StateBlock(
                icon: PhosphorIcons.books(PhosphorIconsStyle.fill),
                tone: Tone.red,
                title: 'No novels yet',
                text: 'The set texts for your exams will show here.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
              children: [
                const AdBanner(screen: 'novels'),
                if (all.any((n) => '${n['title']}'.startsWith('[SAMPLE]'))) ...[
                  InfoBanner(
                    kind: BannerKind.warn,
                    icon: PhosphorIcons.info(PhosphorIconsStyle.fill),
                    child: const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'SAMPLE. ',
                            style: TextStyle(fontWeight: kBold),
                          ),
                          TextSpan(text: 'The JAMB novel is not chosen yet. These are placeholders.'),
                        ],
                      ),
                    ),
                  ),
                  const Gap(Space.s5),
                ],
                _Featured(n: all.first, done: done(all.first['id'])),
                if (all.length > 1) ...[
                  const Gap(Space.s5),
                  const SectTitle('More texts'),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: Space.s3,
                    mainAxisSpacing: Space.s4,
                    childAspectRatio: .58,
                    children: [
                      for (final (i, n) in all.skip(1).indexed)
                        Pressable(
                          onTap: () => openStudyItem(context, n),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  BookCover(
                                    title: '${n['title']}',
                                    index: i + 1,
                                    coverKey: (n['meta'] as Map?)?['cover'] as String?,
                                    itemId: n['id'] as String,
                                  ),
                                  if (n['locked'] == true) const Positioned(top: 6, right: 6, child: TileLock()),
                                ],
                              ),
                              const Gap(Space.s2),
                              Text(
                                '${(n['meta'] as Map?)?['author'] ?? n['subtitle'] ?? ''}',
                                style: context.ty.cap.bold,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ).animate(target: rm ? 0 : 1).fadeIn(delay: (50 * i).ms, duration: Motion.base),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _Featured extends StatelessWidget {
  const _Featured({required this.n, required this.done});
  final Map<String, dynamic> n;
  final double done;
  @override
  Widget build(BuildContext context) {
    final meta = Map<String, dynamic>.from((n['meta'] as Map?) ?? const {});
    final chapters = (meta['chapters'] as num?)?.toInt() ?? 0;
    return AppCard(
      onTap: () => openStudyItem(context, n),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookCover(title: '${n['title']}', width: 96, coverKey: meta['cover'] as String?, itemId: n['id'] as String),
            const Gap(Space.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Pill('Featured text', kind: BadgeKind.gold),
                      const Spacer(),
                      if (n['locked'] == true) const TileLock(),
                    ],
                  ),
                  const Gap(Space.s2),
                  Text(plainTitle(n['title']), style: context.ty.body.bold),
                  const Gap(Space.s1),
                  Text(
                    ['${meta['author'] ?? ''}', if (chapters > 0) '$chapters chapters', 'Summary · themes · characters'].where((x) => x.isNotEmpty).join(' · '),
                    style: context.ty.cap.col(context.c.textMuted),
                  ),
                  const Spacer(),
                  if (done > 0) ...[
                    const Gap(Space.s2),
                    ProgressBar(done),
                    const Gap(Space.s1),
                    Text('${(done * 100).round()}% read', style: context.ty.cap.col(context.c.textMuted)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Novel detail (prototype `novel`): Summary · Chapters · Themes · Characters.
class NovelScreen extends ConsumerStatefulWidget {
  const NovelScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<NovelScreen> createState() => _NovelScreenState();
}

class _NovelScreenState extends ConsumerState<NovelScreen> {
  String _tab = 'Summary';
  Set<int>? _read;

  Future<void> _openChapter(Map<String, dynamic> it, List<Map<String, dynamic>> chapters, int i) async {
    final ch = chapters[i];
    final read = {...?_read, i};
    setState(() => _read = read);
    ref.read(studyRepoProvider).saveProgress(it, chapters.isEmpty ? 0 : read.length / chapters.length, position: {'read': read.toList()..sort()});
    final next = await showSheet<bool>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chapter ${i + 1}', style: ctx.ty.over),
          const Gap(Space.s1),
          Text('${ch['title']}', style: ctx.ty.h2),
          const Gap(Space.s3),
          Text('${ch['summary'] ?? ''}', style: ctx.ty.body.copyWith(height: 26 / 15)),
          const Gap(Space.s5),
          if (i < chapters.length - 1)
            Btn(
              'Next chapter',
              block: true,
              icon: PhosphorIcons.arrowRight(),
              onPressed: () {
                Navigator.of(ctx).pop(true);
                _openChapter(it, chapters, i + 1);
              },
            ),
        ],
      ),
    );
    // Closing a chapter (not going on to the next) is a break.
    if (next != true && mounted) Ads.instance.breakPoint(ref, 'note');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final async = ref.watch(studyItemProvider(widget.id));
    final it = async.value;
    final err = async.error;
    final data = Map<String, dynamic>.from((it?['data'] as Map?) ?? const {});
    List<Map<String, dynamic>> list(String k) => [for (final x in (data[k] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    final chapters = list('chapters'), themes = list('themes'), characters = list('characters');
    if (it != null && _read == null) {
      final p = firstOr((ref.watch(studyProgressProvider).value ?? const []), (p) => p['item_id'] == widget.id);
      final r = ((p['position'] as Map?)?['read'] as List?) ?? const [];
      _read = {for (final x in r) (x as num).toInt()};
    }
    final read = _read ?? const <int>{};

    return Scaffold(
      appBar: TopBar(
        title: 'Novel',
        actions: [if (it != null) BookmarkButton(kind: 'item', refId: 'novel:${widget.id}', label: '${it['title']}')],
      ),
      body: err is ApiError && err.status == 402
          ? Center(
              child: SingleChildScrollView(
                child: StateBlock(
                  icon: PhosphorIcons.lockSimple(PhosphorIconsStyle.fill),
                  tone: Tone.gold,
                  title: 'Novels are for Premium',
                  text: 'Your plan does not include novel summaries. Go Premium to open them.',
                  action: Btn(
                    'See Premium plans',
                    kind: BtnKind.accent,
                    leading: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill),
                    onPressed: () => showContentOffer(
                      context,
                      kind: 'item',
                      itemRef: widget.id,
                      title: 'This novel',
                      paywallReason: 'novel',
                      itemKind: 'novel',
                      onOpened: () => ref.invalidate(studyItemProvider(widget.id)),
                    ),
                  ),
                ),
              ),
            )
          : err != null
          ? StateView.error(err, onRetry: () => ref.invalidate(studyItemProvider(widget.id)))
          : it == null
          ? const ListSkeleton(items: 5)
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
              children: [
                const AdBanner(screen: 'novels'),
                Row(
                  children: [
                    BookCover(
                      title: '${it['title']}',
                      width: 88,
                      coverKey: (firstOr(ref.watch(studyCatalogProvider('novel')).value, (n) => n['id'] == widget.id)['meta'] as Map?)?['cover'] as String?,
                      itemId: widget.id,
                    ),
                    const Gap(Space.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ('${it['title']}'.startsWith('[SAMPLE]')) ...[const Pill('SAMPLE', kind: BadgeKind.sample), const Gap(Space.s1)],
                          Text(plainTitle(it['title']), style: context.ty.h2),
                          Text(
                            ['${data['author'] ?? ''}', if (chapters.isNotEmpty) '${chapters.length} chapters'].where((x) => x.isNotEmpty).join(' · '),
                            style: context.ty.sm.col(c.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if ((it['files'] as Map?)?['pdf'] == true) ...[
                  const Gap(Space.s4),
                  Btn(
                    'Read the book',
                    block: true,
                    leading: PhosphorIcons.bookOpenText(PhosphorIconsStyle.fill),
                    onPressed: () => context.push('/study/doc/${widget.id}'),
                  ),
                ],
                const Gap(Space.s5),
                Seg<String>(
                  value: _tab,
                  items: const [('Summary', 'Summary'), ('Chapters', 'Chapters'), ('Themes', 'Themes'), ('Characters', 'People')],
                  onChanged: (v) => setState(() => _tab = v),
                ),
                const Gap(Space.s4),
                ...switch (_tab) {
                  'Chapters' => [
                    if (chapters.isEmpty) Text('Chapters will be added soon.', style: context.ty.sm.col(c.textMuted)),
                    if (chapters.isNotEmpty)
                      ListCard(
                        children: [
                          for (final (i, ch) in chapters.indexed)
                            ListRow(
                              lead: read.contains(i)
                                  ? IconTile(PhosphorIcons.check(PhosphorIconsStyle.fill), tone: Tone.green)
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(Radii.sm)),
                                      child: Text('${i + 1}', style: context.ty.sm.bold.col(c.onPrimarySoft)),
                                    ),
                              title: '${ch['title']}',
                              caption: read.contains(i) ? 'Read' : 'Summary',
                              onTap: () => _openChapter(it, chapters, i),
                            ),
                        ],
                      ),
                  ],
                  'Themes' => [
                    if (themes.isEmpty) Text('Themes will be added soon.', style: context.ty.sm.col(c.textMuted)),
                    for (final t in themes) ...[
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${t['title']}', style: context.ty.sm.bold),
                            if ('${t['text'] ?? ''}'.isNotEmpty) ...[const Gap(Space.s2), Text('${t['text']}', style: context.ty.sm.col(c.textMuted))],
                          ],
                        ),
                      ),
                      const Gap(Space.s3),
                    ],
                  ],
                  'Characters' => [
                    if (characters.isEmpty) Text('Characters will be added soon.', style: context.ty.sm.col(c.textMuted)),
                    if (characters.isNotEmpty)
                      ListCard(
                        children: [
                          for (final p in characters) ListRow(lead: Avatar('${p['name']}', size: 40), title: '${p['name']}', caption: '${p['text'] ?? ''}'),
                        ],
                      ),
                  ],
                  _ => [
                    if ('${it['body'] ?? ''}'.trim().isEmpty)
                      Text('A summary will be added soon.', style: context.ty.sm.col(c.textMuted))
                    else
                      NoteBody(text: '${it['body']}'),
                  ],
                },
              ],
            ),
    );
  }
}
