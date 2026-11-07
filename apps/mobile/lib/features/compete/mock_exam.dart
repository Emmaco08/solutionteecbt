import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/secure_screen.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/math_text.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/r2_image.dart';
import '../cbt/calculator.dart' show showCalculator;
import '../premium/paywall.dart' show showPaywall;
import 'compete_data.dart';

// JAMB mock challenges (D-099): the whole paper at once, laid out like the JAMB CBT: candidate bar with the timer,
// subject buttons, one question with A–D, Previous / Next, the numbered question grid and Submit. Answers save to
// the server as they are chosen; leaving the screen is logged and the admin's limits apply.

/// Calls for a JAMB mock (replaced in tests).
abstract class MockApi {
  Future<Map<String, dynamic>> start(String id);
  Future<Map<String, dynamic>> save(String entry, String question, String? choice, int ms);
  Future<Map<String, dynamic>> event(String entry, String kind, {int? ms});
  Future<Map<String, dynamic>> submit(String entry);
  Future<Map<String, dynamic>> result(String id);
  Future<Map<String, dynamic>> unlock(String id, String code);
}

class SupabaseMockApi implements MockApi {
  SupabaseMockApi(this.ref);
  final Ref ref;
  Future<Map<String, dynamic>> _rpc(String fn, Map<String, dynamic> p) async =>
      Map<String, dynamic>.from((await ref.read(supabaseProvider).rpc(fn, params: p).timeout(const Duration(seconds: 25)) as Map?) ?? const {});
  @override
  Future<Map<String, dynamic>> start(String id) async =>
      _rpc('mock_start', {'p_id': id, 'p_device': await DeviceCheck.hashedId(), 'p_device_flags': await DeviceCheck.flags()});
  @override
  Future<Map<String, dynamic>> save(String entry, String question, String? choice, int ms) =>
      _rpc('mock_save', {'p_entry': entry, 'p_question': question, 'p_choice': choice, 'p_ms': ms});
  @override
  Future<Map<String, dynamic>> event(String entry, String kind, {int? ms}) => _rpc('mock_event', {'p_entry': entry, 'p_kind': kind, 'p_ms': ms});
  @override
  Future<Map<String, dynamic>> submit(String entry) => _rpc('mock_submit', {'p_entry': entry});
  @override
  Future<Map<String, dynamic>> result(String id) => _rpc('mock_result', {'p_id': id});
  @override
  Future<Map<String, dynamic>> unlock(String id, String code) => _rpc('challenge_unlock', {'p_id': id, 'p_code': code});
}

final mockApiProvider = Provider<MockApi>((ref) => SupabaseMockApi(ref));

// JAMB CBT colours (the exam screen is always light, like the real CBT centre).
const _jBlue = Color(0xFF0B4F9C);
const _jBlueDark = Color(0xFF083A73);
const _jGreen = Color(0xFF138A36);
const _jGrey = Color(0xFFE9EDF2);
const _jLine = Color(0xFFC9D1DC);
const _jText = Color(0xFF111827);
const _jRed = Color(0xFFC62828);

class MockQ {
  MockQ(this.j, this.subject);
  final Map<String, dynamic> j;
  final String subject;
  String get id => '${j['id']}';
  String get body => '${j['body'] ?? ''}';
  Map<String, String> get options => {for (final e in Map<String, dynamic>.from(j['options'] as Map? ?? const {}).entries) e.key: '${e.value}'};
  String? get passageTitle => j['passage_title'] as String?;
  String? get passageBody => (j['passage_body'] as String?)?.trim().isNotEmpty == true ? j['passage_body'] as String : null;
  String? get image => (j['image_path'] as String?)?.isNotEmpty == true ? j['image_path'] as String : null;
  String? choice;
}

class MockSubject {
  MockSubject(this.name, this.questions);
  final String name;
  final List<MockQ> questions;
}

