import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads.dart';
import '../../core/providers.dart';
import '../../core/secure_screen.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/math_text.dart';
import '../../widgets/phosphor.g.dart';
import '../cbt/calculator.dart' show showCalculator;
import '../cbt/cbt_screen.dart' show OptionRow, OptState;
import 'compete_data.dart';

/// Talks to the server for one challenge entry. Separate from the screen so tests can fake it.
abstract class ChallengeApi {
  Future<Map<String, dynamic>> start(String id, String? device, List<String> flags);
  Future<Map<String, dynamic>> answer(String entryId, String questionId, String? choice);
  Future<Map<String, dynamic>> exit(String entryId, String reason);

  /// A screenshot or screen recording during the challenge: a fair-play flag (D-075).
  Future<void> report(String entryId, String what);
}

class SupabaseChallengeApi implements ChallengeApi {
  SupabaseChallengeApi(this.ref);
  final Ref ref;
  Future<Map<String, dynamic>> _rpc(String fn, Map<String, dynamic> p) async =>
      Map<String, dynamic>.from(await ref.read(supabaseProvider).rpc(fn, params: p).timeout(const Duration(seconds: 20)) as Map);
  @override
  Future<Map<String, dynamic>> start(String id, String? device, List<String> flags) =>
      _rpc('challenge_start', {'p_id': id, 'p_device': device, 'p_device_flags': flags});
  @override
  Future<Map<String, dynamic>> answer(String entryId, String questionId, String? choice) =>
      _rpc('challenge_answer', {'p_entry': entryId, 'p_question': questionId, 'p_choice': choice});
  @override
  Future<Map<String, dynamic>> exit(String entryId, String reason) => _rpc('challenge_exit', {'p_entry': entryId, 'p_reason': reason});
  @override
  Future<void> report(String entryId, String what) async {
    await ref.read(supabaseProvider).rpc('challenge_report', params: {'p_entry': entryId, 'p_what': what}).timeout(const Duration(seconds: 20));
  }
}

final challengeApiProvider = Provider<ChallengeApi>((ref) => SupabaseChallengeApi(ref));

/// The challenge itself (prototype `challenge-play` + `challenge-dq`): one question at a time with its own timer;
/// leaving the screen (another app, notification panel, split screen, floating window) is reported to the server,
/// which disqualifies after the allowed exits. Screenshots and screen recording are blocked.
class ChallengePlayScreen extends ConsumerStatefulWidget {
  const ChallengePlayScreen({super.key, required this.id, this.title = 'Challenge'});
  final String id;
  final String title;
  @override
  ConsumerState<ChallengePlayScreen> createState() => _ChallengePlayScreenState();
}

