import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../data/ai_repo.dart' show AiChip;
import '../../data/tests_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../study/note_screens.dart' show NoteBody;

/// Cards the AI tutor shows inside the chat (U3). The server sends them as JSON (see supabase/functions/ai-chat) and
/// saves them in `ai_messages.card`, so they come back with the chat history.

/// Icon for a tool name.
IconData aiToolIcon(String name) => switch (name) {
  'practice_test' => PhosphorIcons.exam(PhosphorIconsStyle.fill),
  'quiz' => PhosphorIcons.question(PhosphorIconsStyle.fill),
  'open_note' => PhosphorIcons.note(PhosphorIconsStyle.fill),
  'qotd' => PhosphorIcons.lightbulb(PhosphorIconsStyle.fill),
  'weak_topics' => PhosphorIcons.chartLineUp(PhosphorIconsStyle.fill),
  'study_plan' => PhosphorIcons.calendarCheck(PhosphorIconsStyle.fill),
  _ => PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
};

/// Sends a message from a card: a chip-like text, with an optional tool and its arguments.
typedef AiSendFn = void Function({String? text, String? tool, Map<String, dynamic>? args, String? questionId, bool explain});

/// Marks one quiz answer on the server.
typedef QuizCheckFn = Future<Map<String, dynamic>> Function(String questionId, String choice);

/// Swaps the "working" card for the real card (200 to 400 ms, ease-out; instant with reduce motion).
class AiToolSlot extends StatelessWidget {
  const AiToolSlot({super.key, required this.name, this.label, this.running = false, this.card, required this.send, required this.check, this.onStarted});
  final String name;
  final String? label;
  final bool running;
  final Map<String, dynamic>? card;
  final AiSendFn send;
  final QuizCheckFn check;
  final ValueChanged<String>? onStarted;

  @override
  Widget build(BuildContext context) {
    final Widget child = running
        ? AiWorkingCard(key: const ValueKey('working'), name: name, label: label ?? 'Working on it…')
        : card == null
        ? const SizedBox.shrink(key: ValueKey('none'))
        : AiCardView(key: ValueKey('card-${card.hashCode}'), card: card!, send: send, check: check, onStarted: onStarted);
    return AnimatedSwitcher(
      duration: context.reduceMotion ? Duration.zero : Motion.base,
      switchInCurve: Motion.out,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: SizeTransition(sizeFactor: a, alignment: Alignment.topCenter, child: c),
      ),
      layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, ?cur]),
      child: child,
    );
  }
}

