import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/phosphor.g.dart';

import '../../core/providers.dart';
import '../../core/secure_screen.dart';
import '../../data/db.dart';
import '../../data/tests_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/math_text.dart';
import '../../widgets/question_image.dart';
import '../../widgets/states.dart';
import '../home/home_screen.dart';
import '../shell/shell.dart';
import 'calculator.dart';
import 'exam_clock.dart';

class _Q {
  _Q(this.row) : options = Map<String, String>.from(jsonDecode(row.optionsJson) as Map);
  final CachedQuestion row;
  final Map<String, String> options;
}

/// The CBT exam screen. Every tap is saved to SQLite at once, so the test survives the app being killed.
class CbtScreen extends ConsumerStatefulWidget {
  const CbtScreen({super.key, required this.attemptId});
  final String attemptId;
  @override
  ConsumerState<CbtScreen> createState() => _CbtScreenState();
}

class _CbtScreenState extends ConsumerState<CbtScreen> with WidgetsBindingObserver {
  LocalAttempt? _a;
  List<_Q> _qs = [];
  final Map<String, String> _answers = {};
  final Set<String> _flags = {};
  final Map<int, String> _subjectNames = {};
  int _i = 0;
  late ExamClock _clock;
  Timer? _tick;
  DateTime _shownAt = DateTime.now();
  bool _passageOpen = true;
  bool _submitting = false;
  Object? _error;

