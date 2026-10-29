import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/phosphor.g.dart';

import '../../core/providers.dart';
import '../../data/db.dart';
import '../../data/tests_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/math_text.dart';
import '../../widgets/question_image.dart';
import '../../widgets/states.dart';
import '../cbt/exam_clock.dart';
import '../cbt/scoring.dart';
import '../shell/shell.dart';

/// Everything the results and review screens need, read from the phone's database.
class AttemptView {
  AttemptView({required this.a, required this.questions, required this.answers, required this.subjectNames});
  final LocalAttempt a;
  final List<CachedQuestion> questions;
  final Map<String, LocalAnswer> answers;
  final Map<int, String> subjectNames;

  Map<String, dynamic> get config => jsonDecode(a.configJson) as Map<String, dynamic>;
  String get title => (config['title'] as String?) ?? a.examCode;
  Map<String, String> get choices => {
    for (final e in answers.entries)
      if (e.value.choice != null) e.key: e.value.choice!,
  };
  List<QuestionKey> get keys => [for (final q in questions) QuestionKey(id: q.id, subjectId: q.subjectId, answer: q.answer, topic: q.topic)];

  /// The server's mark once synced (the one that counts), else the phone's.
  Map<String, dynamic> get score {
    final raw = a.serverScoreJson ?? a.clientScoreJson;
    if (raw != null) return jsonDecode(raw) as Map<String, dynamic>;
    return scoreAttempt(keys, choices).toJson();
  }
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
  return AttemptView(
    a: a,
    questions: await db.questionsByIds(ids),
    answers: {for (final x in await db.answersFor(id)) x.questionId: x},
    subjectNames: {for (final s in subjects) (s['id'] as num).toInt(): s['name'] as String},
  );
});

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, required this.attemptId});
  final String attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(attemptViewProvider(attemptId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your result'),
        leading: IconButton(tooltip: 'Close', icon: Icon(PhosphorIcons.x()), onPressed: () => context.go('/home')),
      ),
      body: asyncView(v, (d) => _ResultsBody(d: d), onRetry: () => ref.invalidate(attemptViewProvider(attemptId))),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({required this.d});
  final AttemptView d;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = d.score;
    final total = (s['total'] as num).toInt(), max = (s['max'] as num).toInt();
    final correct = (s['correct'] as num).toInt(), questions = (s['questions'] as num).toInt();
    final answered = (s['answered'] as num).toInt();
    final pct = max == 0 ? 0.0 : total / max;
    final weak = weakTopics(d.keys, d.choices);
    final subjects = [for (final x in (s['subjects'] as List)) Map<String, dynamic>.from(x as Map)];
    final great = pct >= .7;
    final reduce = context.reduceMotion;

    final children = <Widget>[
      // Score card
      Container(
        padding: const EdgeInsets.all(Space.s5),
        decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(Radii.xl)),
        child: Column(
          children: [
            Row(
              children: [
                ExamLogo(d.a.examCode, size: 36),
                gap3,
                Expanded(
                  child: Text(d.title, style: context.t.labelLarge?.copyWith(color: c.onPrimary), maxLines: 2),
                ),
              ],
            ),
            gap5,
            Semantics(
              label: 'Score $total out of $max',
              child: SizedBox(
                width: 168,
                height: 168,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct),
                      duration: reduce ? Duration.zero : const Duration(milliseconds: 900),
                      curve: Motion.out,
                      builder: (_, p, _) => SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: p,
                          strokeWidth: 12,
                          color: c.accent,
                          backgroundColor: c.onPrimary.withValues(alpha: .15),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: total),
                          duration: reduce ? Duration.zero : const Duration(milliseconds: 900),
                          builder: (_, n, _) => Text(
                            '$n',
                            style: context.t.displaySmall?.copyWith(color: c.onPrimary, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text('out of $max', style: context.t.bodySmall?.copyWith(color: c.onPrimary.withValues(alpha: .8))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            gap4,
            Text(
              great
                  ? 'Excellent work!'
                  : pct >= .5
                  ? 'Good effort. Keep going!'
                  : 'Keep practising. You will get there.',
              style: context.t.titleMedium?.copyWith(color: c.onPrimary),
            ),
            gap2,
            Text(
              d.a.synced ? 'Checked by SolutionTee' : 'Marked on your phone. We will confirm it when you are online.',
              style: context.t.bodySmall?.copyWith(color: c.onPrimary.withValues(alpha: .75)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      // Quick stats
      Row(
        children: [
          _Tile(icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: c.success, value: '$correct/$questions', label: 'Correct'),
          gap3,
          _Tile(icon: PhosphorIcons.pencilSimple(PhosphorIconsStyle.fill), color: c.secondary, value: '$answered', label: 'Answered'),
          gap3,
          _Tile(
            icon: PhosphorIcons.timer(PhosphorIconsStyle.fill),
            color: c.warning,
            value: ExamClock.format(Duration(milliseconds: d.a.usedMs)),
            label: 'Time used',
          ),
        ],
      ),
      // Per subject
      if (subjects.length > 1 || d.a.examCode == 'JAMB') ...[
        Text('By subject', style: context.t.titleMedium),
        for (final x in subjects)
          _SubjectBar(
            name: d.subjectNames[(x['subject_id'] as num).toInt()] ?? 'Subject',
            score: (x['score'] as num).toInt(),
            detail: '${x['correct']}/${x['total']} correct',
          ),
      ],
      // Weak topics
      if (weak.isNotEmpty) ...[
        Text('Topics to revise', style: context.t.titleMedium),
        Card(
          child: Column(
            children: [
              for (final w in weak)
                ListTile(
                  leading: Icon(PhosphorIcons.target(PhosphorIconsStyle.fill), color: c.error),
                  title: Text(w.topic),
                  subtitle: Text('${w.wrong} of ${w.total} wrong'),
                ),
            ],
          ),
        ),
      ],
      FilledButton.icon(onPressed: () => context.push('/review/${d.a.id}'), icon: Icon(PhosphorIcons.listChecks()), label: const Text('Review answers')),
      OutlinedButton(onPressed: () => context.go('/test'), child: const Text('Practise another test')),
    ];

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
          itemCount: children.length,
          separatorBuilder: (_, _) => gap4,
          itemBuilder: (_, i) =>
              reduce ? children[i] : children[i].animate(delay: Motion.stagger * i).fadeIn(duration: Motion.base).slideY(begin: .05, curve: Motion.out),
        ),
        if (great && !reduce) const IgnorePointer(child: _Confetti()),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.color, required this.value, required this.label});
  final IconData icon;
  final Color color;
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(
        color: context.c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: context.c.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          gap2,
          Text(value, style: context.t.titleMedium, maxLines: 1),
          Text(label, style: context.t.labelSmall?.copyWith(color: context.c.textMuted)),
        ],
      ),
    ),
  );
}

class _SubjectBar extends StatelessWidget {
  const _SubjectBar({required this.name, required this.score, required this.detail});
  final String name, detail;
  final int score;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = score >= 70
        ? c.success
        : score >= 50
        ? c.secondary
        : c.error;
    return Semantics(
      label: '$name: $score out of 100',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: context.t.labelLarge)),
              Text('$score', style: context.t.labelLarge?.copyWith(color: color)),
              Text(' /100', style: context.t.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(value: score / 100, minHeight: 10, color: color, backgroundColor: c.surfaceSunken),
          ),
          const SizedBox(height: 4),
          Text(detail, style: context.t.bodySmall?.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

/// A light, one-shot confetti burst (CustomPainter, no extra package). Skipped when reduce motion is on.
class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
  final _bits = List.generate(60, (i) {
    final r = math.Random(i * 7919);
    return (
      x: r.nextDouble(),
      drift: r.nextDouble() - .5,
      speed: .6 + r.nextDouble() * .6,
      spin: r.nextDouble() * 6,
      size: 6 + r.nextDouble() * 6,
      color: i % 3,
    );
  });

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colors = [c.accent, c.secondary, c.success];
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, _) => _ctl.isCompleted ? const SizedBox.shrink() : CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_ctl.value, _bits, colors)),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.bits, this.colors);
  final double t;
  final List<({double x, double drift, double speed, double spin, double size, int color})> bits;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final b in bits) {
      final y = -20 + (size.height + 40) * (t * b.speed);
      final x = size.width * b.x + b.drift * 80 * t;
      p.color = colors[b.color].withValues(alpha: (1 - t).clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * t * math.pi);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * .5), p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