/// "Building your test…": icon, label and a shimmering bar. Loops only when motion is allowed.
class AiWorkingCard extends StatelessWidget {
  const AiWorkingCard({super.key, required this.name, required this.label});
  final String name, label;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    Widget bar = Container(
      height: 8,
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(99)),
    );
    if (!rm) bar = bar.animate(onPlay: (a) => a.repeat()).shimmer(duration: 1200.ms, color: c.secondary.withValues(alpha: .35));
    return Semantics(
      liveRegion: true,
      label: label,
      child: AppCard(
        child: Row(
          children: [
            IconTile(aiToolIcon(name), tone: Tone.blue),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.ty.sm.bold),
                  const Gap(Space.s2),
                  bar,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks the right card for `card['type']`. Unknown types show nothing (older apps stay safe).
class AiCardView extends StatelessWidget {
  const AiCardView({super.key, required this.card, required this.send, required this.check, this.onStarted});
  final Map<String, dynamic> card;
  final AiSendFn send;
  final QuizCheckFn check;
  final ValueChanged<String>? onStarted;
  @override
  Widget build(BuildContext context) => switch (card['type']) {
    'test' => TestCard(card: card, onStarted: onStarted),
    'quiz' => QuizCard(
      card: card,
      check: check,
      onExplain: (id) => send(questionId: id, explain: true),
    ),
    'notes' => NotesCard(card: card),
    'weak' => WeakCard(
      card: card,
      onQuiz: (subject, topic) => send(text: 'Quiz me on $topic', tool: 'quiz', args: {'subject': subject, 'topic': topic, 'count': 3}),
    ),
    'qotd' => _HeaderChip(icon: aiToolIcon('qotd'), text: card['answered'] == true ? "Today's question · answered" : "Today's question · hint only"),
    'plan' => _HeaderChip(icon: aiToolIcon('study_plan'), text: 'Your 7-day plan'),
    _ => const SizedBox.shrink(),
  };
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Pill(text, icon: icon),
  );
}

int _int(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;

// ---------------------------------------------------------------- test
/// "10 hard Physics questions on motion" with a Start test button that opens the CBT screen.
class TestCard extends ConsumerStatefulWidget {
  const TestCard({super.key, required this.card, this.onStarted});
  final Map<String, dynamic> card;

  /// Called with the new test's id. Default: opens `/cbt/<id>`.
  final ValueChanged<String>? onStarted;
  @override
  ConsumerState<TestCard> createState() => _TestCardState();
}

class _TestCardState extends ConsumerState<TestCard> {
  bool _loading = false;
  String? _error;

  Map<String, dynamic> get _c => widget.card;

  Future<void> _start() async {
    if (_loading) return;
    final ids = [for (final i in (_c['ids'] as List? ?? const [])) '$i'];
    final topics = [for (final t in (_c['topics'] as List? ?? const [])) '$t'];
    final count = _int(_c['count'], ids.length);
    final subject = '${_c['subject'] ?? ''}';
    setState(() {
      _loading = true;
      _error = null;
    });
    HapticFeedback.lightImpact();
    try {
      final id = await ref
          .read(testsRepoProvider)
          .start(
            TestRequest(
              mode: TestMode.topic,
              examId: _int(_c['exam_id']),
              examCode: '${_c['exam'] ?? ''}',
              subjectIds: [_int(_c['subject_id'])],
              topics: topics,
              ids: ids,
              years: [for (final y in (_c['years'] as List? ?? const [])) _int(y)],
              count: count,
              limitMinutes: _int(_c['minutes'], count),
              timed: true,
              title: 'AI test · $subject${topics.isEmpty ? '' : ' · ${topics.first}'}',
            ),
            countFor: (_) => count,
            minutesPerQuestion: 1,
          );
      if (!mounted) return;
      if (widget.onStarted != null) {
        widget.onStarted!(id);
      } else {
        context.push('/cbt/$id');
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not build the test. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final topics = [for (final t in (_c['topics'] as List? ?? const [])) '$t'];
    final diff = _c['difficulty'] as String?;
    final count = _int(_c['count']);
    final minutes = _int(_c['minutes']);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(aiToolIcon('practice_test'), tone: Tone.gold),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_c['subject'] ?? 'Practice'} test', style: context.ty.body.bold),
                    Text('${_c['exam'] ?? ''} · $count questions · $minutes min', style: context.ty.cap.col(c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          if (topics.isNotEmpty || diff != null) ...[
            const Gap(Space.s3),
            Wrap(
              spacing: Space.s2,
              runSpacing: Space.s2,
              children: [
                for (final t in topics) Pill(t),
                if (diff != null) Pill(_cap(diff), kind: diff == 'hard' ? BadgeKind.warning : BadgeKind.neutral),
              ],
            ),
          ],
          if (_error != null) ...[const Gap(Space.s3), Text(_error!, style: context.ty.sm.col(c.error))],
          const Gap(Space.s4),
          Btn('Start test', block: true, loading: _loading, icon: PhosphorIcons.arrowRight(), onPressed: _start),
        ],
      ),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ---------------------------------------------------------------- quiz
class _Answer {
  _Answer(this.choice);
  final String choice;
  bool loading = true, failed = false, correct = false;
  String? answer, explanation;
}

/// Questions without answers; a tap is marked by the server (free), then the official explanation shows.
class QuizCard extends StatefulWidget {
  const QuizCard({super.key, required this.card, required this.check, required this.onExplain});
  final Map<String, dynamic> card;
  final QuizCheckFn check;
  final ValueChanged<String> onExplain;
  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> {
  final _answers = <String, _Answer>{};

  Future<void> _pick(String qid, String choice) async {
    if (_answers.containsKey(qid)) return; // one answer per question
    HapticFeedback.selectionClick();
    final a = _Answer(choice);
    setState(() => _answers[qid] = a);
    Map<String, dynamic> r;
    try {
      r = await widget.check(qid, choice);
    } catch (_) {
      r = const {'ok': false};
    }
    if (!mounted) return;
    setState(() {
      a.loading = false;
      if (r['ok'] == true) {
        a.correct = r['correct'] == true;
        a.answer = r['answer'] as String?;
        a.explanation = r['explanation'] as String?;
      } else {
        a.failed = true;
      }
    });
    if (r['ok'] == true) HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final qs = [
      for (final q in (widget.card['questions'] as List? ?? const []))
        if (q is Map) Map<String, dynamic>.from(q),
    ];
    final c = context.c;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(aiToolIcon('quiz'), tone: Tone.blue),
              const Gap(Space.s3),
              Expanded(
                child: Text('${widget.card['subject'] ?? 'Quiz'} quiz · ${qs.length} question${qs.length == 1 ? '' : 's'}', style: context.ty.body.bold),
              ),
            ],
          ),
          for (final (i, q) in qs.indexed) ...[
            const Gap(Space.s4),
            Text('${i + 1}.', style: context.ty.cap.col(c.textMuted)),
            NoteBody(text: '${q['body'] ?? ''}', scale: .94),
            const Gap(Space.s2),
            _options(context, q),
          ],
        ],
      ),
    );
  }

  Widget _options(BuildContext context, Map<String, dynamic> q) {
    final c = context.c;
    final id = '${q['id']}';
    final opts = Map<String, dynamic>.from((q['options'] as Map?) ?? const {});
    final keys = opts.keys.toList()..sort();
    final a = _answers[id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final k in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s2),
            child: _OptionRow(letter: k, text: '${opts[k]}', state: _stateFor(a, k), onTap: a == null ? () => _pick(id, k) : null),
          ),
        if (a != null && a.failed)
          Text('Could not check this answer. Check your internet.', style: context.ty.sm.col(c.error))
        else if (a != null && !a.loading) ...[
          const Gap(Space.s1),
          Row(
            children: [
              Icon(
                a.correct ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                size: 20,
                color: a.correct ? c.success : c.error,
              ),
              const Gap(Space.s2),
              Text(a.correct ? 'Correct!' : 'The answer is ${a.answer ?? ''}', style: context.ty.sm.bold.col(a.correct ? c.success : c.error)),
            ],
          ),
          if (a.explanation != null && a.explanation!.trim().isNotEmpty) ...[
            const Gap(Space.s2),
            Container(
              padding: const EdgeInsets.all(Space.s3),
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
              child: NoteBody(text: a.explanation!, scale: .92),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(
              'Explain with AI',
              kind: BtnKind.ghost,
              sm: true,
              leading: PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
              onPressed: () => widget.onExplain(id),
            ),
          ),
        ],
      ],
    );
  }

  _OptState _stateFor(_Answer? a, String k) {
    if (a == null) return _OptState.idle;
    if (a.loading) return a.choice == k ? _OptState.checking : _OptState.idle;
    if (a.answer == k) return _OptState.right;
    if (a.choice == k) return _OptState.wrong;
    return _OptState.idle;
  }
}

