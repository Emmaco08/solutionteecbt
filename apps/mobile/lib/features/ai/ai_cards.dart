import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../data/ai_repo.dart' show AiChip, aiRepoProvider;
import '../../data/tests_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../premium/paywall.dart';
import 'ai_quiz.dart';

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

/// Icon from a server icon name (suggestion chips, open cards). Unknown names show a sparkle.
IconData aiIconByName(String? name, {bool fill = false}) {
  final st = fill ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular;
  return switch (name) {
    'ranking' => PhosphorIcons.ranking(st),
    'trophy' => PhosphorIcons.trophy(st),
    'books' => PhosphorIcons.books(st),
    'notePencil' => PhosphorIcons.notePencil(st),
    'playCircle' => PhosphorIcons.playCircle(st),
    'bookOpen' => PhosphorIcons.bookOpen(st),
    'bookmarkSimple' => PhosphorIcons.bookmarkSimple(st),
    'clockCounterClockwise' => PhosphorIcons.clockCounterClockwise(st),
    'coins' => PhosphorIcons.coins(st),
    'fire' => PhosphorIcons.fire(st),
    'gift' => PhosphorIcons.gift(st),
    'crownSimple' => PhosphorIcons.crownSimple(st),
    'gearSix' => PhosphorIcons.gearSix(st),
    'newspaper' => PhosphorIcons.newspaper(st),
    'medal' => PhosphorIcons.medal(st),
    'downloadSimple' => PhosphorIcons.downloadSimple(st),
    'exam' => PhosphorIcons.exam(st),
    'lightbulb' => PhosphorIcons.lightbulb(st),
    'chalkboardTeacher' => PhosphorIcons.chalkboardTeacher(st),
    'question' => PhosphorIcons.question(st),
    'trendDown' => PhosphorIcons.trendDown(st),
    'chatsCircle' => PhosphorIcons.chatsCircle(st),
    'chartLineUp' => PhosphorIcons.chartLineUp(st),
    'calendarCheck' => PhosphorIcons.calendarCheck(st),
    'atom' => PhosphorIcons.atom(st),
    'function' => PhosphorIcons.function(st),
    'note' => PhosphorIcons.note(st),
    _ => PhosphorIcons.sparkle(st),
  };
}

/// Sends a message from a card: a chip-like text, with an optional tool and its arguments.
typedef AiSendFn = void Function({String? text, String? tool, Map<String, dynamic>? args, String? questionId, bool explain});

/// Marks one quiz answer on the server.
typedef QuizCheckFn = Future<Map<String, dynamic>> Function(String questionId, String choice);

/// Swaps the "working" card for the real card (200 to 400 ms, ease-out; instant with reduce motion).
/// While [running] it shows the agent steps; [finishing] ticks the rest just before the card arrives.
class AiToolSlot extends StatelessWidget {
  const AiToolSlot({
    super.key,
    required this.name,
    this.label,
    this.running = false,
    this.finishing = false,
    this.steps = const [],
    this.card,
    required this.send,
    required this.check,
    this.onStarted,
    this.onOpenChat,
  });
  final String name;
  final String? label;
  final bool running, finishing;
  final List<String> steps;
  final Map<String, dynamic>? card;
  final AiSendFn send;
  final QuizCheckFn check;
  final ValueChanged<String>? onStarted, onOpenChat;

