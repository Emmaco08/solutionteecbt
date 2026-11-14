import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads.dart';
import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/r2_image.dart';
import '../../widgets/states.dart';
import '../profile/me_extras.dart' show MyAvatar;

/// Leaderboard for a JAMB season (server `leaderboard`, milestone 4E1, D-026/D-066): best full mock per student,
/// first name + initial only. The server decides everything, including whether it is on.
typedef LbKey = ({String exam, int? season, String scope, int? subject, String period, int offset});

/// The Challenges board is a board like the exams, with points from challenges (D-143).
const challengesBoard = 'CHALLENGES';

final leaderboardProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, LbKey>((ref, k) async {
  final sb = ref.read(supabaseProvider);
  final j = k.exam == challengesBoard
      ? await sb
            .rpc('leaderboard_challenges', params: {'p_period': k.period == 'season' ? 'year' : k.period, 'p_offset': k.offset})
            .timeout(const Duration(seconds: 20))
      : await sb
            .rpc(
              'leaderboard_for',
              params: {'p_exam': k.exam, 'p_season': k.season, 'p_scope': k.scope, 'p_subject': k.subject, 'p_period': k.period, 'p_offset': k.offset},
            )
            .timeout(const Duration(seconds: 20));
  return Map<String, dynamic>.from(j as Map);
});

/// The last closed week's and month's top 10 of each board, with their rewards.
final leaderboardWinnersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    return rows(await ref.read(supabaseProvider).rpc('leaderboard_winners').timeout(const Duration(seconds: 15)));
  } catch (_) {
    return const [];
  }
});

const _periods = [('week', 'Week'), ('month', 'Month'), ('year', 'Year'), ('all', 'All time'), ('season', 'Season')];

