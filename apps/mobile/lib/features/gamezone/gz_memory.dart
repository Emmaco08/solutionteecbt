import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../community/community_data.dart' show Json, asList;
import 'gz_avatar.dart';
import 'gz_data.dart';
import 'gz_fx.dart';
import 'gz_match.dart';
import 'gz_scenes.dart';
import 'gz_sound.dart';
import 'gz_theme.dart';

// Memory Flash (D-157): see the cards, remember them, then match each pair. Three levels (4, 5 and 6 pairs).
// The app reports each cleared level; the server checks the moves and time are possible.

enum _Step { show, play, clear, done }

class GzMemoryPlay extends StatefulWidget {
  const GzMemoryPlay({super.key, required this.m, required this.onLeave});
  final GzMatch m;
  final VoidCallback onLeave;
  @override
  State<GzMemoryPlay> createState() => _GzMemoryPlayState();
}

class _Card {
  _Card(this.pair, this.text);
  final Object? pair;
  final String text;
  bool up = true;
  bool matched = false;
}

class _GzMemoryPlayState extends State<GzMemoryPlay> {
  GzMatch get m => widget.m;
  late int _level = (gzMs(m.me['pos']) ?? 0) + 1;
  _Step _step = _Step.show;
  List<_Card> _cards = [];
  final List<int> _open = [];
  int _moves = 0;
  int _stars = 0;
  int _fx = 0;
  bool _busy = false;
  final _clock = Stopwatch();
  Timer? _timer;
  int _showLeft = 0;

  List<Json> get _levels => asList(m.s?['levels']);

