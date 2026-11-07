import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/nav.dart';
import '../../core/providers.dart';
import '../../data/db.dart';
import '../../theme/theme.dart';
import '../home/home_screen.dart' show unfinishedProvider;
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../premium/paywall.dart' show showPaywall;
import 'compete_data.dart';

// JAMB mock challenges (D-099): the whole paper at once in our own CBT screen. Answers save to the server as they
// are chosen; leaving the screen is logged and the admin's limits apply; marked on the server.

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

/// Opens a JAMB mock in our own CBT screen (owner, 2026-11-07): the paper from the server is saved on the phone
/// (questions without answers, the student's saved choices), as a local attempt whose id is the server entry, and the
/// CBT screen runs it in "mock" mode (answers, leaving and submit go to the server; the timer follows the deadline).
/// After submitting, this screen shows the JAMB-style result.
class MockExamScreen extends ConsumerStatefulWidget {
  const MockExamScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends ConsumerState<MockExamScreen> {
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    try {
      final r = await ref.read(mockApiProvider).start(widget.id);
      if (!mounted) return;
      if (r['status'] == 'playing') {
        final entry = await saveMockPaper(ref.read(dbProvider), widget.id, r);
        ref.invalidate(unfinishedProvider);
        if (mounted) context.pushReplacement('/cbt/$entry');
      } else if (r['status'] == 'locked') {
        setState(() => _error = 'Enter your access code on the mock page first.');
      } else {
        final res = await ref.read(mockApiProvider).result(widget.id);
        if (mounted) setState(() => _result = res);
      }
    } catch (e) {
      if (mounted) setState(() => _error = challengeError(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: TopBar(title: 'JAMB mock', onBack: () => context.canPop() ? context.pop() : context.go('/test/challenges')),
    body: _result != null
        ? MockResultView(
            r: _result!,
            onDone: () => context.canPop() ? context.pop() : context.go('/test/challenges'),
            leaderboard: () => openRoute(context, '/test/challenges/${widget.id}/result'),
          )
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.s6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconTile(PhosphorIcons.warningCircle(PhosphorIconsStyle.fill), tone: Tone.red, size: 56, radius: 16),
                  const Gap(Space.s3),
                  Text('Could not open the mock', style: context.ty.h3, textAlign: TextAlign.center),
                  const Gap(Space.s2),
                  Text(_error!, style: context.ty.sm.col(context.c.textMuted), textAlign: TextAlign.center),
                  const Gap(Space.s4),
                  Btn('Back', onPressed: () => context.canPop() ? context.pop() : context.go('/test/challenges')),
                ],
              ),
            ),
          )
        : const Center(child: CircularProgressIndicator()),
  );
}