// ---------------------------------------------------------------- review
enum _Filter { all, wrong, flagged, skipped }

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.attemptId});
  final String attemptId;
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  _Filter _f = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(attemptViewProvider(widget.attemptId));
    return Scaffold(
      appBar: AppBar(title: const Text('Review answers')),
      body: asyncView(v, (d) {
        bool keep(CachedQuestion q) {
          final a = d.answers[q.id];
          return switch (_f) {
            _Filter.all => true,
            _Filter.wrong => a?.choice != null && a!.choice!.toUpperCase() != q.answer,
            _Filter.flagged => a?.flagged == true,
            _Filter.skipped => a?.choice == null,
          };
        }

        final shown = [
          for (var i = 0; i < d.questions.length; i++)
            if (keep(d.questions[i])) i,
        ];
        return Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s2),
                children: [
                  for (final (f, label) in [(_Filter.all, 'All'), (_Filter.wrong, 'Wrong'), (_Filter.skipped, 'Not answered'), (_Filter.flagged, 'Flagged')])
                    Padding(
                      padding: const EdgeInsets.only(right: Space.s2),
                      child: ChoiceChip(label: Text(label), selected: _f == f, onSelected: (_) => setState(() => _f = f)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? StateView(icon: PhosphorIcons.checks(PhosphorIconsStyle.fill), title: 'Nothing here', message: 'No questions match this filter.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => gap4,
                      itemBuilder: (_, k) => _ReviewCard(
                        n: shown[k] + 1,
                        q: d.questions[shown[k]],
                        a: d.answers[d.questions[shown[k]].id],
                        subject: d.subjectNames[d.questions[shown[k]].subjectId],
                      ),
                    ),
            ),
          ],
        );
      }, onRetry: () => ref.invalidate(attemptViewProvider(widget.attemptId))),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.n, required this.q, required this.a, this.subject});
  final int n;
  final CachedQuestion q;
  final LocalAnswer? a;
  final String? subject;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final options = Map<String, String>.from(jsonDecode(q.optionsJson) as Map);
    final chose = a?.choice?.toUpperCase();
    final right = chose == q.answer;
    final (tag, tagBg, tagFg) = chose == null
        ? ('Not answered', c.surfaceSunken, c.textMuted)
        : right
        ? ('Correct', c.successSoft, c.onSuccessSoft)
        : ('Wrong', c.errorSoft, c.onErrorSoft);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Question $n', style: context.t.labelLarge),
                if (subject != null) Text(' · $subject', style: context.t.bodySmall),
                const Spacer(),
                if (a?.flagged == true)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(PhosphorIcons.flag(PhosphorIconsStyle.fill), size: 16, color: c.flagged),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(Radii.pill)),
                  child: Text(
                    tag,
                    style: context.t.labelSmall?.copyWith(color: tagFg, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (q.passageTitle != null) ...[gap2, Text('Passage: ${q.passageTitle}', style: context.t.bodySmall?.copyWith(color: c.textMuted))],
            gap3,
            MathText(q.body, style: context.t.bodyLarge),
            if (q.imagePath != null) ...[gap3, QuestionImage(imageKey: q.imagePath!)],
            gap3,
            for (final k in options.keys.toList()..sort())
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s2),
                child: Container(
                  padding: const EdgeInsets.all(Space.s3),
                  decoration: BoxDecoration(
                    color: k == q.answer
                        ? c.successSoft
                        : k == chose
                        ? c.errorSoft
                        : null,
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border: Border.all(
                      color: k == q.answer
                          ? c.success
                          : k == chose
                          ? c.error
                          : c.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text('$k.', style: context.t.labelLarge),
                      gap3,
                      Expanded(child: MathText(options[k]!, style: context.t.bodyMedium)),
                      if (k == q.answer) Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), size: 18, color: c.success, semanticLabel: 'Correct answer'),
                      if (k == chose && !right) Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), size: 18, color: c.error, semanticLabel: 'Your answer'),
                    ],
                  ),
                ),
              ),
            if ((q.explanation ?? '').isNotEmpty) ...[
              gap2,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Space.s3),
                decoration: BoxDecoration(color: c.secondarySoft, borderRadius: BorderRadius.circular(Radii.md)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(PhosphorIcons.lightbulb(PhosphorIconsStyle.fill), size: 16, color: c.onSecondarySoft),
                        const SizedBox(width: 6),
                        Text('Explanation', style: context.t.labelLarge?.copyWith(color: c.onSecondarySoft)),
                      ],
                    ),
                    gap2,
                    MathText(q.explanation!, style: context.t.bodyMedium?.copyWith(color: c.onSecondarySoft)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
