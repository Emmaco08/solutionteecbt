import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/ads.dart';
import '../../core/api.dart';
import '../../core/providers.dart';
import '../../data/tests_repo.dart';
import '../../data/study_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/note_markdown.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../premium/content_offer.dart';
import 'study_widgets.dart';

/// Lesson notes grouped by subject. Built lazily (hundreds of notes): only the rows on screen are made.
class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});
  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  int? _subject;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final async = ref.watch(studyCatalogProvider('note'));
    final all = async.value ?? const [];
    final shown = [
      for (final n in all)
        if (_subject == null || n['subject_id'] == _subject) n,
    ];
    // Flatten into headers and rows so ListView.builder can build them one by one.
    final groups = <Object?, List<Map<String, dynamic>>>{};
    for (final n in shown) {
      groups.putIfAbsent(n['subject_id'], () => []).add(n);
    }
    final rows = <({Object? subject, Map<String, dynamic>? note, bool first, bool last, bool ad})>[];
    // Card ads (big update 2, step B) go after a subject group, about every N notes as the ads level says.
    final every = (ref.watch(adsConfigProvider).value ?? AdsConfig.off).nativeEvery;
    var seen = 0, nextAd = every;
    for (final e in groups.entries) {
      rows.add((subject: e.key, note: null, first: false, last: false, ad: false));
      for (final (i, n) in e.value.indexed) {
        final last = i == e.value.length - 1;
        seen++;
        final ad = every > 0 && last && seen >= nextAd && seen < shown.length;
        if (ad) nextAd = seen + every;
        rows.add((subject: e.key, note: n, first: i == 0, last: last, ad: ad));
      }
    }
    return Scaffold(
      appBar: const TopBar(title: 'Lesson notes'),
      body: async.hasError && all.isEmpty
          ? StateView.error(async.error!, onRetry: () => ref.invalidate(studyCatalogProvider('note')))
          : async.isLoading && all.isEmpty
          ? const ListSkeleton()
          : RefreshIndicator(
              onRefresh: () => ref.refresh(studyCatalogProvider('note').future),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
                itemCount: rows.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AdBanner(screen: 'notes'),
                        SubjectChips(subjectIds: subjectsIn(ref, all), value: _subject, onChanged: (v) => setState(() => _subject = v)),
                        if (shown.isEmpty)
                          StateBlock(
                            icon: PhosphorIcons.note(PhosphorIconsStyle.fill),
                            tone: Tone.gold,
                            title: 'No notes yet',
                            text: 'Our teachers are writing them. Check back soon.',
                          ),
                      ],
                    );
                  }
                  final r = rows[i - 1];
                  final n = r.note;
                  if (n == null) {
                    final name = subjectName(ref, r.subject);
                    return Padding(
                      padding: const EdgeInsets.only(top: Space.s5),
                      child: SectTitle(name.isEmpty ? 'General' : name),
                    );
                  }
                  const radius = Radius.circular(Radii.lg);
                  final row = Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border(
                        left: BorderSide(color: c.border),
                        right: BorderSide(color: c.border),
                        top: r.first ? BorderSide(color: c.border) : BorderSide.none,
                        bottom: BorderSide(color: c.border),
                      ),
                      borderRadius: BorderRadius.vertical(top: r.first ? radius : Radius.zero, bottom: r.last ? radius : Radius.zero),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListRow(
                      lead: IconTile(PhosphorIcons.note(PhosphorIconsStyle.fill), tone: Tone.gold),
                      title: plainTitle(n['title']),
                      caption: [n['subtitle'], '${(n['meta'] as Map?)?['minutes'] ?? 1} min read'].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                      trailing: n['locked'] == true ? const PremiumPill() : null,
                      onTap: () => openStudyItem(context, n),
                    ),
                  );
                  return r.ad
                      ? Column(
                          children: [
                            row,
                            AdNativeCard(placement: 'notes', key: ValueKey('ad-${n['id']}')),
                          ],
                        )
                      : row;
                },
              ),
            ),
    );
  }
}