/// Gate on the challenge screen: Premium-only or a code box, then Start. Returns true when unlocked.
Future<bool> unlockMock(BuildContext context, WidgetRef ref, Challenge c) async {
  if (c.unlocked) return true;
  if (c.access == 'premium') {
    final ok = await showAppDialog<bool>(
      context,
      title: 'Premium mock exam',
      body: 'This JAMB mock is for Premium students. Upgrade to take it, with every past year and more AI help.',
      icon: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill),
      tone: Tone.gold,
      actions: [
        Builder(
          builder: (ctx) => Btn('Not now', kind: BtnKind.ghost, onPressed: () => Navigator.pop(ctx, false)),
        ),
        Builder(
          builder: (ctx) => Btn('See Premium', kind: BtnKind.accent, onPressed: () => Navigator.pop(ctx, true)),
        ),
      ],
    );
    if (ok == true && context.mounted) await showPaywall(context, reason: 'challenge');
    return false;
  }
  final ctl = TextEditingController();
  String? err;
  var busy = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: ctx.c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
        title: Row(
          children: [
            Icon(PhosphorIcons.key(PhosphorIconsStyle.fill), color: ctx.c.secondary),
            const Gap(Space.s2),
            Expanded(child: Text('Enter your access code', style: ctx.ty.h3)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              c.access == 'invite' ? 'Use the personal code your tutor gave you. It works for you only.' : 'Type the code your tutor shared for this mock.',
              style: ctx.ty.sm.col(ctx.c.textMuted),
            ),
            const Gap(Space.s3),
            TextField(
              key: const ValueKey('mock-code'),
              controller: ctl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(hintText: 'e.g. ABCD-EFGH', errorText: err),
              onSubmitted: (_) {},
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('mock-unlock'),
            onPressed: busy
                ? null
                : () async {
                    set(() => (busy = true, err = null));
                    try {
                      final r = await ref.read(mockApiProvider).unlock(c.id, ctl.text.trim());
                      if (r['ok'] == true) {
                        if (ctx.mounted) Navigator.pop(ctx, true);
                        return;
                      }
                      set(() => (busy = false, err = 'That code is not right. Check it and try again.'));
                    } catch (e) {
                      set(() => (busy = false, err = challengeError(e)));
                    }
                  },
            child: Text(busy ? 'Checking…' : 'Unlock'),
          ),
        ],
      ),
    ),
  );
  ctl.dispose();
  if (ok == true) {
    HapticFeedback.mediumImpact();
    ref.invalidate(challengeProvider(c.id));
    ref.invalidate(challengesProvider);
  }
  return ok == true;
}

class MockExamScreen extends ConsumerStatefulWidget {
  const MockExamScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends ConsumerState<MockExamScreen> with WidgetsBindingObserver {
  MockApi get _api => ref.read(mockApiProvider);
  Map<String, dynamic>? _paper;
  List<MockSubject> _subjects = const [];
  String? _error, _entry;
  int _s = 0, _q = 0;
  DateTime? _deadline;
  Duration _skew = Duration.zero;
  Timer? _tick;
  DateTime _shownAt = DateTime.now();
  DateTime? _leftAt;
  bool _submitting = false;
  Map<String, dynamic>? _result;
  StreamSubscription<MethodCall>? _secure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SecureScreen.on();
    _secure = SecureScreen.watch(onScreenshot: () => _flag('screenshot'), onRecording: () => _flag('screenshot'));
    _begin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _secure?.cancel();
    SecureScreen.off();
    super.dispose();
  }

  Future<void> _begin() async {
    try {
      final r = await _api.start(widget.id);
      if (!mounted) return;
      if (r['status'] == 'playing') {
        _load(r);
      } else if (r['status'] == 'locked') {
        setState(() => _error = 'Enter your access code on the mock page first.');
      } else {
        await _showResult();
      }
    } catch (e) {
      if (mounted) setState(() => _error = challengeError(e));
    }
  }

