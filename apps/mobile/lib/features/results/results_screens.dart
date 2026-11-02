import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ai/ai_screen.dart' show askAiAbout;
import '../../core/providers.dart';
import '../../data/db.dart';
import '../../data/tests_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/confetti.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/math_text.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/question_image.dart';
import '../../widgets/states.dart';
import '../cbt/cbt_screen.dart';
import '../cbt/exam_clock.dart';
import '../cbt/scoring.dart';
import '../home/home_screen.dart';

/// Everything the results and review screens need, read from the phone's database.
class AttemptView {
  AttemptView({required this.a, required this.questions, required this.answers, required this.subjectNames, this.previous});
  final LocalAttempt a;
  final List<CachedQuestion> questions;
  final Map<String, LocalAnswer> answers;
  final Map<int, String> subjectNames;

  /// The last finished test of the same exam and mode (for "You beat your last score by …").
  final LocalAttempt? previous;

  Map<String, dynamic> get config => jsonDecode(a.configJson) as Map<String, dynamic>;
  String get title => (config['title'] as String?) ?? a.examCode;
  Map<String, String> get choices => {
    for (final e in answers.entries)
      if (e.value.choice != null) e.key: e.value.choice!,
  };
  List<QuestionKey> get keys => [for (final q in questions) QuestionKey(id: q.id, subjectId: q.subjectId, answer: q.answer, topic: q.topic)];

  /// The server's mark once synced (the one that counts), else the phone's.
  Map<String, dynamic> get score => scoreOf(a) ?? scoreAttempt(keys, choices).toJson();

  static Map<String, dynamic>? scoreOf(LocalAttempt a) {
    final raw = a.serverScoreJson ?? a.clientScoreJson;
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  /// JAMB full mock and JAMB single subject show a scaled score (/400, /100); everything else shows a percentage.
  bool get scaled => a.examCode == 'JAMB' && (a.mode == 'full' || a.mode == 'subject' || a.mode == 'year');

  static String shortName(String n) => n == 'Use of English' ? 'English' : n;
}

final attemptViewProvider = FutureProvider.autoDispose.family<AttemptView, String>((ref, id) async {
  final db = ref.read(dbProvider);
  final repo = ref.read(testsRepoProvider);
  var a = await (db.select(db.localAttempts)..where((x) => x.id.equals(id))).getSingleOrNull();
  if (a == null) throw Exception('This test is no longer on your phone.');
  if (a.submittedAt != null && !a.synced) {
    await repo.syncPending();
    a = await (db.select(db.localAttempts)..where((x) => x.id.equals(id))).getSingle();
  }
  final ids = (jsonDecode(a.questionIdsJson) as List).cast<String>();
  final subjects = await ref.read(subjectsProvider.future).catchError((_) => <Map<String, dynamic>>[]);
  final history = await db.finishedAttempts();
  final previous = history
      .where((h) => h.id != a!.id && h.examCode == a.examCode && h.mode == a.mode && h.submittedAt!.isBefore(a.submittedAt ?? DateTime.now()))
      .firstOrNull;
  return AttemptView(
    a: a,
    questions: await db.questionsByIds(ids),
    answers: {for (final x in await db.answersFor(id)) x.questionId: x},
    subjectNames: {for (final s in subjects) (s['id'] as num).toInt(): s['name'] as String},
    previous: previous,
  );
});

String _date(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

// ---------------------------------------------------------------- results (prototype: results)
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, required this.attemptId});
  final String attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(attemptViewProvider(attemptId));
    return Scaffold(
      backgroundColor: context.c.bg,
      body: asyncView(v, (d) => _ResultsBody(d: d), onRetry: () => ref.invalidate(attemptViewProvider(attemptId))),
    );
  }
}

