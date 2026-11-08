import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/math_text.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/question_image.dart';
import '../../widgets/states.dart';
import '../ai/ai_screen.dart' show askAiAbout;
import '../cbt/cbt_screen.dart' show OptionRow, OptState;

/// Today's question of the day (server `qotd_today`, milestone 4E1, D-066): one question for everyone, one try,
/// marked on the server. Before answering, the phone has no answer and no explanation.
class Qotd {
  const Qotd({required this.day, required this.nextAt, required this.streak, this.question, this.result});
  final String day;
  final DateTime nextAt;
  final int streak;
  final Map<String, dynamic>? question;
  final Map<String, dynamic>? result;

  factory Qotd.fromJson(Map<String, dynamic> j) => Qotd(
    day: '${j['day']}',
    nextAt: DateTime.tryParse('${j['next_at']}') ?? DateTime.now().add(const Duration(hours: 24)),
    streak: (j['streak'] as num?)?.toInt() ?? 0,
    question: j['question'] is Map ? Map<String, dynamic>.from(j['question'] as Map) : null,
    result: j['result'] is Map ? Map<String, dynamic>.from(j['result'] as Map) : null,
  );
}

/// "4h 05m" until [at].
String untilText(DateTime at, {DateTime? now}) {
  final s = at.difference(now ?? DateTime.now()).inSeconds.clamp(0, 48 * 3600);
  return '${s ~/ 3600}h ${(s % 3600 ~/ 60).toString().padLeft(2, '0')}m';
}

class QotdNotifier extends AsyncNotifier<Qotd?> {
  @override
  Future<Qotd?> build() async {
    final uid = currentSession(ref)?.user.id;
    if (uid == null) return null;
    final q = await cached(ref, 'qotd:$uid', (s) => s.rpc('qotd_today'), (j) => j is Map ? Qotd.fromJson(Map<String, dynamic>.from(j)) : null);
    // An old cached question (offline since yesterday) is not today's.
    if (q != null && q.nextAt.isBefore(DateTime.now())) return null;
    return q;
  }

  /// Sends the answer; the server marks it. Returns false when it could not be sent.
  Future<bool> answer(String choice) async {
    try {
      final j = await ref.read(supabaseProvider).rpc('qotd_answer', params: {'p_choice': choice}).timeout(const Duration(seconds: 15));
      state = AsyncData(Qotd.fromJson(Map<String, dynamic>.from(j as Map)));
      return true;
    } catch (_) {
      return false;
    }
  }
}

final qotdProvider = AsyncNotifierProvider<QotdNotifier, Qotd?>(QotdNotifier.new);

/// Home card (prototype `.qotd2`). Hidden when there is no question today or it cannot load.
class QotdCard extends ConsumerStatefulWidget {
  const QotdCard({super.key});
  @override
  ConsumerState<QotdCard> createState() => _QotdCardState();
}

class _QotdCardState extends ConsumerState<QotdCard> {
  String? _sending;

