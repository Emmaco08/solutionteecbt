import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent, RenderShiftedBox, BoxParentData;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/nav.dart';
import '../../core/providers.dart';
import '../../data/db.dart';
import '../../data/notifications_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../cbt/exam_clock.dart';
import '../news/news_screens.dart';
import '../shell/shell.dart';
import '../premium/paywall.dart';
import '../profile/me_extras.dart';
import '../compete/challenges_screens.dart';
import '../invite/invite_screens.dart';
import '../xp/streak_ui.dart';
import '../xp/xp_screens.dart';
import '../compete/compete_data.dart';
import 'qotd_card.dart';
import 'top_card.dart';
import 'tour.dart';

/// The unfinished test on this phone (if any), for the "Continue your test" card.
final unfinishedProvider = FutureProvider<LocalAttempt?>((ref) => ref.watch(dbProvider).unfinishedAttempt());

/// Answers saved so far in the unfinished test.
final unfinishedAnsweredProvider = FutureProvider.family<int, String>((ref, id) async {
  final rows = await ref.watch(dbProvider).answersFor(id);
  return rows.where((r) => r.choice != null).length;
});

/// Daily goal (questions answered today), the practice streak and this week's practice days, from tests on this phone.
class PracticeStats {
  const PracticeStats({required this.today, required this.streak, required this.week});
  final int today, streak;
  final Set<int> week; // 0 = Monday
  static const dailyGoal = 20;
}

final practiceStatsProvider = FutureProvider<PracticeStats>((ref) async {
  final list = await ref.watch(dbProvider).finishedAttempts();
  ref.watch(unfinishedProvider);
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final now = DateTime.now(), today = day(now);
  final days = <DateTime>{};
  var answeredToday = 0, notSyncedToday = 0;
  for (final a in list) {
    final d = day(a.submittedAt!.toLocal());
    days.add(d);
    if (d == today) {
      final s = a.clientScoreJson == null ? null : jsonDecode(a.clientScoreJson!) as Map<String, dynamic>;
      final n = (s?['answered'] as num?)?.toInt() ?? 0;
      answeredToday += n;
      if (!a.synced) notSyncedToday += n;
    }
  }
  // The server knows every test saved today from any phone (it survives logging out); add this phone's
  // tests that have not reached it yet. Offline with nothing from today: this phone's count only.
  final server = await serverPracticeToday(ref);
  if (server != null) answeredToday = server + notSyncedToday;
  var streak = 0;
  var cur = days.contains(today) ? today : today.subtract(const Duration(days: 1));
  while (days.contains(cur)) {
    streak++;
    cur = cur.subtract(const Duration(days: 1));
  }
  final monday = today.subtract(Duration(days: now.weekday - 1));
  final week = {
    for (final d in days)
      if (!d.isBefore(monday)) d.difference(monday).inDays,
  };
  return PracticeStats(today: answeredToday, streak: streak, week: week);
});
final practiceWeekProvider = FutureProvider<Set<int>>((ref) async => (await ref.watch(practiceStatsProvider.future)).week);
final practiceStreakProvider = FutureProvider<int>((ref) async => (await ref.watch(practiceStatsProvider.future)).streak);