/// Lesson note reader (prototype `note`): reading-progress bar, text size, bookmark, Markdown + maths.
/// Fast with many formulas: the note is parsed once, its blocks are built only when they scroll into view,
/// and scrolling only moves the progress bar (nothing else is rebuilt).
class NoteScreen extends ConsumerStatefulWidget {
  const NoteScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  final _scroll = ScrollController();
  final _read = ValueNotifier<double>(0);
  double _best = 0, _scale = 1;
  Timer? _debounce;
  late final StudyRepo _repo;
  Map<String, dynamic>? _item;
  NoteDoc? _doc;
  String? _docText;
  bool _offered = false;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(studyRepoProvider);
    _scroll.addListener(() {
      final p = _scroll.position;
      final r = p.maxScrollExtent <= 0 ? 1.0 : (p.pixels / p.maxScrollExtent).clamp(0.0, 1.0);
      if ((r - _read.value).abs() > .004) _read.value = r;
      if (r > _best) {
        // Reached the end of the note: a skippable "earn XP" video offer, once (ads level).
        if (_best < .97 && r >= .97 && !_offered && p.maxScrollExtent > 0) {
          _offered = true;
          offerEarnVideo(context, ref, 'note');
        }
        _best = r;
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 2), _save);
      }
    });
  }

  void _save() {
    final it = _item;
    if (it != null) _repo.saveProgress(it, _best);
  }

  @override
  void deactivate() {
    // Leaving a note the student read is a break (ads level: "after reading a note").
    if (_best > .3) Ads.instance.breakPoint(ref, 'note');
    super.deactivate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _save();
    _scroll.dispose();
    _read.dispose();
    super.dispose();
  }

  NoteDoc _parse(String text) {
    if (_doc == null || _docText != text) {
      _doc = NoteDoc.parse(text);
      _docText = text;
    }
    return _doc!;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studyItemProvider(widget.id));
    final it = async.value;
    _item = it;
    final err = async.error;
    final body = '${it?['body'] ?? ''}';
    final minutes = (body.length / 1100).round().clamp(1, 60);
    return Scaffold(
      appBar: TopBar(
        title: it == null ? 'Lesson note' : plainTitle(it['title']),
        subtitle: it == null ? null : '${subjectName(ref, it['subject_id'])} · $minutes min read',
        lined: true,
        actions: [
          IconBtn(
            PhosphorIcons.textAa(),
            label: 'Text size',
            onPressed: () {
              setState(() => _scale = _scale >= 1.3 ? 1 : _scale + .15);
              toast(context, 'Text size ${(_scale * 100).round()}%', icon: PhosphorIcons.textAa(PhosphorIconsStyle.fill));
            },
          ),
          if (it != null) BookmarkButton(kind: 'item', refId: 'note:${widget.id}', label: '${it['title']}'),
        ],
      ),
      body: err is ApiError && err.status == 402
          ? Center(
              child: SingleChildScrollView(
                child: StateBlock(
                  icon: PhosphorIcons.lockSimple(PhosphorIconsStyle.fill),
                  tone: Tone.gold,
                  title: 'Lesson notes are for Premium',
                  text: 'Your plan does not include this note. Go Premium to open every note, video and novel.',
                  action: Btn(
                    'See Premium plans',
                    kind: BtnKind.accent,
                    leading: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill),
                    onPressed: () => showContentOffer(
                      context,
                      kind: 'item',
                      itemRef: widget.id,
                      title: 'This lesson note',
                      paywallReason: 'note',
                      itemKind: 'note',
                      onOpened: () => ref.invalidate(studyItemProvider(widget.id)),
                    ),
                  ),
                ),
              ),
            )
          : err != null
          ? StateView.error(err, onRetry: () => ref.invalidate(studyItemProvider(widget.id)))
          : it == null
          ? const ListSkeleton(items: 7)
          : Column(
              children: [
                // Stays at the top while the student scrolls the note (ads level).
                const AdBanner(screen: 'notes'),
                Expanded(
                  child: Stack(
                    children: [
                      NoteView(
                        doc: _parse(body),
                        scale: _scale,
                        adEvery: (ref.watch(adsConfigProvider).value ?? AdsConfig.off).noteCardsEvery,
                        controller: _scroll,
                        footer: _CheckYourself(subjectId: (it['subject_id'] as num?)?.toInt(), topicId: (it['topic_id'] as num?)?.toInt()),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: ValueListenableBuilder<double>(
                          valueListenable: _read,
                          builder: (context, r, _) => Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: r,
                              child: Container(height: 3, color: context.c.accent),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CheckYourself extends ConsumerStatefulWidget {
  const _CheckYourself({this.subjectId, this.topicId});
  final int? subjectId, topicId;
  @override
  ConsumerState<_CheckYourself> createState() => _CheckYourselfState();
}

/// "Start a topic drill" builds the test at once with this note's subject and topic (owner, 2026-11-07):
/// 20 JAMB questions on the topic, 20 minutes; the setup screen only when the note has no topic.
class _CheckYourselfState extends ConsumerState<_CheckYourself> {
  bool _busy = false;

  Future<void> _start() async {
    final sid = widget.subjectId, tid = widget.topicId;
    if (sid == null || tid == null) {
      context.push('/test/setup?exam=JAMB&mode=topic');
      return;
    }
    setState(() => _busy = true);
    try {
      final sb = ref.read(supabaseProvider);
      final topic = await sb.from('topics').select('name').eq('id', tid).maybeSingle();
      final exams = await ref.read(examsProvider.future);
      final jamb = exams.firstWhere((e) => e['code'] == 'JAMB', orElse: () => exams.first);
      final name = topic?['name'] as String?;
      if (name == null) throw ApiError('This note has no topic questions yet.');
      final id = await ref
          .read(testsRepoProvider)
          .start(
            TestRequest(
              mode: TestMode.topic,
              examId: (jamb['id'] as num).toInt(),
              examCode: 'JAMB',
              subjectIds: [sid],
              topics: [name],
              count: 20,
              limitMinutes: 20,
              title: 'Topic drill · $name',
            ),
            countFor: (_) => 20,
            minutesPerQuestion: 1,
          );
      if (mounted) context.push('/cbt/$id');
    } catch (e) {
      if (mounted) {
        toast(
          context,
          e is ApiError ? e.message : 'Could not start the drill. Check your internet and try again.',
          icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.s6),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Check yourself', style: context.ty.body.bold),
          const Gap(Space.s1),
          Text('20 questions on this topic in 20 minutes.', style: context.ty.sm.col(context.c.textMuted)),
          const Gap(Space.s3),
          Btn('Start a topic drill', block: true, loading: _busy, onPressed: _busy ? null : _start),
        ],
      ),
    ),
  );
}

/// A whole note as a lazy list of blocks (headings, paragraphs, lists, tables, pictures, maths).
class NoteView extends StatelessWidget {
  const NoteView({super.key, required this.doc, this.scale = 1, this.controller, this.footer, this.shrinkWrap = false, this.adEvery = 0});
  final NoteDoc doc;
  final double scale;
  final ScrollController? controller;
  final Widget? footer;
  final bool shrinkWrap;

  /// Card ads between sections (ads level): before a heading once at least this many blocks were read since the last
  /// card (or after twice as many blocks when the note has few headings). 0 = none.
  final int adEvery;

  /// Where the card ads go: block indexes that get a card before them.
  static Set<int> adSpots(NoteDoc doc, int every) {
    final out = <int>{};
    if (every <= 0) return out;
    var since = 0;
    for (var i = 0; i < doc.blocks.length; i++) {
      final n = doc.blocks[i];
      final heading = n is md.Element && const {'h1', 'h2', 'h3'}.contains(n.tag);
      if (i > 0 && i < doc.blocks.length - 1 && ((heading && since >= every) || since >= every * 2)) {
        out.add(i);
        since = 0;
      }
      since++;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final style = NoteStyle(context, scale);
    final spots = adSpots(doc, adEvery);
    final n = doc.blocks.length + (footer == null ? 0 : 1);
    return ListView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: shrinkWrap ? EdgeInsets.zero : const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s8),
      itemCount: n,
      // Formulas are costly to lay out: keep a screen's worth ready above and below.
      scrollCacheExtent: const ScrollCacheExtent.pixels(600),
      itemBuilder: (context, i) {
        if (i == doc.blocks.length) return footer!;
        final block = NoteBlock(doc: doc, node: doc.blocks[i], style: style, first: i == 0);
        if (!spots.contains(i)) return block;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.s3),
              child: AdNativeCard(key: ValueKey('ad-note-$i'), placement: 'note_inside'),
            ),
            block,
          ],
        );
      },
    );
  }
}

/// Note text drawn in place (not scrolling by itself), e.g. inside another list or a test.
class NoteBody extends StatelessWidget {
  const NoteBody({super.key, required this.text, this.scale = 1});
  final String text;
  final double scale;
  @override
  Widget build(BuildContext context) => NoteView(doc: NoteDoc.parse(text), scale: scale, shrinkWrap: true);
}