  Future<void> _pick(String k) async {
    if (_sending != null) return;
    setState(() => _sending = k);
    final ok = await ref.read(qotdProvider.notifier).answer(k);
    if (!mounted) return;
    setState(() => _sending = null);
    if (!ok) toast(context, 'Could not send your answer. Check your internet and try again.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(qotdProvider);
    if (v.isLoading && !v.hasValue) return const Skeleton(height: 260, radius: Radii.lg);
    final q = v.value;
    if (q == null || q.question == null) return const SizedBox.shrink();
    final c = context.c;
    final qq = q.question!;
    final r = q.result;
    final options = Map<String, dynamic>.from(qq['options'] as Map);
    final keys = options.keys.toList()..sort();
    final rm = context.reduceMotion;

    return Container(
      key: const ValueKey('qotd'),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Head: bulb, title, subject + source, streak
          Container(
            color: c.accentSoft,
            padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s3, Space.s3),
            child: Row(
              children: [
                IconTile(PhosphorIcons.lightbulb(PhosphorIconsStyle.fill), tone: Tone.gold, size: 36, radius: 10, iconSize: 20),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Question of the day', style: context.ty.sm.bold),
                      Text(
                        // Lawyer's list (D-120): the two kinds are always named the same way.
                        qq['own'] == true
                            ? [if ((qq['subject'] ?? '').toString().isNotEmpty) qq['subject'], 'SolutionTee Mock Question'].join(' · ')
                            : '${qq['subject']} · Past Question, ${qq['exam']} ${qq['year']}',
                        style: context.ty.cap.col(c.textMuted),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: '${q.streak} days in a row',
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(99)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIcons.fire(PhosphorIconsStyle.fill), size: 16, color: Palette.gold500),
                        const SizedBox(width: 4),
                        Text('${q.streak}', style: context.ty.sm.bold.tnum),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MathText('${qq['body']}', style: context.ty.body.copyWith(fontSize: 16, height: 25 / 16)),
                if ((qq['image_path'] as String?)?.isNotEmpty ?? false) ...[const Gap(Space.s3), QuestionImage(imageKey: qq['image_path'] as String)],
                const Gap(Space.s3),
                for (final k in keys) ...[
                  OptionRow(
                    letter: k,
                    text: '${options[k]}',
                    state: r == null
                        ? (_sending == k ? OptState.selected : OptState.none)
                        : k == r['answer']
                        ? OptState.right
                        : k == r['choice']
                        ? OptState.wrong
                        : OptState.none,
                    onTap: r == null && _sending == null ? () => _pick(k) : null,
                  ),
                  const Gap(Space.s2),
                ],
                if (r != null)
                  _Result(
                    r: r,
                    streak: q.streak,
                    questionId: qq['own'] == true ? null : '${qq['id']}',
                  ).animate(target: rm ? 0 : 1).fadeIn(duration: Motion.base).slideY(begin: .08),
                const Gap(Space.s2),
                Row(
                  children: [
                    Icon(PhosphorIcons.clock(), size: 14, color: c.textMuted),
                    const SizedBox(width: 4),
                    Text('New question in ${untilText(q.nextAt)}', style: context.ty.cap.col(c.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.r, required this.streak, required this.questionId});
  final Map<String, dynamic> r;
  final int streak;

  /// The past question's id for Ask AI; null for the admin's own question (Ask AI explains bank questions).
  final String? questionId;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ok = r['correct'] == true;
    final pct = (r['pct_right'] as num?)?.toInt() ?? 0;
    final explanation = (r['explanation'] as String?) ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(Space.s1),
        Container(
          padding: const EdgeInsets.all(Space.s3),
          decoration: BoxDecoration(color: ok ? c.successSoft : c.errorSoft, borderRadius: BorderRadius.circular(Radii.md)),
          child: Row(
            children: [
              Icon(
                ok ? PhosphorIcons.confetti(PhosphorIconsStyle.fill) : PhosphorIcons.smileySad(PhosphorIconsStyle.fill),
                color: ok ? c.success : c.error,
                size: 24,
              ),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ok ? 'Correct!' : 'Not this time', style: context.ty.sm.bold),
                    Text(
                      ok
                          ? 'Your question-of-the-day streak is $streak ${streak == 1 ? 'day' : 'days'}.'
                          : 'The answer is ${r['answer']}. Read why below. Your streak is $streak ${streak == 1 ? 'day' : 'days'}.',
                      style: context.ty.cap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(Space.s3),
        Row(
          children: [
            Expanded(child: Text('Students who got it right', style: context.ty.cap.col(c.textMuted))),
            Text('$pct%', style: context.ty.cap.bold.tnum),
          ],
        ),
        const Gap(Space.s1),
        ProgressBar(pct / 100, color: c.success),
        if (explanation.isNotEmpty) ...[
          const Gap(Space.s3),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Material(
              color: c.surfaceAlt,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.md),
                side: BorderSide(color: c.border),
              ),
              child: ExpansionTile(
                initiallyExpanded: !ok,
                title: Text('Explanation', style: context.ty.sm.bold),
                childrenPadding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s4),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [MathText(explanation, style: context.ty.body.copyWith(height: 24 / 15))],
              ),
            ),
          ),
        ],
        const Gap(Space.s3),
        Row(
          children: [
            if (questionId != null) ...[
              Expanded(
                child: Btn(
                  'Ask AI',
                  kind: BtnKind.tonal,
                  sm: true,
                  leading: PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                  onPressed: () => askAiAbout(context, questionId: questionId!, label: 'Question of the day'),
                ),
              ),
              const Gap(Space.s2),
            ],
            Expanded(
              child: Btn(
                'Practise more',
                kind: BtnKind.outline,
                sm: true,
                leading: PhosphorIcons.lightning(PhosphorIconsStyle.fill),
                onPressed: () => context.push('/test/setup?exam=JAMB&mode=quick'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