/// Home (prototype: home).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.tour = false});
  final bool tour;
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _startKey = GlobalKey(), _upgradeKey = GlobalKey(), _topKey = GlobalKey(), _challengeKey = GlobalKey(), _chipsKey = GlobalKey();
  final _scroll = ScrollController();
  OverlayEntry? _tour;

  @override
  void initState() {
    super.initState();
    if (widget.tour) Future.delayed(const Duration(milliseconds: 450), _startTour);
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (widget.tour && !old.tour) Future.delayed(const Duration(milliseconds: 450), _startTour);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _tour?.remove();
    super.dispose();
  }

  /// Coach marks over the whole screen (bottom tabs included), on the root overlay.
  void _startTour() {
    if (!mounted || _tour != null) return;
    final premium = ref.read(myPlanProvider).value?['tier'] == 'premium';
    _tour = OverlayEntry(
      builder: (ctx) => TourOverlay(
        steps: [
          TourStep(
            key: _topKey,
            icon: PhosphorIcons.sunHorizon(PhosphorIconsStyle.fill),
            title: 'Your day starts here',
            text: 'A new motivation or study tip every day, your daily goal, and the test you left unfinished.',
          ),
          TourStep(
            key: _chipsKey,
            icon: PhosphorIcons.fire(PhosphorIconsStyle.fill),
            title: 'XP and streak',
            text: 'Earn XP for every test and keep your streak alive by practising each day. Tap to see more.',
          ),
          if (ref.read(challengesProvider).value?['on'] == true)
            TourStep(
              key: _challengeKey,
              icon: PhosphorIcons.trophy(PhosphorIconsStyle.fill),
              title: 'Challenges and events',
              text: 'Join live challenges, climb the leaderboard and win rewards.',
            ),
          TourStep(
            key: _startKey,
            icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
            title: 'Start a test here',
            text: 'Tap JAMB, WAEC or NECO to start a timed CBT practice.',
          ),
          TourStep(
            rect: () => _navRect(ctx, 'study'),
            icon: PhosphorIcons.bookOpenText(PhosphorIconsStyle.fill),
            title: 'Study anytime',
            text: 'Past questions, video solutions, lesson notes, novels and syllabuses.',
          ),
          TourStep(
            rect: () => _navRect(ctx, 'test'),
            icon: PhosphorIcons.exam(PhosphorIconsStyle.fill),
            title: 'All test modes',
            text: 'Full exam, single subject, topic drills, quick tests and practice by year.',
          ),
          TourStep(
            rect: () => _navRect(ctx, 'ai_chat'),
            icon: PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
            title: 'Ask SolutionTee AI',
            text: 'Get step-by-step help on any question.',
          ),
          if (!premium)
            TourStep(
              key: _upgradeKey,
              icon: PhosphorIcons.crownSimple(PhosphorIconsStyle.fill),
              title: 'Unlock everything',
              text: 'Go Premium for all years and all exams.',
            ),
        ],
        onDone: () {
          _tour?.remove();
          _tour = null;
          ref.read(settingsProvider.notifier).update((s) => s.copyWith(toured: true));
          if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
          if (mounted) toast(context, 'Tour finished. Replay it any time from Me, then Help.', icon: PhosphorIcons.flagCheckered(PhosphorIconsStyle.fill));
        },
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_tour!);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'Good morning'
        : h < 17
        ? 'Good afternoon'
        : 'Good evening';
  }

  Future<void> _refresh() async {
    ref.invalidate(examsProvider);
    ref.invalidate(myPlanProvider);
    ref.invalidate(newsProvider);
    ref.invalidate(openYearsProvider);
    ref.invalidate(unfinishedProvider);
    ref.invalidate(practiceStatsProvider);
    ref.invalidate(qotdProvider);
    ref.invalidate(challengesProvider);
    ref.invalidate(myXpProvider);
    ref.invalidate(myStreakProvider);
    await ref.read(examsProvider.future).catchError((_) => <Map<String, dynamic>>[]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final profile = ref.watch(profileProvider).value;
    final name = (profile?['full_name'] as String?) ?? '';
    final first = name.split(' ').first;
    final premium = ref.watch(myPlanProvider).value?['tier'] == 'premium';
    final exams = ref.watch(examsProvider);
    final unfinished = ref.watch(unfinishedProvider).value;
    final news = ref.watch(newsProvider).value ?? const [];
    final stats = ref.watch(practiceStatsProvider).value ?? const PracticeStats(today: 0, streak: 0, week: {});
    // The server's streak (tests, question of the day, challenges, freezes) when known; this phone's tests offline.
    final streakDays = (ref.watch(myStreakProvider).value?['current'] as num?)?.toInt() ?? stats.streak;
    final open = ref.watch(openYearsProvider).value;
    final rm = context.reduceMotion;

    final sections = <Widget>[
      HomeTopCard(key: _topKey, unfinished: unfinished, stats: stats),
      const DailyClaimCard(),
      if (ref.watch(challengesProvider).value?['on'] == true) ChallengeSection(key: _challengeKey),
      Column(
        key: _startKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectTitle('Start a CBT practice'),
          asyncView(
            exams,
            (list) => Column(
              children: [
                for (final e in list) ...[
                  ExamCard(
                    code: e['code'] as String,
                    name: e['name'] as String,
                    meta: examMeta(e),
                    locked: open != null && open.any((y) => y['exam_id'] == e['id']) && !open.any((y) => y['exam_id'] == e['id'] && y['cbt_open'] == true),
                  ),
                  const Gap(Space.s2),
                ],
              ],
            ),
            loading: Column(
              children: [
                for (var i = 0; i < 3; i++) ...[const Skeleton(height: 76, radius: Radii.lg), const Gap(Space.s2)],
              ],
            ),
            onRetry: _refresh,
          ),
        ],
      ),
      if (ref.watch(qotdProvider).isLoading || ref.watch(qotdProvider).value?.question != null) const QotdCard(),
      const InviteCard(),
      if (news.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectTitle('News', action: 'See all', onAction: () => context.push('/news')),
            SizedBox(
              height: 272,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: news.length.clamp(0, 4),
                separatorBuilder: (_, _) => const Gap(Space.s3),
                itemBuilder: (_, i) => SizedBox(
                  width: MediaQuery.sizeOf(context).width * .82 - Space.s5,
                  child: NewsTile(n: news[i]),
                ),
              ),
            ),
          ],
        ),
      if (!premium) UpgradeBanner(key: _upgradeKey),
    ];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            controller: _scroll,
            // Build the whole (short) Home so the tour can find and scroll to every card.
            scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
            padding: const EdgeInsets.only(bottom: Space.s8),
            children: [
              // Home head: avatar, greeting, name, streak
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s3),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Open my profile',
                      child: GestureDetector(onTap: () => context.go('/me'), child: MyAvatar(name)),
                    ),
                    const Gap(Space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_greeting()},', style: context.ty.cap.col(c.textMuted)),
                          Text(first.isEmpty ? 'Student' : first, style: context.ty.h3),
                        ],
                      ),
                    ),
                    Row(
                      key: _chipsKey,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const XpChip(),
                        Semantics(
                          button: true,
                          label: '$streakDays-day streak',
                          child: GestureDetector(
                            onTap: () => openRoute(context, '/me/streak'),
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(99)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(PhosphorIcons.fire(PhosphorIconsStyle.fill), size: 18, color: Palette.gold500),
                                  const SizedBox(width: 4),
                                  Text('$streakDays', style: context.ty.label.bold.tnum.col(c.onAccentSoft)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(Space.s2),
                    Consumer(
                      builder: (context, ref, _) {
                        final unread = ref.watch(unreadCountProvider);
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconBtn(
                              PhosphorIcons.bell(),
                              label: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
                              onPressed: () => context.push('/notifications'),
                            ),
                            if (unread > 0)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: IgnorePointer(
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 18),
                                    height: 18,
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    decoration: BoxDecoration(
                                      color: c.error,
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(color: c.bg, width: 2),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      unread > 9 ? '9+' : '$unread',
                                      style: context.ty.cap.bold.tnum.col(Colors.white).copyWith(fontSize: 10, height: 1),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sections that render nothing (daily XP already claimed, challenges off) take no space,
                    // so the gap between two visible cards is always one Space.s5.
                    for (var i = 0; i < sections.length; i++)
                      _SpaceAbove(
                        i > 0 ? Space.s5 : 0,
                        rm ? sections[i] : sections[i].animate(delay: Motion.stagger * i).fadeIn(duration: Motion.slow).slideY(begin: .06, curve: Motion.out),
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

  /// Where a tab sits in the bottom bar (same list and order the bar is built from); null if it is hidden.
  Rect? _navRect(BuildContext context, String type) {
    final types = visibleTabTypes(ref.read(tabsProvider).value);
    final i = types.indexOf(type);
    if (i < 0) return null;
    final size = MediaQuery.sizeOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final w = size.width / types.length;
    return Rect.fromLTWH(w * i + 6, size.height - bottom - Sizes.bottomNav + 6, w - 12, Sizes.bottomNav - 12);
  }
}

/// "4 subjects · 180 questions · 2 hrs" for JAMB, "Objective papers by subject" otherwise (from exam_configs).
String examMeta(Map<String, dynamic> e) {
  final cfg = (e['exam_configs'] as Map?) ?? const {};
  if (e['code'] == 'JAMB') {
    final mins = (cfg['total_minutes'] as num?)?.toInt() ?? 120;
    final q = (cfg['total_questions'] as num?)?.toInt() ?? 180;
    return '${cfg['subjects_per_candidate'] ?? 4} subjects · $q questions · ${mins % 60 == 0 ? '${mins ~/ 60} hrs' : '$mins mins'}';
  }
  return 'Objective papers by subject';
}

/// Progress ring (`.ring`): accent stroke on a sunken track.
class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, this.size = 64, this.stroke, this.label, this.color, this.track});
  final double value, size;
  final double? stroke;
  final Widget? label;
  final Color? color, track;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0, 1)),
            duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
            curve: Motion.out,
            builder: (_, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: stroke ?? size * 3.6 / 36,
              color: color ?? context.c.accent,
              backgroundColor: track ?? context.c.surfaceSunken,
              strokeCap: StrokeCap.round,
            ),
          ),
        ),
        ?label,
      ],
    ),
  );
}