  @override
  Widget build(BuildContext context) {
    final Widget child = running
        ? AiWorkingCard(key: const ValueKey('working'), name: name, label: label ?? 'Working on it…', steps: steps, finishing: finishing)
        : card == null
        ? const SizedBox.shrink(key: ValueKey('none'))
        : AiCardView(key: ValueKey('card-${card.hashCode}'), card: card!, send: send, check: check, onStarted: onStarted, onOpenChat: onOpenChat);
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

/// "Building your test…": the agent steps (spinner on the current one, ticks on the done ones, the next ones faded).
/// One step moves on about every 1.1 s; [finishing] ticks them all. Without steps it shows a label and a shimmering bar.
/// Loops only when motion is allowed; under reduce motion the current step shows a still dot.
class AiWorkingCard extends StatefulWidget {
  const AiWorkingCard({super.key, required this.name, required this.label, this.steps = const [], this.finishing = false});
  final String name, label;
  final List<String> steps;
  final bool finishing;
  @override
  State<AiWorkingCard> createState() => _AiWorkingCardState();
}

class _AiWorkingCardState extends State<AiWorkingCard> {
  int _cur = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (widget.steps.length > 1) {
      _t = Timer.periodic(const Duration(milliseconds: 1100), (_) {
        if (!mounted || widget.finishing) return;
        if (_cur < widget.steps.length - 1) setState(() => _cur++);
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final steps = widget.steps;
    Widget body;
    if (steps.isEmpty) {
      Widget bar = Container(
        height: 8,
        decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(99)),
      );
      if (!rm) bar = bar.animate(onPlay: (a) => a.repeat()).shimmer(duration: 1200.ms, color: c.secondary.withValues(alpha: .35));
      body = Row(
        children: [
          IconTile(aiToolIcon(widget.name), tone: Tone.blue),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label, style: context.ty.sm.bold),
                const Gap(Space.s2),
                bar,
              ],
            ),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(aiToolIcon(widget.name), tone: Tone.blue, size: 32, radius: 10),
              const Gap(Space.s2),
              Expanded(child: Text(widget.label, style: context.ty.sm.bold)),
            ],
          ),
          const Gap(Space.s3),
          for (final (i, s) in steps.indexed)
            _StepRow(text: s, state: (widget.finishing || i < _cur) ? _StepState.done : (i == _cur ? _StepState.current : _StepState.next)),
        ],
      );
    }
    Widget card = AppCard(child: body);
    if (steps.isNotEmpty) {
      // A soft shimmering border while the tutor works.
      Widget edge = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.secondary.withValues(alpha: .35), width: 1.5),
        ),
      );
      if (!rm) edge = edge.animate(onPlay: (a) => a.repeat()).shimmer(duration: 1800.ms, color: c.accent);
      card = Stack(
        children: [
          card,
          Positioned.fill(child: IgnorePointer(child: edge)),
        ],
      );
    }
    return Semantics(liveRegion: true, label: widget.label, child: card);
  }
}

enum _StepState { done, current, next }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.text, required this.state});
  final String text;
  final _StepState state;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final Widget lead = switch (state) {
      _StepState.done => Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), key: const ValueKey('done'), size: 20, color: c.success),
      _StepState.current =>
        rm
            ? Icon(PhosphorIcons.circle(PhosphorIconsStyle.fill), key: const ValueKey('cur'), size: 12, color: c.secondary)
            : SizedBox(
                key: const ValueKey('cur'),
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: c.secondary),
              ),
      _StepState.next => Icon(PhosphorIcons.circle(), key: const ValueKey('next'), size: 18, color: c.textSubtle),
    };
    Widget mark = SizedBox(width: 22, height: 22, child: Center(child: lead));
    if (state == _StepState.done && !rm) {
      mark = mark.animate(key: const ValueKey('pop')).scaleXY(begin: .4, end: 1, duration: Motion.base, curve: Curves.easeOutBack);
    }
    return AnimatedOpacity(
      duration: rm ? Duration.zero : Motion.base,
      opacity: state == _StepState.next ? .45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            mark,
            const Gap(Space.s3),
            Expanded(child: Text(text, style: state == _StepState.current ? context.ty.sm.bold : context.ty.sm.col(c.textMuted))),
          ],
        ),
      ),
    );
  }
}

