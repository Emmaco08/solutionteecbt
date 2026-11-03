import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/nav.dart';
import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import 'compete_data.dart';

IconData challengeIcon(String name) => switch (name) {
  'function' => PhosphorIcons.mathOperations(PhosphorIconsStyle.fill),
  'atom' => PhosphorIcons.atom(PhosphorIconsStyle.fill),
  'book-open-text' => PhosphorIcons.bookOpenText(PhosphorIconsStyle.fill),
  'flask' => PhosphorIcons.flask(PhosphorIconsStyle.fill),
  'globe' => PhosphorIcons.globeHemisphereWest(PhosphorIconsStyle.fill),
  'lightning' => PhosphorIcons.lightning(PhosphorIconsStyle.fill),
  'star' => PhosphorIcons.star(PhosphorIconsStyle.fill),
  _ => PhosphorIcons.trophy(PhosphorIconsStyle.fill),
};

/// Rebuilds every second (countdowns).
class Ticker extends StatefulWidget {
  const Ticker({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  State<Ticker> createState() => _TickerState();
}

class _TickerState extends State<Ticker> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// The quiet "broadcast" live pill (D-030): ripple dot + LIVE + optional detail. [dark] on navy surfaces.
class LivePill extends StatelessWidget {
  const LivePill({super.key, this.detail, this.dark = false});
  final String? detail;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = dark ? Colors.white : c.error;
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: dark ? const Color(0xFFFF6B6B) : c.error, shape: BoxShape.circle),
    );
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: dark ? Colors.white.withValues(alpha: .12) : c.errorSoft, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          context.reduceMotion
              ? dot
              : dot.animate(onPlay: (a) => a.repeat()).scaleXY(begin: 1, end: 1.5, duration: 900.ms).fade(begin: 1, end: .5, duration: 900.ms),
          const SizedBox(width: 6),
          Text('LIVE', style: context.ty.cap.bold.col(fg)),
          if (detail != null) ...[const SizedBox(width: 6), Text('· $detail', style: context.ty.cap.col(fg))],
        ],
      ),
    );
  }
}

Widget _typeBadge(Challenge c) => switch (c.kind) {
  'cash' => Pill('Cash prize', kind: BadgeKind.gold, icon: PhosphorIcons.currencyNgn(PhosphorIconsStyle.fill)),
  'event' => Pill('Event', icon: PhosphorIcons.calendarStar(PhosphorIconsStyle.fill)),
  _ => const Pill('Practice', kind: BadgeKind.neutral),
};

/// "Biology" for a one-subject challenge, "Your JAMB subjects" for the weekly mixed one.
Widget? _modeBadge(Challenge c) => switch (c.mode) {
  'subject' => Pill(c.subject ?? 'Subject', kind: BadgeKind.neutral, icon: PhosphorIcons.bookOpen(PhosphorIconsStyle.fill)),
  'mixed' => Pill('Your JAMB subjects', kind: BadgeKind.neutral, icon: PhosphorIcons.shuffle(PhosphorIconsStyle.fill)),
  _ => null,
};

Widget _statusBadge(BuildContext context, Challenge c) => c.live
    ? const LivePill()
    : c.upcoming
    ? Ticker(builder: (_) => Pill('Starts in ${untilShort(c.startsAt)}', icon: PhosphorIcons.clock(PhosphorIconsStyle.fill)))
    : const Pill('Ended', kind: BadgeKind.neutral);