/// Whether to show the Leaderboard entry on the Test tab (cached, so it also shows offline).
final leaderboardOnProvider = FutureProvider<bool>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return false;
  return cached(ref, 'lb_on:$uid', (s) => s.rpc('leaderboard'), (j) => j is Map && j['on'] == true).catchError((_) => false);
});

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _exam = 'JAMB';
  int? _season;
  String _scope = 'ng';
  int? _subject;
  String _period = 'week';
  int _offset = 0;

  /// The exam boards the server allows (remembered while the Challenges board is open).
  List<String> _exams = const ['JAMB'];

  LbKey get _key => (exam: _exam, season: _season, scope: _scope, subject: _subject, period: _period, offset: _offset);

  void _rules(int minMocks, bool jamb) => showSheet<void>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('How the leaderboard works', style: ctx.ty.h3),
        const Gap(Space.s4),
        for (final (ic, t) in [
          (
            PhosphorIcons.exam(PhosphorIconsStyle.fill),
            jamb
                ? 'JAMB: your best score in a full mock (Test → Start full exam, out of 400) counts.'
                : 'WAEC and NECO: each subject has its own board. Your best paper in that subject (out of 100) counts.',
          ),
          (
            PhosphorIcons.listChecks(PhosphorIconsStyle.fill),
            'You need at least $minMocks ${jamb ? 'full ${minMocks == 1 ? 'mock' : 'mocks'}' : '${minMocks == 1 ? 'paper' : 'papers'} in the subject'} this season to appear. Quick tests do not count.',
          ),
          (PhosphorIcons.timer(PhosphorIconsStyle.fill), 'If two students tie, the faster time ranks higher.'),
          (PhosphorIcons.eyeSlash(PhosphorIconsStyle.fill), 'Only your first name and an initial are shown. Turn it off in Settings any time.'),
          (PhosphorIcons.calendar(PhosphorIconsStyle.fill), 'Each exam year has its own board. Past years show the best student.'),
        ]) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ic, color: ctx.c.secondary, size: 20),
              const Gap(Space.s3),
              Expanded(child: Text(t, style: ctx.ty.sm)),
            ],
          ),
          const Gap(Space.s3),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final key = _key;
    final v = ref.watch(leaderboardProvider(key));
    final d = v.value;
    final on = d?['on'] == true;
    return Scaffold(
      appBar: TopBar(
        title: 'Leaderboard',
        subtitle: on ? '${d!['label'] ?? ''}' : null,
        actions: [
          if (on && _exam != challengesBoard)
            IconBtn(PhosphorIcons.info(), label: 'How ranking works', onPressed: () => _rules((d!['min_mocks'] as num?)?.toInt() ?? 1, d['exam'] == 'JAMB')),
        ],
      ),
      body: asyncView(
        v,
        (d) => d['on'] != true ? _off(context) : _board(context, d),
        loading: ListView(
          padding: const EdgeInsets.all(Space.s5),
          children: [
            const Skeleton(height: 40),
            const Gap(Space.s4),
            const Skeleton(height: 180, radius: Radii.lg),
            const Gap(Space.s4),
            for (var i = 0; i < 5; i++) ...[const Skeleton(height: 56), const Gap(Space.s2)],
          ],
        ),
        onRetry: () => ref.invalidate(leaderboardProvider(key)),
      ),
      bottomNavigationBar: d != null && on && d['current'] == true ? _MeBar(d: d) : null,
    );
  }

  Widget _off(BuildContext context) => Center(
    child: StateBlock(
      icon: PhosphorIcons.ranking(PhosphorIconsStyle.fill),
      title: 'Leaderboards are switched off',
      text: 'SolutionTee has turned leaderboards off for now. Keep practising: your scores still count.',
      action: Btn('Back to Test', onPressed: () => context.go('/test')),
    ),
  );

  Widget _board(BuildContext context, Map<String, dynamic> d) {
    final c = context.c;
    final chBoard = _exam == challengesBoard;
    if (!chBoard && d['exams'] is List) _exams = [for (final x in d['exams'] as List) '$x'];
    final seasons = [for (final s in (d['seasons'] as List? ?? const [])) (s as num).toInt()];
    final season = (d['season'] as num?)?.toInt() ?? 0;
    final current = d['current'] == true;
    final top = rows(d['top']);
    final best = d['best'] is Map ? Map<String, dynamic>.from(d['best'] as Map) : null;
    final state = d['my_state'] as String?;
    final rm = context.reduceMotion;
    final exam = chBoard ? challengesBoard : '${d['exam'] ?? 'JAMB'}';
    final exams = [..._exams, challengesBoard];
    final label = '${d['label'] ?? ''}';
    final winners = ref.watch(leaderboardWinnersProvider).value ?? const <Map<String, dynamic>>[];
    final lastWin = winners.where((w) => w['board'] == (chBoard ? 'challenges' : 'jamb') && w['period'] == (_period == 'month' ? 'month' : 'week')).firstOrNull;
    final subjects = rows(d['subjects']);
    final subjectId = (d['subject'] as num?)?.toInt();
    final subjectName = subjects.where((x) => x['id'] == subjectId).firstOrNull?['name'];
    final title = chBoard
        ? 'Challenges · $label'
        : exam == 'JAMB'
        ? 'JAMB UTME · $label'
        : '$exam ${subjectName ?? ''} · $label'.replaceAll('  ', ' ');

    final sections = <Widget>[
      if (exams.length > 1)
        Row(
          children: [
            for (final x in exams) ...[
              Expanded(
                child: Semantics(
                  selected: x == exam,
                  button: true,
                  label: '$x leaderboard',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.md),
                    onTap: () => setState(() {
                      _exam = x;
                      _subject = null;
                      if (x == challengesBoard && _period == 'season') _period = 'week';
                    }),
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      constraints: const BoxConstraints(minHeight: 72),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: Space.s2),
                      decoration: BoxDecoration(
                        color: x == exam ? c.secondarySoft : c.surface,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: x == exam ? c.secondary : c.border, width: x == exam ? 2 : 1),
                      ),
                      // Logo above the name so the whole name always shows (owner, 14 Nov 2026: no "J…", "Ch…").
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (x == challengesBoard)
                            SizedBox(
                              height: 32,
                              child: Center(child: Icon(PhosphorIcons.trophy(PhosphorIconsStyle.fill), size: 24, color: c.accent)),
                            )
                          else
                            ExamLogo(x, size: LogoSize.sm),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(x == challengesBoard ? 'Challenges' : x, style: context.ty.sm.bold, maxLines: 1, softWrap: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (x != exams.last) const Gap(Space.s2),
            ],
          ],
        ),
      // Week · Month · Year · All time · Season (D-143); this or the last week/month.
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final (p, l) in _periods)
              if (!(chBoard && p == 'season')) ...[
                AppChip(
                  l,
                  on: _period == p,
                  onTap: () => setState(() {
                    _period = p;
                    _offset = 0;
                  }),
                ),
                const Gap(Space.s2),
              ],
          ],
        ),
      ),
      if (_period == 'week' || _period == 'month')
        Seg<int>(
          value: _offset,
          items: [(0, _period == 'week' ? 'This week' : 'This month'), (1, _period == 'week' ? 'Last week' : 'Last month')],
          onChanged: (o) => setState(() => _offset = o),
        ),
      if (exam != 'JAMB' && !chBoard && subjects.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final sj in subjects) ...[
                AppChip('${sj['name']}', on: sj['id'] == subjectId, onTap: () => setState(() => _subject = (sj['id'] as num).toInt())),
                const Gap(Space.s2),
              ],
            ],
          ),
        ),
      Row(
        children: [
          if (chBoard) IconTile(PhosphorIcons.trophy(PhosphorIconsStyle.fill), tone: Tone.gold, size: 44) else ExamLogo(exam, size: LogoSize.md),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.ty.h3),
                Text(
                  chBoard
                      ? 'Points from every challenge you finish'
                      : current
                      ? 'Now · ${d['scope'] == 'state' ? state : 'Nigeria'}'
                      : 'Closed board',
                  style: context.ty.cap.col(c.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      if (!chBoard && _period == 'season' && seasons.length > 1)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in seasons) ...[
                AppChip('$exam $s${s == seasons.first ? ' (now)' : ''}', on: s == season, onTap: () => setState(() => _season = s)),
                const Gap(Space.s2),
              ],
            ],
          ),
        ),
      if (!chBoard && current && (state ?? '').isNotEmpty)
        Seg<String>(value: d['scope'] as String, items: [('ng', 'Nigeria'), ('state', 'My state ($state)')], onChanged: (s) => setState(() => _scope = s)),
      if (best != null)
        Container(
          padding: const EdgeInsets.all(Space.s4),
          decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(Radii.lg)),
          child: Row(
            children: [
              IconTile(PhosphorIcons.crownSimple(PhosphorIconsStyle.fill), tone: Tone.gold, size: 44, radius: 22),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Best student of $title', style: context.ty.cap.bold.col(c.onAccentSoft)),
                    Text('${best['name']}', style: context.ty.h3),
                    Text([best['school'], best['state']].where((x) => (x ?? '').toString().isNotEmpty).join(' · '), style: context.ty.cap.col(c.textMuted)),
                  ],
                ),
              ),
              Text('${best['score']}', style: context.ty.h2.tnum),
            ],
          ),
        ),
      if (lastWin != null) _WinnersCard(g: lastWin),
      if (top.isEmpty)
        StateBlock(
          icon: PhosphorIcons.ranking(PhosphorIconsStyle.fill),
          tone: Tone.gold,
          title: 'No one here yet',
          text: chBoard
              ? 'Finish a challenge to get points on this board.'
              : current
              ? (exam == 'JAMB'
                    ? 'Finish a full JAMB mock to be the first on this board.'
                    : 'Finish a $exam ${subjectName ?? ''} paper to be the first on this board.')
              : 'No tests counted for this year.',
          action: chBoard
              ? Btn('See challenges', kind: BtnKind.accent, onPressed: () => context.push('/test/challenges'))
              : current
              ? Btn(
                  exam == 'JAMB' ? 'Start a full mock' : 'Practise $exam',
                  kind: BtnKind.accent,
                  onPressed: () => context.push(exam == 'JAMB' ? '/test/setup?exam=JAMB&mode=full' : '/test/setup?exam=$exam'),
                )
              : null,
        )
      else ...[
        _Podium(top: top.take(3).toList()),
        if (top.length > 3)
          ListCard(
            children: [
              for (final p in top.skip(3))
                Container(
                  color: p['me'] == true ? c.secondarySoft : null,
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s2),
                  child: Row(
                    children: [
                      SizedBox(width: 32, child: Text('${p['rank']}', style: context.ty.sm.bold.tnum.col(c.textMuted))),
                      Avatar('${p['name']}', size: 36, photo: _photo(p, 36)),
                      const Gap(Space.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['me'] == true ? '${p['name']} (you)' : '${p['name']}', style: context.ty.sm.bold),
                            if ((p['state'] ?? '').toString().isNotEmpty) Text('${p['state']}', style: context.ty.cap.col(c.textMuted)),
                          ],
                        ),
                      ),
                      Text('${p['score']}', style: context.ty.body.bold.tnum),
                    ],
                  ),
                ),
            ],
          ),
      ],
      Text(
        'Only first names and an initial are shown. You can hide yourself in Me, then Settings.',
        style: context.ty.cap.col(c.textSubtle),
        textAlign: TextAlign.center,
      ),
    ];
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leaderboardProvider(_key));
        ref.invalidate(leaderboardWinnersProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
        children: [
          const AdBanner(screen: 'leaderboard'),
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const Gap(Space.s4),
            rm ? sections[i] : sections[i].animate(delay: Motion.stagger * i).fadeIn(duration: Motion.base).slideY(begin: .05, curve: Motion.out),
          ],
        ],
      ),
    );
  }
}

