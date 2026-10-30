import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/secure_screen.dart';
import '../../data/db.dart';
import '../../data/tests_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/math_text.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/question_image.dart';
import '../home/home_screen.dart';
import 'calculator.dart';
import 'exam_clock.dart';

class _Q {
  _Q(this.row) : options = Map<String, String>.from(jsonDecode(row.optionsJson) as Map);
  final CachedQuestion row;
  final Map<String, String> options;
}

/// CBT exam screen (prototype: cbt). JAMB-style: top bar (logo, name, test, timer, Submit), subject tabs,
/// collapsible passage, question + options A–E, bottom bar (Prev · calculator · palette · flag · Next).
/// Every tap is saved to SQLite at once, so the test survives the app being killed.
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
  bool _passageOpen = true, _submitting = false, _timeUpShown = false;
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
      var resumed = false;
      for (final x in await _db.answersFor(a.id)) {
        if (x.choice != null) _answers[x.questionId] = x.choice!;
        if (x.flagged) _flags.add(x.questionId);
        resumed = true;
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
      if (mounted) {
        toast(
          context,
          resumed ? 'Welcome back. We saved your answers.' : 'New test started. Good luck!',
          icon: resumed ? PhosphorIcons.cloudCheck(PhosphorIconsStyle.fill) : PhosphorIcons.playCircle(PhosphorIconsStyle.fill),
          above: 72,
        );
      }
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
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden || s == AppLifecycleState.detached) {
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
      toast(context, 'Could not submit. Please try again.', icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill), above: 72);
      return;
    }
    ref.invalidate(unfinishedProvider);
    ref.invalidate(practiceStatsProvider);
    if (!mounted) return;
    if (auto) {
      await _timeUp();
      if (!mounted) return;
    }
    context.pushReplacement('/results/${widget.attemptId}');
  }

  /// "Time is up" (sticky): answers were saved and submitted automatically.
  Future<void> _timeUp() async {
    if (_timeUpShown) return;
    _timeUpShown = true;
    Navigator.of(context).popUntil((r) => r is! PopupRoute);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: ctx.c.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s6, Space.s5, Space.s5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTile(PhosphorIcons.alarm(PhosphorIconsStyle.fill), tone: Tone.red, size: 60, radius: 18),
                const Gap(Space.s3),
                Text('Time is up', style: ctx.ty.h2),
                const Gap(Space.s3),
                Text('Your answers were saved and submitted automatically.', style: ctx.ty.sm.col(ctx.c.textMuted), textAlign: TextAlign.center),
                const Gap(Space.s3),
                Btn('See my results', block: true, onPressed: () => Navigator.pop(ctx)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ({int a, int f, int u, int total}) _counts(int subjectId) {
    final qs = _qs.where((q) => q.row.subjectId == subjectId);
    final a = qs.where((q) => _answers.containsKey(q.row.id)).length;
    final f = qs.where((q) => _flags.contains(q.row.id)).length;
    return (a: a, f: f, u: qs.length - a, total: qs.length);
  }

  List<int> get _subjectIds {
    final ids = <int>[];
    for (final q in _qs) {
      if (!ids.contains(q.row.subjectId)) ids.add(q.row.subjectId);
    }
    return ids;
  }

  String _short(int sid) {
    final n = _subjectNames[sid] ?? 'Subject';
    return n == 'Use of English' ? 'English' : n;
  }

  Future<bool?> _confirmSubmit() {
    final c = context.c;
    final unanswered = _qs.length - _answers.length;
    return showAppDialog<bool>(
      context,
      icon: PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill),
      tone: Tone.red,
      title: 'Submit your exam?',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              style: context.ty.sm.col(c.textMuted),
              children: [
                if (_clock.timed) ...[
                  const TextSpan(text: 'You still have '),
                  TextSpan(text: ExamClock.format(_clock.left), style: context.ty.sm.bold.col(c.text)),
                  const TextSpan(text: ' left and '),
                ] else
                  const TextSpan(text: 'You have '),
                TextSpan(text: '$unanswered unanswered', style: context.ty.sm.bold.col(unanswered > 0 ? c.error : c.text)),
                const TextSpan(text: ' questions. You cannot change answers after you submit.'),
              ],
            ),
          ),
          const Gap(Space.s3),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                _SumRow(cells: const ['Subject', 'Done', 'Left', 'Flag'], header: true),
                for (final s in _subjectIds)
                  Builder(
                    builder: (context) {
                      final n = _counts(s);
                      return _SumRow(cells: [_short(s), '${n.a}', '${n.u}', '${n.f}'], colors: [null, c.success, n.u > 0 ? c.error : null, c.warning]);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (ctx) => Row(
            children: [
              Expanded(
                child: Btn('Keep working', kind: BtnKind.outline, block: true, onPressed: () => Navigator.pop(ctx, false)),
              ),
              const Gap(Space.s3),
              Expanded(
                child: Btn('Submit now', kind: BtnKind.danger, block: true, onPressed: () => Navigator.pop(ctx, true)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openPalette() {
    final sid = _qs[_i].row.subjectId;
    final idx = [
      for (var i = 0; i < _qs.length; i++)
        if (_qs[i].row.subjectId == sid) i,
    ];
    final n = _counts(sid);
    showSheet<void>(
      context,
      builder: (ctx) {
        final c = ctx.c;
        Widget legend(Color? fill, Color? ring, String label, {bool dot = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(dot ? 6 : 4),
                border: ring == null ? null : Border.all(color: ring, width: 2),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: ctx.ty.cap.col(c.textMuted)),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(_short(sid), style: ctx.ty.h3)),
                Text('${n.a} answered · ${n.u} left', style: ctx.ty.sm.tnum.col(c.textMuted)),
              ],
            ),
            const Gap(Space.s3),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                legend(c.answered, null, 'Answered'),
                legend(null, c.unanswered, 'Not answered'),
                legend(c.flagged, null, 'Flagged', dot: true),
                legend(null, c.current, 'Current'),
              ],
            ),
            const Gap(Space.s4),
            GridView.count(
              crossAxisCount: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              children: [
                for (var k = 0; k < idx.length; k++)
                  Builder(
                    builder: (context) {
                      final q = _qs[idx[k]].row.id;
                      final ans = _answers.containsKey(q), flag = _flags.contains(q), cur = idx[k] == _i;
                      return Semantics(
                        button: true,
                        label: 'Question ${k + 1}${ans ? ', answered' : ''}${flag ? ', flagged' : ''}',
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _go(idx[k]);
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: ans ? c.answered : c.surface,
                                  borderRadius: BorderRadius.circular(9),
                                  border: cur
                                      ? Border.all(color: c.current, width: 2.5)
                                      : ans
                                      ? null
                                      : Border.all(color: c.unanswered, width: 1.5),
                                ),
                                child: Text('${k + 1}', style: ctx.ty.sm.bold.tnum.col(ans ? Colors.white : (cur ? c.text : c.textMuted))),
                              ),
                              if (flag)
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: c.flagged,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: c.surface, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const Gap(Space.s6),
            Btn(
              'Submit exam',
              kind: BtnKind.outline,
              block: true,
              onPressed: () {
                Navigator.pop(ctx);
                _submit();
              },
            ),
          ],
        );
      },
    );
  }

  void _timerInfo() => showSheet<void>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            style: ctx.ty.h3,
            children: [
              const TextSpan(text: 'Time left: '),
              TextSpan(text: ExamClock.format(_clock.left), style: ctx.ty.h3.tnum),
            ],
          ),
        ),
        const Gap(Space.s2),
        Text(
          'The timer turns amber at 10 minutes and red at 5 minutes. When it reaches zero, your exam submits automatically. '
          'If your phone dies, you continue from where you stopped. The timer pauses while the app is closed.',
          style: ctx.ty.sm.col(ctx.c.textMuted),
        ),
      ],
    ),
  );

  Future<bool> _confirmLeave() async {
    final leave = await showAppDialog<bool>(
      context,
      icon: PhosphorIcons.signOut(PhosphorIconsStyle.fill),
      tone: Tone.blue,
      title: 'Leave the test?',
      body: 'Your answers are saved. Continue from Home later. The timer pauses while you are away.',
      actions: [
        Builder(builder: (ctx) => Btn('Stay', block: true, onPressed: () => Navigator.pop(ctx, false))),
        Builder(
          builder: (ctx) => Btn('Leave', kind: BtnKind.ghost, onPressed: () => Navigator.pop(ctx, true)),
        ),
      ],
    );
    if (leave == true) await _saveProgress(pause: true);
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: const TopBar(),
        body: StateBlock(
          icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
          tone: Tone.red,
          title: 'Something went wrong',
          text: _error.toString().replaceFirst('Exception: ', ''),
          action: Btn(
            'Try again',
            kind: BtnKind.outline,
            onPressed: () {
              setState(() => _error = null);
              _load();
            },
          ),
        ),
      );
    }
    if (_a == null || _qs.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final c = context.c;
    final q = _qs[_i];
    final sids = _subjectIds;
    final firstOf = {for (final s in sids) s: _qs.indexWhere((x) => x.row.subjectId == s)};
    final nInSubject = _i - firstOf[q.row.subjectId]! + 1;
    final total = _counts(q.row.subjectId).total;
    final last = _i == _qs.length - 1;
    final warn = _clock.warning;
    final (timerBg, timerFg) = switch (warn) {
      2 => (c.error, Colors.white),
      1 => (c.warningSoft, c.onWarningSoft),
      _ => (c.primarySoft, c.onPrimarySoft),
    };
    final chosen = _answers[q.row.id];
    final flagged = _flags.contains(q.row.id);
    final name = (ref.watch(profileProvider).value?['full_name'] as String?) ?? 'Candidate';
    final title = ((jsonDecode(_a!.configJson) as Map)['title'] as String?) ?? _a!.examCode;
    final rm = context.reduceMotion;
    // Passage: questions that share it, numbered within the subject.
    final passageNums = q.row.passageId == null
        ? const <int>[]
        : [
            for (var i = 0; i < _qs.length; i++)
              if (_qs[i].row.passageId == q.row.passageId) i - firstOf[_qs[i].row.subjectId]! + 1,
          ];

    Widget timer = Semantics(
      button: true,
      label: 'Time left ${ExamClock.format(_clock.left)}',
      child: GestureDetector(
        onTap: _timerInfo,
        child: AnimatedContainer(
          duration: Motion.base,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: timerBg, borderRadius: BorderRadius.circular(99)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.timer(PhosphorIconsStyle.fill), size: 18, color: timerFg),
              const SizedBox(width: 6),
              Text(ExamClock.format(_clock.left), style: context.ty.timer.col(timerFg)),
            ],
          ),
        ),
      ),
    );
    if (warn == 2 && !rm) timer = timer.animate(onPlay: (a) => a.repeat(reverse: true)).scaleXY(end: 1.06, duration: 500.ms, curve: Motion.standard);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) context.go('/home');
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top bar: logo, candidate + test, timer, Submit
              Container(
                padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s3, Space.s2),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    ExamLogo(_a!.examCode, size: LogoSize.sm),
                    const Gap(Space.s2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: context.ty.sm.bold.copyWith(fontSize: 14, height: 18 / 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(title, style: context.ty.cap.copyWith(fontSize: 11).col(c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (_clock.timed) ...[timer, const Gap(Space.s2)],
                    Pressable(
                      onTap: _submitting ? null : () => _submit(),
                      borderRadius: BorderRadius.circular(99),
                      child: Ink(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(99)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill), size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Submit', style: context.ty.sm.bold.col(Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Subject tabs with answered/total
              if (sids.length > 1)
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
                    children: [
                      for (final s in sids)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Builder(
                            builder: (context) {
                              final on = q.row.subjectId == s;
                              final n = _counts(s);
                              return Semantics(
                                selected: on,
                                button: true,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => _go(firstOf[s]!),
                                  child: AnimatedContainer(
                                    duration: Motion.fast,
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(color: on ? c.primary : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                                    child: Row(
                                      children: [
                                        Text(_short(s), style: context.ty.sm.bold.col(on ? c.onPrimary : c.textMuted)),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: on ? Colors.white.withValues(alpha: .18) : c.surfaceSunken,
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            '${n.a}/${n.total}',
                                            style: context.ty.cap.copyWith(fontSize: 11).tnum.col(on ? c.onPrimary : c.textMuted),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              // Passage (collapsible)
              if (q.row.passageBody != null)
                AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.out,
                  constraints: BoxConstraints(maxHeight: _passageOpen ? MediaQuery.sizeOf(context).height * .42 : 48),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _passageOpen = !_passageOpen),
                        child: SizedBox(
                          height: 48,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s3, 0),
                            child: Row(
                              children: [
                                Icon(PhosphorIcons.article(PhosphorIconsStyle.fill), size: 18, color: c.text),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    passageNums.length > 1
                                        ? 'Read the passage and answer questions ${passageNums.first} to ${passageNums.last}'
                                        : 'Read the passage',
                                    style: context.ty.sm.bold,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                AnimatedRotation(turns: _passageOpen ? 0 : .5, duration: Motion.base, child: Icon(PhosphorIcons.caretUp(), size: 18)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_passageOpen)
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (q.row.passageTitle != null) ...[
                                  Text(q.row.passageTitle!.replaceFirst('[SAMPLE] ', ''), style: context.ty.sm.bold),
                                  const Gap(Space.s2),
                                ],
                                MathText(q.row.passageBody!, style: context.ty.body.copyWith(height: 24 / 15)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              // Question area
              Expanded(
                child: ListView(
                  key: ValueKey(_i),
                  padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s6),
                  children: [
                    Row(
                      children: [
                        Text.rich(
                          TextSpan(
                            style: context.ty.label,
                            children: [
                              const TextSpan(text: 'Question '),
                              TextSpan(text: '$nInSubject', style: context.ty.label.tnum),
                              TextSpan(
                                text: ' of $total',
                                style: context.ty.label.copyWith(fontWeight: FontWeight.w500).col(c.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        flagged
                            ? Pill('Flagged', kind: BadgeKind.warning, icon: PhosphorIcons.flag(PhosphorIconsStyle.fill))
                            : Text(_short(q.row.subjectId), style: context.ty.cap.col(c.textMuted)),
                      ],
                    ),
                    const Gap(Space.s3),
                    _swap(
                      rm,
                      MathText(
                        q.row.body,
                        style: context.ty.body.copyWith(fontSize: TypeScale.question.size, height: TypeScale.question.line / TypeScale.question.size),
                      ),
                    ),
                    if (q.row.imagePath != null) ...[const Gap(Space.s3), QuestionImage(imageKey: q.row.imagePath!)],
                    const Gap(Space.s5),
                    Semantics(
                      container: true,
                      label: 'Options',
                      child: Column(
                        children: [
                          for (final k in q.options.keys.toList()..sort()) ...[
                            OptionRow(letter: k, text: q.options[k]!, state: chosen == k ? OptState.selected : OptState.none, onTap: () => _choose(k)),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom bar: Prev · calculator · palette · flag · Next/Submit
              Container(
                padding: EdgeInsets.fromLTRB(Space.s3, Space.s2, Space.s3, Space.s3 + MediaQuery.paddingOf(context).bottom),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Btn('Prev', kind: BtnKind.outline, sm: true, leading: PhosphorIcons.caretLeft(), onPressed: _i == 0 ? null : () => _go(_i - 1)),
                      ),
                    ),
                    IconBtn(PhosphorIcons.calculator(), label: 'Calculator', onPressed: () => showCalculator(context)),
                    IconBtn(PhosphorIcons.squaresFour(), label: 'Question palette', onPressed: _openPalette),
                    IconBtn(
                      PhosphorIcons.flag(flagged ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular),
                      label: flagged ? 'Remove flag' : 'Flag question',
                      color: flagged ? c.warning : null,
                      onPressed: _toggleFlag,
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: last
                            ? Btn(
                                'Submit',
                                kind: BtnKind.danger,
                                sm: true,
                                leading: PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill),
                                onPressed: _submitting ? null : () => _submit(),
                              )
                            : Btn('Next', sm: true, icon: PhosphorIcons.caretRight(), onPressed: () => _go(_i + 1)),
                      ),
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

  Widget _swap(bool rm, Widget w) => rm ? w : w.animate(key: ValueKey(_i)).fadeIn(duration: Motion.base).slideX(begin: .05, curve: Motion.out);
}

enum OptState { none, selected, right, wrong }

/// Option row (`.opt`, `.opt.sel|right|wrong`): 36 key tile + text, optional tag on the right.
class OptionRow extends StatelessWidget {
  const OptionRow({super.key, required this.letter, required this.text, this.state = OptState.none, this.onTap, this.tag});
  final String letter, text;
  final OptState state;
  final VoidCallback? onTap;
  final String? tag;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, ring, keyBg, keyFg, width) = switch (state) {
      OptState.selected => (c.secondarySoft, c.secondary, c.secondary, Colors.white, 2.0),
      OptState.right => (c.successSoft, c.success, c.success, Colors.white, 2.0),
      OptState.wrong => (c.errorSoft, c.error, c.error, Colors.white, 2.0),
      OptState.none => (c.surface, c.border, c.surfaceSunken, c.textMuted, 1.5),
    };
    final tagColor = state == OptState.right ? c.onSuccessSoft : c.onErrorSoft;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: state == OptState.selected,
      button: onTap != null,
      label: 'Option $letter',
      child: Pressable(
        onTap: onTap,
        scale: .985,
        borderRadius: BorderRadius.circular(Radii.md),
        child: AnimatedContainer(
          duration: Motion.fast,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: ring, width: width),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: Motion.fast,
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: keyBg, borderRadius: BorderRadius.circular(10)),
                child: Text(letter, style: context.ty.body.bold.col(keyFg)),
              ),
              const Gap(Space.s3),
              Expanded(
                child: MathText(text, style: context.ty.body.copyWith(fontSize: 16, height: 23 / 16)),
              ),
              if (tag != null) ...[const Gap(Space.s2), Text(tag!, style: context.ty.cap.bold.copyWith(fontSize: 11).col(tagColor))],
            ],
          ),
        ),
      ),
    );
  }
}

/// A row in the submit summary (`.sum-row`): subject, then three centred counts.
class _SumRow extends StatelessWidget {
  const _SumRow({required this.cells, this.header = false, this.colors = const []});
  final List<String> cells;
  final bool header;
  final List<Color?> colors;
  @override
  Widget build(BuildContext context) {
    final base = header ? context.ty.cap.col(context.c.textMuted) : context.ty.sm;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: header ? null : Border(top: BorderSide(color: context.c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(cells[0], style: header ? base : base.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          for (var i = 1; i < cells.length; i++)
            SizedBox(
              width: 56,
              child: Text(
                cells[i],
                textAlign: TextAlign.center,
                style: header ? base : base.bold.tnum.copyWith(color: i < colors.length ? colors[i] : null),
              ),
            ),
        ],
      ),
    );
  }
}
