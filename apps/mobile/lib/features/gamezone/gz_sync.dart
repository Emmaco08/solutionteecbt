import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../widgets/math_text.dart';
import '../community/community_data.dart' show Json, asJson, asList;
import 'gz_avatar.dart';
import 'gz_data.dart';
import 'gz_fx.dart';
import 'gz_match.dart';
import 'gz_scenes.dart';
import 'gz_sound.dart';
import 'gz_theme.dart';

// Round games (D-157): JAMB Duel, Word War, Knowledge Survival and Team Relay. Everybody gets the same question at
// the same moment (server clock); the right option is shown when the round closes.

class GzSyncPlay extends StatefulWidget {
  const GzSyncPlay({super.key, required this.m, required this.onLeave});
  final GzMatch m;
  final VoidCallback onLeave;
  @override
  State<GzSyncPlay> createState() => _GzSyncPlayState();
}

class _GzSyncPlayState extends State<GzSyncPlay> {
  GzMatch get m => widget.m;
  late int _hits = m.hits;
  late int _misses = m.misses;
  int _fx = 0;
  String? _pop;
  Color _popColor = GzC.goldLight;
  bool _good = false;
  final Map<int, bool> _history = {};

  @override
  void initState() {
    super.initState();
    m.addListener(_watch);
  }

  @override
  void dispose() {
    m.removeListener(_watch);
    super.dispose();
  }