/// "Continue your test" card (prototype `ST.unfinishedCard`).
class ContinueCard extends ConsumerWidget {
  const ContinueCard({super.key, required this.a});
  final LocalAttempt a;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = jsonDecode(a.configJson) as Map<String, dynamic>;
    final total = (jsonDecode(a.questionIdsJson) as List).length;
    final done = ref.watch(unfinishedAnsweredProvider(a.id)).value ?? 0;
    final left = a.limitSeconds == 0 ? null : Duration(seconds: a.limitSeconds) - Duration(milliseconds: a.usedMs);
    final title = (cfg['title'] as String?)?.isNotEmpty == true ? cfg['title'] as String : a.examCode;
    return AppCard(
      onTap: () => context.push('/cbt/${a.id}'),
      child: Row(
        children: [
          IconTile(PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.fill), tone: Tone.blue, size: 44, radius: 12, iconSize: 22),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Continue your test', style: context.ty.sm.bold),
                Text(
                  '$title · $done of $total answered${left == null ? '' : ' · ${ExamClock.format(left)} left'}',
                  style: context.ty.cap.col(context.c.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(Space.s2),
                ProgressBar(total == 0 ? 0 : done / total),
              ],
            ),
          ),
          const Gap(Space.s2),
          Icon(PhosphorIcons.caretRight(), size: 20, color: context.c.text),
        ],
      ),
    );
  }
}

