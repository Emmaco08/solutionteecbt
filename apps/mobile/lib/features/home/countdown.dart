import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/phosphor.g.dart';
import '../xp/streak_ui.dart';
import 'home_screen.dart';
import 'top_card.dart';

/// The exam a student is counting down to (D-135). Dates come from Admin → Motivation → Exam countdown.
class ExamCountdown {
  const ExamCountdown({required this.code, required this.label, required this.date});
  final String code, label;
  final DateTime date;

  int get daysLeft {
    final now = DateTime.now();
    return DateTime(date.year, date.month, date.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// "15 Mar 2027" (fits the small Home chip on narrow phones).
  String get shortDate {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${m[date.month - 1]} ${date.year}';
  }

  String get dateText {
    const m = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${date.day} ${m[date.month - 1]} ${date.year}';
  }
}

/// The exam's everyday name: UTME, WASSCE, SSCE (others: their own code).
String examShortName(String code) => switch (code.toUpperCase()) {
  'JAMB' => 'UTME',
  'WAEC' => 'WASSCE',
  'NECO' => 'SSCE',
  _ => code.toUpperCase(),
};

/// Admin settings: {on, daily, dates: {JAMB: "2027-04-24", …}}.
final countdownSettingsProvider = Provider<Map<String, dynamic>>((ref) {
  final s = ref.watch(appSettingsProvider).value?['exam_countdown'];
  return s is Map ? Map<String, dynamic>.from(s) : const {};
});

/// The next exam this student chose (profile target exams, JAMB first) that has a date in the future. Null when the
/// admin turned the countdown off or set no date.
final examCountdownProvider = Provider<ExamCountdown?>((ref) {
  final s = ref.watch(countdownSettingsProvider);
  if (s['on'] == false) return null;
  final dates = s['dates'] is Map ? Map<String, dynamic>.from(s['dates'] as Map) : const <String, dynamic>{};
  final mine = [for (final e in (ref.watch(profileProvider).value?['target_exams'] as List?) ?? const []) '$e'.toUpperCase()];
  final order = [...mine, 'JAMB', 'WAEC', 'NECO', ...dates.keys.map((k) => k.toUpperCase())];
  final seen = <String>{};
  final all = <ExamCountdown>[];
  for (final code in order) {
    if (!seen.add(code)) continue;
    final raw = dates[code] ?? dates[code.toLowerCase()];
    final d = raw is String ? DateTime.tryParse(raw) : null;
    if (d == null) continue;
    final c = ExamCountdown(code: code, label: examShortName(code), date: d);
    if (c.daysLeft >= 0) all.add(c);
  }
  if (all.isEmpty) return null;
  // The student's own exams first, then the nearest date.
  final own = all.where((c) => mine.contains(c.code)).toList();
  final pool = own.isNotEmpty ? own : all;
  pool.sort((x, y) => x.daysLeft.compareTo(y.daysLeft));
  return pool.first;
});

/// Once a day, on the first open: the full-screen countdown (when the admin left "show every day" on).
Future<void> maybeShowDailyCountdown(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(appSettingsProvider.future).timeout(const Duration(seconds: 8));
    await ref.read(profileProvider.future).timeout(const Duration(seconds: 8));
  } catch (_) {}
  if (!context.mounted) return;
  final s = ref.read(countdownSettingsProvider);
  final c = ref.read(examCountdownProvider);
  if (c == null || s['daily'] == false) return;
  final db = ref.read(dbProvider);
  final now = DateTime.now(), today = '${now.year}-${now.month}-${now.day}';
  if (await db.kvGet('countdown_day') == today || !context.mounted) return;
  await db.kvSet('countdown_day', today);
  if (context.mounted) await showExamCountdown(context);
}

Future<void> showExamCountdown(BuildContext context) => Navigator.of(context, rootNavigator: true).push(
  PageRouteBuilder<void>(
    opaque: true,
    fullscreenDialog: true,
    transitionDuration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 380),
    reverseTransitionDuration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => const ExamCountdownScreen(),
    transitionsBuilder: (_, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween(begin: 1.04, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  ),
);

/// Full-screen countdown: the exam logo, the days left counting up, today's goal and streak, and today's line.
class ExamCountdownScreen extends ConsumerWidget {
  const ExamCountdownScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(examCountdownProvider);
    final rm = context.reduceMotion;
    final stats = ref.watch(practiceStatsProvider).value ?? const PracticeStats(today: 0, streak: 0, week: {});
    final streak = (ref.watch(myStreakProvider).value?['current'] as num?)?.toInt() ?? stats.streak;
    final m = ref.watch(motivationProvider).value ?? const {};
    final line = (m['body'] as String?) ?? 'Small steps every day beat one big push the night before the exam.';
    final goal = PracticeStats.dailyGoal;
    final left = (goal - stats.today).clamp(0, goal);
    final days = c?.daysLeft ?? 0;
    const navy = Color(0xFF0B1F44);
    Animate a(Widget w, int i) =>
        w.animate().fadeIn(duration: rm ? 1.ms : 420.ms, delay: rm ? 0.ms : (120 * i).ms).slideY(begin: rm ? 0 : .12, end: 0, curve: Curves.easeOutCubic);

    return Scaffold(
      backgroundColor: navy,
      body: Stack(
        children: [
          // Soft glow and slow rings behind the number (still with reduce motion)
          const Positioned.fill(child: _Backdrop()),
          SafeArea(
            // Scrolls only on short screens; the spacers keep it centred on normal phones.
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s5),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(PhosphorIcons.x(), color: Colors.white70),
                            ),
                          ),
                          const Spacer(),
                          if (c != null) ...[
                            a(ExamLogo(c.code, px: 64), 0),
                            const Gap(Space.s4),
                            a(Text('YOUR ${c.label} IS COMING', style: context.ty.over.col(const Color(0xFFF2B233))), 1),
                            const Gap(Space.s2),
                            _CountUp(to: days, still: rm, size: box.maxHeight < 700 ? 72 : 96),
                            a(
                              Text(
                                days == 1
                                    ? 'day to go'
                                    : days == 0
                                    ? 'It is exam day. You are ready.'
                                    : 'days to go',
                                style: context.ty.h3.col(Colors.white),
                              ),
                              2,
                            ),
                            const Gap(Space.s1),
                            a(Text(c.dateText, style: context.ty.sm.col(Colors.white60)), 2),
                          ],
                          const Spacer(),
                          a(
                            Container(
                              padding: const EdgeInsets.all(Space.s4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .07),
                                borderRadius: BorderRadius.circular(Radii.lg),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  GoalRing(done: stats.today, goal: goal, size: 52),
                                  const Gap(Space.s3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Today’s goal', style: context.ty.cap.col(Colors.white60)),
                                        Text(left == 0 ? 'Done. Great work!' : '$left questions to go', style: context.ty.body.bold.col(Colors.white)),
                                      ],
                                    ),
                                  ),
                                  Container(width: 1, height: 36, color: Colors.white12),
                                  const Gap(Space.s3),
                                  Icon(PhosphorIcons.fire(PhosphorIconsStyle.fill), size: 22, color: Palette.gold500),
                                  const Gap(Space.s1),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('$streak', style: context.ty.h3.tnum.col(Colors.white)),
                                      Text(streak == 1 ? 'day' : 'days', style: context.ty.cap.col(Colors.white60)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            3,
                          ),
                          const Gap(Space.s4),
                          a(
                            Text(
                              '“$line”',
                              textAlign: TextAlign.center,
                              style: context.ty.body.col(Colors.white.withValues(alpha: .85)).copyWith(fontStyle: FontStyle.italic, height: 1.45),
                            ),
                            4,
                          ),
                          const Gap(Space.s5),
                          a(
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFF2B233),
                                  foregroundColor: navy,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  final code = c?.code ?? 'JAMB';
                                  GoRouter.of(context).push('/test/setup?exam=$code&mode=quick');
                                },
                                icon: Icon(PhosphorIcons.lightning(PhosphorIconsStyle.fill)),
                                label: Text('Start today’s practice', style: context.ty.body.bold.col(navy)),
                              ),
                            ),
                            5,
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Later', style: context.ty.sm.bold.col(Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The big number counting up to the days left.
class _CountUp extends StatelessWidget {
  const _CountUp({required this.to, required this.still, this.size = 96});
  final int to;
  final bool still;
  final double size;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: still ? to.toDouble() : 0, end: to.toDouble()),
    duration: still ? Duration.zero : Duration(milliseconds: (600 + math.min(to, 300) * 3).clamp(600, 1500)),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => Text(
      '${v.round()}',
      style: context.ty.h1.tnum.col(Colors.white).copyWith(fontSize: size, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -3),
    ),
  );
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();
  @override
  Widget build(BuildContext context) {
    final rings = Stack(
      alignment: Alignment.center,
      children: [
        for (final s in [260.0, 380.0, 500.0])
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: .05), width: 1.2),
            ),
          ),
      ],
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(center: Alignment(0, -.35), radius: .9, colors: [Color(0xFF1C3D7A), Color(0xFF0B1F44)]),
      ),
      child: Align(
        alignment: const Alignment(0, -.35),
        child: context.reduceMotion
            ? rings
            : rings.animate(onPlay: (ctl) => ctl.repeat(reverse: true)).scaleXY(begin: .96, end: 1.04, duration: 4.seconds, curve: Curves.easeInOut),
      ),
    );
  }
}