  void _watch() {
    final r = m.result;
    if (m.hits != _hits) {
      _hits = m.hits;
      final pts = gzMs(r?['points']) ?? 0;
      final ms = gzMs(r?['ms']) ?? 99999;
      final combo = gzMs(r?['combo']) ?? 0;
      _pop = '+$pts${ms < m.seconds * 350 ? ' FAST!' : (combo >= 3 ? ' x$combo!' : '')}';
      _popColor = GzC.goldLight;
      _good = true;
      _fx++;
      GzFeel.right();
      if (combo == 3 || combo == 5) Future.delayed(const Duration(milliseconds: 250), () => GzFeel.sfx(GzSfx.combo, volume: .7));
    } else if (m.misses != _misses) {
      _misses = m.misses;
      _pop = m.game == 'survival' ? '-1 HEART' : 'MISSED!';
      _popColor = const Color(0xFFFF8FA8);
      _good = false;
      _fx++;
      GzFeel.wrong();
    }
    final idx = gzMs(m.round?['idx']);
    if (idx != null && r != null && r['correct'] != null) _history[idx] = r['correct'] == true;
    final last = m.last;
    if (last != null) {
      final myId = m.me['id'];
      for (final x in asList(last['results'])) {
        if (x['p'] == myId) _history[gzMs(last['idx']) ?? -1] = x['correct'] == true;
      }
      final li = gzMs(last['idx']);
      if (li != null && !_history.containsKey(li)) _history[li] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = m.game;
    final round = m.round ?? const {};
    final idx = gzMs(round['idx']) ?? 0;
    final open = gzMs(round['open_at']) ?? 0;
    final close = gzMs(round['close_at']) ?? 0;
    final item = round['item'] == null ? null : asJson(round['item']);
    final live = item != null && m.now() >= open;
    final me = m.me;
    final dead = me['alive'] == false;
    final subject = (m.s?['subject'] as Map?)?['name'];

    final bg = switch (game) {
      'words' => const CastleScene(),
      'survival' => LavaScene(level: (idx / math.max(1, m.rounds)).clamp(0, 1).toDouble()),
      'relay' => const ArenaScene(top: Color(0xFF0D2A53), mid: Color(0xFF13234A), glow: GzC.cyan),
      _ => const ArenaScene(top: Color(0xFF3A0E3F), mid: Color(0xFF13234A), glow: GzC.pink),
    };

    final answered = m.picked != null && m.picked!.idx == idx || round['mine'] != null;

    return Stack(
      children: [
        Positioned.fill(child: bg),
        SafeArea(
          child: Column(
            children: [
              GzTopBar(onLeave: widget.onLeave, center: _hud(idx, open, close, live, answered)),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(child: _stage(live)),
                    if (_pop != null)
                      Positioned(
                        top: 4,
                        child: KeyedSubtree(
                          key: ValueKey('pop$_fx'),
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              if (_good) const Positioned(child: Burst(size: 240)),
                              ScorePop(text: _pop!, color: _popColor),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (game != 'survival') _RoundDots(rounds: m.rounds, current: idx, history: _history),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .64, minHeight: 200),
                child: AnimatedSwitcher(
                  layoutBuilder: (cur, prev) => Stack(alignment: Alignment.bottomCenter, children: [...prev, ?cur]),
                  duration: context.calm ? Duration.zero : const Duration(milliseconds: 320),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(a),
                      child: c,
                    ),
                  ),
                  child: dead
                      ? _Fallen(key: const ValueKey('dead'), round: gzMs(me['out_round']), onLeave: widget.onLeave)
                      : live
                      ? _QuestionArea(
                          key: ValueKey('q$idx'),
                          m: m,
                          idx: idx,
                          item: item,
                          label:
                              '${game == 'words' ? 'ROUND' : 'ROUND'} ${idx + 1}${subject != null && game != 'words' ? ' · ${'$subject'.toUpperCase()}' : ''}',
                          shake: !_good ? _fx : 0,
                        )
                      : _Reveal(key: ValueKey('r$idx'), m: m, nextIdx: idx),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- top HUD

  Widget _hud(int idx, int open, int close, bool live, bool answered) {
    // Between rounds the ring counts down to the next question instead of sitting at 0.
    final ring = live
        ? TimerRing(now: m.now, from: open, to: math.max(open + 1, close), size: 58)
        : TimerRing(key: ValueKey('next$open'), now: m.now, from: open - (gzMs(m.s?['gap_ms']) ?? 3500), to: open, size: 58, ticks: false);
    final players = m.players;
    switch (m.game) {
      case 'survival':
        final alive = players.where((p) => p['alive'] == true).length;
        final lives = gzMs(m.me['lives']) ?? 0;
        return Row(
          children: [
            GzTag('ROUND ${idx + 1}', color: GzC.ink.withValues(alpha: .75), border: GzC.goldLight, size: 14),
            Expanded(
              child: Text('$alive OF ${players.length} LEFT', textAlign: TextAlign.center, style: gzFont(15)),
            ),
            Semantics(
              label: '$lives of 3 hearts left',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(color: GzC.ink.withValues(alpha: .75), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [for (var i = 0; i < 3; i++) HeartIcon2(full: i < lives, size: 20)]),
              ),
            ),
            const SizedBox(width: 6),
            ring,
          ],
        );
      case 'relay':
        int team(int t) => players.where((p) => gzMs(p['team']) == t).fold(0, (s, p) => s + (gzMs(p['score']) ?? 0));
        final a = team(1), b = team(2);
        return Row(
          children: [
            Expanded(
              child: _ScoreSide(name: 'BLUE', score: a, of: math.max(1, a + b), color: GzC.sky, left: true),
            ),
            const SizedBox(width: 8),
            ring,
            const SizedBox(width: 8),
            Expanded(
              child: _ScoreSide(name: 'RED', score: b, of: math.max(1, a + b), color: GzC.pink, left: false),
            ),
          ],
        );
      default:
        final me = m.me;
        final opp = players.firstWhere((p) => p['me'] != true, orElse: () => const {});
        final max = math.max(1, m.rounds * 150);
        return Row(
          children: [
            Expanded(
              child: _ScoreSide(name: 'YOU', score: gzMs(me['score']) ?? 0, of: max, color: GzC.goldLight, left: true),
            ),
            const SizedBox(width: 8),
            ring,
            const SizedBox(width: 8),
            Expanded(
              child: _ScoreSide(name: '${opp['name'] ?? ''}'.toUpperCase(), score: gzMs(opp['score']) ?? 0, of: max, color: GzC.pink, left: false),
            ),
          ],
        );
    }
  }

  // ---------------------------------------------------------------- stage

  Widget _stage(bool live) {
    final players = m.players;
    final last = m.last;
    final lastRes = {for (final x in asList(last?['results'])) x['p']: x['correct'] == true};
    final showLast = !live && last != null;
    switch (m.game) {
      case 'survival':
        return _Islands(players: players, lastRes: showLast ? lastRes : const {});
      case 'relay':
        return Row(
          children: [
            for (final t in const [1, 2])
              Expanded(
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in players.where((p) => gzMs(p['team']) == t))
                        _Seat(p: p, size: 58, ring: t == 1 ? GzC.sky : GzC.pink, result: showLast ? lastRes[p['id']] : null, live: live),
                    ],
                  ),
                ),
              ),
          ],
        );
      default:
        final me = players.firstWhere((p) => p['me'] == true, orElse: () => const {});
        final opp = players.firstWhere((p) => p['me'] != true, orElse: () => const {});
        final r = m.result;
        final myMood = r == null ? 'focus' : (r['correct'] == true ? 'grin' : 'focus');
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Seat(p: me, size: 104, ring: GzC.goldLight, result: showLast ? lastRes[me['id']] : null, live: live, mood: myMood, bounce: _good ? _fx : 0),
              if (m.game == 'words') Text('VS', style: gzFont(30, color: const Color(0xFFD7B4F0))),
              _Seat(p: opp, size: 104, ring: GzC.pink, result: showLast ? lastRes[opp['id']] : null, live: live),
            ],
          ),
        );
    }
  }
}

