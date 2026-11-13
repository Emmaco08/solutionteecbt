import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../widgets/phosphor.g.dart';
import '../community/community_data.dart' show Json;
import 'gz_avatar.dart';
import 'gz_data.dart';
import 'gz_find.dart';
import 'gz_fx.dart';
import 'gz_hub.dart';
import 'gz_memory.dart';
import 'gz_race.dart';
import 'gz_reading.dart';
import 'gz_result.dart';
import 'gz_scenes.dart';
import 'gz_sound.dart';
import 'gz_sync.dart';
import 'gz_theme.dart';

// One match from lobby to results (D-157): lobby → VS reveal with 3-2-1-GO → the game → results.

class GzMatchScreen extends StatefulWidget {
  const GzMatchScreen({super.key, required this.id});
  final String id;
  @override
  State<GzMatchScreen> createState() => _GzMatchScreenState();
}

class _GzMatchScreenState extends State<GzMatchScreen> {
  late final GzMatch _m = GzMatch(widget.id)
    ..addListener(_sounds)
    ..open();
  GzPhase? _was;
  int _seats = 0;

  /// Sounds for match moments: a player joins the lobby, the match is found, the game starts.
  void _sounds() {
    final p = _m.phase;
    final n = _m.players.where((x) => x['bot'] != true).length;
    if (p == GzPhase.lobby && _seats > 0 && n > _seats) GzFeel.sfx(GzSfx.pop);
    _seats = n;
    if (p != _was) {
      if (p == GzPhase.intro) {
        GzFeel.sfx(GzSfx.found);
        Future.delayed(const Duration(milliseconds: 450), () => GzFeel.sfx(GzSfx.whoosh));
      }
      _was = p;
    }
  }