/// Big navy card for a live challenge (prototype `.ch-hero`).
class ChallengeHero extends StatelessWidget {
  const ChallengeHero({super.key, required this.c});
  final Challenge c;
  @override
  Widget build(BuildContext context) {
    final mine = c.mine;
    return Pressable(
      onTap: () => openRoute(context, '/test/challenges/${c.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Container(
          padding: const EdgeInsets.all(Space.s4),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Palette.navy900, Color(0xFF13306A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LivePill(detail: '${c.joined} playing', dark: true),
                  const Spacer(),
                  if (mine != null) Pill(mine['status'] == 'disqualified' ? 'Disqualified' : 'You took part', kind: BadgeKind.success),
                ],
              ),
              const Gap(Space.s3),
              Text(c.title, style: context.ty.cap.bold.col(Palette.gold300)),
              Text(c.prizes.isNotEmpty ? 'Win ${nairaWhole(c.prizes.first)}' : (c.reward ?? c.title), style: context.ty.h1.col(Colors.white)),
              Text('${c.questions} questions · ${c.seconds}s each · free for everyone', style: context.ty.sm.col(const Color(0xFFDCE4F2))),
              const Gap(Space.s3),
              Row(
                children: [
                  Icon(PhosphorIcons.timer(PhosphorIconsStyle.fill), size: 16, color: const Color(0xFFAFC0DD)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Ticker(builder: (_) => Text('Winners in ${untilShort(c.endsAt)}', style: context.ty.cap.col(const Color(0xFFAFC0DD)))),
                  ),
                  Btn(
                    mine != null ? 'See result' : 'Play now',
                    kind: BtnKind.accent,
                    sm: true,
                    onPressed: () => openRoute(context, '/test/challenges/${c.id}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home "Challenges & events" section (D-037): live first, else the next one, else a calm empty card.
class ChallengeSection extends ConsumerWidget {
  const ChallengeSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(challengesProvider).value;
    if (d == null || d['on'] != true) return const SizedBox.shrink();
    final c = context.c;
    final items = [for (final x in rows(d['items'])) Challenge(x)];
    final live = items.where((x) => x.live).toList();
    final up = items.where((x) => x.upcoming).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final featured = live.where((x) => x.kind == 'cash').firstOrNull ?? live.firstOrNull ?? up.firstOrNull;
    final others = items.where((x) => x != featured).toList();
    final Widget top;
    if (featured != null && featured.live) {
      top = ChallengeHero(c: featured);
    } else if (featured != null) {
      top = AppCard(
        onTap: () => openRoute(context, '/test/challenges/${featured.id}'),
        child: Row(
          children: [
            IconTile(challengeIcon(featured.icon), tone: Tone.blue, size: 48, radius: 14, iconSize: 24),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Ticker(builder: (_) => Text('Next: starts in ${untilShort(featured.startsAt)}', style: context.ty.cap.bold.col(c.onSecondarySoft))),
                  Text(featured.title, style: context.ty.body.bold),
                  Text('${featured.rewardText} · Free to join', style: context.ty.cap.col(c.textMuted)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      top = Container(
        padding: const EdgeInsets.all(Space.s4),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(PhosphorIcons.trophy(PhosphorIconsStyle.fill), tone: Tone.gold, size: 44, radius: 12),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No challenge right now', style: context.ty.body.bold),
                  Text('New challenges with prizes come every week. We tell you the moment one starts.', style: context.ty.sm.col(c.textMuted)),
                  const Gap(Space.s2),
                  Btn('Past winners', kind: BtnKind.ghost, sm: true, onPressed: () => openRoute(context, '/test/winners-wall')),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectTitle('Challenges & events', action: 'See all', onAction: () => openRoute(context, '/test/challenges')),
        top,
        if (others.isNotEmpty) ...[
          const Gap(Space.s4),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: others.length,
              separatorBuilder: (_, _) => const Gap(Space.s3),
              itemBuilder: (_, i) => SizedBox(width: 220, child: _Mini(c: others[i])),
            ),
          ),
        ],
      ],
    );
  }
}

/// Small card (`.ch-mini`, D-041): icon + status on top, title, then Prize / Entry split by a line.
class _Mini extends StatelessWidget {
  const _Mini({required this.c});
  final Challenge c;
  @override
  Widget build(BuildContext context) {
    final cc = context.c;
    return AppCard(
      onTap: () => openRoute(context, '/test/challenges/${c.id}'),
      padding: const EdgeInsets.all(Space.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(challengeIcon(c.icon), tone: Tone.navy, size: 32, radius: 9, iconSize: 18),
              const Spacer(),
              _statusBadge(context, c),
            ],
          ),
          const Gap(Space.s2),
          Text(c.title, style: context.ty.sm.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Divider(height: Space.s3, color: cc.border),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prize', style: context.ty.cap.col(cc.textMuted)),
                    Text(c.prizes.isNotEmpty ? nairaWhole(c.prizes.first) : (c.reward != null ? 'Reward' : 'Practice'), style: context.ty.sm.bold),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Entry', style: context.ty.cap.col(cc.textMuted)),
                    Text('Free', style: context.ty.sm.bold),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Test → Challenges & events (prototype `compete`): live, coming up, Winners wall, past winners.
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(challengesProvider);
    return Scaffold(
      appBar: TopBar(
        title: 'Challenges & events',
        onBack: () => context.canPop() ? context.pop() : context.go('/test'),
        subtitle: 'Win prizes. Free and Premium can join.',
        actions: [IconBtn(PhosphorIcons.sealCheck(), label: 'Winners wall', onPressed: () => openRoute(context, '/test/winners-wall'))],
      ),
      body: asyncView(
        v,
        (d) {
          if (d['on'] != true) {
            return Center(
              child: StateBlock(
                icon: PhosphorIcons.trophy(PhosphorIconsStyle.fill),
                tone: Tone.gold,
                title: 'Challenges are switched off',
                text: 'Check back soon.',
              ),
            );
          }
          final items = [for (final x in rows(d['items'])) Challenge(x)];
          final past = [for (final x in rows(d['past'])) Challenge(x)];
          final live = items.where((x) => x.live).toList(), up = items.where((x) => x.upcoming).toList();
          final c = context.c;
          Widget card(Challenge x) => AppCard(
            onTap: () => openRoute(context, '/test/challenges/${x.id}'),
            child: Row(
              children: [
                IconTile(challengeIcon(x.icon), tone: x.kind == 'cash' ? Tone.gold : Tone.navy, size: 48, radius: 14, iconSize: 24),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: Space.s2, runSpacing: Space.s1, children: [_statusBadge(context, x), _typeBadge(x), ?_modeBadge(x)]),
                      const Gap(Space.s1),
                      Text(x.title, style: context.ty.sm.bold),
                      Text('${x.rewardText} · Free to join', style: context.ty.cap.col(c.textMuted)),
                    ],
                  ),
                ),
                Icon(PhosphorIcons.caretRight(), size: 18, color: c.textSubtle),
              ],
            ),
          );
          final sections = <Widget>[
            if (live.isEmpty && up.isEmpty)
              StateBlock(
                icon: PhosphorIcons.trophy(PhosphorIconsStyle.fill),
                tone: Tone.gold,
                title: 'No challenge right now',
                text: 'New challenges are posted every week. Keep Challenges notifications on so you never miss one.',
              ),
            if (live.isNotEmpty) ...[
              const SectTitle('Live now'),
              for (final x in live) ...[card(x), const Gap(Space.s2)],
            ],
            if (up.isNotEmpty) ...[
              const SectTitle('Coming up'),
              for (final x in up) ...[card(x), const Gap(Space.s2)],
            ],
            AppCard(
              onTap: () => openRoute(context, '/test/winners-wall'),
              child: Row(
                children: [
                  IconTile(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill), tone: Tone.green, size: 44, radius: 12),
                  const Gap(Space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Winners wall', style: context.ty.body.bold),
                        Text('Proof that we pay our winners', style: context.ty.cap.col(c.textMuted)),
                      ],
                    ),
                  ),
                  Icon(PhosphorIcons.caretRight(), size: 18, color: c.textSubtle),
                ],
              ),
            ),
            if (past.isNotEmpty) ...[
              const SectTitle('Past winners'),
              for (final x in past) ...[
                AppCard(
                  onTap: () => openRoute(context, '/test/challenges/${x.id}/winners'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(x.title, style: context.ty.sm.bold)),
                          Text('${x.joined} took part', style: context.ty.cap.col(c.textMuted)),
                        ],
                      ),
                      const Gap(Space.s2),
                      if (x.winners.isEmpty) Text('No winners', style: context.ty.cap.col(c.textMuted)),
                      for (final w in x.winners)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              SizedBox(width: 24, child: Text('${w['rank']}', style: context.ty.sm.bold.tnum)),
                              Expanded(child: Text('${w['name']}  ${w['state'] ?? ''}', style: context.ty.sm)),
                              Text('${w['score']}/${x.questions} · ${mmss(w['time_ms'] as num? ?? 0)}', style: context.ty.cap.tnum.col(c.textMuted)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const Gap(Space.s2),
              ],
            ],
            Text('Prizes are paid after a fair-play review.', style: context.ty.cap.col(c.textSubtle), textAlign: TextAlign.center),
          ];
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(challengesProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
              children: [
                for (var i = 0; i < sections.length; i++) ...[if (i > 0) const Gap(Space.s3), sections[i]],
              ],
            ),
          );
        },
        loading: ListView(
          padding: const EdgeInsets.all(Space.s5),
          children: [
            for (var i = 0; i < 4; i++) ...[const Skeleton(height: 84, radius: Radii.lg), const Gap(Space.s3)],
          ],
        ),
        onRetry: () => ref.invalidate(challengesProvider),
      ),
    );
  }
}

/// Fair-play rules (prototype FAIR).
List<(IconData, String, String)> fairRules(int allowedExits) => [
  (
    PhosphorIcons.deviceMobile(PhosphorIconsStyle.fill),
    'Stay on the challenge screen',
    allowedExits == 0
        ? 'Leaving the app, opening another app, the notification panel, split screen or a floating window submits your answers and disqualifies you.'
        : 'Leaving the app more than $allowedExits ${allowedExits == 1 ? 'time' : 'times'} submits your answers and disqualifies you.',
  ),
  (PhosphorIcons.cameraSlash(PhosphorIconsStyle.fill), 'Screenshots and copying are blocked', 'You cannot screenshot, screen-record or copy the questions.'),
  (PhosphorIcons.timer(PhosphorIconsStyle.fill), 'One question at a time, timed', 'Each question has its own short timer. You cannot go back.'),
  (
    PhosphorIcons.shuffle(PhosphorIconsStyle.fill),
    'Your questions are shuffled',
    'Every student gets the questions and options in a different order. The answers are checked on our server.',
  ),
  (PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.fill), 'Answers are reviewed', 'Very fast or unusual answer patterns are checked before prizes are paid.'),
  (
    PhosphorIcons.identificationBadge(PhosphorIconsStyle.fill),
    'Winners are verified',
    'One account per person and phone. Under 18? A parent or guardian must agree and receives the prize.',
  ),
];