class _ScoreSide extends StatelessWidget {
  const _ScoreSide({required this.name, required this.score, required this.of, required this.color, required this.left});
  final String name;
  final int score;
  final int of;
  final Color color;
  final bool left;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: left ? CrossAxisAlignment.start : CrossAxisAlignment.end,
    children: [
      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: gzFont(14)),
      const SizedBox(height: 2),
      Container(
        height: 14,
        decoration: BoxDecoration(
          color: GzC.ink,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: GzC.navy, width: 2),
        ),
        child: Align(
          alignment: left ? Alignment.centerLeft : Alignment.centerRight,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (score / of).clamp(0.03, 1).toDouble()),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => FractionallySizedBox(
              widthFactor: v,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
              ),
            ),
          ),
        ),
      ),
      TweenAnimationBuilder<int>(
        tween: IntTween(end: score),
        duration: const Duration(milliseconds: 600),
        builder: (_, v, _) => Text(gzNum(v), style: gzFont(18, color: Color.lerp(color, Colors.white, .35)!)),
      ),
    ],
  );
}

/// A player portrait with an "answered" tick while the round is open, and right/wrong after it.
class _Seat extends StatelessWidget {
  const _Seat({required this.p, required this.size, required this.ring, required this.result, required this.live, this.mood, this.bounce = 0});
  final Json p;
  final double size;
  final Color ring;
  final bool? result;
  final bool live;
  final String? mood;
  final int bounce;

  @override
  Widget build(BuildContext context) {
    if (p.isEmpty) return SizedBox(width: size);
    final cur = p['cur'] == true;
    Widget pic = GzPortrait(
      face: GzFace.from(p['avatar']),
      size: size,
      ring: ring,
      name: '${p['name']}',
      bot: p['bot'] == true,
      dim: p['alive'] == false,
      mood: mood ?? (result == true ? 'grin' : (live ? 'focus' : null)),
    );
    if (bounce > 0 && !context.calm) {
      pic = pic
          .animate(key: ValueKey('b$bounce'))
          .moveY(begin: 0, end: -16, duration: 180.ms, curve: Curves.easeOut)
          .then()
          .moveY(end: 0, duration: 260.ms, curve: Curves.bounceOut);
    }
    final badge = live
        ? (cur ? _Bubble(text: 'DONE', color: GzC.mint) : null)
        : (result == null ? null : _Bubble(text: result! ? 'RIGHT' : 'MISS', color: result! ? GzC.mint : GzC.pink));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            pic,
            if (badge != null)
              Positioned(
                right: -6,
                top: -6,
                child: badge.animate().scale(begin: const Offset(.3, .3), duration: 260.ms, curve: Curves.easeOutBack),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size * 1.4),
          child: Text(p['me'] == true ? 'YOU' : '${p['name']}'.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: gzFont(size > 80 ? 16 : 12)),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: GzC.ink, width: 2),
      boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 2))],
    ),
    child: Text(text, style: gzFont(11, color: GzC.navy, shadow: 0)),
  );
}

class _RoundDots extends StatelessWidget {
  const _RoundDots({required this.rounds, required this.current, required this.history});
  final int rounds;
  final int current;
  final Map<int, bool> history;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Round ${current + 1} of $rounds',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < rounds; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: i == current ? 28 : 20,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: history[i] == null ? (i == current ? Colors.white : Colors.white.withValues(alpha: .25)) : (history[i]! ? GzC.mint : GzC.pink),
            ),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- Survival islands

class _Islands extends StatefulWidget {
  const _Islands({required this.players, required this.lastRes});
  final List<Json> players;
  final Map<Object?, bool> lastRes;
  @override
  State<_Islands> createState() => _IslandsState();
}