/// Picks the right card for `card['type']`. Unknown types show nothing (older apps stay safe).
class AiCardView extends StatelessWidget {
  const AiCardView({super.key, required this.card, required this.send, required this.check, this.onStarted, this.onOpenChat});
  final Map<String, dynamic> card;
  final AiSendFn send;
  final QuizCheckFn check;
  final ValueChanged<String>? onStarted, onOpenChat;
  @override
  Widget build(BuildContext context) => switch (card['type']) {
    'test' => TestCard(card: card, onStarted: onStarted),
    'quiz' => QuizCard(card: card, check: check, send: send),
    'choices' => ChoicesCard(card: card, send: send, onOpenChat: onOpenChat),
    'open' => OpenCard(card: card),
    'notes' => NotesCard(card: card),
    'weak' => WeakCard(
      card: card,
      onQuiz: (subject, topic) => send(text: 'Quiz me on $topic', tool: 'quiz', args: {'subject': subject, 'topic': topic, 'count': 3}),
    ),
    'qotd' => _HeaderChip(icon: aiToolIcon('qotd'), text: card['answered'] == true ? "Today's question · answered" : "Today's question · hint only"),
    'plan' =>
      (card['days'] is List && (card['days'] as List).isNotEmpty)
          ? PlanCard(card: card, send: send)
          : _HeaderChip(icon: aiToolIcon('study_plan'), text: 'Your 7-day plan'),
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
  int get _year => _int(_c['year']);

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
              title: 'AI test · ${_year > 0 ? '${_c['exam'] ?? ''} $_year · ' : ''}$subject${topics.isEmpty ? '' : ' · ${topics.first}'}',
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
                    Text(
                      _year > 0 ? '${_c['exam'] ?? ''} $_year · ${_c['subject'] ?? 'Practice'}' : '${_c['subject'] ?? 'Practice'} test',
                      style: context.ty.body.bold,
                    ),
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
              child: _fade(rm, i, AppChip(ch.label, on: false, icon: aiIconByName(ch.icon, fill: true), onTap: () => onTap(ch))),
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

// ---------------------------------------------------------------- choices and open cards (U3b)
/// A title and buttons. Each item sends a tool (its label is the message), opens a page, sends text or opens a chat.
class ChoicesCard extends StatelessWidget {
  const ChoicesCard({super.key, required this.card, required this.send, this.onOpenChat});
  final Map<String, dynamic> card;
  final AiSendFn send;
  final ValueChanged<String>? onOpenChat;

  void _tap(BuildContext context, Map<String, dynamic> it) {
    final label = '${it['label'] ?? ''}';
    final tool = it['tool'] as String?;
    final route = it['route'] as String?;
    if (tool != null) {
      send(text: label, tool: tool, args: it['args'] is Map ? Map<String, dynamic>.from(it['args'] as Map) : null);
    } else if (route != null) {
      aiOpenRoute(context, route);
    } else if (it['text'] is String) {
      send(text: it['text'] as String);
    } else if (it['chat_id'] is String) {
      onOpenChat?.call(it['chat_id'] as String);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final i in (card['items'] as List? ?? const []))
        if (i is Map) Map<String, dynamic>.from(i),
    ];
    final c = context.c;
    final rm = context.reduceMotion;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ('${card['title'] ?? ''}'.isNotEmpty) ...[Text('${card['title']}', style: context.ty.body.bold), const Gap(Space.s3)],
          for (final (i, it) in items.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s2),
              child: _fade(
                rm,
                i,
                _ChoiceButton(
                  label: '${it['label'] ?? ''}',
                  icon: it['icon'] == null ? null : aiIconByName('${it['icon']}', fill: true),
                  onTap: () => _tap(context, it),
                ),
              ),
            ),
          if (items.isEmpty) Text('Nothing to choose yet.', style: context.ty.sm.col(c.textMuted)),
        ],
      ),
    );
  }

  static Widget _fade(bool rm, int i, Widget w) =>
      rm ? w : w.animate().fadeIn(delay: Motion.stagger * i, duration: Motion.base, curve: Motion.out).slideY(begin: .15, end: 0);
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.label, required this.onTap, this.icon});
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = BorderRadius.circular(Radii.md);
    return Pressable(
      onTap: onTap,
      scale: .985,
      borderRadius: r,
      child: Container(
        constraints: const BoxConstraints(minHeight: Sizes.tapMin),
        padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: r,
          border: Border.all(color: c.borderStrong, width: 1.5),
        ),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 20, color: c.secondary), const Gap(Space.s3)],
            Expanded(child: Text(label, style: context.ty.sm.bold)),
            Icon(PhosphorIcons.caretRight(), size: 18, color: c.textSubtle),
          ],
        ),
      ),
    );
  }
}

/// Opens a page: the route "paywall" opens Premium; any other route is pushed.
void aiOpenRoute(BuildContext context, String route) {
  if (route == 'paywall') {
    showPaywall(context, reason: 'years');
  } else {
    context.push(route);
  }
}

/// "Open Leaderboard": an icon, a title, a short line and one primary button.
class OpenCard extends StatelessWidget {
  const OpenCard({super.key, required this.card});
  final Map<String, dynamic> card;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final route = '${card['route'] ?? ''}';
    final sub = '${card['subtitle'] ?? ''}';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(aiIconByName(card['icon'] as String?, fill: true), tone: Tone.gold),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${card['title'] ?? ''}', style: context.ty.body.bold),
                    if (sub.isNotEmpty) Text(sub, style: context.ty.cap.col(c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const Gap(Space.s3),
          Btn(
            '${card['button'] ?? 'Open'}',
            block: true,
            icon: PhosphorIcons.arrowRight(),
            kind: route == 'paywall' ? BtnKind.accent : BtnKind.primary,
            onPressed: route.isEmpty ? null : () => aiOpenRoute(context, route),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- follow-ups and hint ladder (U3b)
/// "What next?" chips under a reply; they fade in one after another. Tapping one sends its text.
class AiFollowupChips extends StatelessWidget {
  const AiFollowupChips({super.key, required this.items, required this.onTap, this.title = 'What next?'});
  final List<String> items;
  final ValueChanged<String> onTap;
  final String title;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Space.s1, bottom: Space.s1),
            child: Text(title, style: context.ty.cap.bold.col(c.textMuted)),
          ),
          Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: [
              for (final (i, t) in items.indexed)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .84),
                  child: rm
                      ? _FollowChip(text: t, onTap: () => onTap(t))
                      : _FollowChip(
                          text: t,
                          onTap: () => onTap(t),
                        ).animate().fadeIn(delay: Motion.stagger * (i + 1) * 2, duration: Motion.base, curve: Motion.out).slideY(begin: .2, end: 0),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowChip extends StatelessWidget {
  const _FollowChip({required this.text, required this.onTap, this.icon});
  final String text;
  final IconData? icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = BorderRadius.circular(Radii.pill);
    return Pressable(
      onTap: onTap,
      scale: .96,
      borderRadius: r,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
        decoration: BoxDecoration(color: c.secondarySoft, borderRadius: r),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: c.onSecondarySoft), const SizedBox(width: 6)],
            Flexible(child: Text(text, style: context.ty.sm.bold.col(c.onSecondarySoft))),
          ],
        ),
      ),
    );
  }
}

