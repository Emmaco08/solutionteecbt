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
import '../compete/challenges_screens.dart' show Ticker;
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

/// The countdown card on Home (owner, 13 Nov 2026): "122 days to your UTME (15 March 2027)" as big flip-in day
/// tiles, a live hours · minutes · seconds clock, and a track of the study year. Tap: the full-screen countdown.
class CountdownChip extends ConsumerWidget {
  const CountdownChip({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cd = ref.watch(examCountdownProvider);
    if (cd == null) return const SizedBox.shrink();
    final d = cd.daysLeft;
    final rm = context.reduceMotion;
    // The study year: the last 365 days before the exam.
    final done = (1 - d / 365).clamp(0.02, 1.0);
    final note = d == 0
        ? 'Today is the day. You are ready!'
        : d <= 7
        ? 'Final week. Light revision, good sleep.'
        : d <= 30
        ? 'Under a month. Full mock exams now.'
        : d <= 90
        ? 'Every day counts. Keep going.'
        : 'Plenty of time if you start today.';
    return Semantics(
      button: true,
      label: d == 0 ? 'Your ${cd.label} is today' : '$d days to your ${cd.label} (${cd.dateText}). Open the countdown',
      child: GestureDetector(
        onTap: () => showExamCountdown(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.lg),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0B1F44), Color(0xFF173B7A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Stack(
              children: [
                // Rings on the right, like the full-screen countdown.
                Positioned(right: -46, top: -40, child: _Rings(size: 170, still: rm)),
                if (!rm)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0x00F2B233), Color(0x22F2B233), Color(0x00F2B233)],
                            stops: [.35, .5, .65],
                            begin: Alignment(-1, -.3),
                            end: Alignment(1, .3),
                          ),
                        ),
                      ).animate(onPlay: (c) => c.repeat()).slideX(begin: -1.2, end: 1.2, duration: 3200.ms, delay: 1500.ms, curve: Curves.easeInOut),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                            child: ExamLogo(cd.code, px: 30),
                          ),
                          const Gap(Space.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('COUNTDOWN', style: context.ty.over.col(Palette.gold300)),
                                const Gap(2),
                                Text(
                                  d == 0 ? 'Your ${cd.label} is today (${cd.dateText})' : '$d ${d == 1 ? 'day' : 'days'} to your ${cd.label} (${cd.dateText})',
                                  style: context.ty.sm.bold.col(Colors.white),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                          _Glass(icon: PhosphorIcons.hourglassMedium(PhosphorIconsStyle.fill), still: rm),
                        ],
                      ),
                      const Gap(Space.s4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final (i, ch) in '$d'.split('').indexed) ...[
                            if (i > 0) const Gap(5),
                            _DigitTile(ch, index: i, still: rm),
                          ],
                          const Gap(Space.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d == 1 ? 'DAY' : 'DAYS', style: context.ty.label.bold.col(Colors.white)),
                                const Gap(6),
                                // Live clock: what is left of today.
                                Ticker(
                                  builder: (context) {
                                    final now = DateTime.now();
                                    final left = DateTime(now.year, now.month, now.day + 1).difference(now);
                                    return Row(
                                      children: [
                                        _Mini('${left.inHours}'.padLeft(2, '0'), 'HRS'),
                                        _Colon(),
                                        _Mini('${left.inMinutes % 60}'.padLeft(2, '0'), 'MIN'),
                                        _Colon(),
                                        _Mini('${left.inSeconds % 60}'.padLeft(2, '0'), 'SEC'),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Gap(Space.s4),
                      // The study-year track.
                      LayoutBuilder(
                        builder: (context, box) {
                          final bar = Container(
                            height: 8,
                            width: box.maxWidth * done,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              gradient: const LinearGradient(colors: [Palette.gold400, Color(0xFFFFD877)]),
                            ),
                          );
                          return Stack(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
                              ),
                              rm ? bar : bar.animate().scaleX(begin: 0, end: 1, alignment: Alignment.centerLeft, duration: 900.ms, delay: 250.ms, curve: Curves.easeOutCubic),
                            ],
                          );
                        },
                      ),
                      const Gap(Space.s2),
                      Row(
                        children: [
                          Expanded(child: Text(note, style: context.ty.cap.col(const Color(0xFFC9D6EE)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Text('Open', style: context.ty.cap.bold.col(Colors.white)),
                          const Gap(2),
                          Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold), size: 12, color: Colors.white),
                        ],
                      ),
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

/// One day digit on a dark tile; the tiles flip in one after another.
class _DigitTile extends StatelessWidget {
  const _DigitTile(this.ch, {required this.index, required this.still});
  final String ch;
  final int index;
  final bool still;
  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: 46,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF07162F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(ch, style: context.ty.display.tnum.copyWith(fontSize: 38, height: 1).col(Palette.gold300)),
          // The flip-clock seam.
          Container(height: 1.2, color: Colors.black.withValues(alpha: .45)),
        ],
      ),
    );
    if (still) return tile;
    return tile
        .animate(delay: (120 * index + 150).ms)
        .fadeIn(duration: 250.ms)
        .flipV(begin: -.5, end: 0, duration: 450.ms, curve: Curves.easeOutBack)
        .then(delay: 4.seconds)
        .shimmer(duration: 1200.ms, color: const Color(0x55FFFFFF));
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.v, this.label);
  final String v, label;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 30,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(7)),
        child: Text(v, style: context.ty.label.bold.tnum.col(Palette.gold300)),
      ),
      const Gap(2),
      Text(label, style: context.ty.over.copyWith(fontSize: 9).col(const Color(0xFFAFC0DD))),
    ],
  );
}

class _Colon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(3, 0, 3, 14),
    child: Text(':', style: context.ty.label.bold.col(const Color(0xFFAFC0DD))),
  );
}

/// The hourglass turns over every few seconds.
class _Glass extends StatelessWidget {
  const _Glass({required this.icon, required this.still});
  final IconData icon;
  final bool still;
  @override
  Widget build(BuildContext context) {
    final i = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: Palette.gold400),
    );
    if (still) return i;
    return i.animate(onPlay: (c) => c.repeat()).rotate(begin: 0, end: .5, duration: 700.ms, delay: 3.seconds, curve: Curves.easeInOutBack);
  }
}

class _Rings extends StatelessWidget {
  const _Rings({required this.size, required this.still});
  final double size;
  final bool still;
  @override
  Widget build(BuildContext context) {
    final r = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final f in const [1.0, .72, .46])
            Container(
              width: size * f,
              height: size * f,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .07), width: 1.4)),
            ),
        ],
      ),
    );
    if (still) return r;
    return r.animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: .95, end: 1.05, duration: 4.seconds, curve: Curves.easeInOut);
  }
}
