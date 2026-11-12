import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/math_text.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import 'tutor.dart';
import 'tutor_chat.dart' show TutorAvatar;

// Tutor quizzes (D-154): the tutor sets a quiz (random past questions, their own questions, or both); the student finds
// it in the chat, on Home and in Test, takes it here with an optional timer, and sees the score and every answer at the
// end. Answers stay on the server until the quiz is submitted; the tutor sees the result and what was missed.

/// The student's quizzes (empty, with no server call, when they have no tutor).
final tutorQuizzesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final req = ref.watch(tutorProvider).value?['request'];
  if (req == null) return const [];
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const [];
  return cached(
    ref,
    'tutor_quizzes:$uid',
    (s) => s.rpc('tutor_quizzes_mine'),
    (j) => [for (final x in (j as List? ?? const [])) Map<String, dynamic>.from(x as Map)],
  );
});

/// "Due today", "Due tomorrow", "Due 14 Nov", "Overdue".
String quizDue(Object? iso, [DateTime? now]) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '';
  final n = now ?? DateTime.now();
  if (d.isBefore(n)) return 'Overdue';
  final days = DateTime(d.year, d.month, d.day).difference(DateTime(n.year, n.month, n.day)).inDays;
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  return 'Due ${tutorDate(d.toIso8601String()).replaceAll(RegExp(r' \d{4}$'), '')}';
}

/// Score words for the result screen.
String quizCheer(int score, int total) {
  final p = total == 0 ? 0 : score / total;
  if (p >= .9) return 'Excellent! Your tutor will be proud.';
  if (p >= .7) return 'Great work. A few to look at again.';
  if (p >= .5) return 'Good effort. Go through the ones you missed.';
  return 'Keep going. Your tutor will help you with these.';
}

bool quizPending(Map<String, dynamic> q) => q['state'] == 'new' || q['state'] == 'started';

/// Home: "From your tutor" with the quizzes still to do. Nothing at all when there are none.
class TutorQuizHomeCard extends ConsumerWidget {
  const TutorQuizHomeCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = (ref.watch(tutorQuizzesProvider).value ?? const []).where(quizPending).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectTitle('From your tutor', action: list.length > 1 ? 'See all' : null, onAction: () => context.push('/tutor/quizzes')),
        for (final (i, q) in list.take(2).indexed) ...[if (i > 0) const Gap(Space.s2), TutorQuizTile(q: q, big: i == 0)],
      ],
    );
  }
}

/// One quiz: the tutor's photo, the title, questions / minutes / due, and Start, Continue or the score.
class TutorQuizTile extends StatelessWidget {
  const TutorQuizTile({super.key, required this.q, this.big = false});
  final Map<String, dynamic> q;
  final bool big;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final state = '${q['state']}';
    final done = state == 'done';
    final due = quizDue(q['due_at']);
    final mins = (q['minutes'] as num?)?.toInt();
    final meta = ['${q['count']} questions', if (mins != null) '$mins min', if (!done && due.isNotEmpty) due].join(' · ');
    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: big && !done ? Palette.navy900 : c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: big && !done ? Palette.navy900 : c.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/tutor/quiz/${q['id']}'),
          child: Padding(
            padding: const EdgeInsets.all(Space.s4),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    TutorAvatar(name: '${q['tutor'] ?? 'Tutor'}', photo: q['tutor_photo'] as String?, size: 48),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Palette.gold400,
                          shape: BoxShape.circle,
                          border: Border.all(color: big && !done ? Palette.navy900 : c.surface, width: 2),
                        ),
                        child: Icon(PhosphorIcons.exam(PhosphorIconsStyle.fill), size: 12, color: Palette.navy900),
                      ),
                    ),
                  ],
                ),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done ? 'QUIZ DONE' : (state == 'started' ? 'QUIZ IN PROGRESS' : 'NEW QUIZ'),
                        style: context.ty.cap.bold
                            .col(big && !done ? Palette.gold400 : (context.isDark ? Palette.gold400 : Palette.gold700))
                            .copyWith(fontSize: 10.5, letterSpacing: .6),
                      ),
                      Text(
                        '${q['title']}',
                        style: context.ty.body.bold.col(big && !done ? Colors.white : c.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(meta, style: context.ty.cap.col(big && !done ? Palette.navy100 : (due == 'Overdue' && !done ? c.error : c.textMuted))),
                    ],
                  ),
                ),
                const Gap(Space.s2),
                if (done)
                  _ScorePill(score: (q['score'] as num?)?.toInt() ?? 0, total: (q['total'] as num?)?.toInt() ?? 0)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(color: Palette.gold400, borderRadius: BorderRadius.circular(14)),
                    child: Text(state == 'started' ? 'Continue' : 'Start', style: context.ty.sm.bold.col(Palette.navy900)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return context.reduceMotion ? card : card.animate().fadeIn(duration: Motion.base).slideY(begin: .08, end: 0, curve: Curves.easeOut);
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score, required this.total});
  final int score, total;
  @override
  Widget build(BuildContext context) {
    final good = total > 0 && score / total >= .5;
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: good ? c.successSoft : c.errorSoft, borderRadius: BorderRadius.circular(14)),
      child: Text('$score/$total', style: context.ty.sm.bold.tnum.col(good ? c.onSuccessSoft : c.onErrorSoft)),
    );
  }
}

