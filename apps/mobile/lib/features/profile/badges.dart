import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/confetti.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../xp/streak_ui.dart';

// Badges v2 (B8, D-142): the admin's badges with bronze, silver, gold and diamond levels. The server counts and
// rewards everything (badges_check); the app shows the levels and celebrates new ones once.

const tierNames = ['', 'Bronze', 'Silver', 'Gold', 'Diamond'];
const _tierKeys = ['', 'bronze', 'silver', 'gold', 'diamond'];
const tierColors = [Color(0xFF9AA6B2), Color(0xFFCD7F32), Color(0xFF9AA6B2), Color(0xFFF2B233), Color(0xFF38BDF8)];

IconData badgeIcon(String name, [PhosphorIconsStyle s = PhosphorIconsStyle.fill]) => switch (name) {
  'fire' => PhosphorIcons.fire(s),
  'exam' => PhosphorIcons.exam(s),
  'target' => PhosphorIcons.target(s),
  'checkFat' => PhosphorIcons.checkFat(s),
  'trophy' => PhosphorIcons.trophy(s),
  'timer' => PhosphorIcons.timer(s),
  'sealCheck' => PhosphorIcons.sealCheck(s),
  'chartLineUp' => PhosphorIcons.chartLineUp(s),
  'lightning' => PhosphorIcons.lightning(s),
  'calendarCheck' => PhosphorIcons.calendarCheck(s),
  'clock' => PhosphorIcons.clock(s),
  'moonStars' => PhosphorIcons.moonStars(s),
  'sunHorizon' => PhosphorIcons.sunHorizon(s),
  'calendarStar' => PhosphorIcons.calendarStar(s),
  'listChecks' => PhosphorIcons.listChecks(s),
  'bookOpenText' => PhosphorIcons.bookOpenText(s),
  'hourglass' => PhosphorIcons.hourglass(s),
  'gearSix' => PhosphorIcons.gearSix(s),
  'books' => PhosphorIcons.books(s),
  'playCircle' => PhosphorIcons.playCircle(s),
  'notePencil' => PhosphorIcons.notePencil(s),
  'bookOpen' => PhosphorIcons.bookOpen(s),
  'sparkle' => PhosphorIcons.sparkle(s),
  'flagCheckered' => PhosphorIcons.flagCheckered(s),
  'users' => PhosphorIcons.users(s),
  'lightbulb' => PhosphorIcons.lightbulb(s),
  'coins' => PhosphorIcons.coins(s),
  'chatCircleText' => PhosphorIcons.chatCircleText(s),
  'heart' => PhosphorIcons.heart(s),
  'star' => PhosphorIcons.star(s),
  'crownSimple' => PhosphorIcons.crownSimple(s),
  'rocket' => PhosphorIcons.rocket(s),
  'graduationCap' => PhosphorIcons.graduationCap(s),
  _ => PhosphorIcons.medal(s),
};

/// Badges with my level and progress, cached for offline. Each load also records and rewards new levels.
final badgesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const {};
  return cached(ref, 'badges2:$uid', (s) => s.rpc('badges_check'), (j) => Map<String, dynamic>.from((j as Map?) ?? const {}));
});

List<Map<String, dynamic>> badgeList(Map<String, dynamic>? d) => [for (final b in (d?['badges'] as List? ?? const [])) Map<String, dynamic>.from(b as Map)];

/// 0..1 towards the next level (1 at diamond).
double badgeProgress(Map<String, dynamic> b) {
  final tier = (b['tier'] as num?)?.toInt() ?? 0;
  if (tier >= 4) return 1;
  final t = Map<String, dynamic>.from((b['targets'] as Map?) ?? const {});
  final from = tier == 0 ? 0 : (t[_tierKeys[tier]] as num?)?.toDouble() ?? 0;
  final to = (t[_tierKeys[tier + 1]] as num?)?.toDouble() ?? 1;
  final v = (b['value'] as num?)?.toDouble() ?? 0;
  return to <= from ? 0 : ((v - from) / (to - from)).clamp(0, 1).toDouble();
}