class _ChallengePlayScreenState extends ConsumerState<ChallengePlayScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _q;
  String? _sending;
  String? _error;
  String? _warning;
  String? _dqReason;
  bool _away = false;
  bool _done = false;
  int _qMs = 0; // time on this question, counted by the 250 ms ticker (the server checks the real time)
  bool _hasQ = false;
  final _startedAt = DateTime.now();
  Timer? _tick;
  StreamSubscription<MethodCall>? _events, _secure;

  ChallengeApi get _api => ref.read(challengeApiProvider);
  String? get _entry => _q?['entry_id'] as String?;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SecureScreen.on();
    AdsGate.enter(); // never an ad here (big update 2, step B)
    _events = DeviceEvents.stream.listen((call) {
      if (call.method == 'focus' && call.arguments == false) _left('Another window or the notification panel opened over the challenge');
      if (call.method == 'multiWindow' && call.arguments == true) _left('Split screen or a floating window was opened');
      if (call.method == 'focus' && call.arguments == true) _away = false;
    });
    _secure = SecureScreen.watch(onScreenshot: () => _capture('screenshot'), onRecording: () => _capture('recording'));
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => _onTick());
    _begin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    _secure?.cancel();
    _tick?.cancel();
    SecureScreen.off();
    AdsGate.leave();
    super.dispose();
  }

  /// Screenshots are blocked; an attempt is shown to the student and saved for the fair-play review.
  void _capture(String what) {
    if (!mounted || _done) return;
    final e = _entry;
    if (e != null) _api.report(e, what).ignore(); // saved for the fair-play review even when screenshots are allowed
    if (!SecureScreen.protecting) return;
    toast(
      context,
      what == 'screenshot'
          ? 'Screenshots are not allowed in challenges. This attempt was recorded.'
          : 'Screen recording is not allowed in challenges. Stop it, or your entry may not win.',
      icon: PhosphorIcons.cameraSlash(PhosphorIconsStyle.fill),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _away = false;
    } else if (s == AppLifecycleState.inactive || s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      _left('You left the challenge screen (another app or the home button)');
    }
  }

  Future<void> _begin() async {
    try {
      final r = await _api.start(widget.id, await DeviceCheck.hashedId(), await DeviceCheck.flags());
      _apply(r);
    } catch (e) {
      if (mounted) setState(() => _error = challengeError(e));
    }
  }

  void _apply(Map<String, dynamic> r) {
    if (!mounted) return;
    final status = r['status'];
    if (status == 'playing' && r['question'] is Map) {
      final q = Map<String, dynamic>.from(r['question'] as Map);
      final same = q['question_id'] == _q?['question_id'];
      setState(() {
        _q = q;
        _sending = null;
        _warning = r['warning'] as String? ?? (same ? _warning : null);
        if (!same) {
          _qMs = 0;
          _hasQ = true;
        }
      });
    } else if (status == 'disqualified') {
      _finish(dq: true);
    } else {
      _finish(dq: false);
    }
  }

  void _finish({required bool dq}) {
    if (_done) return;
    _done = true;
    _tick?.cancel();
    ref.invalidate(challengesProvider);
    ref.invalidate(challengeProvider(widget.id));
    if (dq) {
      setState(() => _dqReason ??= 'You left the challenge screen.');
    } else {
      context.go('/test/challenges/${widget.id}/result');
    }
  }

  /// Reported once per time away; the server decides (warning or disqualified).
  Future<void> _left(String reason) async {
    if (_away || _done || _entry == null) return;
    _away = true;
    _dqReason = reason;
    try {
      _apply(await _api.exit(_entry!, reason));
    } catch (_) {
      // No internet: the server still counts it when the app comes back (starting again counts as leaving).
    }
  }

  void _onTick() {
    if (!mounted || _q == null || _done || !_hasQ) return;
    if (_sending == null) _qMs += 250;
    final left = _secondsLeft;
    if (left <= 0 && _sending == null) {
      _send(null);
    } else {
      setState(() {});
    }
  }

  double get _secondsLeft {
    final total = (_q?['seconds'] as num?)?.toDouble() ?? 30;
    return total - _qMs / 1000;
  }

  Future<void> _send(String? choice) async {
    if (_sending != null || _q == null || _done) return;
    setState(() => _sending = choice ?? '');
    HapticFeedback.selectionClick();
    try {
      _apply(await _api.answer(_entry!, '${_q!['question_id']}', choice));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = null);
      toast(context, 'Could not send your answer. Check your internet; it is sent again when you tap.');
    }
  }

  Future<bool> _confirmLeave() async {
    final ok = await showAppDialog<bool>(
      context,
      title: 'Leave the challenge?',
      body: 'Your answers are submitted now and this entry is disqualified.',
      icon: PhosphorIcons.shieldWarning(PhosphorIconsStyle.fill),
      tone: Tone.red,
      actions: [
        Builder(
          builder: (ctx) => Btn('Leave', kind: BtnKind.danger, block: true, onPressed: () => Navigator.of(ctx).pop(true)),
        ),
        Builder(
          builder: (ctx) => Btn('Keep playing', kind: BtnKind.ghost, block: true, onPressed: () => Navigator.of(ctx).pop(false)),
        ),
      ],
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_dqReason != null && _done) {
      return _Disqualified(
        challengeId: widget.id,
        reason: _dqReason!,
        answered: (_q?['index'] as num?)?.toInt() ?? 0,
        total: (_q?['total'] as num?)?.toInt() ?? 0,
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_done || _q == null) {
          if (context.mounted) context.pop();
          return;
        }
        if (await _confirmLeave()) {
          await _left('You left the challenge with the back button');
          if (!mounted || _done) return;
          GoRouter.of(this.context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: _error != null
              ? Center(
                  child: StateBlock(
                    icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                    tone: Tone.red,
                    title: 'Could not start',
                    text: _error,
                    action: Btn('Back', onPressed: () => context.pop()),
                  ),
                )
              : _q == null
              ? const Center(child: CircularProgressIndicator())
              : _question(context),
        ),
      ),
    );
  }

  Widget _question(BuildContext context) {
    final c = context.c;
    final q = _q!;
    final index = (q['index'] as num).toInt(), total = (q['total'] as num).toInt();
    final seconds = (q['seconds'] as num?)?.toDouble() ?? 30;
    final left = _secondsLeft.clamp(0, seconds).toDouble();
    final elapsed = DateTime.now().difference(_startedAt).inSeconds;
    final opts = [for (final o in (q['options'] as List)) Map<String, dynamic>.from(o as Map)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, Space.s2),
          child: Row(
            children: [
              Pill('Fair play on', kind: BadgeKind.success, icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill)),
              Expanded(
                child: Text(
                  ref.watch(challengeProvider(widget.id)).value?.title ?? widget.title,
                  style: context.ty.sm.bold,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (ref.watch(challengeProvider(widget.id)).value?.calculator == true)
                IconBtn(PhosphorIcons.calculator(), label: 'Calculator', onPressed: () => showCalculator(context)),
              Text('${elapsed ~/ 60}:${(elapsed % 60).toString().padLeft(2, '0')}', style: context.ty.cap.tnum.col(c.textMuted)),
            ],
          ),
        ),
        ProgressBar(index / total, height: 4),
        if (_warning != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, 0),
            child: InfoBanner(kind: BannerKind.warn, icon: PhosphorIcons.shieldWarning(PhosphorIconsStyle.fill), child: Text(_warning!)),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s6),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Question ${index + 1} '),
                          TextSpan(text: 'of $total', style: context.ty.label.col(c.textMuted)),
                        ],
                      ),
                      style: context.ty.label,
                    ),
                  ),
                  _Ring(value: left / seconds, label: '${left.ceil()}', low: left <= 5),
                ],
              ),
              const Gap(Space.s3),
              MathText(
                '${q['body']}',
                style: context.ty.body.copyWith(fontSize: TypeScale.question.size, height: TypeScale.question.line / TypeScale.question.size),
              ).animate(key: ValueKey(q['question_id'])).fadeIn(duration: Motion.base),
              const Gap(Space.s4),
              for (final (k, o) in opts.indexed) ...[
                OptionRow(
                  letter: 'ABCDE'[k],
                  text: '${o['text']}',
                  state: _sending == o['key'] ? OptState.selected : OptState.none,
                  onTap: _sending == null ? () => _send('${o['key']}') : null,
                ),
                const Gap(Space.s2),
              ],
              const Gap(Space.s3),
              Row(
                children: [
                  Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), size: 14, color: c.textSubtle),
                  const SizedBox(width: 4),
                  Expanded(child: Text('You cannot go back. Answers are checked on our server.', style: context.ty.cap.col(c.textSubtle))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Per-question timer ring (`.q-timer`).
class _Ring extends StatelessWidget {
  const _Ring({required this.value, required this.label, required this.low});
  final double value;
  final String label;
  final bool low;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(value: value.clamp(0, 1), strokeWidth: 4, color: low ? c.error : c.secondary, backgroundColor: c.surfaceSunken),
          Text(label, style: context.ty.sm.bold.tnum.col(low ? c.error : c.text)),
        ],
      ),
    );
  }
}