/// The small countdown chip on Home: "122 days to your UTME (15 March 2027)" (owner, 13 Nov 2026: small, like before;
/// the number counts up once and the hourglass turns over now and then). Tap: the full-screen countdown.
class CountdownChip extends ConsumerWidget {
  const CountdownChip({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cd = ref.watch(examCountdownProvider);
    if (cd == null) return const SizedBox.shrink();
    final c = context.c;
    final d = cd.daysLeft;
    final rm = context.reduceMotion;
    Text line(int n) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: d == 0 ? 'Your ${cd.label} is today' : '$n ${d == 1 ? 'day' : 'days'}', style: context.ty.label.bold.tnum),
          TextSpan(text: d == 0 ? ' (${cd.shortDate})' : ' to your ${cd.label} (${cd.shortDate})', style: context.ty.sm.col(c.textMuted)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return Semantics(
      button: true,
      label: d == 0 ? 'Your ${cd.label} is today. Open the countdown' : '$d days to your ${cd.label} (${cd.dateText}). Open the countdown',
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () => showExamCountdown(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(Space.s2, Space.s2, Space.s2, Space.s2),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              ExamLogo(cd.code, px: 32),
              const Gap(Space.s2),
              Expanded(
                child: rm || d <= 0
                    ? line(d)
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: math.max(0, d - 30).toDouble(), end: d.toDouble()),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => line(v.round()),
                      ),
              ),
              _Glass(icon: PhosphorIcons.hourglassMedium(PhosphorIconsStyle.fill), still: rm),
            ],
          ),
        ),
      ),
    );
  }
}

/// The hourglass turns over every few seconds.
class _Glass extends StatelessWidget {
  const _Glass({required this.icon, required this.still});
  final IconData icon;
  final bool still;
  @override
  Widget build(BuildContext context) {
    final i = SizedBox(width: 28, height: 28, child: Icon(icon, size: 18, color: Palette.gold500));
    if (still) return i;
    return i.animate(onPlay: (c) => c.repeat()).rotate(begin: 0, end: .5, duration: 700.ms, delay: 3.seconds, curve: Curves.easeInOutBack);
  }
}