String _num(num v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k' : '${v.round()}';

/// Checks for new levels and celebrates each one once (after a test, and when the app opens).
Future<void> checkBadgeWins(BuildContext context, WidgetRef ref) async {
  try {
    ref.invalidate(badgesProvider);
    final d = await ref.read(badgesProvider.future).timeout(const Duration(seconds: 12));
    final won = [for (final w in (d['won'] as List? ?? const [])) Map<String, dynamic>.from(w as Map)];
    if (won.isEmpty || !context.mounted) return;
    // Show the highest new level of each badge (several levels at once are one moment).
    final best = <Object?, Map<String, dynamic>>{};
    for (final w in won) {
      final cur = best[w['badge_id']];
      if (cur == null || ((w['tier'] as num?) ?? 0) > ((cur['tier'] as num?) ?? 0)) best[w['badge_id']] = w;
    }
    for (final w in best.values.take(3)) {
      if (!context.mounted) return;
      final more = won.where((x) => x['badge_id'] == w['badge_id']).fold<({int xp, int days})>((
        xp: 0,
        days: 0,
      ), (a, x) => (xp: a.xp + ((x['xp'] as num?)?.toInt() ?? 0), days: a.days + ((x['days'] as num?)?.toInt() ?? 0)));
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierColor: Colors.black.withValues(alpha: .75),
        builder: (_) => BadgeWonDialog(win: w, xp: more.xp, days: more.days),
      );
    }
    await Supabase.instance.client.rpc('badges_seen', params: {'p_badges': best.keys.toList()});
    ref.invalidate(myStreakProvider);
  } catch (_) {}
}

/// Full-screen "Badge won" moment: the medal pops in with the level colour, confetti, the reward.
class BadgeWonDialog extends StatelessWidget {
  const BadgeWonDialog({super.key, required this.win, this.xp = 0, this.days = 0});
  final Map<String, dynamic> win;
  final int xp, days;
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    final tier = ((win['tier'] as num?)?.toInt() ?? 1).clamp(1, 4);
    final color = tierColors[tier];
    HapticFeedback.mediumImpact();
    Widget medal = Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [Color.lerp(color, Colors.white, .35)!, color]),
        boxShadow: [BoxShadow(color: color.withValues(alpha: .55), blurRadius: 36, spreadRadius: 4)],
        border: Border.all(color: Colors.white.withValues(alpha: .8), width: 4),
      ),
      child: Icon(badgeIcon('${win['icon']}'), size: 60, color: Colors.white),
    );
    if (!rm) {
      medal = medal
          .animate()
          .scale(begin: const Offset(.2, .2), duration: 520.ms, curve: Curves.elasticOut)
          .rotate(begin: -.08, end: 0, duration: 520.ms)
          .then()
          .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: .6));
    }
    final reward = [if (xp > 0) '+$xp XP', if (days > 0) '+$days days of Premium'].join('  ·  ');
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          if (!rm) const Positioned.fill(child: IgnorePointer(child: Confetti(pieces: 70))),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.s6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('BADGE WON', style: context.ty.over.col(Colors.white.withValues(alpha: .8))),
                  const Gap(Space.s5),
                  medal,
                  const Gap(Space.s5),
                  Text('${win['name']}', textAlign: TextAlign.center, style: context.ty.h1.col(Colors.white)),
                  const Gap(Space.s2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: 6),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                    child: Text('${tierNames[tier]} level', style: context.ty.sm.bold.col(tier == 3 ? Palette.navy900 : Colors.white)),
                  ),
                  const Gap(Space.s3),
                  Text('${win['description'] ?? ''}', textAlign: TextAlign.center, style: context.ty.body.col(Colors.white.withValues(alpha: .85))),
                  if (reward.isNotEmpty) ...[const Gap(Space.s4), Text(reward, style: context.ty.h3.col(const Color(0xFFF2B233)))],
                  const Gap(Space.s6),
                  SizedBox(
                    width: 240,
                    child: Btn('Nice!', kind: BtnKind.accent, block: true, onPressed: () => Navigator.of(context).pop()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One badge: medal in the level colour with a progress ring to the next level.
class BadgeTile extends StatelessWidget {
  const BadgeTile({super.key, required this.b, this.size = 56});
  final Map<String, dynamic> b;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tier = (b['tier'] as num?)?.toInt() ?? 0;
    final color = tier == 0 ? c.textSubtle : tierColors[tier];
    return Semantics(
      button: true,
      label: '${b['name']}, ${tier == 0 ? 'not won yet' : '${tierNames[tier]} level'}',
      child: Pressable(
        onTap: () => showBadgeSheet(context, b),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: size + 8,
              height: size + 8,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: size + 8,
                    height: size + 8,
                    child: CircularProgressIndicator(
                      value: tier >= 4 ? 1 : badgeProgress(b),
                      strokeWidth: 3,
                      color: tier >= 4 ? color : c.secondary,
                      backgroundColor: c.surfaceSunken,
                    ),
                  ),
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: tier == 0 ? c.surfaceSunken : color),
                    child: Icon(badgeIcon('${b['icon']}'), size: size * .46, color: tier == 0 ? c.textSubtle : Colors.white),
                  ),
                ],
              ),
            ),
            const Gap(Space.s1),
            Text('${b['name']}', style: context.ty.cap.bold, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

Future<void> showBadgeSheet(BuildContext context, Map<String, dynamic> b) => showSheet<void>(
  context,
  builder: (context) {
    final c = context.c;
    final tier = (b['tier'] as num?)?.toInt() ?? 0;
    final t = Map<String, dynamic>.from((b['targets'] as Map?) ?? const {});
    final r = Map<String, dynamic>.from((b['rewards'] as Map?) ?? const {});
    final v = (b['value'] as num?) ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: BadgeTile(b: b, size: 72)),
          const Gap(Space.s2),
          Text('${b['description']}', textAlign: TextAlign.center, style: context.ty.body.col(c.textMuted)),
          const Gap(Space.s2),
          Text(
            tier >= 4 ? 'Diamond reached. Well done!' : 'You have ${_num(v)} of ${_num((t[_tierKeys[tier + 1]] as num?) ?? 0)} for ${tierNames[tier + 1]}',
            textAlign: TextAlign.center,
            style: context.ty.sm.bold,
          ),
          const Gap(Space.s4),
          ListCard(
            children: [
              for (var i = 1; i <= 4; i++)
                Builder(
                  builder: (context) {
                    final rw = Map<String, dynamic>.from((r[_tierKeys[i]] as Map?) ?? const {});
                    final xp = (rw['xp'] as num?)?.toInt() ?? 0, days = (rw['days'] as num?)?.toInt() ?? 0;
                    return ListRow(
                      lead: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: i <= tier ? tierColors[i] : c.surfaceSunken),
                        child: Icon(
                          i <= tier ? PhosphorIcons.check(PhosphorIconsStyle.fill) : badgeIcon('${b['icon']}', PhosphorIconsStyle.regular),
                          size: 18,
                          color: i <= tier ? Colors.white : tierColors[i],
                        ),
                      ),
                      title: '${tierNames[i]} · ${_num((t[_tierKeys[i]] as num?) ?? 0)}',
                      caption: [if (xp > 0) '$xp XP', if (days > 0) '$days days of Premium'].join(' + ').ifEmpty('No reward'),
                      caret: false,
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  },
);

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// Me screen: the badges with the most progress first, and a link to all of them.
class BadgesSection extends ConsumerWidget {
  const BadgesSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final d = ref.watch(badgesProvider).value;
    final list = badgeList(d);
    if (d == null || d['on'] == false || list.isEmpty) return const SizedBox.shrink();
    final levels = list.fold<int>(0, (a, b) => a + ((b['tier'] as num?)?.toInt() ?? 0));
    final sorted = [...list]
      ..sort((a, b) {
        final ta = (a['tier'] as num?)?.toInt() ?? 0, tb = (b['tier'] as num?)?.toInt() ?? 0;
        return tb != ta ? tb.compareTo(ta) : badgeProgress(b).compareTo(badgeProgress(a));
      });
    final rm = context.reduceMotion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s3),
          child: Row(
            children: [
              Expanded(child: Text('Badges', style: context.ty.h3)),
              Text('$levels of ${list.length * 4} levels', style: context.ty.cap.col(c.textMuted)),
              const Gap(Space.s2),
              TextButton(onPressed: () => context.push('/badges'), child: const Text('See all')),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.s2,
          crossAxisSpacing: Space.s2,
          childAspectRatio: .72,
          children: [
            for (final (i, b) in sorted.take(8).indexed)
              rm ? BadgeTile(b: b) : BadgeTile(b: b).animate().fadeIn(delay: (30 * i).ms, duration: Motion.base).scale(begin: const Offset(.9, .9)),
          ],
        ),
      ],
    );
  }
}

