import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../widgets/question_image.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/confetti.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../study/note_screens.dart' show NoteBody;
import 'ai_cards.dart' show AiSendFn, QuizCheckFn, aiToolIcon;

/// Quiz v2 (U3b): one question at a time, a progress bar, an animated right/wrong reveal, then a score screen.
/// Questions come without answers; each tap is marked by the server (free). `source` is "past" (real past questions)
/// or "ai" (written by the AI, kept on the server too).

class _Answer {
  _Answer(this.choice);
  final String choice;
  bool loading = true, failed = false, correct = false;
  String? answer, explanation;
}

class QuizCard extends StatefulWidget {
  const QuizCard({super.key, required this.card, required this.check, required this.send});
  final Map<String, dynamic> card;
  final QuizCheckFn check;
  final AiSendFn send;
  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> with AutomaticKeepAliveClientMixin {
  late List<Map<String, dynamic>> _qs;
  int _idx = 0, _right = 0, _round = 1;
  _Answer? _a;
  final _wrong = <Map<String, dynamic>>[];
  bool _done = false;

  @override
  bool get wantKeepAlive => true;

  bool get _ai => widget.card['source'] == 'ai';

  @override
  void initState() {
    super.initState();
    _qs = [
      for (final q in (widget.card['questions'] as List? ?? const []))
        if (q is Map) Map<String, dynamic>.from(q),
    ];
    if (_qs.isEmpty) _done = true;
  }

  Future<void> _pick(String choice) async {
    final q = _qs[_idx];
    if (_a != null && !_a!.failed) return; // one answer per question
    HapticFeedback.selectionClick();
    final a = _Answer(choice);
    setState(() => _a = a);
    Map<String, dynamic> r;
    try {
      r = await widget.check('${q['id']}', choice);
    } catch (_) {
      r = const {'ok': false};
    }
    if (!mounted || _a != a) return;
    setState(() {
      a.loading = false;
      if (r['ok'] == true) {
        a.correct = r['correct'] == true;
        a.answer = r['answer'] as String?;
        a.explanation = r['explanation'] as String?;
        if (a.correct) {
          _right++;
        } else {
          _wrong.add(q);
        }
      } else {
        a.failed = true;
      }
    });
    if (r['ok'] == true) HapticFeedback.mediumImpact();
  }

  void _next() {
    setState(() {
      _a = null;
      if (_idx + 1 >= _qs.length) {
        _done = true;
      } else {
        _idx++;
      }
    });
  }

  void _retryWrong() {
    setState(() {
      _qs = List.of(_wrong);
      _wrong.clear();
      _idx = 0;
      _right = 0;
      _a = null;
      _done = false;
      _round++;
    });
  }

  void _moreLikeThis() {
    final topic = widget.card['topic'] as String?;
    widget.send(
      text: 'More like this',
      tool: _ai ? 'ai_quiz' : 'quiz',
      args: {'subject': '${widget.card['subject'] ?? ''}', 'topic': ?((topic ?? '').isEmpty ? null : topic), 'count': 5},
    );
  }

  void _explain(Map<String, dynamic> q) {
    if (_ai) {
      widget.send(text: 'Explain this question: ${q['body'] ?? ''}');
    } else {
      widget.send(questionId: '${q['id']}', explain: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rm = context.reduceMotion;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const Gap(Space.s3),
          AnimatedSwitcher(
            duration: rm ? Duration.zero : Motion.base,
            switchInCurve: Motion.out,
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(.06, 0), end: Offset.zero).animate(a),
                child: c,
              ),
            ),
            layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, ?cur]),
            child: _done
                ? _Score(
                    key: ValueKey('score-$_round'),
                    right: _right,
                    total: _qs.length,
                    round: _round,
                    canRetry: _wrong.isNotEmpty,
                    onRetry: _retryWrong,
                    onMore: _moreLikeThis,
                  )
                : KeyedSubtree(key: ValueKey('q-$_round-$_idx'), child: _question(context)),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final c = context.c;
    final total = _qs.length;
    final revealed = _a != null && !_a!.loading && !_a!.failed;
    final value = _done ? 1.0 : (total == 0 ? 0.0 : (_idx + (revealed ? 1 : 0)) / total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconTile(aiToolIcon('quiz'), tone: Tone.blue),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.card['subject'] ?? 'Quiz'} quiz', style: context.ty.body.bold),
                  const Gap(2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _ai
                        ? Pill('AI-written', kind: BadgeKind.gold, icon: PhosphorIcons.sparkle(PhosphorIconsStyle.fill))
                        : Pill('Real past question', icon: PhosphorIcons.books(PhosphorIconsStyle.fill)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Gap(Space.s3),
        Row(
          children: [
            Expanded(child: ProgressBar(value, color: c.secondary)),
            const Gap(Space.s3),
            Text(_done ? 'Done' : '${math.min(_idx + 1, total)} of $total', style: context.ty.cap.bold.tnum.col(c.textMuted)),
          ],
        ),
        if (_round > 1)
          Padding(
            padding: const EdgeInsets.only(top: Space.s1),
            child: Text('Round $_round · the ones you missed', style: context.ty.cap.col(c.textSubtle)),
          ),
      ],
    );
  }

  Widget _question(BuildContext context) {
    final c = context.c;
    final q = _qs[_idx];
    final opts = Map<String, dynamic>.from((q['options'] as Map?) ?? const {});
    final keys = opts.keys.toList()..sort();
    final a = _a;
    final rm = context.reduceMotion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoteBody(text: '${q['body'] ?? ''}', scale: .98),
        if ('${q['image_path'] ?? ''}'.isNotEmpty) ...[const Gap(Space.s3), QuestionImage(imageKey: '${q['image_path']}')],
        const Gap(Space.s3),
        for (final k in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s2),
            child: _OptionRow(letter: k, text: '${opts[k]}', state: _stateFor(a, k), onTap: (a == null || a.failed) ? () => _pick(k) : null),
          ),
        if (a != null && a.failed)
          Padding(
            padding: const EdgeInsets.only(top: Space.s1),
            child: Text('Could not check this answer. Check your internet, then tap an option again.', style: context.ty.sm.col(c.error)),
          )
        else if (a != null && !a.loading)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: rm ? 1 : 0, end: 1),
            duration: rm ? Duration.zero : Motion.base,
            curve: Motion.out,
            builder: (_, v, child) => Opacity(opacity: v, child: child),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(Space.s1),
                Row(
                  children: [
                    Icon(
                      a.correct ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                      size: 20,
                      color: a.correct ? c.success : c.error,
                    ),
                    const Gap(Space.s2),
                    Expanded(
                      child: Text(a.correct ? 'Correct!' : 'The answer is ${a.answer ?? ''}', style: context.ty.sm.bold.col(a.correct ? c.success : c.error)),
                    ),
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
                const Gap(Space.s2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn(
                    'Explain with AI',
                    kind: BtnKind.ghost,
                    sm: true,
                    leading: PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                    onPressed: () => _explain(q),
                  ),
                ),
                const Gap(Space.s2),
                Btn(_idx + 1 >= _qs.length ? 'See my score' : 'Next', block: true, icon: PhosphorIcons.arrowRight(), onPressed: _next),
              ],
            ),
          ),
      ],
    );
  }

  _OptState _stateFor(_Answer? a, String k) {
    if (a == null) return _OptState.idle;
    if (a.loading || a.failed) return a.choice == k ? _OptState.checking : _OptState.idle;
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
    final rm = context.reduceMotion;
    final (bg, border, fg) = switch (state) {
      _OptState.right => (c.successSoft, c.success, c.onSuccessSoft),
      _OptState.wrong => (c.errorSoft, c.error, c.onErrorSoft),
      _OptState.checking => (c.secondarySoft, c.secondary, c.onSecondarySoft),
      _OptState.idle => (c.surface, c.borderStrong, c.text),
    };
    final r = BorderRadius.circular(Radii.md);
    Widget icon = switch (state) {
      _OptState.right => Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 26, color: c.success),
      _OptState.wrong => Icon(PhosphorIcons.xCircle(PhosphorIconsStyle.fill), size: 26, color: c.error),
      _OptState.checking => SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: c.secondary)),
      _OptState.idle => const SizedBox.shrink(),
    };
    if (!rm && state == _OptState.right) icon = icon.animate().scaleXY(begin: .2, end: 1, duration: Motion.slow, curve: Curves.easeOutBack);
    Widget row = Semantics(
      button: onTap != null,
      label: 'Option $letter',
      child: Pressable(
        onTap: onTap,
        scale: .985,
        borderRadius: r,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.out,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: r,
            border: Border.all(color: border, width: state == _OptState.idle ? 1.5 : 2),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: state == _OptState.idle ? c.surfaceSunken : Colors.transparent, shape: BoxShape.circle),
                child: Text(letter, style: context.ty.sm.bold.col(fg)),
              ),
              const Gap(Space.s3),
              Expanded(child: NoteBody(text: text, scale: .95)),
              const Gap(Space.s2),
              icon,
            ],
          ),
        ),
      ),
    );
    if (!rm && state == _OptState.wrong) row = row.animate().shake(hz: 4, offset: const Offset(8, 0), duration: Motion.slow, curve: Curves.easeOut);
    return row;
  }
}