class _ResultsBody extends ConsumerWidget {
  const _ResultsBody({required this.d});
  final AttemptView d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = d.score;
    final questions = (s['questions'] as num).toInt(), correct = (s['correct'] as num).toInt();
    final accuracy = questions == 0 ? 0 : (100 * correct / questions).round();
    final total = (s['total'] as num).toInt(), max = (s['max'] as num).toInt();
    final value = d.scaled ? total : accuracy;
    final fraction = d.scaled ? (max == 0 ? 0.0 : total / max) : accuracy / 100;
    final subjects = [for (final x in (s['subjects'] as List)) Map<String, dynamic>.from(x as Map)];
    final weak = weakTopics(d.keys, d.choices, top: 4);
    final first = ((ref.watch(profileProvider).value?['full_name'] as String?) ?? '').split(' ').first;
    final rm = context.reduceMotion;
    final perQ = questions == 0 ? 0 : (d.a.usedMs / 1000 / questions).round();
    final good = fraction >= .5;

    // Compared with the last test of the same kind.
    String? compare;
    final prev = d.previous == null ? null : AttemptView.scoreOf(d.previous!);
    if (prev != null) {
      final pq = (prev['questions'] as num).toInt();
      final pv = d.scaled ? (prev['total'] as num).toInt() : (pq == 0 ? 0 : (100 * (prev['correct'] as num) / pq).round());
      final diff = value - pv;
      compare = diff > 0 ? 'beat' : (diff < 0 ? 'below' : 'same');
      compare = '$compare:${diff.abs()}';
    }