class _IslandsState extends State<_Islands> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final players = [...widget.players]..sort((a, b) => (b['me'] == true ? 1 : 0) - (a['me'] == true ? 1 : 0));
    return LayoutBuilder(
      builder: (context, box) {
        final n = players.length;
        final cols = n <= 6 ? 3 : (n <= 12 ? 4 : 5);
        final rows = (n / cols).ceil();
        final cw = box.maxWidth / cols;
        final rh = box.maxHeight / math.max(rows, 1);
        final size = math.min(cw * .62, rh * .62).clamp(30.0, 64.0);
        return AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Stack(children: [for (var i = 0; i < n; i++) _island(players[i], i, cols, cw, rh, size)]),
        );
      },
    );
  }

  Widget _island(Json p, int i, int cols, double cw, double rh, double size) {
    final alive = p['alive'] != false;
    final me = p['me'] == true;
    final row = i ~/ cols, col = i % cols;
    final bob = context.calm ? 0.0 : math.sin((_c.value + i * .17) * math.pi * 2) * 4;
    final x = col * cw + (cw - size * 1.3) / 2 + (row.isOdd ? cw * .12 : 0);
    final y = row * rh + (rh - size * 1.5) / 2 + bob;
    final res = widget.lastRes[p['id']];
    final lives = gzMs(p['lives']) ?? 3;
    return AnimatedPositioned(
      key: ValueKey(p['id']),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeIn,
      left: x,
      top: alive ? y : y + rh * 2,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 900),
        opacity: alive ? 1 : 0,
        child: SizedBox(
          width: size * 1.3,
          height: size * 1.55,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 0,
                child: CustomPaint(
                  size: Size(size * 1.3, size * .6),
                  painter: IslandPainter(cracked: lives <= 1),
                ),
              ),
              GzPortrait(
                face: GzFace.from(p['avatar']),
                size: size,
                ring: me ? GzC.goldLight : (res == false ? GzC.pink : GzC.sky),
                name: '${p['name']}',
                mood: res == true ? 'grin' : null,
              ),
              if (res != null)
                Positioned(
                  right: -4,
                  top: -4,
                  child: _Bubble(text: res ? '✓' : '−1', color: res ? GzC.mint : GzC.pink),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- question and options

class _QuestionArea extends StatelessWidget {
  const _QuestionArea({super.key, required this.m, required this.idx, required this.item, required this.label, required this.shake});
  final GzMatch m;
  final int idx;
  final Json item;
  final String label;
  final int shake;

  @override
  Widget build(BuildContext context) {
    final opts = asList(item['options']);
    final picked = m.picked != null && m.picked!.idx == idx ? m.picked!.choice : (m.round?['mine'] as Map?)?['choice'] as String?;
    final res = m.result ?? (m.round?['mine'] == null ? null : asJson(m.round!['mine']));
    final key = res?['key'] as String?;
    final late = res?['late'] == true;
    final words = m.game == 'words';
    final long = opts.any((o) => '${o['text']}'.length > 26);
    Widget grid = long
        ? Column(
            children: [
              for (final (i, o) in opts.indexed) Padding(padding: const EdgeInsets.only(bottom: 4), child: _option(context, i, o, picked, key, words, 60)),
            ],
          )
        : GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 10,
            childAspectRatio: words ? 2.5 : 2.05,
            children: [for (final (i, o) in opts.indexed) _option(context, i, o, picked, key, words, null)],
          );
    if (shake > 0 && !context.calm) grid = grid.animate(key: ValueKey('s$shake')).shakeX(hz: 6, amount: 6, duration: 360.ms);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: words ? _WordCard(item: item, label: label) : _QuestionCard(text: '${item['body'] ?? ''}', label: label),
          ),
          const SizedBox(height: 12),
          grid,
          if (late)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Too late for this one. Get ready for the next!', style: gzBody(13, color: const Color(0xFFFFB3C3))),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _Tip(game: m.game),
            ),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, int i, Json o, String? picked, String? key, bool words, double? height) {
    final k = '${o['key']}';
    final isRight = key != null && k == key;
    final isWrong = picked == k && key != null && k != key;
    final waiting = picked == k && key == null;
    final dim = picked != null && !isRight && !isWrong && !waiting;
    final color = isRight ? GzC.green : (isWrong ? GzC.wrong : GzC.options[i % 4]);
    final letter = String.fromCharCode(65 + i);
    Widget b = GameButton(
      color: color,
      height: height,
      radius: 16,
      depth: 6,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      glow: isRight ? GzC.mint : (waiting ? GzC.goldLight : null),
      semantics: 'Option $letter',
      onTap: picked == null ? () => m.answerRound(idx, k) : null,
      haptic: true,
      child: Row(
        children: [
          if (!words) ...[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: GzC.ink.withValues(alpha: .3), borderRadius: BorderRadius.circular(8)),
              child: Text(letter, style: gzFont(15, shadow: 0)),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: words
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('${o['text']}'.toUpperCase(), style: gzFont(19)),
                  )
                : _optionText('${o['text']}'),
          ),
        ],
      ),
    );
    if (isRight || isWrong) {
      b = Stack(
        clipBehavior: Clip.none,
        children: [
          b,
          Positioned(
            right: -4,
            top: -6,
            child: Container(
              decoration: BoxDecoration(
                color: isRight ? GzC.mint : GzC.pink,
                shape: BoxShape.circle,
                border: Border.all(color: GzC.ink, width: 2.5),
              ),
              child: Icon(isRight ? Icons.check_rounded : Icons.close_rounded, color: GzC.navy, size: 18),
            ),
          ),
        ],
      );
    }
    if (dim) b = Opacity(opacity: .45, child: b);
    if (isRight && !context.calm) b = b.animate().scale(begin: const Offset(1.08, 1.08), duration: 280.ms, curve: Curves.easeOutBack);
    return b;
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.game});
  final String game;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: GzC.ink.withValues(alpha: .8),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: GzC.line, width: 2),
    ),
    child: Row(
      children: [
        Icon(Icons.bolt_rounded, color: GzC.goldLight, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(switch (game) {
            'survival' => 'A wrong or late answer costs a heart. Lose all 3 and your island falls.',
            'relay' => 'Right answers in a row add a team bonus. Keep the baton moving!',
            'words' => 'Answer fast: the quicker right answer scores more.',
            _ => 'The faster right answer scores more. 3 in a row builds your combo.',
          }, style: gzBody(12, color: GzC.subLight)),
        ),
      ],
    ),
  );
}