  void _load(Map<String, dynamic> r) {
    final now = DateTime.tryParse('${r['now']}');
    _skew = now == null ? Duration.zero : now.difference(DateTime.now());
    _deadline = DateTime.tryParse('${r['deadline']}');
    _entry = '${r['entry_id']}';
    _subjects = [
      for (final s in (r['subjects'] as List? ?? const []))
        MockSubject('${(s as Map)['name']}', [
          for (final q in (s['questions'] as List? ?? const [])) MockQ(Map<String, dynamic>.from(q as Map), '${s['name']}')..choice = (q['choice'] as String?),
        ]),
    ];
    setState(() => _paper = r);
    _shownAt = DateTime.now();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left <= Duration.zero && !_submitting && _result == null) {
        _submit(auto: true);
      } else {
        setState(() {});
      }
    });
  }

  Duration get _left => _deadline == null ? Duration.zero : _deadline!.difference(DateTime.now().add(_skew));

  MockQ? get _cur => _subjects.isEmpty || _subjects[_s].questions.isEmpty ? null : _subjects[_s].questions[_q];

  int get _answered => _subjects.fold(0, (a, s) => a + s.questions.where((q) => q.choice != null).length);
  int get _total => _subjects.fold(0, (a, s) => a + s.questions.length);

  /// Time on the current question since it was shown (sent with each save, so the admin sees time per question).
  int _spent() {
    final ms = DateTime.now().difference(_shownAt).inMilliseconds;
    _shownAt = DateTime.now();
    return ms;
  }

  void _go(int s, int q) {
    final cur = _cur;
    if (cur != null && cur.choice != null) _api.save(_entry!, cur.id, cur.choice, _spent()).ignore();
    if (cur != null && cur.choice == null) _spent();
    setState(() => (_s = s, _q = q));
  }

  void _next() {
    final sub = _subjects[_s];
    if (_q < sub.questions.length - 1) return _go(_s, _q + 1);
    if (_s < _subjects.length - 1) return _go(_s + 1, 0);
  }

  void _prev() {
    if (_q > 0) return _go(_s, _q - 1);
    if (_s > 0) return _go(_s - 1, _subjects[_s - 1].questions.length - 1);
  }

  Future<void> _choose(String letter) async {
    final q = _cur;
    if (q == null || _submitting) return;
    HapticFeedback.selectionClick();
    setState(() => q.choice = letter);
    try {
      final r = await _api.save(_entry!, q.id, letter, _spent());
      if (r['status'] == 'finished' && mounted) await _showResult();
    } catch (_) {
      // Saved again on the next move or at submit; a short network drop does not lose the choice on screen.
    }
  }

  // ---- leaving the screen
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (_entry == null || _result != null) return;
    if ((s == AppLifecycleState.paused || s == AppLifecycleState.hidden) && _leftAt == null) {
      // Once per time away (Android passes through hidden and paused).
      _leftAt = DateTime.now();
      _api.event(_entry!, 'leave').then((r) => _onEvent(r, back: false)).ignore();
    } else if (s == AppLifecycleState.resumed && _leftAt != null) {
      final ms = DateTime.now().difference(_leftAt!).inMilliseconds;
      _leftAt = null;
      _api.event(_entry!, 'return', ms: ms).then((r) => _onEvent(r, back: true)).catchError((_) => <String, dynamic>{});
    }
  }

  void _flag(String kind) {
    if (_entry == null) return;
    _api.event(_entry!, kind).ignore();
    if (mounted) toast(context, 'Screenshots are not allowed in this mock. This was recorded.', icon: PhosphorIcons.cameraSlash(PhosphorIconsStyle.fill));
  }

  Future<void> _onEvent(Map<String, dynamic> r, {required bool back}) async {
    if (!mounted || _result != null) return;
    if (r['status'] == 'finished') {
      await _showResult(reason: r['reason'] == 'left_too_much' ? 'You left the exam screen more than allowed, so your mock was submitted.' : null);
      return;
    }
    final leaves = (r['leaves'] as num?)?.toInt() ?? 0;
    final allowed = (r['allowed_exits'] as num?)?.toInt();
    final awayS = ((r['away_ms'] as num?)?.toInt() ?? 0) ~/ 1000;
    final maxAway = (r['max_away_seconds'] as num?)?.toInt();
    if (leaves == 0 || !back) return; // the warning shows when the student is back on the screen
    final parts = [
      if (allowed != null) 'You have left the exam $leaves of $allowed allowed time${allowed == 1 ? '' : 's'}.',
      if (maxAway != null) 'Time away: ${awayS ~/ 60} min ${awayS % 60} s of ${maxAway ~/ 60} min allowed.',
      'Your tutor can see every time you leave.',
    ];
    if (r['status'] == 'playing') {
      showAppDialog<void>(
        context,
        title: 'Stay on the exam screen',
        body: parts.join(' '),
        icon: PhosphorIcons.warning(PhosphorIconsStyle.fill),
        tone: Tone.gold,
        actions: [Builder(builder: (ctx) => Btn('Back to my exam', onPressed: () => Navigator.pop(ctx)))],
      );
    }
  }

  // ---- submit and result
  Future<void> _confirmSubmit() async {
    final left = _total - _answered;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Submit your exam?',
          style: TextStyle(color: _jText, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in _subjects)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${s.name}: ${s.questions.where((q) => q.choice != null).length} of ${s.questions.length} answered',
                  style: const TextStyle(color: _jText),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              left > 0
                  ? '$left question${left == 1 ? '' : 's'} not answered. You cannot change your answers after you submit.'
                  : 'You cannot change your answers after you submit.',
              style: TextStyle(color: left > 0 ? _jRed : _jText),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Go back')),
          FilledButton(
            key: const ValueKey('mock-submit-yes'),
            style: FilledButton.styleFrom(backgroundColor: _jGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, submit'),
          ),
        ],
      ),
    );
    if (ok == true) await _submit();
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting || _entry == null) return;
    setState(() => _submitting = true);
    final cur = _cur;
    try {
      if (cur?.choice != null) await _api.save(_entry!, cur!.id, cur.choice, _spent());
      await _api.submit(_entry!);
      await _showResult(reason: auto ? 'Time is up. Your exam was submitted.' : null);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        toast(context, challengeError(e), icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
      }
    }
  }

  Future<void> _showResult({String? reason}) async {
    if (_result != null) return;
    _tick?.cancel();
    try {
      final r = await _api.result(widget.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ref.invalidate(challengeProvider(widget.id));
      setState(() => _result = {...r, 'reason': ?reason});
    } catch (e) {
      if (mounted) setState(() => _error = challengeError(e));
    }
  }

  Future<bool> _confirmLeave() async {
    final ok = await showAppDialog<bool>(
      context,
      title: 'Leave the exam?',
      body: 'Your answers are saved, but the timer keeps running and leaving is recorded for your tutor.',
      icon: PhosphorIcons.signOut(),
      tone: Tone.gold,
      actions: [
        Builder(builder: (ctx) => Btn('Stay', onPressed: () => Navigator.pop(ctx, false))),
        Builder(
          builder: (ctx) => Btn('Leave', kind: BtnKind.ghost, onPressed: () => Navigator.pop(ctx, true)),
        ),
      ],
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final light = buildTheme(Brightness.light);
    return Theme(
      data: light,
      child: PopScope(
        canPop: _paper == null || _result != null,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await _confirmLeave() && context.mounted) context.pop();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: _result != null
                ? _ResultView(r: _result!, onDone: () => context.pop())
                : _error != null
                ? _Message(text: _error!, onBack: () => context.pop())
                : _paper == null
                ? const Center(child: CircularProgressIndicator(color: _jBlue))
                : _exam(context),
          ),
        ),
      ),
    );
  }

  Widget _exam(BuildContext context) {
    final p = _paper!;
    final q = _cur;
    final sub = _subjects[_s];
    final left = _left.isNegative ? Duration.zero : _left;
    final low = left.inMinutes < 5;
    String two(int n) => n.toString().padLeft(2, '0');
    final clock = '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    final isLast = _s == _subjects.length - 1 && _q == sub.questions.length - 1;
    return Column(
      children: [
        // Candidate bar
        Container(
          color: _jBlue,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.all(3),
                child: ExamLogo('${p['exam_code'] ?? 'JAMB'}', size: LogoSize.bare, px: 34),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p['candidate'] ?? 'Candidate'}'.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      '${p['title'] ?? 'UTME Mock'} · SolutionTee',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFCFE0F5), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: 'Time left $clock',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: low ? _jRed : _jBlueDark, borderRadius: BorderRadius.circular(6)),
                  child: Column(
                    children: [
                      const Text(
                        'TIME LEFT',
                        style: TextStyle(color: Color(0xFFCFE0F5), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .5),
                      ),
                      Text(
                        clock,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Subject buttons
        Container(
          color: _jGrey,
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            itemCount: _subjects.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final on = i == _s;
              return InkWell(
                key: ValueKey('mock-subject-$i'),
                onTap: () => _go(i, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? _jBlue : Colors.white,
                    border: Border.all(color: on ? _jBlue : _jLine),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _subjects[i].name.toUpperCase(),
                    style: TextStyle(color: on ? Colors.white : _jText, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              );
            },
          ),
        ),
        // Question
        Expanded(
          child: q == null
              ? const Center(child: Text('No questions in this subject.'))
              : ListView(
                  key: ValueKey('mock-q-${q.id}'),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  children: [
                    Text(
                      'Question ${_q + 1} of ${sub.questions.length}',
                      style: const TextStyle(color: _jBlue, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    if (q.passageBody != null) _Passage(title: q.passageTitle, body: q.passageBody!),
                    MathText(q.body, style: const TextStyle(color: _jText, fontSize: 16, height: 1.45)),
                    if (q.image != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: R2Image(imageKey: q.image!, fit: BoxFit.contain),
                      ),
                    ],
                    const SizedBox(height: 12),
                    for (final e in q.options.entries) _JOption(letter: e.key, text: e.value, selected: q.choice == e.key, onTap: () => _choose(e.key)),
                  ],
                ),
        ),
        // Previous / Next / Submit
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          decoration: const BoxDecoration(
            color: _jGrey,
            border: Border(top: BorderSide(color: _jLine)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _JButton('Previous', onTap: _s == 0 && _q == 0 ? null : _prev)),
                  const SizedBox(width: 6),
                  Expanded(child: _JButton('Next', onTap: isLast ? null : _next)),
                  if (p['allow_calculator'] == true)
                    IconButton(
                      tooltip: 'Calculator',
                      onPressed: () => showCalculator(context),
                      icon: Icon(PhosphorIcons.calculator(), color: _jBlue),
                    )
                  else
                    const SizedBox(width: 6),
                  Expanded(
                    child: _JButton('Submit', key: const ValueKey('mock-submit'), color: _jGreen, onTap: _submitting ? null : _confirmSubmit),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Question grid (this subject): answered green, current outlined.
              SizedBox(
                height: 76,
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 40, mainAxisSpacing: 4, crossAxisSpacing: 4),
                  itemCount: sub.questions.length,
                  itemBuilder: (_, i) {
                    final done = sub.questions[i].choice != null;
                    final cur = i == _q;
                    return InkWell(
                      onTap: () => _go(_s, i),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: done ? _jGreen : Colors.white,
                          border: Border.all(color: cur ? _jRed : (done ? _jGreen : _jLine), width: cur ? 2 : 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(color: done ? Colors.white : _jText, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text('$_answered of $_total answered', style: const TextStyle(color: Color(0xFF4B5563), fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Passage extends StatefulWidget {
  const _Passage({this.title, required this.body});
  final String? title;
  final String body;
  @override
  State<_Passage> createState() => _PassageState();
}

class _PassageState extends State<_Passage> {
  bool _open = true;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      border: Border.all(color: _jLine),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title?.isNotEmpty == true ? widget.title! : 'Read the passage',
                    style: const TextStyle(color: _jBlue, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(_open ? PhosphorIcons.caretUp() : PhosphorIcons.caretDown(), color: _jBlue, size: 18),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: MathText(widget.body, style: const TextStyle(color: _jText, fontSize: 15, height: 1.5)),
          ),
      ],
    ),
  );
}

class _JOption extends StatelessWidget {
  const _JOption({required this.letter, required this.text, required this.selected, required this.onTap});
  final String letter, text;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: selected ? const Color(0xFFE6F0FB) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: selected ? _jBlue : _jLine, width: selected ? 2 : 1),
      ),
      child: InkWell(
        key: ValueKey('mock-opt-$letter'),
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? _jBlue : const Color(0xFF6B7280), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: _jBlue, shape: BoxShape.circle),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  '$letter.',
                  style: const TextStyle(color: _jText, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MathText(text, style: const TextStyle(color: _jText, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _JButton extends StatelessWidget {
  const _JButton(this.label, {super.key, this.onTap, this.color = _jBlue});
  final String label;
  final VoidCallback? onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onTap,
    style: FilledButton.styleFrom(
      backgroundColor: color,
      disabledBackgroundColor: const Color(0xFFB8C2CF),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    child: Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.onBack});
  final String text;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Space.s6),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.fill), size: 48, color: _jBlue),
        const Gap(Space.s3),
        Text(text, textAlign: TextAlign.center, style: context.ty.label),
        const Gap(Space.s4),
        Btn('Back', onPressed: onBack),
      ],
    ),
  );
}

/// After submitting: JAMB-style scores (each subject /100, total /400), or "results come later".
class _ResultView extends StatelessWidget {
  const _ResultView({required this.r, required this.onDone});
  final Map<String, dynamic> r;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) {
    final visible = r['visible'] == true;
    final subjects = rows(r['subjects']);
    final score = (r['score'] as num?)?.toInt() ?? 0;
    final max = subjects.isEmpty ? 400 : subjects.length * 100;
    return ListView(
      padding: const EdgeInsets.all(Space.s5),
      children: [
        const Gap(Space.s4),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: Color(0xFFE6F4EA), shape: BoxShape.circle),
            child: Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill), size: 40, color: _jGreen),
          ),
        ),
        const Gap(Space.s3),
        Text('Exam submitted', textAlign: TextAlign.center, style: context.ty.h2.col(_jText)),
        if (r['reason'] != null) ...[
          const Gap(Space.s2),
          Text('${r['reason']}', textAlign: TextAlign.center, style: context.ty.sm.col(const Color(0xFF4B5563))),
        ],
        const Gap(Space.s5),
        if (!visible)
          InfoBanner(
            child: Text(
              r['when'] == 'after_end'
                  ? 'Your score will show here when the mock ends. Your tutor will share the results.'
                  : 'Your tutor will share the results.',
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(Space.s4),
            decoration: BoxDecoration(color: _jBlue, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                const Text(
                  'YOUR SCORE',
                  style: TextStyle(color: Color(0xFFCFE0F5), fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: .5),
                ),
                Text(
                  '$score / $max',
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700),
                ),
                if (r['rank'] != null) Text('Position ${r['rank']} of ${r['players']}', style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const Gap(Space.s3),
          for (final s in subjects)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: _jLine),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${s['name']}',
                      style: const TextStyle(color: _jText, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('${s['correct']}/${s['total']} correct · ', style: const TextStyle(color: Color(0xFF4B5563))),
                  Text(
                    '${s['score']}',
                    style: const TextStyle(color: _jBlue, fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ],
              ),
            ),
        ],
        const Gap(Space.s5),
        Btn('Done', block: true, onPressed: onDone),
      ],
    );
  }
}

/// The rules of a JAMB mock on its challenge page: the JAMB CBT layout, time, subjects, leaving and results.
class MockRulesCard extends StatelessWidget {
  const MockRulesCard({super.key, required this.c});
  final Challenge c;
  @override
  Widget build(BuildContext context) {
    final cc = context.c;
    final leave = [
      if (c.allowedExits > 0) 'up to ${c.allowedExits} time${c.allowedExits == 1 ? '' : 's'}',
      if (c.maxAwaySeconds != null) 'for ${(c.maxAwaySeconds! / 60).ceil()} min in total',
    ];
    final items = [
      (
        PhosphorIcons.exam(PhosphorIconsStyle.fill),
        'Exactly like the JAMB CBT',
        'Subject buttons, Previous / Next, the question grid and one timer. You can change answers until you submit.',
      ),
      (PhosphorIcons.books(PhosphorIconsStyle.fill), 'Use of English + your subjects', 'Each subject is scored out of 100, like the UTME.'),
      (
        PhosphorIcons.shieldWarning(PhosphorIconsStyle.fill),
        'Stay on the exam screen',
        leave.isEmpty
            ? 'Every time you leave the app is recorded for your tutor.'
            : 'You may leave ${leave.join(' and ')}. ${c.autoSubmitOnLeave ? 'After that your exam is submitted.' : 'After that your entry is flagged.'}',
      ),
      (
        PhosphorIcons.chartLineUp(PhosphorIconsStyle.fill),
        'Results',
        switch (c.results) {
          'after_end' => 'Scores show when the mock ends.',
          'hidden' => 'Your tutor shares the results.',
          _ => 'You see your score as soon as you submit.',
        },
      ),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill), color: cc.secondary, size: 20),
              const Gap(Space.s2),
              Text('JAMB mock exam', style: context.ty.sm.bold),
            ],
          ),
          const Gap(Space.s3),
          for (final (icon, title, body) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconTile(icon, tone: Tone.blue, size: 32, radius: 9, iconSize: 16),
                  const Gap(Space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.ty.sm.bold),
                        Text(body, style: context.ty.cap.col(cc.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