    const heroFg = Color(0xFFF4F7FC), heroMuted = Color(0xFFAFC0DD);
    final hero = Container(
      color: Palette.navy900,
      padding: EdgeInsets.fromLTRB(Space.s5, MediaQuery.paddingOf(context).top, Space.s5, Space.s7),
      child: Column(
        children: [
          SizedBox(
            height: Sizes.appBar,
            child: Row(
              children: [
                IconBtn(PhosphorIcons.x(), label: 'Close', color: Colors.white, onPressed: () => context.go('/home')),
                Expanded(
                  child: Text('Your result', textAlign: TextAlign.center, style: context.ty.h3.col(heroFg)),
                ),
                const SizedBox(width: Sizes.tapMin),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExamLogo(d.a.examCode, size: LogoSize.sm),
              const Gap(Space.s2),
              Flexible(
                child: Text(
                  '${d.title} · ${_date(d.a.submittedAt!.toLocal())}',
                  style: context.ty.sm.col(heroMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Gap(Space.s4),
          Semantics(
            label: d.scaled ? 'Score $total out of $max' : 'Score $accuracy percent',
            child: Ring(
              value: fraction,
              size: 176,
              stroke: 12,
              track: Colors.white.withValues(alpha: .12),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: rm ? value : 0, end: value),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (_, n, _) =>
                        Text(d.scaled ? '$n' : '$n%', style: context.ty.display.copyWith(fontSize: 48, height: 1, letterSpacing: -1).tnum.col(heroFg)),
                  ),
                  const SizedBox(height: 2),
                  Text(d.scaled ? 'out of $max' : 'score', style: context.ty.sm.copyWith(fontSize: 14).col(heroMuted)),
                ],
              ),
            ),
          ),
          const Gap(Space.s3),
          Text(
            good ? 'Great work${first.isEmpty ? '' : ', $first'}!' : 'Keep practising${first.isEmpty ? '' : ', $first'}. You will get there.',
            style: context.ty.h2.col(heroFg),
            textAlign: TextAlign.center,
          ),
          const Gap(Space.s2),
          if (compare != null)
            Text.rich(
              TextSpan(
                style: context.ty.sm.col(heroMuted),
                children: switch (compare.split(':')) {
                  ['beat', final n] => [
                    const TextSpan(text: 'You beat your last score by '),
                    TextSpan(text: '$n ${d.scaled ? 'points' : 'percent'}', style: context.ty.sm.bold.col(Palette.gold400)),
                    const TextSpan(text: '.'),
                  ],
                  ['below', final n] => [
                    TextSpan(text: '$n ${d.scaled ? 'points' : 'percent'} below your last score. Review the wrong answers and try again.'),
                  ],
                  _ => [const TextSpan(text: 'The same as your last score.')],
                },
              ),
              textAlign: TextAlign.center,
            ),
          Text(
            d.a.synced ? 'Checked by SolutionTee.' : 'Marked on your phone. We will confirm it when you are online.',
            style: context.ty.cap.col(heroMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    final cards = <Widget>[
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(subjects.length > 1 ? 'Score by subject' : 'Your score', style: context.ty.h3),
            const Gap(Space.s4),
            for (final x in subjects) ...[
              _SubjectScore(
                name: AttemptView.shortName(d.subjectNames[(x['subject_id'] as num).toInt()] ?? 'Subject'),
                score: (x['score'] as num).toInt(),
                detail: '${x['correct']}/${x['total']}',
                scaled: d.scaled,
              ),
              const Gap(Space.s4),
            ],
          ],
        ),
      ),
      if (weak.isNotEmpty)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Topics to practise', style: context.ty.h3),
              const Gap(Space.s3),
              Wrap(
                spacing: Space.s2,
                runSpacing: Space.s2,
                children: [for (final w in weak) AppChip(w.topic, on: false, icon: PhosphorIcons.target())],
              ),
              const Gap(Space.s3),
              Btn('Practise weak topics', kind: BtnKind.tonal, block: true, onPressed: () => context.push('/test/setup?exam=${d.a.examCode}&mode=topic')),
            ],
          ),
        ),
      Row(
        children: [
          Expanded(child: Btn('Review answers', block: true, onPressed: () => context.push('/review/${d.a.id}'))),
          const Gap(Space.s3),
          Expanded(
            child: Btn('Share', kind: BtnKind.outline, block: true, leading: PhosphorIcons.shareNetwork(), onPressed: () => _share(context, first, value, d)),
          ),
        ],
      ),
    ];

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.only(bottom: Space.s8 + MediaQuery.paddingOf(context).bottom),
          children: [
            hero,
            // KPIs overlap the hero
            Transform.translate(
              offset: const Offset(0, -Space.s6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.s5),
                child: Row(
                  children: [
                    _Kpi(value: '$accuracy%', label: 'Accuracy'),
                    const Gap(Space.s2),
                    _Kpi(value: perQ >= 60 ? '${perQ ~/ 60}m ${perQ % 60}s' : '${perQ}s', label: 'Per question'),
                    const Gap(Space.s2),
                    _Kpi(
                      value: ExamClock.format(Duration(milliseconds: d.a.usedMs)),
                      label: 'Time used',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s5, 0, Space.s5, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const Gap(Space.s5),
                    rm ? cards[i] : cards[i].animate(delay: Motion.stagger * (i + 2)).fadeIn(duration: Motion.slow).slideY(begin: .06, curve: Motion.out),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (good && !rm) const IgnorePointer(child: Confetti(delay: Duration(milliseconds: 300))),
      ],
    );
  }

  void _share(BuildContext context, String first, int value, AttemptView d) {
    final text =
        '${first.isEmpty ? 'I' : first} scored ${d.scaled ? '$value / ${(d.score['max'] as num).toInt()}' : '$value%'} in ${d.title} on SolutionTee CBT. Learn. Think. Solve.';
    showSheet<void>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share your result', style: ctx.ty.h3),
          const Gap(Space.s4),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.lg),
            child: Container(
              padding: const EdgeInsets.all(Space.s5),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Palette.navy900, Palette.blue800], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Mark(height: 22, onDark: true),
                      const Gap(Space.s2),
                      Text('SolutionTee CBT', style: ctx.ty.sm.bold.col(const Color(0xFFF4F7FC))),
                    ],
                  ),
                  const Gap(Space.s4),
                  Text('${first.isEmpty ? 'I' : first} scored', style: ctx.ty.sm.col(const Color(0xFFAFC0DD))),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: d.scaled ? '$value' : '$value%',
                          style: ctx.ty.display.copyWith(fontSize: 56, height: 1, letterSpacing: -1).tnum.col(const Color(0xFFF4F7FC)),
                        ),
                        if (d.scaled)
                          TextSpan(text: ' / ${(d.score['max'] as num).toInt()}', style: ctx.ty.h3.copyWith(fontSize: 18).col(const Color(0xFFAFC0DD))),
                      ],
                    ),
                  ),
                  const Gap(Space.s2),
                  Text('${d.title} · Learn. Think. Solve.', style: ctx.ty.sm.col(const Color(0xFFAFC0DD))),
                ],
              ),
            ),
          ),
          const Gap(Space.s4),
          Row(
            children: [
              Expanded(
                child: Btn(
                  'WhatsApp',
                  kind: BtnKind.accent,
                  block: true,
                  leading: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
                  onPressed: () => launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication),
                ),
              ),
              const Gap(Space.s3),
              Expanded(
                child: Btn(
                  'Copy text',
                  kind: BtnKind.outline,
                  block: true,
                  leading: PhosphorIcons.copy(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    Navigator.pop(ctx);
                    toast(context, 'Copied. Paste it anywhere.', icon: PhosphorIcons.copy(PhosphorIconsStyle.fill));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: AppCard(
      padding: const EdgeInsets.all(Space.s3),
      child: Column(
        children: [
          FittedBox(
            child: Text(value, style: context.ty.h2.copyWith(fontSize: 20, height: 26 / 20).tnum),
          ),
          Text(label, style: context.ty.cap.bold.copyWith(fontSize: 11).col(context.c.textMuted)),
        ],
      ),
    ),
  );
}

class _SubjectScore extends StatelessWidget {
  const _SubjectScore({required this.name, required this.score, required this.detail, required this.scaled});
  final String name, detail;
  final int score;
  final bool scaled;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$name: $score ${scaled ? 'out of 100' : 'percent'}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(name, style: context.ty.sm.bold)),
            Text('$detail · ', style: context.ty.cap.col(context.c.textMuted)),
            Text(scaled ? '$score/100' : '$score%', style: context.ty.sm.bold.tnum),
          ],
        ),
        const SizedBox(height: 6),
        ProgressBar(score / 100, color: score >= 70 ? context.c.success : null),
      ],
    ),
  );
}