/// The last closed week's or month's top 3 of this board, with what they won.
class _WinnersCard extends StatelessWidget {
  const _WinnersCard({required this.g});
  final Map<String, dynamic> g;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = rows(g['winners']);
    return Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.crownSimple(PhosphorIconsStyle.fill), size: 18, color: c.onAccentSoft),
              const Gap(Space.s2),
              Expanded(child: Text('Winners · ${g['label']}', style: context.ty.sm.bold.col(c.onAccentSoft))),
            ],
          ),
          const Gap(Space.s2),
          for (final p in w.take(3))
            Padding(
              padding: const EdgeInsets.only(top: Space.s1),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Text('#${p['rank']}', style: context.ty.sm.bold.tnum)),
                  Expanded(child: Text(p['me'] == true ? '${p['name']} (you)' : '${p['name']}', style: context.ty.sm)),
                  Text(
                    [if (((p['xp'] as num?) ?? 0) > 0) '+${p['xp']} XP', if (((p['days'] as num?) ?? 0) > 0) '${p['days']} days Premium'].join(' · '),
                    style: context.ty.cap.bold.col(c.onAccentSoft),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A student's profile photo, when they allow it on leaderboards (D-069); otherwise the avatar shows initials.
Widget? _photo(Map<String, dynamic> p, double size) {
  final key = p['photo'] as String?;
  if (key == null || key.isEmpty) return null;
  return R2Image.face(imageKey: key, decodeWidth: (size * 3).round(), semanticLabel: 'Photo of ${p['name']}');
}

/// Top 3 (`.podium`): 2nd, 1st, 3rd, with gold, silver and bronze rings.
class _Podium extends StatelessWidget {
  const _Podium({required this.top});
  final List<Map<String, dynamic>> top;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const ring = {1: Palette.gold500, 2: Color(0xFFA7B1C2), 3: Color(0xFFC6865A)};
    Widget pod(Map<String, dynamic>? p, int place, double bar) => Expanded(
      child: p == null
          ? const SizedBox.shrink()
          : Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ring[place]!, width: 3),
                      ),
                      child: Avatar('${p['name']}', size: place == 1 ? 60 : 48, photo: _photo(p, place == 1 ? 60 : 48)),
                    ),
                    Positioned(
                      bottom: -8,
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ring[place],
                          shape: BoxShape.circle,
                          border: Border.all(color: c.bg, width: 2),
                        ),
                        child: Text('$place', style: context.ty.cap.bold.col(place == 1 ? Palette.navy900 : Colors.white).copyWith(fontSize: 11, height: 1)),
                      ),
                    ),
                  ],
                ),
                const Gap(Space.s3),
                Text(
                  p['me'] == true ? '${p['name']} (you)' : '${p['name']}',
                  style: context.ty.sm.bold,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('${p['state'] ?? ''}', style: context.ty.cap.col(c.textMuted), maxLines: 1),
                const Gap(Space.s2),
                Container(
                  height: bar,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: Space.s2),
                  decoration: BoxDecoration(
                    color: place == 1 ? c.accentSoft : c.surfaceAlt,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Text('${p['score']}', style: context.ty.body.bold.tnum),
                ),
              ],
            ),
    );
    Map<String, dynamic>? at(int i) => i < top.length ? top[i] : null;
    return Semantics(
      label: 'Top 3',
      child: SizedBox(
        height: 252,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [pod(at(1), 2, 70), pod(at(0), 1, 96), pod(at(2), 3, 54)]),
      ),
    );
  }
}

