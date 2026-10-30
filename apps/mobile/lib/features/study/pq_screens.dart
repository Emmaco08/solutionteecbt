import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/db.dart';
import '../../data/study_repo.dart';
import '../../data/tests_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/math_text.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/question_image.dart';
import '../../widgets/states.dart';
import '../cbt/cbt_screen.dart' show OptionRow, OptState;
import '../premium/paywall.dart';
import 'study_widgets.dart';

/// Past questions: exam → subject → year (prototype `pq`). Open years come from the server (`pq_open`).
class PqBrowseScreen extends ConsumerStatefulWidget {
  const PqBrowseScreen({super.key, this.subjectId});
  final int? subjectId;
  @override
  ConsumerState<PqBrowseScreen> createState() => _PqBrowseScreenState();
}

class _PqBrowseScreenState extends ConsumerState<PqBrowseScreen> {
  String _exam = 'JAMB';
  int? _subject;

  @override
  void initState() {
    super.initState();
    _subject = widget.subjectId;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final exams = ref.watch(examsProvider).value ?? const [];
    final yearsAsync = ref.watch(openYearsProvider);
    final years = yearsAsync.value ?? const [];
    final examSubjects = ref.watch(examSubjectsProvider).value ?? const [];
    final subjects = ref.watch(subjectsProvider).value ?? const [];
    final exam = firstOr(exams, (e) => e['code'] == _exam, fallbackFirst: true);
    final examId = exam['id'];
    bool examOpen(Object? id) => !years.any((y) => y['exam_id'] == id) || years.any((y) => y['exam_id'] == id && y['pq_open'] == true);

    final subjectList = [
      for (final s in subjects)
        if (examSubjects.any((es) => es['exam_id'] == examId && es['subject_id'] == s['id']) || examSubjects.isEmpty) s,
    ];
    // Default: the first subject that has published years.
    final withYears = {
      for (final y in years)
        if (y['exam_id'] == examId) y['subject_id'],
    };
    final subjectId = _subject != null && subjectList.any((s) => s['id'] == _subject)
        ? _subject
        : (firstOr(subjectList, (s) => withYears.contains(s['id']), fallbackFirst: true)['id'] as num?)?.toInt();
    final subject = firstOr(subjectList, (s) => s['id'] == subjectId);
    final rows = [
      for (final y in years)
        if (y['exam_id'] == examId && y['subject_id'] == subjectId) y,
    ]..sort((a, b) => (b['year'] as num).compareTo(a['year'] as num));
    final allOpen = rows.every((y) => y['pq_open'] == true);
    final pqRule = myRules(ref)['pq'];
    final rm = context.reduceMotion;

    return Scaffold(
      appBar: const TopBar(title: 'Past questions'),
      body: yearsAsync.hasError && years.isEmpty
          ? StateView.error(yearsAsync.error!, onRetry: () => ref.invalidate(openYearsProvider))
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
              children: [
                Seg<String>(
                  value: _exam,
                  items: [for (final e in exams) (e['code'] as String, examOpen(e['id']) ? e['code'] as String : '${e['code']} · Premium')],
                  onChanged: (v) {
                    final e = firstOr(exams, (x) => x['code'] == v);
                    if (!examOpen(e['id'])) {
                      showPaywall(context, reason: v);
                      return;
                    }
                    setState(() => _exam = v);
                  },
                ),
                const Gap(Space.s5),
                Text('Subject', style: context.ty.label),
                const Gap(Space.s2),
                _PickField(
                  icon: subjectIconFor(ref, subjectId, PhosphorIconsStyle.regular),
                  text: '${subject['name'] ?? 'Choose a subject'}',
                  onTap: () async {
                    final picked = await showSheet<int>(
                      context,
                      builder: (ctx) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Choose a subject', style: ctx.ty.h3),
                          const Gap(Space.s3),
                          ListCard(
                            children: [
                              for (final s in subjectList)
                                ListRow(
                                  lead: IconTile(subjectIconFor(ref, s['id']), tone: s['id'] == subjectId ? Tone.blue : Tone.neutral),
                                  title: '${s['name']}',
                                  caption: withYears.contains(s['id']) ? null : 'No years yet',
                                  trailing: s['id'] == subjectId ? Icon(PhosphorIcons.check(PhosphorIconsStyle.fill), color: ctx.c.secondary) : null,
                                  onTap: () => Navigator.of(ctx).pop((s['id'] as num).toInt()),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                    if (picked != null) setState(() => _subject = picked);
                  },
                ),
                const Gap(Space.s5),
                Row(
                  children: [
                    Expanded(child: Text('Choose a year', style: context.ty.h3)),
                    if (rows.isNotEmpty && allOpen)
                      Pill('All years open', kind: BadgeKind.gold, icon: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill))
                    else if (rows.isNotEmpty)
                      Row(
                        children: [
                          Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), size: 13, color: c.textMuted),
                          const SizedBox(width: 4),
                          Text('= Premium', style: context.ty.cap.col(c.textMuted)),
                        ],
                      ),
                  ],
                ),
                const Gap(Space.s3),
                if (yearsAsync.isLoading && years.isEmpty)
                  const Skeleton(height: 120, radius: Radii.md)
                else if (rows.isEmpty)
                  StateBlock(
                    icon: PhosphorIcons.exam(PhosphorIconsStyle.fill),
                    tone: Tone.neutral,
                    title: 'No years yet',
                    text: 'We are still adding ${subject['name'] ?? 'this subject'} past questions. Try another subject.',
                  )
                else
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: Space.s2,
                    crossAxisSpacing: Space.s2,
                    childAspectRatio: 1.45,
                    children: [
                      for (final (i, y) in rows.indexed)
                        _YearTile(
                          year: (y['year'] as num).toInt(),
                          locked: y['pq_open'] != true,
                          onTap: () => y['pq_open'] == true
                              ? context.push('/study/pq/$examId/$subjectId/${y['year']}')
                              : showPaywall(context, reason: '$_exam ${y['year']}'),
                        ).animate(target: rm ? 0 : 1).fadeIn(delay: (25 * i).ms, duration: Motion.base),
                    ],
                  ),
                if (rows.isNotEmpty && !allOpen) ...[
                  const Gap(Space.s5),
                  InfoBanner(
                    icon: PhosphorIcons.info(PhosphorIconsStyle.fill),
                    child: Text(
                      'Your plan includes ${pqRule is num ? '$pqRule years' : 'some years'} of study-mode past questions per exam '
                      '(${rows.where((y) => y['pq_open'] == true).map((y) => y['year']).join(', ')}). Upgrade to open every year.',
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// `.field` look-alike that opens a picker.
class _PickField extends StatelessWidget {
  const _PickField({required this.icon, required this.text, required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: .99,
    borderRadius: BorderRadius.circular(Radii.md),
    child: Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: Space.s4),
      decoration: BoxDecoration(
        color: context.c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: context.c.borderStrong, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.c.textMuted),
          const Gap(Space.s3),
          Expanded(child: Text(text, style: context.ty.body)),
          Icon(PhosphorIcons.caretDown(), size: 18, color: context.c.textMuted),
        ],
      ),
    ),
  );
}

/// `.year` / `.year.locked` grid tile.
class _YearTile extends StatelessWidget {
  const _YearTile({required this.year, required this.locked, required this.onTap});
  final int year;
  final bool locked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      label: locked ? '$year, Premium' : '$year',
      child: Pressable(
        onTap: onTap,
        scale: .95,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Container(
          decoration: BoxDecoration(
            color: locked ? c.surfaceAlt : c.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: c.border),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text('$year', style: context.ty.body.bold.col(locked ? c.textSubtle : c.text)),
              if (locked) Positioned(top: 5, right: 6, child: Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), size: 12, color: c.textSubtle)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One past paper in study mode (prototype `pq-study`): tap an option to see the answer and explanation.
class PqStudyScreen extends ConsumerStatefulWidget {
  const PqStudyScreen({super.key, required this.examId, required this.subjectId, required this.year, this.questionId});
  final int examId, subjectId, year;
  final String? questionId;
  @override
  ConsumerState<PqStudyScreen> createState() => _PqStudyScreenState();
}

class _PqStudyScreenState extends ConsumerState<PqStudyScreen> {
  late Future<List<CachedQuestion>> _paper;
  int _n = 0;
  final _chosen = <int, String>{};
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _paper = ref.read(testsRepoProvider).paper(widget.examId, widget.subjectId, widget.year, mode: 'pq').then((qs) {
      final i = widget.questionId == null ? -1 : qs.indexWhere((q) => q.id == widget.questionId);
      if (i >= 0) _n = i;
      return qs;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int n) {
    setState(() => _n = n);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final exams = ref.watch(examsProvider).value ?? const [];
    final code = firstOr(exams, (e) => e['id'] == widget.examId)['code'];
    final name = subjectName(ref, widget.subjectId);
    final title = '$code ${widget.year} $name';
    return FutureBuilder<List<CachedQuestion>>(
      future: _paper,
      builder: (context, snap) {
        final qs = snap.data ?? const <CachedQuestion>[];
        final q = qs.isEmpty ? null : qs[_n.clamp(0, qs.length - 1)];
        return Scaffold(
          appBar: TopBar(
            title: title,
            subtitle: qs.isEmpty ? 'Study mode' : 'Study mode · Question ${_n + 1} of ${qs.length}',
            lined: true,
            actions: [
              if (q != null)
                BookmarkButton(kind: 'question', refId: '${widget.examId}/${widget.subjectId}/${widget.year}/${q.id}', label: '$title Q${q.number ?? _n + 1}'),
            ],
          ),
          body: snap.connectionState != ConnectionState.done
              ? const ListSkeleton(items: 6)
              : snap.hasError
              ? StateView.error(snap.error!, onRetry: () => setState(_load))
              : q == null
              ? Center(
                  child: StateBlock(
                    icon: PhosphorIcons.exam(PhosphorIconsStyle.fill),
                    tone: Tone.neutral,
                    title: 'No questions yet',
                    text: 'This paper has no questions yet. Try another year.',
                  ),
                )
              : ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s8),
                  children: [_StudyQuestion(key: ValueKey(q.id), q: q, chosen: _chosen[_n], onChoose: (k) => setState(() => _chosen[_n] = k))],
                ),
          bottomNavigationBar: qs.isEmpty
              ? null
              : Container(
                  padding: EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, Space.s3 + MediaQuery.paddingOf(context).bottom),
                  decoration: BoxDecoration(
                    color: context.c.surface,
                    border: Border(top: BorderSide(color: context.c.border)),
                  ),
                  child: Row(
                    children: [
                      Btn('Prev', kind: BtnKind.outline, sm: true, leading: PhosphorIcons.caretLeft(), onPressed: _n == 0 ? null : () => _go(_n - 1)),
                      Expanded(
                        child: Text('${_n + 1} / ${qs.length}', textAlign: TextAlign.center, style: context.ty.cap.tnum.col(context.c.textMuted)),
                      ),
                      Btn('Next', sm: true, icon: PhosphorIcons.caretRight(), onPressed: _n >= qs.length - 1 ? null : () => _go(_n + 1)),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _StudyQuestion extends ConsumerWidget {
  const _StudyQuestion({super.key, required this.q, required this.chosen, required this.onChoose});
  final CachedQuestion q;
  final String? chosen;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final options = Map<String, String>.from(jsonDecode(q.optionsJson) as Map);
    final shown = chosen != null;
    final videos = ref.watch(studyCatalogProvider('video_solution')).value ?? const [];
    final video = firstOr(videos, (v) => v['question_id'] == q.id);
    final rm = context.reduceMotion;
    final explain = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((q.explanation ?? '').isNotEmpty)
          Container(
            padding: const EdgeInsets.all(Space.s4),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explanation', style: context.ty.body.bold),
                const Gap(Space.s2),
                MathText(q.explanation!, style: context.ty.body.copyWith(height: 24 / 15)),
              ],
            ),
          ),
        const Gap(Space.s3),
        Row(
          children: [
            if (video.isNotEmpty) ...[
              Expanded(
                child: Btn(
                  'Watch solution',
                  kind: BtnKind.tonal,
                  sm: true,
                  leading: video['locked'] == true ? PhosphorIcons.lockSimple(PhosphorIconsStyle.fill) : PhosphorIcons.playCircle(PhosphorIconsStyle.fill),
                  onPressed: () => openStudyItem(context, video),
                ),
              ),
              const Gap(Space.s2),
            ],
            Expanded(
              child: Btn(
                'Ask AI',
                kind: BtnKind.outline,
                sm: true,
                leading: PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                onPressed: () => toast(context, 'The AI tutor arrives in the next update.', icon: PhosphorIcons.sparkle(PhosphorIconsStyle.fill), above: 64),
              ),
            ),
          ],
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Space.s2,
          runSpacing: Space.s2,
          children: [
            if ((q.topic ?? '').isNotEmpty) Pill(q.topic!),
            if (q.number != null) Pill('Question ${q.number}', kind: BadgeKind.neutral),
          ],
        ),
        const Gap(Space.s4),
        if (q.passageBody != null) ...[
          Container(
            padding: const EdgeInsets.all(Space.s4),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIcons.article(PhosphorIconsStyle.fill), size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(plainTitle(q.passageTitle ?? 'Passage'), style: context.ty.sm.bold)),
                  ],
                ),
                const Gap(Space.s2),
                MathText(q.passageBody!, style: context.ty.body.copyWith(height: 24 / 15)),
              ],
            ),
          ),
          const Gap(Space.s4),
        ],
        MathText(
          q.body,
          style: context.ty.body.copyWith(fontSize: TypeScale.question.size, height: TypeScale.question.line / TypeScale.question.size),
        ),
        if (q.imagePath != null) ...[const Gap(Space.s3), QuestionImage(imageKey: q.imagePath!)],
        const Gap(Space.s4),
        for (final k in options.keys.toList()..sort()) ...[
          OptionRow(
            letter: k,
            text: options[k]!,
            state: !shown
                ? OptState.none
                : k == q.answer
                ? OptState.right
                : k == chosen
                ? OptState.wrong
                : OptState.none,
            tag: !shown
                ? null
                : k == q.answer
                ? 'Correct answer'
                : k == chosen
                ? 'Your answer'
                : null,
            onTap: shown ? null : () => onChoose(k),
          ),
          const SizedBox(height: 10),
        ],
        if (shown) ...[const Gap(Space.s2), rm ? explain : explain.animate().fadeIn(duration: Motion.base).scaleXY(begin: .97, end: 1, curve: Curves.easeOut)],
      ],
    );
  }
}