// ---------------------------------------------------------------- review (prototype: review)
enum _Filter { all, wrong, flagged, skipped }

/// One question at a time, filtered (All · Wrong · Flagged · Skipped), with the correct answer, the student's
/// answer and the explanation.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.attemptId});
  final String attemptId;
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  _Filter? _f;
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(attemptViewProvider(widget.attemptId));
    return v.when(
      loading: () => const Scaffold(
        appBar: TopBar(title: 'Review answers'),
        body: ListSkeleton(),
      ),
      error: (e, _) => Scaffold(
        appBar: const TopBar(title: 'Review answers'),
        body: StateView.error(e, onRetry: () => ref.invalidate(attemptViewProvider(widget.attemptId))),
      ),
      data: (d) {
        bool isIn(_Filter f, CachedQuestion q) {
          final a = d.answers[q.id];
          return switch (f) {
            _Filter.all => true,
            _Filter.wrong => a?.choice != null && a!.choice!.toUpperCase() != q.answer,
            _Filter.flagged => a?.flagged == true,
            _Filter.skipped => a?.choice == null,
          };
        }

        final f = _f ?? (d.questions.any((q) => isIn(_Filter.wrong, q)) ? _Filter.wrong : _Filter.all);
        final list = d.questions.where((q) => isIn(f, q)).toList();
        final i = _i.clamp(0, list.isEmpty ? 0 : list.length - 1);
        final q = list.isEmpty ? null : list[i];
        final c = context.c;

        return Scaffold(
          appBar: TopBar(
            title: 'Review answers',
            subtitle: q == null ? 'Nothing here' : '${AttemptView.shortName(d.subjectNames[q.subjectId] ?? 'Subject')} · ${i + 1} of ${list.length}',
            lined: true,
          ),
          body: Column(
            children: [
              Container(
                color: c.bg,
                padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (k, l) in const [
                        (_Filter.all, 'All'),
                        (_Filter.wrong, 'Wrong'),
                        (_Filter.flagged, 'Flagged'),
                        (_Filter.skipped, 'Skipped'),
                      ]) ...[
                        AppChip(
                          '$l  ${d.questions.where((x) => isIn(k, x)).length}',
                          on: k == f,
                          onTap: () => setState(() {
                            _f = k;
                            _i = 0;
                          }),
                        ),
                        const Gap(Space.s2),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: q == null
                    ? StateBlock(
                        icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                        tone: Tone.blue,
                        title: 'Nothing to review here',
                        text: 'Pick another filter above.',
                      )
                    : _ReviewBody(key: ValueKey(q.id), q: q, a: d.answers[q.id]),
              ),
              if (q != null)
                Container(
                  padding: EdgeInsets.fromLTRB(Space.s3, Space.s2, Space.s3, Space.s3 + MediaQuery.paddingOf(context).bottom),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      Btn(
                        'Prev',
                        kind: BtnKind.outline,
                        sm: true,
                        leading: PhosphorIcons.caretLeft(),
                        onPressed: i == 0 ? null : () => setState(() => _i = i - 1),
                      ),
                      Expanded(
                        child: Text('${i + 1} / ${list.length}', textAlign: TextAlign.center, style: context.ty.cap.tnum.col(c.textMuted)),
                      ),
                      Btn('Next', sm: true, icon: PhosphorIcons.caretRight(), onPressed: i >= list.length - 1 ? null : () => setState(() => _i = i + 1)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({super.key, required this.q, required this.a});
  final CachedQuestion q;
  final LocalAnswer? a;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final options = Map<String, String>.from(jsonDecode(q.optionsJson) as Map);
    final chose = a?.choice?.toUpperCase();
    final right = chose == q.answer;
    final secs = ((a?.timeMs ?? 0) / 1000).round();
    final took = chose == null ? 'Not answered' : 'You took ${secs >= 60 ? '${secs ~/ 60}m ${secs % 60}s' : '${secs}s'}';
    final rm = context.reduceMotion;
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
      children: [
        Wrap(
          spacing: Space.s2,
          runSpacing: Space.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (chose == null)
              Pill('Skipped', kind: BadgeKind.neutral, icon: PhosphorIcons.minusCircle(PhosphorIconsStyle.fill))
            else if (right)
              Pill('Correct', kind: BadgeKind.success, icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill))
            else
              Pill('Wrong', kind: BadgeKind.error, icon: PhosphorIcons.xCircle(PhosphorIconsStyle.fill)),
            if (a?.flagged == true) Pill('Flagged', kind: BadgeKind.warning, icon: PhosphorIcons.flag(PhosphorIconsStyle.fill)),
            if ((q.topic ?? '').isNotEmpty) Pill(q.topic!),
            Text(took, style: context.ty.cap.col(c.textMuted)),
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
                    Text((q.passageTitle ?? 'Passage').replaceFirst('[SAMPLE] ', ''), style: context.ty.sm.bold),
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
            state: k == q.answer
                ? OptState.right
                : k == chose
                ? OptState.wrong
                : OptState.none,
            tag: k == q.answer
                ? 'Correct answer'
                : k == chose
                ? 'Your answer'
                : null,
          ),
          const SizedBox(height: 10),
        ],
        if ((q.explanation ?? '').isNotEmpty) ...[
          const Gap(Space.s3),
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
        ],
        const Gap(Space.s3),
        Btn(
          'Ask SolutionTee AI to explain',
          kind: BtnKind.outline,
          block: true,
          leading: PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
          onPressed: () => askAiAbout(context, questionId: q.id, label: '${q.year} question ${q.number ?? ''}'.trim()),
        ),
      ],
    );
    return rm ? body : body.animate().fadeIn(duration: Motion.base);
  }
}