  @override
  void dispose() {
    _m.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final code = _m.s?['code'];
    if (code == null) return;
    final g = GzGame.of(_m.game);
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Play ${g.name} with me on SolutionTee CBT! Open the app, go to Game Zone, tap JOIN A CODE and type $code. '
            'Get the app: https://cbt.solutiontee.com',
      ),
    );
  }

  Future<bool> _confirmLeave() async {
    final p = _m.phase;
    if (p == GzPhase.done || p == GzPhase.cancelled || p == GzPhase.error || p == GzPhase.loading) return true;
    if (p == GzPhase.lobby) {
      await _m.leave();
      return true;
    }
    if (_m.me['alive'] == false) return true;
    final ok = await showGzDialog<bool>(
      context,
      title: 'LEAVE THE GAME?',
      body: 'If you leave now, this game counts as a loss and you get no XP.',
      yes: 'KEEP PLAYING',
      no: 'LEAVE',
    );
    if (ok == false) {
      await _m.leave();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) async {
        if (did) return;
        if (await _confirmLeave() && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: GzC.ink,
        body: ListenableBuilder(
          listenable: _m,
          builder: (context, _) {
            final phase = _m.phase;
            Widget child = switch (phase) {
              GzPhase.loading => const _Stage(key: ValueKey('load'), child: GzLoading()),
              GzPhase.error => _Stage(
                key: const ValueKey('err'),
                child: GzErrorView(text: _m.error ?? 'Something went wrong.', onRetry: _m.load),
              ),
              GzPhase.cancelled => _Stage(
                key: const ValueKey('cancel'),
                child: _Ended(onBack: () => context.pop()),
              ),
              GzPhase.lobby => _Stage(
                key: const ValueKey('lobby'),
                child: GzLobbyView(
                  m: _m,
                  onShare: _share,
                  onStart: () => _m.startNow(),
                  onLeave: () async {
                    if (await _confirmLeave() && context.mounted) context.pop();
                  },
                ),
              ),
              GzPhase.intro => KeyedSubtree(
                key: const ValueKey('intro'),
                child: GzVsIntro(m: _m),
              ),
              GzPhase.play => KeyedSubtree(key: ValueKey('play-${_m.game}'), child: _play()),
              GzPhase.done => KeyedSubtree(
                key: const ValueKey('done'),
                child: GzResults(m: _m),
              ),
            };
            final track = switch (phase) {
              GzPhase.lobby || GzPhase.loading => 'hub',
              GzPhase.intro || GzPhase.play => 'battle',
              _ => null,
            };
            return GzMusic(
              track: track,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: context.calm ? Duration.zero : const Duration(milliseconds: 360),
                      switchInCurve: Curves.easeOut,
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(a), child: c),
                      ),
                      child: child,
                    ),
                  ),
                  if (_m.s != null && _m.status == 'playing' && _m.now() < _m.startsAt + 900)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: StartCountdown(now: _m.now, startsAt: _m.startsAt),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _play() => switch (_m.game) {
    'rush' || 'blitz' => GzRacePlay(m: _m, onLeave: _leaveNow),
    'reading' => GzReadingPlay(m: _m, onLeave: _leaveNow),
    'memory' => GzMemoryPlay(m: _m, onLeave: _leaveNow),
    _ => GzSyncPlay(m: _m, onLeave: _leaveNow),
  };

  Future<void> _leaveNow() async {
    if (await _confirmLeave() && mounted) context.pop();
  }
}

/// Arena background with content on top (lobby, loading, errors).
class _Stage extends StatelessWidget {
  const _Stage({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(child: ArenaScene(beams: false)),
      SafeArea(child: child),
    ],
  );
}

class _Ended extends StatelessWidget {
  const _Ended({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: GzPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('GAME CLOSED', style: gzFont(26)),
            const SizedBox(height: 8),
            Text(
              'Nobody joined in time. Try Quick Match: a SolutionTee Bot joins if nobody is free.',
              textAlign: TextAlign.center,
              style: gzBody(14, color: GzC.subLight),
            ),
            const SizedBox(height: 16),
            GameButton(
              color: GzC.gold,
              height: 52,
              onTap: onBack,
              child: Text('BACK', style: gzFont(20, color: GzC.navy, shadow: 0)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The "how to play" line for each game.
String gzRules(GzMatch m) => switch (m.game) {
  'duel' => '${m.rounds} questions · ${m.seconds} seconds each · same question at the same time',
  'words' => '${m.rounds} words · ${m.seconds} seconds each · the faster right answer scores more',
  'survival' => '3 hearts · a wrong or late answer costs a heart · last one standing wins',
  'relay' => 'Blue team vs red team · every right answer adds to your team',
  'rush' => 'First to ${m.target} right answers · a wrong answer spins you out for 2 seconds',
  'blitz' => '60 seconds of quick maths · right answers in a row build your combo',
  'reading' => 'Read the passage fast · it disappears · then ${m.rounds} questions · most right wins, then the faster finish',
  _ => '3 levels · remember the cards, then match them',
};

// ---------------------------------------------------------------- VS reveal

class GzVsIntro extends StatelessWidget {
  const GzVsIntro({super.key, required this.m});
  final GzMatch m;

  @override
  Widget build(BuildContext context) {
    final players = m.players;
    final g = GzGame.of(m.game);
    final me = players.firstWhere((p) => p['me'] == true, orElse: () => players.isEmpty ? const {} : players.first);
    final others = players.where((p) => p['me'] != true).toList();
    final subject = (m.s?['subject'] as Map?)?['name'];
    final calm = context.calm;
    final ranked = m.s?['mode'] == 'ranked';

    if (players.length == 2) {
      final opp = others.first;
      return Stack(
        children: [
          const Positioned.fill(child: VersusScene()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final h = box.maxHeight;
                return Stack(
                  children: [
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: GzTag(
                              '${g.name.toUpperCase()}${subject != null ? ' · ${'$subject'.toUpperCase()}' : ''}',
                              color: GzC.ink.withValues(alpha: .6),
                              textColor: GzC.goldLight,
                              border: GzC.goldLight,
                            ),
                          ),
                          if (ranked) Text('RANKED', style: gzFont(15)),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: h * .1,
                      child: _Fighter(
                        p: me,
                        left: true,
                        size: math.min(170, h * .22),
                      ).animate().slideX(begin: calm ? 0 : -1.4, duration: 520.ms, curve: Curves.easeOutBack),
                    ),
                    Positioned(
                      right: 20,
                      top: h * .52,
                      child: _Fighter(
                        p: opp,
                        left: false,
                        size: math.min(170, h * .22),
                      ).animate(delay: 120.ms).slideX(begin: calm ? 0 : 1.4, duration: 520.ms, curve: Curves.easeOutBack),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: h * .4,
                      child: Center(
                        child:
                            SizedBox(
                                  width: 110,
                                  height: 110,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const RankShield(color: GzC.gold, size: 100),
                                      Text('VS', style: gzFont(40, color: GzC.navy, shadow: 0, spacing: 1)),
                                    ],
                                  ),
                                )
                                .animate(delay: 520.ms)
                                .scale(begin: Offset(calm ? 1 : 3, calm ? 1 : 3), duration: 360.ms, curve: Curves.easeOutBack)
                                .fadeIn(duration: 120.ms),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: Column(
                        children: [
                          Text('MATCH FOUND!', style: gzFont(26, spacing: 1)),
                          const SizedBox(height: 4),
                          Text(
                            gzRules(m),
                            textAlign: TextAlign.center,
                            style: gzBody(13, color: const Color(0xFFFFD0DA)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }

    // Group games: everybody pops in.
    final relay = m.game == 'relay';
    return Stack(
      children: [
        Positioned.fill(child: ArenaScene(glow: relay ? GzC.cyan : (m.game == 'survival' ? GzC.orange : GzC.mint))),
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              GzTag(g.name.toUpperCase(), color: g.color, textColor: g.dark ? GzC.navy : Colors.white, size: 18),
              const SizedBox(height: 8),
              Text('${players.length} PLAYERS', style: gzFont(30)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: relay
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final team in const [1, 2])
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(team == 1 ? 'BLUE TEAM' : 'RED TEAM', style: gzFont(18, color: team == 1 ? GzC.sky : const Color(0xFFFF8FA8))),
                                    const SizedBox(height: 10),
                                    for (final (i, p) in players.where((p) => gzMs(p['team']) == team).indexed)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _badge(p, team == 1 ? GzC.sky : GzC.red, 74).popIn(delay: (120 * i + (team - 1) * 60).ms, calm: calm),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        )
                      : Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 12,
                          children: [
                            for (final (i, p) in players.indexed)
                              _badge(p, p['me'] == true ? GzC.goldLight : GzC.sky, 60).popIn(delay: (45 * i).ms, calm: calm),
                          ],
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Text(
                  gzRules(m),
                  textAlign: TextAlign.center,
                  style: gzBody(13, color: GzC.subLight),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(Json p, Color ring, double size) => GzPlayerBadge(
    face: GzFace.from(p['avatar']),
    name: p['me'] == true ? 'You' : '${p['name']}',
    size: size,
    ring: p['me'] == true ? GzC.goldLight : ring,
    bot: p['bot'] == true,
  );
}

class _Fighter extends StatelessWidget {
  const _Fighter({required this.p, required this.left, required this.size});
  final Json p;
  final bool left;
  final double size;

  @override
  Widget build(BuildContext context) {
    final rating = gzMs(p['rating']);
    final rank = rating != null ? GzRank.of(rating) : null;
    final bot = p['bot'] == true;
    final level = '${p['level'] ?? ''}';
    final info = Column(
      crossAxisAlignment: left ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(p['me'] == true ? 'YOU' : '${p['name']}'.toUpperCase(), style: gzFont(28, spacing: 1)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: left ? GzC.brand : Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Text(
            bot ? 'SOLUTIONTEE BOT · ${level.toUpperCase()}' : (rank != null ? '${rank.label} · ${gzNum(rating!)}' : 'PLAYER'),
            style: gzFont(13, color: GzC.navy, shadow: 0),
          ),
        ),
      ],
    );
    final pic = GzPortrait(
      face: GzFace.from(p['avatar']),
      size: size,
      ring: left ? GzC.goldLight : Colors.white,
      name: '${p['name']}',
      bot: bot,
      mood: 'focus',
    );
    return Row(mainAxisSize: MainAxisSize.min, children: left ? [pic, const SizedBox(width: 12), info] : [info, const SizedBox(width: 12), pic]);
  }
}

/// The small top bar every game screen uses: leave, title tag, and a slot on the right.
class GzTopBar extends StatelessWidget {
  const GzTopBar({super.key, required this.onLeave, required this.center, this.right});
  final VoidCallback onLeave;
  final Widget center;
  final Widget? right;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 10, 0),
    child: Row(
      children: [
        GzRoundIcon(icon: PhosphorIcons.x(PhosphorIconsStyle.bold), label: 'Leave the game', size: 38, onTap: onLeave),
        const SizedBox(width: 4),
        Expanded(child: center),
        if (right != null) ...[const SizedBox(width: 8), right!],
      ],
    ),
  );
}