/// All badges, grouped: won first, then the ones still to win.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const TopBar(title: 'Badges'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(badgesProvider);
          await ref.read(badgesProvider.future).catchError((_) => const <String, dynamic>{});
        },
        child: asyncView(ref.watch(badgesProvider), (d) {
          final list = badgeList(d);
          if (d['on'] == false || list.isEmpty) {
            return ListView(
              children: [
                StateBlock(
                  icon: PhosphorIcons.medal(PhosphorIconsStyle.fill),
                  tone: Tone.gold,
                  title: 'Badges are coming soon',
                  text: 'Keep practising. Your progress already counts.',
                ),
              ],
            );
          }
          final won = list.where((b) => ((b['tier'] as num?) ?? 0) > 0).toList();
          final todo = list.where((b) => ((b['tier'] as num?) ?? 0) == 0).toList();
          Widget grid(List<Map<String, dynamic>> items) => GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Space.s3,
            crossAxisSpacing: Space.s2,
            childAspectRatio: .72,
            children: [for (final b in items) BadgeTile(b: b)],
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
            children: [
              Text('Tap a badge to see its levels and rewards. Each level pays once.', style: context.ty.sm.col(context.c.textMuted)),
              const Gap(Space.s4),
              if (won.isNotEmpty) ...[SectTitle('Won (${won.length})'), grid(won), const Gap(Space.s5)],
              if (todo.isNotEmpty) ...[SectTitle('To win (${todo.length})'), grid(todo)],
            ],
          );
        }, onRetry: () => ref.invalidate(badgesProvider)),
      ),
    );
  }
}