enum _OptState { idle, checking, right, wrong }

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.letter, required this.text, required this.state, required this.onTap});
  final String letter, text;
  final _OptState state;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, border, fg) = switch (state) {
      _OptState.right => (c.successSoft, c.success, c.onSuccessSoft),
      _OptState.wrong => (c.errorSoft, c.error, c.onErrorSoft),
      _OptState.checking => (c.secondarySoft, c.secondary, c.onSecondarySoft),
      _OptState.idle => (c.surface, c.borderStrong, c.text),
    };
    final icon = switch (state) {
      _OptState.right => PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
      _OptState.wrong => PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
      _ => null,
    };
    final r = BorderRadius.circular(Radii.md);
    return Semantics(
      button: onTap != null,
      label: 'Option $letter',
      child: Pressable(
        onTap: onTap,
        scale: .985,
        borderRadius: r,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.out,
          constraints: const BoxConstraints(minHeight: Sizes.tapMin),
          padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: r,
            border: Border.all(color: border, width: state == _OptState.idle ? 1.5 : 2),
          ),
          child: Row(
            children: [
              Text('$letter.', style: context.ty.sm.bold.col(fg)),
              const Gap(Space.s2),
              Expanded(child: NoteBody(text: text, scale: .9)),
              if (icon != null) ...[const Gap(Space.s2), Icon(icon, size: 22, color: state == _OptState.right ? c.success : c.error)],
              if (state == _OptState.checking) ...[
                const Gap(Space.s2),
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: c.secondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- notes
/// Lesson notes the student may open.
class NotesCard extends StatelessWidget {
  const NotesCard({super.key, required this.card, this.onOpen});
  final Map<String, dynamic> card;
  final ValueChanged<String>? onOpen;
  @override
  Widget build(BuildContext context) {
    final items = [
      for (final i in (card['items'] as List? ?? const []))
        if (i is Map) Map<String, dynamic>.from(i),
    ];
    final c = context.c;
    return AppCard(
      pad: false,
      child: Column(
        children: [
          for (final (i, n) in items.indexed) ...[
            if (i > 0) Divider(height: 1, color: c.border),
            Pressable(
              onTap: () => onOpen != null ? onOpen!('${n['id']}') : context.push('/study/note/${n['id']}'),
              borderRadius: BorderRadius.circular(Radii.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sizes.tapMin + 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
                  child: Row(
                    children: [
                      IconTile(aiToolIcon('open_note'), tone: Tone.green),
                      const Gap(Space.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${n['title'] ?? ''}', style: context.ty.sm.bold),
                            if ('${n['subtitle'] ?? ''}'.isNotEmpty) Text('${n['subtitle']}', style: context.ty.cap.col(c.textMuted)),
                          ],
                        ),
                      ),
                      Icon(
                        n['locked'] == true ? PhosphorIcons.lockSimple(PhosphorIconsStyle.fill) : PhosphorIcons.caretRight(),
                        size: 20,
                        color: n['locked'] == true ? c.onAccentSoft : c.textSubtle,
                        semanticLabel: n['locked'] == true ? 'Premium' : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- weak topics
/// Accuracy bars for the weakest topics, each with a "Quiz me" action.
class WeakCard extends StatelessWidget {
  const WeakCard({super.key, required this.card, required this.onQuiz});
  final Map<String, dynamic> card;
  final void Function(String subject, String topic) onQuiz;
  @override
  Widget build(BuildContext context) {
    final items = [
      for (final i in (card['items'] as List? ?? const []))
        if (i is Map) Map<String, dynamic>.from(i),
    ];
    final c = context.c;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(aiToolIcon('weak_topics'), tone: Tone.gold),
              const Gap(Space.s3),
              Text('Your weak topics', style: context.ty.body.bold),
            ],
          ),
          for (final w in items) ...[
            const Gap(Space.s4),
            Builder(
              builder: (context) {
                final pct = _int(w['pct']).clamp(0, 100);
                final color = pct < 40
                    ? c.error
                    : pct < 60
                    ? c.warning
                    : c.success;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${w['topic'] ?? ''}', style: context.ty.sm.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Text('$pct%', style: context.ty.sm.bold.tnum.col(color)),
                      ],
                    ),
                    Text('${w['subject'] ?? ''} · ${_int(w['correct'])} of ${_int(w['answered'])} right', style: context.ty.cap.col(c.textMuted)),
                    const Gap(Space.s2),
                    ProgressBar(pct / 100, color: color),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Btn('Quiz me', kind: BtnKind.ghost, sm: true, onPressed: () => onQuiz('${w['subject'] ?? ''}', '${w['topic'] ?? ''}')),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- suggestions and typing
/// A row of suggestion chips that fades in one after another.
class AiChipRow extends StatelessWidget {
  const AiChipRow({super.key, required this.chips, required this.onTap});
  final List<AiChip> chips;
  final ValueChanged<AiChip> onTap;
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.s4),
      child: Row(
        children: [
          for (final (i, ch) in chips.indexed)
            Padding(
              padding: const EdgeInsets.only(right: Space.s2),
              child: _fade(rm, i, AppChip(ch.label, on: false, icon: PhosphorIcons.sparkle(PhosphorIconsStyle.fill), onTap: () => onTap(ch))),
            ),
        ],
      ),
    );
  }

  static Widget _fade(bool rm, int i, Widget w) => rm ? w : w.animate().fadeIn(delay: Motion.stagger * i, duration: Motion.base, curve: Motion.out);
}

/// Thinking state: three soft pulsing dots and a shimmering line.
class AiTyping extends StatelessWidget {
  const AiTyping({super.key, this.label});
  final String? label;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    Widget line = Container(
      width: 120,
      height: 8,
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(99)),
    );
    if (!rm) line = line.animate(onPlay: (a) => a.repeat()).shimmer(duration: 1200.ms, color: c.secondary.withValues(alpha: .3));
    return Semantics(
      liveRegion: true,
      label: label ?? 'Thinking',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: c.textSubtle, shape: BoxShape.circle),
                ).animate(onPlay: (a) => rm ? null : a.repeat(reverse: true)).fadeIn(begin: .3, delay: (150 * i).ms, duration: 450.ms),
              if (label != null) ...[const Gap(Space.s2), Text(label!, style: context.ty.cap.col(c.textMuted))],
            ],
          ),
          const Gap(Space.s2),
          line,
        ],
      ),
    );
  }
}