  AppDb get _db => ref.read(dbProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SecureScreen.on();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await (_db.select(_db.localAttempts)..where((x) => x.id.equals(widget.attemptId))).getSingleOrNull();
      if (a == null) throw Exception('This test is no longer on your phone.');
      if (a.submittedAt != null) {
        if (mounted) context.pushReplacement('/results/${a.id}');
        return;
      }
      final ids = (jsonDecode(a.questionIdsJson) as List).cast<String>();
      final rows = await _db.questionsByIds(ids);
      for (final x in await _db.answersFor(a.id)) {
        if (x.choice != null) _answers[x.questionId] = x.choice!;
        if (x.flagged) _flags.add(x.questionId);
      }
      final subjects = await ref.read(subjectsProvider.future).catchError((_) => <Map<String, dynamic>>[]);
      for (final s in subjects) {
        _subjectNames[(s['id'] as num).toInt()] = s['name'] as String;
      }
      _clock = ExamClock(
        limit: Duration(seconds: a.limitSeconds),
        used: Duration(milliseconds: a.usedMs),
      )..start();
      setState(() {
        _a = a;
        _qs = [for (final r in rows) _Q(r)];
        _i = a.currentIndex.clamp(0, _qs.isEmpty ? 0 : _qs.length - 1);
        _shownAt = DateTime.now();
      });
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_clock.expired && !_submitting) {
          _submit(auto: true);
        } else {
          setState(() {});
        }
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    SecureScreen.off();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (_a == null) return;
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive || s == AppLifecycleState.detached) {
      _saveProgress(pause: true);
    } else if (s == AppLifecycleState.resumed) {
      _clock.start();
    }
  }

  Future<void> _saveProgress({bool pause = false}) async {
    final used = pause ? _clock.pause() : _clock.snapshot();
    await _db.saveProgress(widget.attemptId, usedMs: used.inMilliseconds, index: _i);
  }

  int _timeOnCurrent() {
    final ms = DateTime.now().difference(_shownAt).inMilliseconds;
    _shownAt = DateTime.now();
    return ms.clamp(0, 3600000);
  }

  Future<void> _choose(String key) async {
    final q = _qs[_i].row.id;
    HapticFeedback.selectionClick();
    setState(() => _answers[q] = key);
    await _db.saveAnswer(widget.attemptId, q, choice: key, addMs: _timeOnCurrent());
    await _saveProgress();
  }

  Future<void> _toggleFlag() async {
    final q = _qs[_i].row.id;
    final on = !_flags.contains(q);
    setState(() => on ? _flags.add(q) : _flags.remove(q));
    await _db.saveAnswer(widget.attemptId, q, flagged: on);
  }

  Future<void> _go(int i) async {
    if (i < 0 || i >= _qs.length) return;
    final q = _qs[_i].row.id;
    await _db.saveAnswer(widget.attemptId, q, addMs: _timeOnCurrent());
    setState(() => _i = i);
    await _saveProgress();
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;
    if (!auto) {
      final ok = await _confirmSubmit();
      if (ok != true) return;
    }
    setState(() => _submitting = true);
    _tick?.cancel();
    await _db.saveAnswer(widget.attemptId, _qs[_i].row.id, addMs: _timeOnCurrent());
    final used = _clock.pause();
    try {
      await ref.read(testsRepoProvider).submit(widget.attemptId, usedMs: used.inMilliseconds);
    } catch (_) {
      // Answers are already saved on the phone; let the student try again.
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not submit. Please try again.')));
      return;
    }
    ref.invalidate(unfinishedProvider);
    if (!mounted) return;
    if (auto) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Time is up. Your test was submitted.')));
    }
    context.pushReplacement('/results/${widget.attemptId}');
  }

  Future<bool?> _confirmSubmit() {
    final answered = _answers.length, flagged = _flags.length, left = _qs.length - answered;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.s5, 0, Space.s5, Space.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Submit your test?', style: ctx.t.headlineSmall),
            gap4,
            Row(
              children: [
                _Stat(label: 'Answered', value: '$answered', color: ctx.c.answered),
                gap3,
                _Stat(label: 'Not answered', value: '$left', color: ctx.c.textMuted),
                gap3,
                _Stat(label: 'Flagged', value: '$flagged', color: ctx.c.flagged),
              ],
            ),
            if (left > 0) ...[
              gap4,
              Text('You still have $left unanswered question${left == 1 ? '' : 's'}. Unanswered questions count as wrong.', style: ctx.t.bodyMedium),
            ],
            gap5,
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit now')),
            gap3,
            OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
          ],
        ),
      ),
    );
  }

  void _openPalette() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        maxChildSize: .9,
        builder: (_, sc) {
          final c = ctx.c;
          return ListView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(Space.s5, 0, Space.s5, Space.s6),
            children: [
              Row(
                children: [
                  Text('All questions', style: ctx.t.titleMedium),
                  const Spacer(),
                  Text('${_answers.length} answered · ${_qs.length - _answers.length} left', style: ctx.t.bodySmall),
                ],
              ),
              gap3,
              Wrap(
                spacing: Space.s4,
                runSpacing: Space.s2,
                children: [
                  _Legend(color: c.answered, label: 'Answered'),
                  _Legend(color: c.unanswered, label: 'Not answered', outline: true),
                  _Legend(color: c.flagged, label: 'Flagged'),
                  _Legend(color: c.current, label: 'Current', outline: true),
                ],
              ),
              gap4,
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 52, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemCount: _qs.length,
                itemBuilder: (_, i) {
                  final id = _qs[i].row.id;
                  final answered = _answers.containsKey(id), flagged = _flags.contains(id), current = i == _i;
                  return Semantics(
                    button: true,
                    label: 'Question ${i + 1}${answered ? ', answered' : ''}${flagged ? ', flagged' : ''}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      onTap: () {
                        Navigator.pop(ctx);
                        _go(i);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: answered ? c.answered : c.surface,
                          borderRadius: BorderRadius.circular(Radii.sm),
                          border: Border.all(
                            color: current
                                ? c.current
                                : flagged
                                ? c.flagged
                                : c.unanswered,
                            width: current || flagged ? 2.5 : 1.5,
                          ),
                        ),
                        child: Text('${i + 1}', style: ctx.t.labelLarge?.copyWith(color: answered ? Colors.white : c.text)),
                      ),
                    ),
                  );
                },
              ),
              gap5,
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _submit();
                },
                child: const Text('Submit test'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the test?'),
        content: const Text('Your answers are saved. You can continue from Home later. The timer pauses while you are away.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true) await _saveProgress(pause: true);
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: StateView.error(
          _error!,
          onRetry: () {
            setState(() => _error = null);
            _load();
          },
        ),
      );
    }
    if (_a == null || _qs.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final c = context.c;
    final q = _qs[_i];
    final subjectIds = <int>[];
    for (final x in _qs) {
      if (!subjectIds.contains(x.row.subjectId)) subjectIds.add(x.row.subjectId);
    }
    final firstOf = {for (final s in subjectIds) s: _qs.indexWhere((x) => x.row.subjectId == s)};
    final countOf = {for (final s in subjectIds) s: _qs.where((x) => x.row.subjectId == s).length};
    final indexInSubject = _i - firstOf[q.row.subjectId]! + 1;
    final last = _i == _qs.length - 1;
    final warn = _clock.warning;
    final timerBg = warn == 2
        ? c.error
        : warn == 1
        ? c.warning
        : c.secondarySoft;
    final timerFg = warn == 0 ? c.onSecondarySoft : Colors.white;
    final chosen = _answers[q.row.id];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) context.go('/home');
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Header: logo, test name, timer, submit
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s4, Space.s2),
                child: Row(
                  children: [
                    ExamLogo(_a!.examCode, size: 36),
                    gap3,
                    Expanded(
                      child: Text(
                        (jsonDecode(_a!.configJson) as Map)['title'] as String? ?? _a!.examCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.t.labelLarge,
                      ),
                    ),
                    if (_clock.timed)
                      AnimatedContainer(
                        duration: Motion.base,
                        padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: 6),
                        decoration: BoxDecoration(color: timerBg, borderRadius: BorderRadius.circular(Radii.pill)),
                        child: Semantics(
                          label: 'Time left ${ExamClock.format(_clock.left)}',
                          child: Row(
                            children: [
                              Icon(PhosphorIcons.timer(PhosphorIconsStyle.fill), size: 16, color: timerFg),
                              const SizedBox(width: 4),
                              Text(
                                ExamClock.format(_clock.left),
                                style: context.t.labelLarge?.copyWith(color: timerFg, fontFeatures: const [FontFeature.tabularFigures()]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    gap2,
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 40),
                        padding: const EdgeInsets.symmetric(horizontal: Space.s3),
                      ),
                      onPressed: _submitting ? null : () => _submit(),
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ),
              // Subject tabs (full JAMB)
              if (subjectIds.length > 1)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Space.s4),
                    children: [
                      for (final s in subjectIds)
                        Padding(
                          padding: const EdgeInsets.only(right: Space.s2),
                          child: ChoiceChip(
                            label: Text(
                              '${_subjectNames[s] ?? 'Subject'} · ${_qs.where((x) => x.row.subjectId == s && _answers.containsKey(x.row.id)).length}/${countOf[s]}',
                            ),
                            selected: q.row.subjectId == s,
                            onSelected: (_) => _go(firstOf[s]!),
                          ),
                        ),
                    ],
                  ),
                ),
              Divider(color: c.border),
              Expanded(
                child: ListView(
                  key: ValueKey(_i),
                  padding: const EdgeInsets.fromLTRB(Space.s5, Space.s3, Space.s5, Space.s6),
                  children: [
                    if (q.row.passageBody != null) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _passageOpen = !_passageOpen),
                              child: Padding(
                                padding: const EdgeInsets.all(Space.s3),
                                child: Row(
                                  children: [
                                    Icon(PhosphorIcons.article(PhosphorIconsStyle.fill), size: 18, color: c.secondary),
                                    gap2,
                                    Expanded(child: Text(q.row.passageTitle ?? 'Read the passage', style: context.t.labelLarge)),
                                    Icon(_passageOpen ? PhosphorIcons.caretUp() : PhosphorIcons.caretDown(), size: 18),
                                  ],
                                ),
                              ),
                            ),
                            if (_passageOpen)
                              ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .32),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(Space.s3, 0, Space.s3, Space.s3),
                                  child: Text(q.row.passageBody!, style: context.t.bodyMedium?.copyWith(height: 1.6)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      gap4,
                    ],
                    Row(
                      children: [
                        Text('Question $indexInSubject', style: context.t.labelLarge),
                        Text(' of ${countOf[q.row.subjectId]}', style: context.t.bodySmall),
                        const Spacer(),
                        if (_flags.contains(q.row.id))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: c.warningSoft, borderRadius: BorderRadius.circular(Radii.pill)),
                            child: Text(
                              'Flagged',
                              style: context.t.labelSmall?.copyWith(color: c.onWarningSoft, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    gap3,
                    MathText(
                      q.row.body,
                      style: context.t.bodyLarge?.copyWith(fontSize: TypeScale.question.size, height: TypeScale.question.line / TypeScale.question.size),
                    ),
                    if (q.row.imagePath != null) ...[gap3, QuestionImage(imageKey: q.row.imagePath!)],
                    gap5,
                    for (final k in q.options.keys.toList()..sort())
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.s3),
                        child: _OptionTile(letter: k, text: q.options[k]!, selected: chosen == k, onTap: () => _choose(k)),
                      ),
                  ].animate(interval: context.reduceMotion ? 0.ms : 30.ms).fadeIn(duration: context.reduceMotion ? 1.ms : Motion.fast),
                ),
              ),
              // Bottom bar: previous · calculator · palette · flag · next
              Container(
                padding: const EdgeInsets.fromLTRB(Space.s3, Space.s2, Space.s3, Space.s2),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: _i == 0 ? null : () => _go(_i - 1),
                      icon: Icon(PhosphorIcons.caretLeft(), size: 18),
                      label: const Text('Prev'),
                    ),
                    const Spacer(),
                    IconButton(tooltip: 'Calculator', icon: Icon(PhosphorIcons.calculator()), onPressed: () => showCalculator(context)),
                    IconButton(tooltip: 'All questions', icon: Icon(PhosphorIcons.squaresFour()), onPressed: _openPalette),
                    IconButton(
                      tooltip: _flags.contains(q.row.id) ? 'Remove flag' : 'Flag for review',
                      icon: Icon(
                        PhosphorIcons.flag(_flags.contains(q.row.id) ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular),
                        color: _flags.contains(q.row.id) ? c.flagged : null,
                      ),
                      onPressed: _toggleFlag,
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 48), backgroundColor: last ? c.error : c.primary),
                      onPressed: _submitting ? null : () => last ? _submit() : _go(_i + 1),
                      icon: Icon(last ? PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill) : PhosphorIcons.caretRight(), size: 18),
                      label: Text(last ? 'Submit' : 'Next'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.letter, required this.text, required this.selected, required this.onTap});
  final String letter, text;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: 'Option $letter',
      child: Material(
        color: selected ? c.secondarySoft : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: selected ? c.secondary : c.border, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.tapMin + 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s3),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: Motion.fast,
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: selected ? c.secondary : c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.sm)),
                    child: Text(letter, style: context.t.labelLarge?.copyWith(color: selected ? Colors.white : c.text)),
                  ),
                  gap3,
                  Expanded(child: MathText(text, style: context.t.bodyLarge)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(color: context.c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
      child: Column(
        children: [
          Text(value, style: context.t.headlineSmall?.copyWith(color: color)),
          Text(label, style: context.t.labelSmall),
        ],
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.outline = false});
  final Color color;
  final String label;
  final bool outline;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: outline ? null : color,
          borderRadius: BorderRadius.circular(4),
          border: outline ? Border.all(color: color, width: 2) : null,
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: context.t.labelSmall),
    ],
  );
}