/// Test tab entry: only when the student has quizzes.
class TutorQuizTestEntry extends ConsumerWidget {
  const TutorQuizTestEntry({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(tutorQuizzesProvider).value ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    final todo = list.where(quizPending).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s3),
      child: AppCard(
        onTap: () => context.push('/tutor/quizzes'),
        child: Row(
          children: [
            IconTile(PhosphorIcons.exam(PhosphorIconsStyle.fill), tone: Tone.gold, size: 48),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tutor quizzes', style: context.ty.body.bold),
                  Text(
                    todo > 0 ? '$todo new from ${'${list.first['tutor'] ?? 'your tutor'}'.split(' ').first}' : 'Your results and answers',
                    style: context.ty.cap.col(todo > 0 ? context.c.success : context.c.textMuted),
                  ),
                ],
              ),
            ),
            if (todo > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Palette.gold400, borderRadius: BorderRadius.circular(12)),
                child: Text('$todo', style: context.ty.cap.bold.col(Palette.navy900)),
              )
            else
              Icon(PhosphorIcons.caretRight(), size: 18, color: context.c.textSubtle),
          ],
        ),
      ),
    );
  }
}

class TutorQuizzesScreen extends ConsumerWidget {
  const TutorQuizzesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(tutorQuizzesProvider);
    return Scaffold(
      appBar: const TopBar(title: 'Tutor quizzes'),
      body: asyncView(
        v,
        onRetry: () => ref.invalidate(tutorQuizzesProvider),
        (list) => list.isEmpty
            ? StateBlock(
                icon: PhosphorIcons.exam(PhosphorIconsStyle.fill),
                tone: Tone.gold,
                title: 'No quizzes yet',
                text: 'When your tutor sets a quiz, it shows here, on Home and in your chat.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(tutorQuizzesProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s4, Space.s8),
                  children: [
                    if (list.any(quizPending)) ...[
                      const SectTitle('To do'),
                      for (final q in list.where(quizPending)) ...[TutorQuizTile(q: q), const Gap(Space.s2)],
                    ],
                    if (list.any((q) => !quizPending(q))) ...[
                      const SectTitle('Done'),
                      for (final q in list.where((q) => !quizPending(q))) ...[TutorQuizTile(q: q), const Gap(Space.s2)],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// Takes a quiz: one question at a time, a question grid, an optional countdown that submits by itself, progress saved
/// on the server as the student goes; then the score and every answer.
class TutorQuizScreen extends ConsumerStatefulWidget {
  const TutorQuizScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<TutorQuizScreen> createState() => _TutorQuizScreenState();
}

class _TutorQuizScreenState extends ConsumerState<TutorQuizScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  final _answers = <String, String>{};
  int _i = 0;
  bool _submitting = false;
  Timer? _tick, _saveSoon;
  DateTime? _ends;

  SupabaseClient get _db => Supabase.instance.client;
  bool get _review => _data?['review'] == true;
  List<Map<String, dynamic>> get _qs => [for (final q in (_data?['questions'] as List? ?? const [])) Map<String, dynamic>.from(q as Map)];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _saveSoon?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = Map<String, dynamic>.from(await _db.rpc('tutor_quiz_start', params: {'p_quiz': widget.id}).timeout(const Duration(seconds: 20)) as Map);
      if (r['ok'] != true) {
        setState(() => _error = r['error'] == 'closed' ? 'Your tutor closed this quiz.' : 'Could not open the quiz.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _data = r;
        if (r['answers'] is Map) _answers.addAll({for (final e in (r['answers'] as Map).entries) '${e.key}': '${e.value}'});
      });
      final mins = ((r['quiz'] as Map?)?['minutes'] as num?)?.toInt();
      final started = DateTime.tryParse('${r['started_at'] ?? ''}')?.toLocal();
      if (!_review && mins != null && started != null) {
        _ends = started.add(Duration(minutes: mins));
        _tick = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() {});
          if (DateTime.now().isAfter(_ends!)) {
            _tick?.cancel();
            _submit(force: true);
          }
        });
      }
      ref.invalidate(tutorQuizzesProvider);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach SolutionTee. Check your internet and try again.');
    }
  }

