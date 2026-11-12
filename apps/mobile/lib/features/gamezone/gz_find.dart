import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/phosphor.g.dart';
import '../community/community_data.dart' show asJson;
import 'gz_avatar.dart';
import 'gz_data.dart';
import 'gz_hub.dart';
import 'gz_scenes.dart';
import 'gz_sound.dart';
import 'gz_theme.dart';

// Matchmaking (D-157): a radar sweep while the server looks for a student of a similar level; a SolutionTee Bot
// joins after the wait so a game always starts. Practice and friend games skip straight to the match.

class GzFindScreen extends ConsumerStatefulWidget {
  const GzFindScreen({super.key, required this.game, required this.mode, this.subject, this.level = 'medium', this.autoStart = true});
  final String game;
  final String mode;
  final int? subject;
  final String level;

  /// Off in screenshot tests (no server).
  final bool autoStart;
  @override
  ConsumerState<GzFindScreen> createState() => _GzFindScreenState();
}

class _GzFindScreenState extends ConsumerState<GzFindScreen> {
  late final GzFinder _f = GzFinder(game: widget.game, mode: widget.mode, subject: widget.subject, level: widget.level)..addListener(_changed);
  final _clock = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      _f.start();
    } else {
      _f.stage = FindStage.searching;
    }
  }

  void _changed() {
    if (!mounted) return;
    if (_f.stage == FindStage.found && _f.matchId != null) {
      HapticFeedback.heavyImpact();
      GzFeel.sfx(GzSfx.found);
      context.pushReplacement('/games/m/${_f.matchId}');
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    if (_f.stage == FindStage.searching) _f.cancel();
    _f.removeListener(_changed);
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = GzGame.of(widget.game);
    final home = ref.watch(gzHomeProvider).value;
    final face = GzFace.from(asJson(home?['me'])['avatar']);
    final queue = widget.mode == 'quick' || widget.mode == 'ranked';
    return GzMusic(
      track: 'hub',
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: PopScope(
          canPop: true,
          child: Scaffold(
            backgroundColor: GzC.ink,
            body: Stack(
              children: [
                const Positioned.fill(
                  child: ArenaScene(top: Color(0xFF0B1F44), mid: Color(0xFF13234A), glow: GzC.cyan, beams: false),
                ),
                SafeArea(
                  child: _f.stage == FindStage.failed
                      ? GzErrorView(text: _f.error ?? 'Something went wrong.', onRetry: () => _f.start())
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GzTag(g.name.toUpperCase(), color: g.color, textColor: g.dark ? GzC.navy : Colors.white),
                                  if (widget.mode == 'ranked') const GzTag('RANKED', color: GzC.red),
                                ],
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 300,
                              height: 300,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Positioned.fill(child: _Radar()),
                                  if (queue) ..._ghosts(context),
                                  GzPortrait(face: face, size: 120, name: 'You'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(queue ? 'FINDING A PLAYER' : (widget.mode == 'friend' ? 'MAKING YOUR CODE' : 'GETTING READY'), style: gzFont(28, spacing: 1)),
                            const SizedBox(height: 6),
                            if (queue) _Waiting(clock: _clock, wait: _f.wait, searching: _f.searching),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
                              child: GameButton(
                                color: GzC.navy2,
                                height: 54,
                                onTap: () async {
                                  await _f.cancel();
                                  if (context.mounted) context.pop();
                                },
                                child: Text('CANCEL', style: gzFont(20)),
                              ),
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

  /// Unknown players flying around the radar while the search runs.
  List<Widget> _ghosts(BuildContext context) {
    if (context.calm) return const [];
    return [
      for (var i = 0; i < 3; i++)
        _Orbit(
          radius: 118,
          phase: i / 3,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: GzC.navy,
              shape: BoxShape.circle,
              border: Border.all(color: GzC.ink, width: 3),
              boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 3))],
            ),
            child: Center(
              child: Text('?', style: gzFont(24, color: GzC.cyan)),
            ),
          ),
        ),
    ];
  }
}

class _Waiting extends StatefulWidget {
  const _Waiting({required this.clock, required this.wait, required this.searching});
  final Stopwatch clock;
  final int wait;
  final int searching;
  @override
  State<_Waiting> createState() => _WaitingState();
}

class _WaitingState extends State<_Waiting> {
  late final _t = Stream.periodic(const Duration(milliseconds: 500));

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _t,
    builder: (_, _) {
      final s = widget.clock.elapsed.inSeconds;
      final left = math.max(0, widget.wait - s);
      return Column(
        children: [
          Text('0:${s.toString().padLeft(2, '0')}', style: gzFont(22, color: GzC.goldLight)),
          const SizedBox(height: 4),
          Text(left > 0 ? 'A SolutionTee Bot joins in $left s if nobody is free' : 'A SolutionTee Bot is joining…', style: gzBody(13, color: GzC.subLight)),
          if (widget.searching > 1) Text('${widget.searching} students searching now', style: gzBody(12, color: GzC.mint)),
        ],
      );
    },
  );
}

class _Radar extends StatefulWidget {
  const _Radar();
  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: CustomPaint(painter: _RadarPainter(context.calm ? null : _c)));
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.a) : super(repaint: a);
  final Animation<double>? a;

  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero);
    final r = s.width / 2;
    c.drawCircle(center, r, Paint()..color = GzC.navy.withValues(alpha: .7));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = GzC.cyan.withValues(alpha: .35);
    for (final k in const [.4, .7, 1.0]) {
      c.drawCircle(center, r * k - 1, ring);
    }
    final t = a?.value ?? 0;
    // The sweep.
    c.drawArc(
      Rect.fromCircle(center: center, radius: r),
      t * math.pi * 2 - .9,
      .9,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: .9,
          colors: [GzC.cyan.withValues(alpha: 0), GzC.cyan.withValues(alpha: .45)],
          transform: GradientRotation(t * math.pi * 2 - .9),
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    // A pulse ring going out.
    c.drawCircle(
      center,
      r * (.3 + .7 * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = GzC.mint.withValues(alpha: (1 - t) * .6),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter o) => false;
}

class _Orbit extends StatefulWidget {
  const _Orbit({required this.radius, required this.phase, required this.child});
  final double radius;
  final double phase;
  final Widget child;
  @override
  State<_Orbit> createState() => _OrbitState();
}

class _OrbitState extends State<_Orbit> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      final a = (_c.value + widget.phase) * math.pi * 2;
      return Transform.translate(offset: Offset(math.cos(a) * widget.radius, math.sin(a) * widget.radius * .85), child: child);
    },
    child: widget.child.animate().fadeIn(duration: 400.ms),
  );
}