  @override
  void initState() {
    super.initState();
    _startLevel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startLevel() {
    if (_level > _levels.length || m.me['finished'] == true) {
      _step = _Step.done;
      return;
    }
    final lv = _levels[_level - 1];
    _cards = [for (final c in asList(lv['cards'])) _Card(c['pair'], '${c['text']}')];
    _open.clear();
    _moves = 0;
    _step = _Step.show;
    final pairs = gzMs(lv['pairs']) ?? 4;
    final showMs = 2500 + 450 * pairs;
    _showLeft = (showMs / 1000).ceil();
    _timer?.cancel();
    final until = DateTime.now().add(Duration(milliseconds: showMs));
    _timer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      final left = until.difference(DateTime.now()).inMilliseconds;
      if (!mounted) return t.cancel();
      if (left <= 0) {
        t.cancel();
        setState(() {
          for (final c in _cards) {
            c.up = false;
          }
          _step = _Step.play;
          _clock
            ..reset()
            ..start();
        });
      } else if ((left / 1000).ceil() != _showLeft) {
        setState(() => _showLeft = (left / 1000).ceil());
      }
    });
  }

  Future<void> _tap(int i) async {
    if (_step != _Step.play || _busy) return;
    final c = _cards[i];
    if (c.up || c.matched || _open.length >= 2) return;
    GzFeel.sfx(GzSfx.flip);
    setState(() {
      c.up = true;
      _open.add(i);
    });
    if (_open.length < 2) return;
    _moves++;
    final a = _cards[_open[0]], b = _cards[_open[1]];
    if (a.pair == b.pair) {
      HapticFeedback.mediumImpact();
      GzFeel.sfx(GzSfx.pair);
      setState(() {
        a.matched = true;
        b.matched = true;
        _open.clear();
        _fx++;
      });
      if (_cards.every((x) => x.matched)) await _clear();
    } else {
      _busy = true;
      await Future.delayed(const Duration(milliseconds: 750));
      if (!mounted) return;
      setState(() {
        a.up = false;
        b.up = false;
        _open.clear();
        _busy = false;
      });
    }
  }

  Future<void> _clear() async {
    _clock.stop();
    final pairs = _cards.length ~/ 2;
    _stars = _moves <= pairs + 1 ? 3 : (_moves <= (pairs * 1.6).round() ? 2 : 1);
    setState(() => _step = _Step.clear);
    HapticFeedback.heavyImpact();
    GzFeel.sfx(GzSfx.level);
    final r = await m.memoryLevel(_level, _moves, _clock.elapsedMilliseconds);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _level++;
      if (r?['finished'] == true || _level > _levels.length) {
        _step = _Step.done;
      } else {
        _startLevel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final opp = m.players.firstWhere((p) => p['me'] != true, orElse: () => const {});
    final oppLevel = math.min(3, gzMs(opp['pos']) ?? 0);
    final subject = (m.s?['subject'] as Map?)?['name'];
    return Stack(
      children: [
        const Positioned.fill(child: FeltScene()),
        SafeArea(
          child: Column(
            children: [
              GzTopBar(
                onLeave: widget.onLeave,
                center: Row(
                  children: [
                    GzTag('LEVEL ${math.min(_level, 3)}', color: GzC.navy, border: GzC.cyan, size: 14),
                    Expanded(
                      child: Text('MEMORY FLASH', textAlign: TextAlign.center, style: gzFont(17)),
                    ),
                  ],
                ),
                right: SecondsLeft(now: m.now, to: m.endsAt, size: 16),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _Chip(
                        face: GzFace.from(m.me['avatar']),
                        text: 'You: ${_cards.where((c) => c.matched).length ~/ 2} pairs · $_moves moves',
                        ring: GzC.goldLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (opp.isNotEmpty)
                      Expanded(
                        child: _Chip(
                          face: GzFace.from(opp['avatar']),
                          text: '${opp['name']}: ${oppLevel >= 3 ? 'all done' : 'level ${oppLevel + 1}'}',
                          ring: GzC.cyan,
                          bot: opp['bot'] == true,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(switch (_step) {
                _Step.show => 'REMEMBER THE CARDS!  $_showLeft',
                _Step.play => 'MATCH THE PAIRS',
                _Step.clear => 'LEVEL CLEAR!',
                _Step.done => 'ALL LEVELS CLEAR!',
              }, style: gzFont(22, color: _step == _Step.show ? GzC.goldLight : Colors.white)),
              Text(
                subject != null ? '$subject: match each card with its partner' : 'Match each card with its partner',
                style: gzBody(12, color: const Color(0xFFBFEFF8)),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: context.calm ? Duration.zero : const Duration(milliseconds: 300),
                  child: _step == _Step.done
                      ? _AllDone(key: const ValueKey('done'))
                      : _step == _Step.clear
                      ? _LevelClear(key: ValueKey('clear$_level'), stars: _stars, moves: _moves)
                      : _grid(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: GzPanel(
                  color: GzC.navy,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const GzStar(size: 26),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Fewer moves and a quicker finish score more. Each level adds more cards.', style: gzBody(12))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _grid() => LayoutBuilder(
    key: ValueKey('g$_level'),
    builder: (context, box) {
      final n = _cards.length;
      const cols = 4;
      final rows = (n / cols).ceil();
      final w = (box.maxWidth - 24 - (cols - 1) * 10) / cols;
      final h = math.min(w * 1.25, (box.maxHeight - (rows - 1) * 10) / rows);
      return Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < n; i++)
                  SizedBox(
                    width: w,
                    height: h,
                    child: _FlipCard(card: _cards[i], onTap: () => _tap(i)),
                  ).popIn(delay: (30 * i).ms, calm: context.calm),
              ],
            ),
          ),
          if (_fx > 0)
            IgnorePointer(
              child: KeyedSubtree(key: ValueKey('fx$_fx'), child: const Burst(size: 260)),
            ),
        ],
      );
    },
  );
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.card, required this.onTap});
  final _Card card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: card.up ? card.text : 'Hidden card',
    child: GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: card.up ? 0 : 1),
        duration: context.calm ? Duration.zero : const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        builder: (_, v, _) {
          final back = v > .5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0012)
              ..rotateY(v * math.pi),
            child: back ? Transform(alignment: Alignment.center, transform: Matrix4.identity()..rotateY(math.pi), child: _back()) : _front(),
          );
        },
      ),
    ),
  );

  Widget _front() => AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    decoration: BoxDecoration(
      color: card.matched ? const Color(0xFFDDFBE9) : GzC.cream,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: card.matched ? GzC.green : GzC.ink, width: 3),
      boxShadow: [
        const BoxShadow(color: GzC.ink, offset: Offset(0, 4)),
        if (card.matched) BoxShadow(color: GzC.mint.withValues(alpha: .6), blurRadius: 12),
      ],
    ),
    padding: const EdgeInsets.all(6),
    child: Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 90),
          child: Text(
            card.text,
            textAlign: TextAlign.center,
            style: gzFont(card.text.length <= 3 ? 30 : 16, color: GzC.navy, shadow: 0, height: 1.1),
          ),
        ),
      ),
    ),
  );

  Widget _back() => Container(
    decoration: BoxDecoration(
      color: GzC.blue,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: GzC.ink, width: 3),
      boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 4))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CardBackPainter())),
          const Center(child: GzStar(size: 30)),
        ],
      ),
    ),
  );
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.white.withValues(alpha: .12);
    for (var y = -s.width; y < s.height; y += 14) {
      c.drawLine(Offset(0, y), Offset(s.width, y + s.width), p..strokeWidth = 5);
    }
    c.drawRRect(
      RRect.fromRectAndRadius((Offset.zero & s).deflate(5), const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = GzC.goldLight.withValues(alpha: .7),
    );
  }

  @override
  bool shouldRepaint(_CardBackPainter o) => false;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.face, required this.text, required this.ring, this.bot = false});
  final GzFace face;
  final String text;
  final Color ring;
  final bool bot;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
    decoration: BoxDecoration(color: GzC.ink.withValues(alpha: .6), borderRadius: BorderRadius.circular(14)),
    child: Row(
      children: [
        GzPortrait(face: face, size: 32, ring: ring, bot: false),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: gzBody(12)),
        ),
      ],
    ),
  );
}

class _LevelClear extends StatelessWidget {
  const _LevelClear({super.key, required this.stars, required this.moves});
  final int stars;
  final int moves;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 1 ? 0 : 14),
                child: GzStar(size: i == 1 ? 72 : 56, on: i < stars).popIn(delay: (180 * i).ms, calm: context.calm),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text('$moves moves', style: gzFont(22)),
      ],
    ),
  );
}

class _AllDone extends StatelessWidget {
  const _AllDone({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TreasureChest(size: 150, delay: Duration(milliseconds: 200)),
        const SizedBox(height: 12),
        Text('Waiting for the results…', style: gzBody(15, color: const Color(0xFFBFEFF8))),
      ],
    ),
  );
}