/// Exam card (`.exam-card`): logo, title, meta, navy play circle (or a Premium badge when locked).
class ExamCard extends StatelessWidget {
  const ExamCard({super.key, required this.code, required this.name, required this.meta, this.locked = false});
  final String code, name, meta;
  final bool locked;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
      onTap: locked ? () => showPaywall(context, reason: code) : () => context.push('/test/setup?exam=$code'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76 - 24),
        child: Row(
          children: [
            ExamLogo(code),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: context.ty.body.bold),
                  Text(meta, style: context.ty.cap.col(c.textMuted)),
                ],
              ),
            ),
            locked
                ? Pill('Premium', kind: BadgeKind.neutral, icon: PhosphorIcons.lockSimple(PhosphorIconsStyle.fill))
                : Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                    child: Icon(PhosphorIcons.play(PhosphorIconsStyle.fill), size: 18, color: c.onPrimary),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Navy upgrade banner with a gold crown tile (`.upgrade-banner`). Free plan only.
class UpgradeBanner extends StatelessWidget {
  const UpgradeBanner({super.key, this.title = 'Get every year and every lesson', this.text = 'Videos, notes, novels, offline downloads and more AI help.'});
  final String title, text;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(Radii.lg),
    child: Container(
      color: Palette.navy900,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color.fromRGBO(242, 178, 51, .35), Color.fromRGBO(242, 178, 51, 0)], stops: [0, .7]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.s4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: Palette.gold400, borderRadius: BorderRadius.circular(12)),
                  child: Icon(PhosphorIcons.crownSimple(PhosphorIconsStyle.fill), size: 24, color: Palette.navy900),
                ),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.ty.body.bold.col(const Color(0xFFF4F7FC))),
                      Text(text, style: context.ty.sm.col(const Color(0xFFAFC0DD))),
                    ],
                  ),
                ),
                const Gap(Space.s2),
                Btn('Upgrade', kind: BtnKind.accent, sm: true, onPressed: () => showPaywall(context)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Adds [top] of space above [child] only when the child has a height (a widget that builds nothing adds no gap).
class _SpaceAbove extends SingleChildRenderObjectWidget {
  const _SpaceAbove(this.top, Widget child) : super(child: child);
  final double top;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSpaceAbove(top);
  @override
  void updateRenderObject(BuildContext context, _RenderSpaceAbove r) => r.top = top;
}

class _RenderSpaceAbove extends RenderShiftedBox {
  _RenderSpaceAbove(this._top) : super(null);
  double _top;
  set top(double v) {
    if (v == _top) return;
    _top = v;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicHeight(double width) => _h(child?.getMinIntrinsicHeight(width) ?? 0);
  @override
  double computeMaxIntrinsicHeight(double width) => _h(child?.getMaxIntrinsicHeight(width) ?? 0);
  double _h(double h) => h <= 0 ? 0 : h + _top;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final c = child;
    if (c == null) return constraints.smallest;
    final s = c.getDryLayout(constraints);
    return constraints.constrain(Size(s.width, _h(s.height)));
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(constraints, parentUsesSize: true);
    final gap = c.size.height <= 0 ? 0.0 : _top;
    (c.parentData! as BoxParentData).offset = Offset(0, gap);
    size = constraints.constrain(Size(c.size.width, c.size.height + gap));
  }
}