  void _pick(String qid, String key) {
    setState(() => _answers[qid] = key);
    _saveSoon?.cancel();
    _saveSoon = Timer(const Duration(milliseconds: 1500), () {
      _db.rpc('tutor_quiz_save', params: {'p_quiz': widget.id, 'p_answers': _answers}).catchError((_) => null);
    });
  }

  Future<void> _submit({bool force = false}) async {
    if (_submitting) return;
    final left = _qs.length - _answers.length;
    if (!force && left > 0) {
      final go = await showAppDialog<bool>(
        context,
        title: 'Submit now?',
        body: '$left question${left == 1 ? ' is' : 's are'} not answered yet. You cannot change your answers after you submit.',
        icon: PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill),
        actions: [
          Btn('Submit', block: true, onPressed: () => Navigator.pop(context, true)),
          Btn('Keep going', kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(context, false)),
        ],
      );
      if (go != true) return;
    }
    setState(() => _submitting = true);
    try {
      final r = Map<String, dynamic>.from(
        await _db.rpc('tutor_quiz_submit', params: {'p_quiz': widget.id, 'p_answers': _answers}).timeout(const Duration(seconds: 25)) as Map,
      );
      if (!mounted) return;
      _tick?.cancel();
      setState(() => (_data = r, _i = 0));
      ref.invalidate(tutorQuizzesProvider);
      if (force) toast(context, 'Time is up. Your answers were sent.', icon: PhosphorIcons.timer(PhosphorIconsStyle.fill));
    } catch (_) {
      if (mounted) toast(context, 'Could not submit. Check your internet and try again.', icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _grid() => showSheet<void>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Questions', style: ctx.ty.h2),
        const Gap(Space.s1),
        Text('${_answers.length} of ${_qs.length} answered', style: ctx.ty.sm.col(ctx.c.textMuted)),
        const Gap(Space.s4),
        Wrap(
          spacing: Space.s2,
          runSpacing: Space.s2,
          children: [
            for (final (i, q) in _qs.indexed)
              Pressable(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _i = i);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _answers.containsKey('${q['id']}') ? Palette.navy900 : ctx.c.surfaceSunken,
                    borderRadius: BorderRadius.circular(12),
                    border: i == _i ? Border.all(color: Palette.gold400, width: 2) : null,
                  ),
                  child: Text('${i + 1}', style: ctx.ty.sm.bold.col(_answers.containsKey('${q['id']}') ? Colors.white : ctx.c.text)),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final quiz = Map<String, dynamic>.from(_data?['quiz'] as Map? ?? const {});
    if (_error != null) {
      return Scaffold(
        appBar: const TopBar(title: 'Quiz'),
        body: StateBlock(
          icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
          tone: Tone.red,
          title: 'Quiz not available',
          text: _error,
          action: Btn('Try again', onPressed: _load),
        ),
      );
    }
    if (_data == null) {
      return Scaffold(
        appBar: const TopBar(title: 'Quiz'),
        body: const ListSkeleton(),
      );
    }
    return _review ? _QuizReview(data: _data!) : _take(context, quiz);
  }

  Widget _take(BuildContext context, Map<String, dynamic> quiz) {
    final c = context.c;
    final qs = _qs;
    final q = qs[_i];
    final qid = '${q['id']}';
    final opts = Map<String, dynamic>.from(q['options'] as Map? ?? const {});
    final left = _ends?.difference(DateTime.now());
    final last = _i == qs.length - 1;
    return Scaffold(
      appBar: TopBar(
        title: '${quiz['title'] ?? 'Quiz'}',
        actions: [
          if (left != null)
            Container(
              margin: const EdgeInsets.only(right: Space.s3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: left.inSeconds < 60 ? c.errorSoft : c.surfaceSunken, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.timer(PhosphorIconsStyle.fill), size: 16, color: left.inSeconds < 60 ? c.onErrorSoft : c.textMuted),
                  const Gap(4),
                  Text(fmtClock(math.max(0, left.inSeconds)), style: context.ty.sm.bold.tnum.col(left.inSeconds < 60 ? c.onErrorSoft : c.text)),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s4),
            child: Row(
              children: [
                Text('Question ${_i + 1} of ${qs.length}', style: context.ty.sm.bold.col(c.textMuted)),
                const Spacer(),
                TextButton.icon(onPressed: _grid, icon: Icon(PhosphorIcons.gridFour(), size: 18), label: Text('${_answers.length}/${qs.length} answered')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: (_i + 1) / qs.length, minHeight: 4, color: Palette.gold400, backgroundColor: c.surfaceSunken),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: context.reduceMotion ? Duration.zero : Motion.base,
              transitionBuilder: (w, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(.04, 0), end: Offset.zero).animate(a),
                  child: w,
                ),
              ),
              child: ListView(
                key: ValueKey(qid),
                padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s6),
                children: [
                  MathText('${q['body']}', style: context.ty.lg.copyWith(height: 1.45)),
                  const Gap(Space.s5),
                  for (final e in opts.entries) ...[
                    _Option(letter: e.key, text: '${e.value}', on: _answers[qid] == e.key, onTap: () => _pick(qid, e.key)),
                    const Gap(Space.s2),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.bg,
          border: Border(top: BorderSide(color: c.border)),
        ),
        padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, Space.s3),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              if (_i > 0) ...[
                Expanded(
                  child: Btn('Back', kind: BtnKind.outline, onPressed: () => setState(() => _i--)),
                ),
                const Gap(Space.s3),
              ],
              Expanded(
                flex: 2,
                child: last
                    ? Btn('Submit quiz', kind: BtnKind.accent, loading: _submitting, onPressed: _submitting ? null : _submit)
                    : Btn('Next', icon: PhosphorIcons.arrowRight(), onPressed: () => setState(() => _i++)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String fmtClock(int secs) => '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';

class _Option extends StatelessWidget {
  const _Option({required this.letter, required this.text, required this.on, required this.onTap, this.state});
  final String letter, text;
  final bool on;
  final VoidCallback? onTap;

  /// Review: 'right', 'wrong' or null.
  final String? state;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final right = state == 'right', wrong = state == 'wrong';
    final border = right ? c.success : (wrong ? c.error : (on ? Palette.gold400 : c.border));
    final bg = right ? c.successSoft : (wrong ? c.errorSoft : (on ? (context.isDark ? Palette.navy800 : Palette.gold50) : c.surface));
    return Semantics(
      button: onTap != null,
      selected: on,
      child: Pressable(
        onTap: onTap,
        scale: .985,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: Motion.fast,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: on || right || wrong ? 2 : 1),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: Motion.fast,
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: right ? c.success : (wrong ? c.error : (on ? Palette.gold400 : c.surfaceSunken))),
                child: right || wrong
                    ? Icon(right ? PhosphorIcons.check() : PhosphorIcons.x(), size: 16, color: Colors.white)
                    : Text(letter, style: context.ty.sm.bold.col(on ? Palette.navy900 : c.textMuted)),
              ),
              const Gap(Space.s3),
              Expanded(child: MathText(text, style: context.ty.body)),
            ],
          ),
        ),
      ),
    );
  }
}

/// After submitting: the score in a ring that fills, then every question with the student's choice and the right answer.
class _QuizReview extends StatefulWidget {
  const _QuizReview({required this.data});
  final Map<String, dynamic> data;
  @override
  State<_QuizReview> createState() => _QuizReviewState();
}

class _QuizReviewState extends State<_QuizReview> {
  bool _missed = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final quiz = Map<String, dynamic>.from(widget.data['quiz'] as Map? ?? const {});
    final score = (widget.data['score'] as num?)?.toInt() ?? 0;
    final total = math.max(1, (widget.data['total'] as num?)?.toInt() ?? 1);
    final qs = [for (final q in (widget.data['questions'] as List? ?? const [])) Map<String, dynamic>.from(q as Map)];
    final shown = _missed ? qs.where((q) => q['correct'] != true).toList() : qs;
    final pct = score / total;
    final ring = SizedBox(
      width: 132,
      height: 132,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: pct),
        duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                color: pct >= .5 ? c.success : Palette.gold400,
                backgroundColor: c.surfaceSunken,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$score/$total', style: context.ty.display.tnum.copyWith(fontSize: 30)),
                Text('${(v * 100).round()}%', style: context.ty.sm.bold.col(c.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: TopBar(title: '${quiz['title'] ?? 'Quiz'}'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s4, Space.s8),
        children: [
          Center(child: ring),
          const Gap(Space.s3),
          Text(quizCheer(score, total), style: context.ty.h3, textAlign: TextAlign.center),
          const Gap(Space.s1),
          Text('Your tutor can see your result and the questions you missed.', style: context.ty.sm.col(c.textMuted), textAlign: TextAlign.center),
          const Gap(Space.s4),
          Row(
            children: [
              Expanded(child: Text('Your answers', style: context.ty.h3)),
              AppChip('Only missed', on: _missed, onTap: () => setState(() => _missed = !_missed)),
            ],
          ),
          const Gap(Space.s3),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Space.s5),
              child: Text('You got every question right!', style: context.ty.body.bold, textAlign: TextAlign.center),
            ),
          for (final q in shown) ...[
            Container(
              padding: const EdgeInsets.all(Space.s4),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('Question ${qs.indexOf(q) + 1}', style: context.ty.cap.bold.col(c.textMuted)),
                      const Spacer(),
                      Pill(
                        q['correct'] == true ? 'Right' : (q['chosen'] == null ? 'Not answered' : 'Missed'),
                        kind: q['correct'] == true ? BadgeKind.success : BadgeKind.error,
                      ),
                    ],
                  ),
                  const Gap(Space.s2),
                  MathText('${q['body']}', style: context.ty.body),
                  const Gap(Space.s3),
                  for (final e in Map<String, dynamic>.from(q['options'] as Map? ?? const {}).entries) ...[
                    _Option(
                      letter: e.key,
                      text: '${e.value}',
                      on: q['chosen'] == e.key,
                      onTap: null,
                      state: e.key == q['answer'] ? 'right' : (e.key == q['chosen'] ? 'wrong' : null),
                    ),
                    const Gap(6),
                  ],
                  if ('${q['explanation'] ?? ''}'.isNotEmpty) ...[
                    const Gap(Space.s2),
                    Container(
                      padding: const EdgeInsets.all(Space.s3),
                      decoration: BoxDecoration(color: c.secondarySoft, borderRadius: BorderRadius.circular(12)),
                      child: MathText('${q['explanation']}', style: context.ty.sm.col(c.onSecondarySoft)),
                    ),
                  ],
                ],
              ),
            ),
            const Gap(Space.s3),
          ],
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s4, Space.s4),
        child: SafeArea(top: false, child: Btn('Back to my tutor', block: true, onPressed: () => context.canPop() ? context.pop() : context.go('/tutor'))),
      ),
    );
  }
}