/// One long word ("Mitochondrion") shrinks to fit instead of breaking across lines.
Widget _optionText(String t) {
  final style = gzBody(15, height: 1.2);
  if (!t.contains(' ') && !t.contains(r'$') && t.length > 9) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(t, maxLines: 1, style: style),
    );
  }
  return MathText(t, style: style, textAlign: TextAlign.left);
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.text, required this.label});
  final String text;
  final String label;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.topCenter,
    children: [
      Container(
        margin: const EdgeInsets.only(top: 14),
        width: double.infinity,
        decoration: BoxDecoration(
          color: GzC.cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GzC.ink, width: 4),
          boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 6))],
        ),
        child: SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
          child: MathText(
            text,
            textAlign: TextAlign.center,
            style: gzBody(17, color: GzC.navy, height: 1.4),
          ),
        ),
      ),
      GzTag(label, color: GzC.blue, size: 13),
    ],
  );
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.item, required this.label});
  final Json item;
  final String label;
  @override
  Widget build(BuildContext context) {
    final spelling = item['kind'] == 'spelling';
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 14),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          decoration: BoxDecoration(
            color: GzC.cream,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GzC.ink, width: 4),
            boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${item['body'] ?? ''}'.toUpperCase(), style: gzBody(13, color: GzC.navy)),
              const SizedBox(height: 4),
              if (!spelling)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${item['word'] ?? ''}'.toUpperCase(), style: gzFont(38, color: GzC.navy, shadow: 0, spacing: 1.5)),
                )
              else
                Text('Pick the word that is spelt correctly', style: gzBody(14, color: GzC.purple)),
            ],
          ),
        ),
        GzTag(label, color: GzC.purple, size: 13),
      ],
    );
  }
}

/// Between rounds: the right answer of the round that just closed.
class _Reveal extends StatelessWidget {
  const _Reveal({super.key, required this.m, required this.nextIdx});
  final GzMatch m;
  final int nextIdx;

