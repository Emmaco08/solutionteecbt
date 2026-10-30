import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../data/study_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/math_text.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../premium/paywall.dart';
import 'study_widgets.dart';

/// Lesson notes grouped by subject.
class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});
  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  int? _subject;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studyCatalogProvider('note'));
    final all = async.value ?? const [];
    final shown = [
      for (final n in all)
        if (_subject == null || n['subject_id'] == _subject) n,
    ];
    final groups = <Object?, List<Map<String, dynamic>>>{};
    for (final n in shown) {
      groups.putIfAbsent(n['subject_id'], () => []).add(n);
    }
    final rm = context.reduceMotion;
    return Scaffold(
      appBar: const TopBar(title: 'Lesson notes'),
      body: async.hasError && all.isEmpty
          ? StateView.error(async.error!, onRetry: () => ref.invalidate(studyCatalogProvider('note')))
          : async.isLoading && all.isEmpty
          ? const ListSkeleton()
          : RefreshIndicator(
              onRefresh: () => ref.refresh(studyCatalogProvider('note').future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
                children: [
                  SubjectChips(subjectIds: subjectsIn(ref, all), value: _subject, onChanged: (v) => setState(() => _subject = v)),
                  if (shown.isEmpty)
                    StateBlock(
                      icon: PhosphorIcons.note(PhosphorIconsStyle.fill),
                      tone: Tone.gold,
                      title: 'No notes yet',
                      text: 'Our teachers are writing them. Check back soon.',
                    ),
                  for (final (gi, e) in groups.entries.indexed) ...[
                    const Gap(Space.s5),
                    SectTitle(subjectName(ref, e.key).isEmpty ? 'General' : subjectName(ref, e.key)),
                    ListCard(
                      children: [
                        for (final n in e.value)
                          ListRow(
                            lead: IconTile(PhosphorIcons.note(PhosphorIconsStyle.fill), tone: Tone.gold),
                            title: plainTitle(n['title']),
                            caption: [n['subtitle'], '${(n['meta'] as Map?)?['minutes'] ?? 1} min read'].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                            trailing: n['locked'] == true ? const PremiumPill() : null,
                            onTap: () => openStudyItem(context, n),
                          ),
                      ],
                    ).animate(target: rm ? 0 : 1).fadeIn(delay: (60 * gi).ms, duration: Motion.base),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Lesson note reader (prototype `note`): reading-progress bar, text size, bookmark, maths.
class NoteScreen extends ConsumerStatefulWidget {
  const NoteScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  final _scroll = ScrollController();
  double _read = 0, _best = 0, _scale = 1;
  Timer? _debounce;
  late final StudyRepo _repo;
  Map<String, dynamic>? _item;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(studyRepoProvider);
    _scroll.addListener(() {
      final p = _scroll.position;
      final r = p.maxScrollExtent <= 0 ? 1.0 : (p.pixels / p.maxScrollExtent).clamp(0.0, 1.0);
      if ((r - _read).abs() > .005) setState(() => _read = r);
      if (r > _best) {
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
  void dispose() {
    _debounce?.cancel();
    _save();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studyItemProvider(widget.id));
    final it = async.value;
    _item = it;
    final err = async.error;
    final minutes = it == null ? 1 : ('${it['body'] ?? ''}'.length / 1100).round().clamp(1, 60);
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
                    onPressed: () => showPaywall(context, reason: 'note'),
                  ),
                ),
              ),
            )
          : err != null
          ? StateView.error(err, onRetry: () => ref.invalidate(studyItemProvider(widget.id)))
          : it == null
          ? const ListSkeleton(items: 7)
          : Stack(
              children: [
                ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s8),
                  children: [
                    NoteBody(text: '${it['body'] ?? ''}', scale: _scale),
                    const Gap(Space.s6),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Check yourself', style: context.ty.body.bold),
                          const Gap(Space.s1),
                          Text('Practise questions on this subject in a short test.', style: context.ty.sm.col(context.c.textMuted)),
                          const Gap(Space.s3),
                          Btn('Start a topic drill', block: true, onPressed: () => context.push('/test/setup?exam=JAMB&mode=topic')),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _read,
                      child: Container(height: 3, color: context.c.accent),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Renders note text (`.note-body`): `#`/`##` headings, `-` lists, `>` tip boxes, `$$…$$` blocks,
/// `$…$` maths and `**bold**`. Simple on purpose, so teachers can write notes in the admin text box.
class NoteBody extends StatelessWidget {
  const NoteBody({super.key, required this.text, this.scale = 1});
  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final base = context.ty.body.copyWith(fontSize: 16 * scale, height: 27 / 16);
    final blocks = text.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'));
    final out = <Widget>[];
    for (final raw in blocks) {
      final b = raw.trim();
      if (b.isEmpty) continue;
      if (b.startsWith('## ')) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: Space.s4, bottom: Space.s2),
            child: MathText(
              b.substring(3),
              style: base.copyWith(fontSize: 17 * scale, height: 24 / 17, fontWeight: kBold),
            ),
          ),
        );
      } else if (b.startsWith('# ')) {
        out.add(
          Padding(
            padding: EdgeInsets.only(top: out.isEmpty ? 0 : Space.s6, bottom: Space.s2),
            child: MathText(
              b.substring(2),
              style: base.copyWith(fontSize: 19 * scale, height: 26 / 19, fontWeight: kBold),
            ),
          ),
        );
      } else if (b.startsWith('> ')) {
        out.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: Space.s4),
            padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(Radii.md)),
            child: MathText(
              b.split('\n').map((l) => l.replaceFirst(RegExp(r'^>\s?'), '')).join('\n'),
              bold: true,
              style: base.copyWith(fontSize: 15 * scale, height: 23 / 15, color: c.onAccentSoft),
            ),
          ),
        );
      } else if (b.split('\n').every((l) => RegExp(r'^\s*[-*]\s').hasMatch(l))) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s3),
            child: Column(
              children: [
                for (final (i, l) in b.split('\n').indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 6, left: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 11 * scale, right: 10),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: c.textMuted, shape: BoxShape.circle),
                          ),
                        ),
                        Expanded(child: MathText(l.replaceFirst(RegExp(r'^\s*[-*]\s'), ''), bold: true, style: base)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      } else {
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s3),
            child: MathText(b, bold: true, style: base),
          ),
        );
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
  }
}