/// "WAITING FOR PLAYERS" lobby for group games and friend codes.
class GzLobbyView extends StatelessWidget {
  const GzLobbyView({super.key, required this.m, required this.onShare, required this.onStart, required this.onLeave});
  final GzMatch m;
  final VoidCallback onShare;
  final VoidCallback onStart;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final s = m.s!;
    final g = GzGame.of(m.game);
    final code = s['code'] as String?;
    final players = m.players;
    final max = gzMs(s['max']) ?? 2;
    final host = s['host'] == true;
    final friend = s['mode'] == 'friend';
    final until = gzMs(s['lobby_until']) ?? 0;
    final calm = context.calm;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              GzRoundIcon(icon: PhosphorIcons.x(PhosphorIconsStyle.bold), label: 'Leave', onTap: onLeave),
              const Spacer(),
              GzTag(g.name.toUpperCase(), color: g.color, textColor: g.dark ? GzC.navy : Colors.white),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (code != null) ...[
          Text('YOUR GAME CODE', style: gzFont(18, color: GzC.subLight)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              HapticFeedback.selectionClick();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: GzC.cream,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: GzC.ink, width: 4),
                boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 6))],
              ),
              child: Text(code, style: gzFont(46, color: GzC.navy, shadow: 0, spacing: 8)),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: GameButton(
              color: GzC.green,
              height: 52,
              onTap: onShare,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.shareNetwork(PhosphorIconsStyle.fill), color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('SEND TO A FRIEND', style: gzFont(17)),
                ],
              ),
            ),
          ),
        ] else
          Text('WAITING FOR PLAYERS', style: gzFont(26)),
        const SizedBox(height: 22),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: [
                for (var i = 0; i < math.max(players.length, math.min(max, 6)); i++)
                  i < players.length
                      ? GzPlayerBadge(
                          key: ValueKey('p${players[i]['id']}'),
                          face: GzFace.from(players[i]['avatar']),
                          name: players[i]['me'] == true ? 'You' : '${players[i]['name']}',
                          size: 76,
                          ring: players[i]['me'] == true ? GzC.goldLight : GzC.sky,
                        ).popIn(calm: calm)
                      : _EmptySeat(),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            children: [
              if (!friend || g.group) _LobbyTimer(m: m, until: until, text: g.group ? 'Bots fill the empty seats in' : 'Starting in'),
              if (friend && host) ...[
                const SizedBox(height: 10),
                GameButton(
                  color: GzC.gold,
                  height: 60,
                  onTap: players.where((p) => p['bot'] != true).length >= 2 || g.group ? onStart : null,
                  child: Text(
                    players.where((p) => p['bot'] != true).length >= 2 || g.group ? 'START NOW' : 'WAITING FOR YOUR FRIEND',
                    style: gzFont(20, color: GzC.navy, shadow: 0),
                  ),
                ),
              ] else if (friend)
                Text('Waiting for the host to start…', style: gzBody(14, color: GzC.subLight)),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptySeat extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: GzC.ink.withValues(alpha: .5),
          border: Border.all(color: GzC.line, width: 3),
        ),
        child: Icon(PhosphorIcons.userPlus(PhosphorIconsStyle.bold), color: GzC.line, size: 30),
      ),
      const SizedBox(height: 6),
      Text('OPEN', style: gzFont(13, color: GzC.sub)),
    ],
  );
}

class _LobbyTimer extends StatefulWidget {
  const _LobbyTimer({required this.m, required this.until, required this.text});
  final GzMatch m;
  final int until;
  final String text;
  @override
  State<_LobbyTimer> createState() => _LobbyTimerState();
}

class _LobbyTimerState extends State<_LobbyTimer> {
  late final _t = Stream.periodic(const Duration(milliseconds: 500));
  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _t,
    builder: (_, _) {
      final left = math.max(0, ((widget.until - widget.m.now()) / 1000).ceil());
      if (left > 120) return const SizedBox.shrink();
      return Text('${widget.text} $left s', style: gzFont(18, color: GzC.goldLight));
    },
  );
}
