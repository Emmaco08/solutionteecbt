import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../data/study_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../premium/paywall.dart';
import 'study_widgets.dart';

/// Syllabus & brochure list (prototype `docs`). Free users see which documents are free; the rest open the paywall.
class DocsScreen extends ConsumerWidget {
  const DocsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studyCatalogProvider('doc'));
    final all = async.value ?? const [];
    final free = all.where((d) => d['locked'] != true).length;
    final rm = context.reduceMotion;
    return Scaffold(
      appBar: const TopBar(title: 'Syllabus & brochure'),
      body: async.hasError && all.isEmpty
          ? StateView.error(async.error!, onRetry: () => ref.invalidate(studyCatalogProvider('doc')))
          : async.isLoading && all.isEmpty
          ? const ListSkeleton()
          : all.isEmpty
          ? Center(
              child: StateBlock(
                icon: PhosphorIcons.filePdf(PhosphorIconsStyle.fill),
                tone: Tone.navy,
                title: 'No documents yet',
                text: 'Syllabuses and the JAMB brochure will show here.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
              children: [
                if (free < all.length) ...[
                  InfoBanner(
                    icon: PhosphorIcons.info(PhosphorIconsStyle.fill),
                    child: Text('Your plan includes $free document${free == 1 ? '' : 's'}. Upgrade to open every syllabus.'),
                  ),
                  const Gap(Space.s4),
                ],
                ListCard(
                  children: [
                    for (final d in all)
                      ListRow(
                        icon: PhosphorIcons.filePdf(PhosphorIconsStyle.fill),
                        title: plainTitle(d['title']),
                        caption: [
                          d['subtitle'],
                          if ((d['meta'] as Map?)?['pages'] != null) '${(d['meta'] as Map)['pages']} pages',
                        ].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                        trailing: d['locked'] == true ? const PremiumPill() : null,
                        onTap: () => openStudyItem(context, d),
                      ),
                  ],
                ).animate(target: rm ? 0 : 1).fadeIn(duration: Motion.base).slideY(begin: .04, end: 0),
              ],
            ),
    );
  }
}

/// PDF viewer (prototype `doc`): the file is fetched through a short signed link and kept in memory only.
class DocScreen extends ConsumerStatefulWidget {
  const DocScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<DocScreen> createState() => _DocScreenState();
}

class _DocScreenState extends ConsumerState<DocScreen> {
  PdfControllerPinch? _pdf;
  Object? _error;
  bool _topics = false, _noFile = false;
  final _page = ValueNotifier<int>(1);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _noFile = false;
    });
    try {
      final item = await ref.read(studyItemProvider(widget.id).future);
      if ((item['files'] as Map?)?['pdf'] != true) {
        setState(() => _noFile = true);
        return;
      }
      final url = await ref.read(studyRepoProvider).fileUrl(widget.id, 'pdf');
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
      if (r.statusCode != 200) throw ApiError('Could not download the PDF. Try again.');
      final ctl = PdfControllerPinch(document: PdfDocument.openData(r.bodyBytes));
      if (!mounted) {
        ctl.dispose();
        return;
      }
      setState(() => _pdf = ctl);
      ref.read(studyRepoProvider).saveProgress(item, .05);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiError ? e : ApiError('No internet connection. Check your data or Wi-Fi and try again.'));
    }
  }

  @override
  void dispose() {
    _pdf?.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final itemAsync = ref.watch(studyItemProvider(widget.id));
    final it = itemAsync.value;
    final err = _error ?? itemAsync.error;
    final data = Map<String, dynamic>.from((it?['data'] as Map?) ?? const {});
    final topics = [for (final t in (data['topics'] as List? ?? const [])) Map<String, dynamic>.from(t as Map)];
    final pages = _pdf?.pagesCount ?? (data['pages'] as num?)?.toInt();
    final size = megabytes(((it?['sizes'] as Map?)?['pdf']) as num?);
    final saver = ref.watch(settingsProvider).dataSaver;

    return Scaffold(
      appBar: TopBar(
        title: it == null ? 'Document' : plainTitle(it['title']),
        subtitle: ['PDF', if (pages != null) '$pages pages', if (size.isNotEmpty) size].join(' · '),
        lined: true,
        actions: [if (it != null) BookmarkButton(kind: 'item', refId: 'doc:${widget.id}', label: '${it['title']}')],
      ),
      body: err is ApiError && err.status == 402
          ? Center(
              child: SingleChildScrollView(
                child: StateBlock(
                  icon: PhosphorIcons.lockSimple(PhosphorIconsStyle.fill),
                  tone: Tone.gold,
                  title: 'This is part of Premium',
                  text: 'Go Premium to open every syllabus, brochure and book.',
                  action: Btn(
                    'See Premium plans',
                    kind: BtnKind.accent,
                    leading: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill),
                    onPressed: () => showPaywall(context, reason: 'doc'),
                  ),
                ),
              ),
            )
          : err != null
          ? StateView.error(err, onRetry: _load)
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      if (topics.isNotEmpty)
                        SizedBox(
                          width: 220,
                          child: Seg<bool>(value: _topics, items: const [(false, 'PDF'), (true, 'Topic list')], onChanged: (v) => setState(() => _topics = v)),
                        ),
                      const Spacer(),
                      if (pages != null)
                        ValueListenableBuilder<int>(
                          valueListenable: _page,
                          builder: (context, p, _) => Text('Page $p / $pages', style: context.ty.cap.tnum.col(c.textMuted)),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _topics
                      ? ListView(
                          padding: const EdgeInsets.all(Space.s4),
                          children: [
                            if (topics.isEmpty)
                              StateBlock(
                                icon: PhosphorIcons.listBullets(PhosphorIconsStyle.fill),
                                tone: Tone.neutral,
                                title: 'No topic list',
                                text: 'Scroll the PDF to read it.',
                              )
                            else
                              ListCard(
                                children: [
                                  for (final (i, t) in topics.indexed)
                                    ListRow(
                                      lead: Container(
                                        width: 40,
                                        height: 40,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(Radii.sm)),
                                        child: Text('${i + 1}', style: context.ty.sm.bold.col(c.onPrimarySoft)),
                                      ),
                                      title: '${t['title']}',
                                      caption: t['page'] == null ? null : 'Page ${t['page']}',
                                      onTap: t['page'] == null || _pdf == null
                                          ? null
                                          : () {
                                              setState(() => _topics = false);
                                              WidgetsBinding.instance.addPostFrameCallback((_) => _pdf?.jumpToPage((t['page'] as num).toInt()));
                                              toast(context, 'Jumped to page ${t['page']}', icon: PhosphorIcons.fileText(PhosphorIconsStyle.fill));
                                            },
                                    ),
                                ],
                              ),
                          ],
                        )
                      : _noFile
                      ? Center(
                          child: StateBlock(
                            icon: PhosphorIcons.filePdf(PhosphorIconsStyle.fill),
                            tone: Tone.neutral,
                            title: 'The PDF is not added yet',
                            text: topics.isEmpty ? 'Check back soon.' : 'You can still see the topic list.',
                          ),
                        )
                      : _pdf == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const Gap(Space.s3),
                              Text(saver && size.isNotEmpty ? 'Downloading $size…' : 'Opening the PDF…', style: context.ty.sm.col(c.textMuted)),
                            ],
                          ),
                        )
                      : Container(
                          color: c.surfaceSunken,
                          child: PdfViewPinch(
                            controller: _pdf!,
                            onPageChanged: (p) => _page.value = p,
                            backgroundDecoration: BoxDecoration(color: c.surfaceSunken),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