/// Saves the server paper on the phone for the CBT screen. Returns the attempt id (= the server entry id).
Future<String> saveMockPaper(AppDb db, String challengeId, Map<String, dynamic> r) async {
  final entry = '${r['entry_id']}';
  final now = DateTime.tryParse('${r['now']}')?.toUtc() ?? DateTime.now().toUtc();
  final deadline = DateTime.tryParse('${r['deadline']}')?.toUtc() ?? now.add(const Duration(hours: 2));
  final skew = now.difference(DateTime.now().toUtc()).inMilliseconds;
  final ids = <String>[], sids = <int>[];
  final choices = <String, String>{};
  for (final s in (r['subjects'] as List? ?? const [])) {
    final sid = ((s as Map)['id'] as num).toInt();
    sids.add(sid);
    for (final q in (s['questions'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(q as Map);
      final id = '${m['id']}';
      ids.add(id);
      if (m['choice'] is String) choices[id] = m['choice'] as String;
      final key = m['passage_key'] as String?;
      await db
          .into(db.cachedQuestions)
          .insertOnConflictUpdate(
            CachedQuestionsCompanion.insert(
              id: id,
              examId: 0,
              subjectId: sid,
              year: 0,
              number: Value((m['number'] as num?)?.toInt()),
              body: '${m['body'] ?? ''}',
              optionsJson: jsonEncode(m['options'] ?? const {}),
              answer: '', // never sent to the phone: marked on the server
              topic: Value(m['section'] as String?),
              imagePath: Value(m['image_path'] as String?),
              passageId: Value(key == null || key.isEmpty ? null : '$entry:$key'),
              passageTitle: Value(m['passage_title'] as String?),
              passageBody: Value(m['passage_body'] as String?),
            ),
          );
    }
  }
  await db
      .into(db.localAttempts)
      .insertOnConflictUpdate(
        LocalAttemptsCompanion.insert(
          id: entry,
          examId: 0,
          examCode: '${r['exam_code'] ?? 'JAMB'}',
          mode: 'mock',
          configJson: jsonEncode({
            'mock': challengeId,
            'entry': entry,
            'title': '${r['title'] ?? 'JAMB mock'}',
            'subjects': sids,
            'timed': true,
            'deadline': deadline.toIso8601String(),
            'skew_ms': skew,
          }),
          questionIdsJson: jsonEncode(ids),
          limitSeconds: deadline.difference(now).inSeconds.clamp(1, 6 * 3600),
          usedMs: const Value(0),
          startedAt: DateTime.now(),
        ),
      );
  for (final e in choices.entries) {
    await db.saveAnswer(entry, e.key, choice: e.value);
  }
  return entry;
}

/// After submitting: JAMB-style scores (each subject /100, total /400), or "results come later".
class MockResultView extends StatelessWidget {
  const MockResultView({super.key, required this.r, required this.onDone, this.leaderboard});
  final Map<String, dynamic> r;
  final VoidCallback onDone;

  /// Opens the challenge leaderboard (the same one other challenges use).
  final VoidCallback? leaderboard;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final visible = r['visible'] == true;
    final subjects = rows(r['subjects']);
    final score = (r['score'] as num?)?.toInt() ?? 0;
    final max = subjects.isEmpty ? 400 : subjects.length * 100;
    return ListView(
      padding: const EdgeInsets.all(Space.s5),
      children: [
        const Gap(Space.s3),
        Center(child: IconTile(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill), tone: Tone.green, size: 72, radius: 22, iconSize: 38)),
        const Gap(Space.s3),
        Text('Exam submitted', textAlign: TextAlign.center, style: context.ty.h2),
        if (r['reason'] != null) ...[const Gap(Space.s2), Text('${r['reason']}', textAlign: TextAlign.center, style: context.ty.sm.col(c.textMuted))],
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
            padding: const EdgeInsets.all(Space.s5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Palette.navy900, Color(0xFF1C4C9C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Column(
              children: [
                Text('YOUR SCORE', style: context.ty.over.col(Palette.gold400)),
                const Gap(Space.s1),
                Text('$score / $max', style: context.ty.h1.col(Colors.white).tnum),
                if (r['rank'] != null) Text('Position ${r['rank']} of ${r['players']}', style: context.ty.sm.col(Colors.white)),
              ],
            ),
          ),
          const Gap(Space.s4),
          for (final s in subjects)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s2),
              child: AppCard(
                child: Row(
                  children: [
                    Expanded(child: Text('${s['name']}', style: context.ty.sm.bold)),
                    Text('${s['correct']}/${s['total']} correct', style: context.ty.cap.col(c.textMuted)),
                    const Gap(Space.s3),
                    Text('${s['score']}', style: context.ty.h3.col(c.secondary).tnum),
                  ],
                ),
              ),
            ),
        ],
        const Gap(Space.s5),
        if (leaderboard != null) ...[
          Btn('See the leaderboard', kind: BtnKind.outline, block: true, leading: PhosphorIcons.ranking(PhosphorIconsStyle.fill), onPressed: leaderboard),
          const Gap(Space.s2),
        ],
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
        'A full JAMB CBT mock',
        'Our exam screen with all your subjects and one timer. You can change answers until you submit.',
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
