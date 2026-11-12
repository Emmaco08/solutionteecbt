import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../ui/confetti.dart';
import '../../ui/kit.dart' show toast;
import '../../widgets/math_text.dart';
import '../community/community_data.dart' show Json, asJson, asList;
import 'gz_avatar.dart';
import 'gz_data.dart';
import 'gz_fx.dart';
import 'gz_hub.dart';
import 'gz_scenes.dart';
import 'gz_sound.dart';
import 'gz_theme.dart';

// Results (D-157): victory ribbon, stars, the treasure chest with XP, rating change, every question to review, and
// rematch / new match / share.

class GzResults extends StatefulWidget {
  const GzResults({super.key, required this.m});
  final GzMatch m;
  @override
  State<GzResults> createState() => _GzResultsState();
}

class _GzResultsState extends State<GzResults> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_win) {
      GzFeel.win();
    } else {
      GzFeel.sfx(GzSfx.lose);
    }
    if (v.xp > 0) Future.delayed(const Duration(milliseconds: 1500), () => GzFeel.sfx(GzSfx.coin));
  }

  GzMatchView get v => GzMatchView(widget.m.s ?? const {});

  bool get _win => v.myPlace == 1;

  Future<void> _rematch() async {
    setState(() => _busy = true);
    try {
      final r = await GzMatch.rematch(v.id);
      if (!mounted) return;
      if (r['match'] != null) context.pushReplacement('/games/m/${r['match']}');
    } catch (e) {
      if (mounted) toast(context, gzErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final g = GzGame.of(v.game);
    final text = _win
        ? 'I just won ${g.name} on SolutionTee CBT with ${gzNum(v.myScore)} points! Can you beat me? https://cbt.solutiontee.com'
        : 'I just played ${g.name} on SolutionTee CBT. Come and play with me! https://cbt.solutiontee.com';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final v = this.v;
    final g = GzGame.of(v.game);
    final win = _win;
    final calm = context.calm;
    final group = v.players.length > 2 && v.game != 'relay';
    final title = switch (v.game) {
      'relay' => win ? 'YOUR TEAM WINS!' : 'GOOD GAME',
      _ when group => win ? 'CHAMPION!' : '${gzOrdinal(v.myPlace)} PLACE',
      _ => win ? 'VICTORY!' : (v.draw ? 'DRAW!' : 'GOOD GAME'),
    };
    final stars = v.stars;
    final opp = v.players.firstWhere((p) => p['me'] != true, orElse: () => const {});
    return Stack(
      children: [
        Positioned.fill(
          child: win
              ? const ArenaScene(top: Color(0xFF5C3A0E), mid: Color(0xFF2A1A05), glow: GzC.goldLight)
              : const ArenaScene(top: Color(0xFF13234A), mid: Color(0xFF0B1F44), glow: GzC.sky, beams: false),
        ),
        if (win) const Positioned(top: -60, left: 0, right: 0, child: Center(child: SunRays(size: 460))),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: RibbonBanner(
                  text: title,
                  color: win ? GzC.brand : GzC.sky,
                  width: 300,
                ).animate().scale(begin: Offset(calm ? 1 : .2, calm ? 1 : .2), duration: 520.ms, curve: Curves.elasticOut),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Transform.rotate(
                      angle: (i - 1) * .2,
                      child: Padding(
                        padding: EdgeInsets.only(top: i == 1 ? 0 : 12),
                        child: GzStar(size: i == 1 ? 58 : 44, on: i < stars).popIn(delay: (400 + 220 * i).ms, calm: calm),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 180,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        (calm || !win
                            ? GzPortrait(face: GzFace.from(v.me['avatar']), size: 128, ring: GzC.goldLight, name: 'You', mood: win ? 'grin' : 'smile')
                            : GzPortrait(
                                face: GzFace.from(v.me['avatar']),
                                size: 128,
                                ring: GzC.goldLight,
                                name: 'You',
                                mood: 'grin',
                              ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: -10, duration: 500.ms, curve: Curves.easeOut)),
                        const SizedBox(height: 6),
                        Text('YOU', style: gzFont(18)),
                      ],
                    ),
                    const TreasureChest(size: 160),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Tile(big: '+${v.xp} XP', small: v.xp > 0 ? (win ? 'win + play' : 'for playing') : 'no XP', color: GzC.goldLight, count: v.xp),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: v.ratingDelta != null
                        ? _Tile(
                            big: '${v.ratingDelta! >= 0 ? '+' : ''}${v.ratingDelta}',
                            small: 'rating ${gzNum((v.ratingBefore ?? 1000) + v.ratingDelta!)}',
                            color: v.ratingDelta! >= 0 ? GzC.mint : GzC.pink,
                          )
                        : _Tile(big: gzNum(v.myScore), small: 'points', color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Tile(
                      big: v.game == 'memory' ? '${v.myPlace}/${v.players.length}' : '${v.correct}/${v.answered}',
                      small: v.speedText,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (v.ratingDelta != null) ...[const SizedBox(height: 12), _RankPanel(rating: (v.ratingBefore ?? 1000) + v.ratingDelta!)],
              if (group || v.game == 'relay') ...[
                const SizedBox(height: 14),
                Text(v.game == 'relay' ? 'TEAMS' : 'STANDINGS', style: gzFont(17)),
                const SizedBox(height: 8),
                for (final p in v.standings.take(group ? 6 : 6)) _StandRow(p: p, relay: v.game == 'relay'),
              ] else if (opp.isNotEmpty) ...[
                const SizedBox(height: 14),
                _VsLine(me: v.me, opp: opp),
              ],
              if (v.review.isNotEmpty) ...[
                const SizedBox(height: 14),
                GzPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR ANSWERS', style: gzFont(15)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          for (final (i, r) in v.review.indexed)
                            Semantics(
                              button: true,
                              label: 'Question ${i + 1}, ${r['correct'] == true ? 'right' : 'wrong'}',
                              child: GestureDetector(
                                onTap: () => _showReview(context, r, i, g),
                                child: Container(
                                  width: 30,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: r['correct'] == true ? GzC.green : (r['answered'] == true ? GzC.red : GzC.line),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(color: GzC.ink, width: 2),
                                  ),
                                  child: Text('${i + 1}', style: gzFont(12, shadow: 0)),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap a square to see the question and the right answer.',
                        style: gzBody(12, color: GzC.sub, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              GameButton(
                color: GzC.gold,
                depthColor: GzC.goldDeep,
                height: 64,
                radius: 20,
                depth: 7,
                onTap: _busy ? null : _rematch,
                child: Text(
                  opp.isNotEmpty && !group && v.game != 'relay' ? 'REMATCH ${'${opp['name']}'.toUpperCase()}' : 'PLAY AGAIN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: gzFont(24, color: GzC.navy, shadow: 0, spacing: 1),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: GameButton(
                      color: GzC.blue,
                      height: 52,
                      onTap: () => context.pop(),
                      child: Text('NEW MATCH', style: gzFont(17)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GameButton(
                      color: GzC.purple,
                      height: 52,
                      onTap: _share,
                      child: Text(win ? 'SHARE WIN' : 'SHARE', style: gzFont(17)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (win)
          const Positioned.fill(
            child: IgnorePointer(child: Confetti(delay: Duration(milliseconds: 500), pieces: 90)),
          ),
      ],
    );
  }

  void _showReview(BuildContext context, Json r, int i, GzGame g) {
    final item = asJson(r['item']);
    final key = '${r['key']}';
    final opts = asList(item['options']);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
        decoration: const BoxDecoration(
          color: GzC.navy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: GzC.ink, width: 4)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('QUESTION ${i + 1}', style: gzFont(20)),
              const SizedBox(height: 10),
              if (g.id == 'words') ...[
                Text('${item['body'] ?? ''}', style: gzBody(13, color: GzC.subLight)),
                if (item['word'] != null) Text('${item['word']}'.toUpperCase(), style: gzFont(26)),
              ] else
                MathText('${item['body'] ?? ''}', style: gzBody(16, height: 1.4)),
              const SizedBox(height: 12),
              for (final (j, o) in opts.indexed)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: '${o['key']}' == key ? GzC.green : ('${o['key']}' == r['choice'] ? GzC.wrong : GzC.ink.withValues(alpha: .5)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GzC.ink, width: 2),
                  ),
                  child: Row(
                    children: [
                      Text('${String.fromCharCode(65 + j)}  ', style: gzFont(15, shadow: 0)),
                      Expanded(child: MathText('${o['text']}', style: gzBody(15))),
                      if ('${o['key']}' == key) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      if ('${o['key']}' == r['choice'] && '${o['key']}' != key) const Icon(Icons.cancel_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              if (r['answered'] != true) Text('You did not answer this one in time.', style: gzBody(13, color: GzC.sub)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reads the finished match for the results screen.
class GzMatchView {
  GzMatchView(this.s);
  final Json s;

  String get id => '${s['id']}';
  String get game => '${s['game']}';
  Json get me => asJson(s['me']);
  List<Json> get players => asList(s['players']);
  List<Json> get review => asList(s['review']);
  int get myPlace => gzMs(me['place']) ?? 0;
  int get myScore => gzMs(me['score']) ?? 0;
  int get xp => gzMs(me['xp']) ?? 0;
  int get correct => gzMs(me['correct']) ?? 0;
  int get answered => math.max(gzMs(me['answered']) ?? 0, game == 'blitz' || game == 'rush' ? (gzMs(me['answered']) ?? 0) : review.length);
  int? get ratingDelta => s['mode'] == 'ranked' ? gzMs(me['rating_delta']) : null;
  int? get ratingBefore => gzMs(me['rating']);
  bool get draw => players.length == 2 && players.every((p) => gzMs(p['place']) == 1);

  int get stars {
    if (game == 'memory') return myPlace == 1 ? 3 : 2;
    final n = math.max(1, answered);
    final acc = correct / n;
    return acc >= .8 ? 3 : (acc >= .5 ? 2 : (correct > 0 ? 1 : 0));
  }

  String get speedText {
    if (game == 'memory') return 'place';
    final ms = review.where((r) => r['correct'] == true && r['ms'] != null).map((r) => gzMs(r['ms']) ?? 0).toList();
    if (ms.isEmpty) return 'right';
    final avg = ms.reduce((a, b) => a + b) / ms.length / 1000;
    return '${avg.toStringAsFixed(1)} s each';
  }

  List<Json> get standings {
    if (game == 'relay') {
      int team(int t) => players.where((p) => gzMs(p['team']) == t).fold(0, (s, p) => s + (gzMs(p['score']) ?? 0));
      return [
        {'name': 'BLUE TEAM', 'score': team(1), 'place': team(1) >= team(2) ? 1 : 2, 'me': gzMs(me['team']) == 1, 'team': 1},
        {'name': 'RED TEAM', 'score': team(2), 'place': team(2) > team(1) ? 1 : 2, 'me': gzMs(me['team']) == 2, 'team': 2},
      ]..sort((a, b) => (a['place'] as int).compareTo(b['place'] as int));
    }
    final l = [...players]..sort((a, b) => (gzMs(a['place']) ?? 99).compareTo(gzMs(b['place']) ?? 99));
    final top = l.take(5).toList();
    if (!top.any((p) => p['me'] == true)) top.add(l.firstWhere((p) => p['me'] == true, orElse: () => const {}));
    return top.where((p) => p.isNotEmpty).toList();
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.big, required this.small, required this.color, this.count});
  final String big;
  final String small;
  final Color color;
  final int? count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    decoration: BoxDecoration(
      color: GzC.navy,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: GzC.ink, width: 3),
      boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 5))],
    ),
    child: Column(
      children: [
        FittedBox(
          child: count != null && !context.calm
              ? TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: count!),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Text('+$v XP', style: gzFont(24, color: color)),
                )
              : Text(big, style: gzFont(24, color: color)),
        ),
        Text(
          small,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: gzBody(12, color: GzC.sub),
        ),
      ],
    ),
  );
}

class _RankPanel extends StatelessWidget {
  const _RankPanel({required this.rating});
  final int rating;
  @override
  Widget build(BuildContext context) {
    final r = GzRank.of(rating);
    return GzPanel(
      child: Column(
        children: [
          Row(
            children: [
              RankShield(color: r.color, text: r.division == 0 ? 'D' : ['', 'I', 'II', 'III'][r.division], size: 34),
              const SizedBox(width: 8),
              Text(r.label, style: gzFont(16)),
              const Spacer(),
              if (r.toNext > 0) Text('${r.toNext} TO ${r.next}', style: gzFont(14, color: GzC.goldLight)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 14,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: GzC.navy2,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: GzC.line, width: 1.5),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: r.progress.clamp(.03, 1)),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: r.color, borderRadius: BorderRadius.circular(7)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StandRow extends StatelessWidget {
  const _StandRow({required this.p, required this.relay});
  final Json p;
  final bool relay;
  @override
  Widget build(BuildContext context) {
    final place = gzMs(p['place']) ?? 0;
    final me = p['me'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        decoration: BoxDecoration(
          color: me ? GzC.navy2 : GzC.ink.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: me ? GzC.brand : GzC.line, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: place == 1 ? GzC.brand : (place == 2 ? const Color(0xFFC9D6EA) : (place == 3 ? const Color(0xFFCD7F4A) : GzC.navy)),
                shape: BoxShape.circle,
                border: Border.all(color: GzC.ink, width: 2),
              ),
              child: Text('$place', style: gzFont(15, color: place <= 3 ? GzC.navy : Colors.white, shadow: 0)),
            ),
            const SizedBox(width: 8),
            if (!relay) ...[GzPortrait(face: GzFace.from(p['avatar']), size: 36, ring: me ? GzC.goldLight : GzC.sky, bot: false), const SizedBox(width: 8)],
            Expanded(
              child: Text(
                relay ? '${p['name']}${me ? ' (YOU)' : ''}' : (me ? 'YOU' : '${p['name']}'.toUpperCase()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: gzFont(15, color: relay ? (gzMs(p['team']) == 1 ? GzC.sky : const Color(0xFFFF8FA8)) : Colors.white),
              ),
            ),
            if (p['bot'] == true)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GzTag('BOT', color: GzC.cyan, size: 10),
              ),
            Text(gzNum(gzMs(p['score']) ?? 0), style: gzFont(15, color: GzC.goldLight)),
          ],
        ),
      ),
    );
  }
}

class _VsLine extends StatelessWidget {
  const _VsLine({required this.me, required this.opp});
  final Json me;
  final Json opp;
  @override
  Widget build(BuildContext context) => GzPanel(
    child: Row(
      children: [
        Expanded(
          child: Text('YOU ${gzNum(gzMs(me['score']) ?? 0)}', style: gzFont(17, color: GzC.goldLight)),
        ),
        Text('VS', style: gzFont(15, color: GzC.sub)),
        Expanded(
          child: Text(
            textAlign: TextAlign.right,
            '${'${opp['name']}'.toUpperCase()} ${gzNum(gzMs(opp['score']) ?? 0)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: gzFont(17, color: const Color(0xFFFFB3C3)),
          ),
        ),
      ],
    ),
  );
}
