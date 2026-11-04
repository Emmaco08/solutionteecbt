import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/db.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/phosphor.g.dart';
import '../cbt/exam_clock.dart';
import 'home_screen.dart';

/// Today's line from the admin's list (Admin → Motivation), cached for offline.
final motivationProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => cached(ref, 'motivation', (s) => s.rpc('today_motivation'), (j) => j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{}),
);

/// The first card on Home: the unfinished test when there is one, else today's motivation and goal.
class HomeTopCard extends ConsumerWidget {
  const HomeTopCard({super.key, required this.unfinished, required this.stats});
  final LocalAttempt? unfinished;
  final PracticeStats stats;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = unfinished;
    return AnimatedSwitcher(
      duration: context.reduceMotion ? Duration.zero : Motion.slow,
      child: a != null ? ResumeHero(key: ValueKey(a.id), a: a) : TodayCard(key: const ValueKey('today'), stats: stats),
    );
  }
}

/// "Continue where you stopped": navy card with the exam logo, how far you got, time left and a big Continue button.
class ResumeHero extends ConsumerWidget {
  const ResumeHero({super.key, required this.a});
  final LocalAttempt a;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rm = context.reduceMotion;
    final cfg = jsonDecode(a.configJson) as Map<String, dynamic>;
    final total = (jsonDecode(a.questionIdsJson) as List).length;
    final done = ref.watch(unfinishedAnsweredProvider(a.id)).value ?? 0;
    final left = a.limitSeconds == 0 ? null : Duration(seconds: a.limitSeconds) - Duration(milliseconds: a.usedMs);
    final title = (cfg['title'] as String?)?.isNotEmpty == true ? cfg['title'] as String : a.examCode;
    final frac = total == 0 ? 0.0 : done / total;
    const ink = Color(0xFFF4F7FC), soft = Color(0xFFAFC0DD);
    return Semantics(
      button: true,
      label: 'Continue your test: $title, $done of $total answered',
      child: GestureDetector(
        onTap: () => context.push('/cbt/${a.id}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.navy900, Color(0xFF16336B)]),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -50,
                  top: -60,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [Color.fromRGBO(37, 99, 179, .55), Color.fromRGBO(37, 99, 179, 0)]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Space.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Palette.gold400.withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _Dot(still: rm),
                                const SizedBox(width: 6),
                                Text('CONTINUE WHERE YOU STOPPED', style: context.ty.over.col(Palette.gold400)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Gap(Space.s3),
                      Row(
                        children: [
                          ExamLogo(a.examCode, px: 44),
                          const Gap(Space.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: context.ty.h3.col(ink), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(
                                  '$done of $total answered${left == null ? '' : ' · ${ExamClock.format(left.isNegative ? Duration.zero : left)} left'}',
                                  style: context.ty.sm.col(soft),
                                ),
                              ],
                            ),
                          ),
                          Ring(
                            value: frac,
                            size: 52,
                            color: Palette.gold400,
                            track: const Color(0x33FFFFFF),
                            label: Text('${(frac * 100).round()}%', style: context.ty.cap.bold.tnum.col(ink)),
                          ),
                        ],
                      ),
                      const Gap(Space.s4),
                      Btn('Continue test', kind: BtnKind.accent, block: true, icon: PhosphorIcons.arrowRight(), onPressed: () => context.push('/cbt/${a.id}')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.still = false});
  final bool still;
  @override
  Widget build(BuildContext context) {
    final d = Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(color: Palette.gold400, shape: BoxShape.circle),
    );
    return still ? d : d.animate(onPlay: (a) => a.repeat(reverse: true)).scaleXY(begin: .7, end: 1.15, duration: 700.ms).fade(begin: .6, end: 1);
  }
}

/// "Today": the day's motivation or study tip, plus the daily goal ring and a Practise button.
class TodayCard extends ConsumerWidget {
  const TodayCard({super.key, required this.stats});
  final PracticeStats stats;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final rm = context.reduceMotion;
    final m = ref.watch(motivationProvider).value ?? const {};
    final body = (m['body'] as String?) ?? 'Small steps every day beat one big push the night before the exam.';
    final author = m['author'] as String?;
    final tip = m['kind'] == 'tip';
    final h = DateTime.now().hour;
    final icon = h < 12
        ? PhosphorIcons.sunHorizon(PhosphorIconsStyle.fill)
        : h < 17
        ? PhosphorIcons.sun(PhosphorIconsStyle.fill)
        : PhosphorIcons.moonStars(PhosphorIconsStyle.fill);
    final goal = PracticeStats.dailyGoal;
    final left = (goal - stats.today).clamp(0, goal);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.surface, c.accentSoft.withValues(alpha: .55)]),
      ),
      padding: const EdgeInsets.all(Space.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Palette.gold500),
              const Gap(Space.s2),
              Expanded(child: Text(tip ? 'TODAY\'S STUDY TIP' : 'TODAY\'S MOTIVATION', style: context.ty.over.col(c.textMuted))),
              Icon(tip ? PhosphorIcons.lightbulb(PhosphorIconsStyle.fill) : PhosphorIcons.quotes(PhosphorIconsStyle.fill), size: 22, color: c.accent),
            ],
          ),
          const Gap(Space.s2),
          Text(body, style: context.ty.h3.copyWith(height: 1.3))
              .animate(key: ValueKey(body))
              .fadeIn(duration: rm ? 1.ms : 450.ms)
              .slideY(begin: rm ? 0 : .15, end: 0, duration: rm ? 1.ms : 450.ms, curve: Curves.easeOutCubic),
          if (author != null && author.isNotEmpty) ...[const Gap(Space.s1), Text('— $author', style: context.ty.sm.col(c.textMuted))],
          const Gap(Space.s4),
          Container(
            padding: const EdgeInsets.fromLTRB(Space.s3, Space.s2, Space.s2, Space.s2),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Ring(
                  value: stats.today / goal,
                  size: 40,
                  label: left == 0 ? Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), size: 16, color: c.success) : null,
                ),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${stats.today} of $goal questions today', style: context.ty.sm.bold),
                      Text(left == 0 ? 'Goal reached. Great work!' : '$left more to reach today\'s goal', style: context.ty.cap.col(c.textMuted)),
                    ],
                  ),
                ),
                Btn('Practise', kind: BtnKind.tonal, sm: true, onPressed: () => context.push('/test/setup?exam=JAMB&mode=quick')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