class _Disqualified extends StatelessWidget {
  const _Disqualified({required this.challengeId, required this.reason, required this.answered, required this.total});
  final String challengeId;
  final String reason;
  final int answered, total;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: TopBar(
        showBack: false,
        actions: [IconBtn(PhosphorIcons.x(), label: 'Close', onPressed: () => context.go('/test/challenges'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.s5),
        children: [
          StateBlock(
            icon: PhosphorIcons.shieldWarning(PhosphorIconsStyle.fill),
            tone: Tone.red,
            title: 'Entry disqualified',
            text: '$reason. Your answers were submitted automatically after $answered of $total questions.',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What this means', style: context.ty.sm.bold),
                const Gap(Space.s1),
                Text('This entry cannot win a prize. You can still join the next challenge.', style: context.ty.sm.col(c.textMuted)),
              ],
            ),
          ),
          const Gap(Space.s3),
          InfoBanner(
            kind: BannerKind.warn,
            icon: PhosphorIcons.phoneCall(PhosphorIconsStyle.fill),
            child: const Text('Was it a phone call or a crash? Send an appeal within 24 hours, with a screenshot if you can. Our team checks it.'),
          ),
          const Gap(Space.s3),
          Btn(
            'Send an appeal',
            block: true,
            leading: PhosphorIcons.scales(PhosphorIconsStyle.fill),
            onPressed: () => context.go('/test/challenges/$challengeId/appeal'),
          ),
          const Gap(Space.s4),
          Btn('Back to challenges', kind: BtnKind.outline, block: true, onPressed: () => context.go('/test/challenges')),
        ],
      ),
    );
  }
}