  @override
  Widget build(BuildContext context) {
    final last = m.last;
    final calm = context.calm;
    final openAt = gzMs(m.round?['open_at']) ?? 0;
    final next = nextIdx >= m.rounds ? 'RESULTS COMING' : (nextIdx == 0 ? 'GET READY!' : 'ROUND ${nextIdx + 1}');
    final countdown = _NextIn(m: m, at: openAt, label: next);
    if (last == null || last['item'] == null) {
      return Center(child: countdown);
    }
    final item = asJson(last['item']);
    final key = '${last['key']}';
    final right = asList(item['options']).firstWhere((o) => '${o['key']}' == key, orElse: () => const {});
    final mine = asList(last['results']).firstWhere((x) => x['p'] == m.me['id'], orElse: () => const {});
    final ok = mine['correct'] == true;
    final pts = gzMs(mine['points']) ?? 0;
    final title = mine.isEmpty ? 'TIME UP!' : (ok ? 'CORRECT!' : 'WRONG!');
    final color = mine.isEmpty ? GzC.goldLight : (ok ? GzC.mint : const Color(0xFFFF8FA8));
    Widget banner = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedText(title, size: 34, color: color, stroke: 3, shadow: 4),
        if (ok && pts > 0) ...[const SizedBox(width: 10), GzTag('+$pts', color: GzC.brand, textColor: GzC.navy, size: 18)],
      ],
    );
    if (!calm) banner = banner.animate().scale(begin: const Offset(.5, .5), duration: 360.ms, curve: Curves.easeOutBack).fadeIn(duration: 140.ms);
    final words = m.game == 'words';
    Widget answer = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: GzC.green,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GzC.ink, width: 3),
        boxShadow: [
          const BoxShadow(color: GzC.ink, offset: Offset(0, 6)),
          BoxShadow(color: GzC.mint.withValues(alpha: .45), blurRadius: 16),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: GzC.mint,
              shape: BoxShape.circle,
              border: Border.all(color: GzC.ink, width: 2.5),
            ),
            child: const Icon(Icons.check_rounded, color: GzC.navy, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: words
                ? Text('${right['text'] ?? key}'.toUpperCase(), style: gzFont(22))
                : MathText('${right['text'] ?? key}', style: gzBody(17, height: 1.25)),
          ),
        ],
      ),
    );
    if (!calm) answer = answer.animate(delay: 160.ms).slideY(begin: .3, duration: 320.ms, curve: Curves.easeOutBack).fadeIn(duration: 160.ms);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          banner,
          const SizedBox(height: 10),
          Flexible(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: GzC.cream,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: GzC.ink, width: 4),
                    boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 6))],
                  ),
                  child: SingleChildScrollView(
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
                    child: words
                        ? Column(
                            children: [
                              Text('${item['body'] ?? ''}'.toUpperCase(), style: gzBody(12, color: GzC.navy)),
                              FittedBox(
                                child: Text('${item['word'] ?? ''}'.toUpperCase(), style: gzFont(30, color: GzC.navy, shadow: 0)),
                              ),
                            ],
                          )
                        : MathText(
                            '${item['body'] ?? ''}',
                            textAlign: TextAlign.center,
                            style: gzBody(15, color: GzC.navy, height: 1.35),
                          ),
                  ),
                ),
                GzTag('THE ANSWER', color: GzC.green, size: 13),
              ],
            ),
          ),
          const SizedBox(height: 14),
          answer,
          const SizedBox(height: 16),
          countdown,
        ],
      ),
    );
  }
}

/// "ROUND 7 IN 3": counts down to the next round on the server clock.
class _NextIn extends StatefulWidget {
  const _NextIn({required this.m, required this.at, required this.label});
  final GzMatch m;
  final int at;
  final String label;
  @override
  State<_NextIn> createState() => _NextInState();
}

class _NextInState extends State<_NextIn> {
  late final _t = Stream.periodic(const Duration(milliseconds: 200));
  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _t,
    builder: (_, _) {
      final left = math.max(0, ((widget.at - widget.m.now()) / 1000).ceil());
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: GzC.ink.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GzC.goldLight, width: 2.5),
          boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 4))],
        ),
        child: Text(left > 0 ? '${widget.label} IN $left' : widget.label, style: gzFont(20, color: GzC.goldLight)),
      );
    },
  );
}

class _Fallen extends StatelessWidget {
  const _Fallen({super.key, required this.round, required this.onLeave});
  final int? round;
  final VoidCallback onLeave;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: GzPanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OutlinedText('YOUR ISLAND FELL!', size: 28, color: Color(0xFFFF8FA8)),
            const SizedBox(height: 8),
            Text(
              'You lasted ${round != null ? round! + 1 : 'some'} rounds. Stay to watch who wins, or see your results when it ends.',
              textAlign: TextAlign.center,
              style: gzBody(14, color: GzC.subLight, weight: FontWeight.w500),
            ),
          ],
        ),
      ),
    ),
  );
}