/// After a hint reply: Next hint, Show the answer, Check my working.
class AiHintChips extends StatelessWidget {
  const AiHintChips({super.key, required this.level, required this.onNext, required this.onAnswer, required this.onCheck});
  final int level;
  final VoidCallback onNext, onAnswer, onCheck;
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    Widget f(int i, Widget w) => rm ? w : w.animate().fadeIn(delay: Motion.stagger * i, duration: Motion.base, curve: Motion.out);
    return Padding(
      padding: const EdgeInsets.only(top: Space.s2),
      child: Wrap(
        spacing: Space.s2,
        runSpacing: Space.s2,
        children: [
          if (level < 3) f(0, _FollowChip(text: 'Next hint', icon: PhosphorIcons.lightbulb(PhosphorIconsStyle.fill), onTap: onNext)),
          if (level < 3) f(1, _FollowChip(text: 'Show the answer', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), onTap: onAnswer)),
          f(2, _FollowChip(text: 'Check my working', icon: PhosphorIcons.notePencil(PhosphorIconsStyle.fill), onTap: onCheck)),
        ],
      ),
    );
  }
}

/// Three small dots showing how far down the hint ladder a reply is.
class HintDots extends StatelessWidget {
  const HintDots({super.key, required this.level});
  final int level;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: 'Hint $level of 3',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 3; i++)
            AnimatedContainer(
              duration: context.reduceMotion ? Duration.zero : Motion.base,
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: i <= level ? c.accent : c.surfaceSunken,
                shape: BoxShape.circle,
                border: Border.all(color: i <= level ? c.accent : c.borderStrong),
              ),
            ),
          const SizedBox(width: 2),
          Text('Hint $level of 3', style: context.ty.cap.col(c.textSubtle)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- study plan (U3b)
/// The 7-day plan: day chips (today highlighted, past days dim), the chosen day's focus and checklist, its action button,
/// a morning-reminder switch and "Mark today done".
class PlanCard extends ConsumerStatefulWidget {
  const PlanCard({super.key, required this.card, required this.send, this.today});
  final Map<String, dynamic> card;
  final AiSendFn send;

  /// For tests: the date that counts as today.
  final DateTime? today;
  @override
  ConsumerState<PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<PlanCard> {
  late final List<Map<String, dynamic>> _days = [
    for (final d in (widget.card['days'] as List? ?? const []))
      if (d is Map) Map<String, dynamic>.from(d),
  ];
  late final int _todayIdx = _computeToday();
  late int _sel = _todayIdx.clamp(0, _days.length - 1);
  late bool _remind = widget.card['reminders'] != false;
  final _checked = <int, Set<int>>{};
  final _doneDays = <int>{};
  bool _busy = false;

  int _computeToday() {
    final start = DateTime.tryParse('${widget.card['starts_on']}');
    if (start == null) return 0;
    final now = widget.today ?? DateTime.now();
    return DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  }

  String? get _planId => widget.card['plan_id'] as String?;

  Future<void> _run(Future<void> Function() f, {VoidCallback? undo}) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (_) {
      undo?.call();
      if (mounted) toast(context, 'Could not save. Check your internet.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setRemind(bool v) async {
    final id = _planId;
    if (id == null) return;
    setState(() => _remind = v);
    await _run(() => ref.read(aiRepoProvider).planUpdate(id, reminders: v), undo: () => _remind = !v);
  }

  Future<void> _markToday() async {
    final id = _planId;
    if (id == null || _todayIdx < 0 || _todayIdx >= _days.length) return;
    HapticFeedback.mediumImpact();
    final n = _todayIdx + 1;
    setState(() => _doneDays.add(n));
    await _run(() => ref.read(aiRepoProvider).planUpdate(id, doneDay: n), undo: () => _doneDays.remove(n));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final d = _days[_sel];
    final tasks = [for (final t in (d['tasks'] as List? ?? const [])) '$t'];
    final action = d['action'] is Map ? Map<String, dynamic>.from(d['action'] as Map) : null;
    final minutes = _int(d['minutes']);
    final inRange = _todayIdx >= 0 && _todayIdx < _days.length;
    final todayDone = _doneDays.contains(_todayIdx + 1);
    final checked = _checked.putIfAbsent(_sel, () => {});
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(aiToolIcon('study_plan'), tone: Tone.gold),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.card['title'] ?? 'Your 7-day plan'}', style: context.ty.body.bold, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text('${_days.length} days · ${_doneDays.length} done', style: context.ty.cap.col(c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const Gap(Space.s3),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, _) in _days.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.s2),
                    child: _DayChip(
                      n: i + 1,
                      selected: i == _sel,
                      today: i == _todayIdx,
                      past: i < _todayIdx,
                      done: _doneDays.contains(i + 1),
                      onTap: () => setState(() => _sel = i),
                    ),
                  ),
              ],
            ),
          ),
          const Gap(Space.s3),
          AnimatedSwitcher(
            duration: rm ? Duration.zero : Motion.base,
            switchInCurve: Motion.out,
            transitionBuilder: (w, a) => FadeTransition(opacity: a, child: w),
            layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, ?cur]),
            child: Column(
              key: ValueKey('day-$_sel'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${d['focus'] ?? 'Day ${_sel + 1}'}', style: context.ty.body.bold)),
                    if (minutes > 0) Pill('$minutes min', icon: PhosphorIcons.clock(PhosphorIconsStyle.fill)),
                  ],
                ),
                const Gap(Space.s2),
                for (final (i, t) in tasks.indexed)
                  InkWell(
                    onTap: () => setState(() => checked.contains(i) ? checked.remove(i) : checked.add(i)),
                    borderRadius: BorderRadius.circular(Radii.sm),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 10, right: Space.s2),
                            child: Icon(
                              checked.contains(i) ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.circle(),
                              size: 20,
                              color: checked.contains(i) ? c.success : c.textSubtle,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                t,
                                style: context.ty.sm
                                    .col(checked.contains(i) ? c.textMuted : c.text)
                                    .copyWith(decoration: checked.contains(i) ? TextDecoration.lineThrough : null),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (action != null) ...[
                  const Gap(Space.s2),
                  Btn(
                    '${action['label'] ?? 'Start'}',
                    block: true,
                    icon: PhosphorIcons.arrowRight(),
                    onPressed: () => widget.send(
                      text: '${action['label'] ?? 'Start'}',
                      tool: action['tool'] as String?,
                      args: action['args'] is Map ? Map<String, dynamic>.from(action['args'] as Map) : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_planId != null) ...[
            const Gap(Space.s2),
            Divider(height: 1, color: c.border),
            const Gap(Space.s1),
            Row(
              children: [
                Expanded(child: Text('Remind me every morning', style: context.ty.sm.bold)),
                AppSwitch(value: _remind, onChanged: (v) => _busy ? null : _setRemind(v)),
              ],
            ),
            if (inRange) ...[
              const Gap(Space.s2),
              Btn(
                todayDone ? 'Today is done' : 'Mark today done',
                kind: todayDone ? BtnKind.tonal : BtnKind.outline,
                block: true,
                leading: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                onPressed: todayDone || _busy ? null : _markToday,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.n, required this.selected, required this.today, required this.past, required this.done, required this.onTap});
  final int n;
  final bool selected, today, past, done;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bg = selected ? c.primary : (today ? c.accentSoft : c.surface);
    final fg = selected ? c.onPrimary : (today ? c.onAccentSoft : c.text);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Day $n${today ? ', today' : ''}${done ? ', done' : ''}',
      child: Pressable(
        onTap: onTap,
        scale: .94,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Opacity(
          opacity: past && !selected && !done ? .55 : 1,
          child: AnimatedContainer(
            duration: context.reduceMotion ? Duration.zero : Motion.fast,
            constraints: const BoxConstraints(minWidth: 52, minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: today && !selected ? c.accent : c.borderStrong, width: today ? 2 : 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(today ? 'Today' : 'Day', style: context.ty.cap.col(fg)),
                done
                    ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 18, color: selected ? c.onPrimary : c.success)
                    : Text('$n', style: context.ty.body.bold.col(fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