/// The student's own rank, pinned at the bottom (`.lb-me`).
class _MeBar extends ConsumerWidget {
  const _MeBar({required this.d});
  final Map<String, dynamic> d;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final me = Map<String, dynamic>.from(d['me'] as Map? ?? const {});
    final rank = (me['rank'] as num?)?.toInt();
    final name = (ref.watch(profileProvider).value?['full_name'] as String?) ?? '';
    final ahead = (me['ahead'] as num?)?.toInt();
    final String line;
    if (rank != null) {
      line = rank == 1
          ? 'You are first. Keep it up!'
          : ahead == null || ahead == 0
          ? 'Tied on points: be faster to move up'
          : '$ahead points to reach #${rank - 1}';
    } else if (me['hidden'] == true) {
      line = 'You are hidden. Turn it on in Settings to appear.';
    } else {
      final needs = (me['needs'] as num?)?.toInt() ?? 0;
      final jamb = d['exam'] == null || d['exam'] == 'JAMB';
      line = d['board'] == 'challenges'
          ? 'Finish a challenge to get points'
          : needs > 0
          ? (jamb
                ? 'Finish $needs more full JAMB ${needs == 1 ? 'mock' : 'mocks'} to appear'
                : 'Finish $needs more ${needs == 1 ? 'paper' : 'papers'} in this subject to appear')
          : 'Not on this board yet';
    }
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s3, Space.s5, Space.s3),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
          boxShadow: context.shadow(2),
        ),
        child: Row(
          children: [
            SizedBox(width: 48, child: Text(rank == null ? '–' : '#$rank', style: context.ty.body.bold.tnum)),
            MyAvatar(name, size: 36),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('You', style: context.ty.sm.bold),
                  Text(line, style: context.ty.cap.col(c.textMuted)),
                ],
              ),
            ),
            if (me['score'] != null) Text('${me['score']}', style: context.ty.body.bold.tnum),
          ],
        ),
      ),
    );
  }
}

/// Test tab card (shown only when the leaderboard is on).
class LeaderboardEntry extends ConsumerWidget {
  const LeaderboardEntry({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(leaderboardOnProvider).value != true) return const SizedBox.shrink();
    final c = context.c;
    return AppCard(
      onTap: () => context.push('/leaderboard'),
      child: Row(
        children: [
          IconTile(PhosphorIcons.ranking(PhosphorIconsStyle.fill), tone: Tone.gold, size: 44, radius: 12, iconSize: 22),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leaderboard', style: context.ty.body.bold),
                Text('See the best JAMB, WAEC and NECO students', style: context.ty.cap.col(c.textMuted)),
              ],
            ),
          ),
          const ExamLogo('JAMB', size: LogoSize.sm),
          const Gap(Space.s2),
          Icon(PhosphorIcons.caretRight(), size: 18, color: c.textSubtle),
        ],
      ),
    );
  }
}