/// The end of a round: a big score ring, a kind message, and what to do next.
class _Score extends StatelessWidget {
  const _Score({super.key, required this.right, required this.total, required this.round, required this.canRetry, required this.onRetry, required this.onMore});
  final int right, total, round;
  final bool canRetry;
  final VoidCallback onRetry, onMore;

  static String message(double pct) => pct >= .9
      ? 'Excellent! You really know this.'
      : pct >= .6
      ? 'Well done! Keep it up.'
      : pct >= .4
      ? 'Good try. A little more practice and you will get it.'
      : "Don't worry. Every try makes you stronger.";

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final pct = total == 0 ? 0.0 : right / total;
    final color = pct >= .6 ? c.success : (pct >= .4 ? c.warning : c.error);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(Space.s2),
        Center(
          child: SizedBox(
            width: 148,
            height: 148,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: rm ? Duration.zero : Motion.celebrate,
              curve: Motion.out,
              builder: (_, v, _) => CustomPaint(
                painter: _RingPainter(v, color, c.surfaceSunken),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$right/$total', style: context.ty.h2.tnum),
                      Text('${(pct * 100).round()}%', style: context.ty.sm.bold.col(c.textMuted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Gap(Space.s3),
        Text(message(pct), textAlign: TextAlign.center, style: context.ty.body.bold),
        const Gap(Space.s4),
        if (canRetry) ...[Btn('Try the wrong ones again', block: true, leading: PhosphorIcons.arrowClockwise(), onPressed: onRetry), const Gap(Space.s2)],
        Btn(
          'More like this',
          kind: canRetry ? BtnKind.outline : BtnKind.primary,
          block: true,
          leading: PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
          onPressed: onMore,
        ),
      ],
    );
    if (pct < .6 || rm) return body;
    return Stack(
      children: [
        body,
        Positioned.fill(
          child: IgnorePointer(child: ClipRect(child: Confetti(pieces: 50))),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.track);
  final double v;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size size) {
    const w = 14.0;
    final rect = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, p..color = track);
    if (v > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v, false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color || o.track != track;
}