/// Challenge details (prototype `challenge`): prizes, fair-play rules, the agreement, then Start.
class ChallengeScreen extends ConsumerStatefulWidget {
  const ChallengeScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends ConsumerState<ChallengeScreen> {
  bool _agree = false;
  bool _shake = false;

  void _start(Challenge c) {
    if (!_agree) {
      setState(() => _shake = true);
      Future.delayed(const Duration(milliseconds: 450), () => mounted ? setState(() => _shake = false) : null);
      toast(context, 'Tick the fair-play box first.', icon: PhosphorIcons.shieldWarning(PhosphorIconsStyle.fill));
      return;
    }
    context.push('/challenges/${c.id}/play');
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(challengeProvider(widget.id));
    final c = context.c;
    return Scaffold(
      appBar: TopBar(onBack: () => context.canPop() ? context.pop() : context.go('/test/challenges')),
      body: asyncView(
        v,
        (ch) => ListView(
          padding: const EdgeInsets.fromLTRB(Space.s5, 0, Space.s5, Space.s8),
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: ch.kind == 'cash' ? const [Palette.navy900, Color(0xFF3A2C05)] : const [Palette.navy900, Color(0xFF13306A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(Radii.lg),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(challengeIcon(ch.icon), size: 56, color: Palette.gold500),
                  if (ch.exam != null) ...[const Gap(Space.s4), ExamLogo(ch.exam!, size: LogoSize.md)],
                ],
              ),
            ),
            const Gap(Space.s4),
            Wrap(spacing: Space.s2, runSpacing: Space.s2, children: [_statusBadge(context, ch), _typeBadge(ch), ?_modeBadge(ch)]),
            const Gap(Space.s3),
            Text(ch.title, style: context.ty.h1),
            if ((ch.subtitle ?? '').isNotEmpty) ...[const Gap(Space.s1), Text(ch.subtitle!, style: context.ty.body.col(c.textMuted))],
            const Gap(Space.s4),
            Row(
              children: [
                for (final (v, l) in [('${ch.questions}', 'questions'), ('${ch.seconds}s', 'per question'), ('Free', 'entry')])
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: Space.s3),
                      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
                      child: Column(
                        children: [
                          Text(v, style: context.ty.h3.tnum),
                          Text(l, style: context.ty.cap.col(c.textMuted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const Gap(Space.s4),
            if (ch.ineligibleText != null) ...[
              InfoBanner(kind: BannerKind.warn, icon: PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), child: Text(ch.ineligibleText!)),
              const Gap(Space.s3),
            ],
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconTile(
                    ch.mode == 'fixed' ? PhosphorIcons.shuffle(PhosphorIconsStyle.fill) : PhosphorIcons.bookOpen(PhosphorIconsStyle.fill),
                    tone: Tone.blue,
                    size: 36,
                    radius: 10,
                    iconSize: 18,
                  ),
                  const Gap(Space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your questions', style: context.ty.sm.bold),
                        Text(ch.modeText, style: context.ty.cap.col(c.textMuted)),
                        if (ch.mode != 'fixed' && ch.perLevel.isNotEmpty) ...[
                          const Gap(Space.s1),
                          Text(
                            '${ch.mode == 'mixed' ? 'From each subject' : 'You get'}: ${ch.perLevel.map((e) => '${e.$2} ${e.$1.toLowerCase()}').join(', ')}. '
                            'Every student gets the same mix, but different questions.',
                            style: context.ty.cap.col(c.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Gap(Space.s3),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(ch.prizes.isNotEmpty ? 'Prizes' : 'Reward', style: context.ty.body.bold),
                  const Gap(Space.s2),
                  for (final (i, p) in ch.prizes.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          _Medal(place: i + 1),
                          const Gap(Space.s3),
                          Expanded(child: Text(['1st', '2nd', '3rd'][i.clamp(0, 2)], style: context.ty.sm.bold)),
                          Text(nairaWhole(p), style: context.ty.body.bold.tnum),
                        ],
                      ),
                    ),
                  if ((ch.reward ?? '').isNotEmpty) Text(ch.reward!, style: context.ty.sm),
                  if (ch.prizes.isEmpty && (ch.reward ?? '').isEmpty) Text('No prize. Practise and see how you rank.', style: context.ty.sm),
                  const Gap(Space.s1),
                  Text(ch.rule, style: context.ty.cap.col(c.textMuted)),
                ],
              ),
            ),
            const Gap(Space.s5),
            Row(
              children: [
                IconTile(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), tone: Tone.green, size: 32, radius: 9, iconSize: 18),
                const Gap(Space.s2),
                Text('Fair-play rules', style: context.ty.h3),
              ],
            ),
            const Gap(Space.s3),
            ListCard(
              children: [
                for (final (ic, t, d) in fairRules(ch.allowedExits))
                  Padding(
                    padding: const EdgeInsets.all(Space.s3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconTile(ic, tone: Tone.green, size: 36, radius: 10, iconSize: 18),
                        const Gap(Space.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t, style: context.ty.sm.bold),
                              Text(d, style: context.ty.cap.col(c.textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (ch.live && ch.mine == null && ch.eligible) ...[
              const Gap(Space.s3),
              CheckRow(
                value: _agree,
                onChanged: (x) => setState(() => _agree = x),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'I agree to the fair-play rules. I understand that leaving the challenge screen '),
                      TextSpan(text: 'disqualifies', style: context.ty.sm.bold),
                      const TextSpan(text: ' me.'),
                    ],
                  ),
                  style: context.ty.sm.col(_shake ? c.error : c.text),
                ),
              ).animate(target: _shake ? 1 : 0).shakeX(hz: 6, amount: 4),
            ],
          ],
        ),
        loading: ListView(
          padding: const EdgeInsets.all(Space.s5),
          children: const [
            Skeleton(height: 140, radius: Radii.lg),
            Gap(Space.s4),
            Skeleton(height: 220, radius: Radii.lg),
          ],
        ),
        onRetry: () => ref.invalidate(challengeProvider(widget.id)),
      ),
      bottomNavigationBar: v.value == null ? null : _Footer(c: v.value!, onStart: () => _start(v.value!)),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.place});
  final int place;
  @override
  Widget build(BuildContext context) {
    const ring = {1: Palette.gold500, 2: Color(0xFFA7B1C2), 3: Color(0xFFC6865A)};
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: ring[place.clamp(1, 3)], shape: BoxShape.circle),
      child: Text('$place', style: context.ty.cap.bold.col(place == 1 ? Palette.navy900 : Colors.white)),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.c, required this.onStart});
  final Challenge c;
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) {
    final mine = c.mine;
    final cc = context.c;
    final Widget child;
    if (c.ended) {
      child = Btn('See the winners', block: true, onPressed: () => openRoute(context, '/test/challenges/${c.id}/winners'));
    } else if (mine != null) {
      final dq = mine['status'] == 'disqualified';
      child = Row(
        children: [
          Icon(
            dq ? PhosphorIcons.shieldWarning(PhosphorIconsStyle.fill) : PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
            color: dq ? cc.error : cc.success,
          ),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dq
                      ? 'Your entry was disqualified'
                      : mine['status'] == 'playing'
                      ? 'You started this challenge'
                      : 'You scored ${mine['score']}/${c.questions} in ${mmss(mine['time_ms'] as num? ?? 0)}',
                  style: context.ty.sm.bold,
                ),
                Text('Each challenge can be taken only once.', style: context.ty.cap.col(cc.textMuted)),
              ],
            ),
          ),
          Btn(
            mine['status'] == 'playing' ? 'Continue' : 'Result',
            kind: BtnKind.tonal,
            sm: true,
            onPressed: () {
              if (mine['status'] == 'playing') {
                context.push('/challenges/${c.id}/play');
              } else {
                openRoute(context, '/test/challenges/${c.id}/result');
              }
            },
          ),
        ],
      );
    } else if (c.upcoming) {
      child = Ticker(
        builder: (_) => Btn(
          'Starts in ${untilShort(c.startsAt)}',
          kind: BtnKind.tonal,
          block: true,
          leading: PhosphorIcons.bellRinging(PhosphorIconsStyle.fill),
          onPressed: () => toast(context, 'We will send you a notification the moment it starts.', icon: PhosphorIcons.bellRinging(PhosphorIconsStyle.fill)),
        ),
      );
    } else if (!c.eligible) {
      child = c.mode == 'subject'
          ? Btn('Not one of your subjects', kind: BtnKind.tonal, block: true, leading: PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), onPressed: null)
          : Btn('Choose my JAMB subjects', block: true, onPressed: () => context.push('/subjects'));
    } else {
      child = Btn('Start challenge', block: true, leading: PhosphorIcons.play(PhosphorIconsStyle.fill), onPressed: c.questions == 0 ? null : onStart);
    }
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s3, Space.s5, Space.s3),
        decoration: BoxDecoration(
          color: cc.surface,
          border: Border(top: BorderSide(color: cc.border)),
        ),
        child: child,
      ),
    );
  }
}
