import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../widgets/math_text.dart';
import '../community/community_data.dart' show Json, asList;
import 'gz_avatar.dart';
import 'gz_data.dart';
import 'gz_fx.dart';
import 'gz_match.dart';
import 'gz_scenes.dart';
import 'gz_sound.dart';
import 'gz_theme.dart';

// Race games (D-157): Speed Rush (first to 10 right; a wrong answer spins you out for 2 s) and Maths Blitz
// (60 seconds, combo points). Each answer brings the next item straight back from the server.

const _laneColors = [GzC.pink, GzC.blue, GzC.green, GzC.purple, GzC.cyan, GzC.orange];

class GzRacePlay extends StatefulWidget {
  const GzRacePlay({super.key, required this.m, required this.onLeave});
  final GzMatch m;
  final VoidCallback onLeave;
  @override
  State<GzRacePlay> createState() => _GzRacePlayState();
}

class _GzRacePlayState extends State<GzRacePlay> {
  GzMatch get m => widget.m;
  int _fx = 0;
  String? _pop;
  bool _good = false;
  ({String key, bool ok})? _flash;

  Future<void> _answer(String key) async {
    final r = await m.answerRace(key);
    if (!mounted || r == null || r['ok'] != true) return;
    final ok = r['correct'] == true;
    final combo = gzMs(r['combo']) ?? 0;
    final pts = gzMs(r['points']) ?? 0;
    setState(() {
      _fx++;
      _good = ok;
      _flash = (key: key, ok: ok);
      _pop = ok
          ? (m.game == 'blitz' ? '+$pts${combo >= 2 ? ' x${math.min(combo, 5)}!' : ''}' : (combo >= 3 ? 'NITRO!' : '+1'))
          : (m.game == 'rush' ? 'SPIN OUT!' : 'OOPS!');
    });
    ok ? GzFeel.right() : GzFeel.wrong();
    if (!ok && m.game == 'rush') GzFeel.sfx(GzSfx.spin, volume: .8);
    if (ok && (combo == 3 || combo == 5)) GzFeel.sfx(GzSfx.combo, volume: .7);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _flash = null);
    });
    if (m.game == 'rush' && !ok) {
      Future.delayed(const Duration(milliseconds: 2050), () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) => m.game == 'blitz' ? _blitz(context) : _rush(context);

  // ---------------------------------------------------------------- Speed Rush

  Widget _rush(BuildContext context) {
    final players = m.players;
    final target = math.max(1, m.target);
    final lanes = <RushLane>[];
    final standings = <(String, int, bool)>[];
    for (final (i, p) in players.indexed) {
      final me = p['me'] == true;
      final c = me ? m.raceCorrect : (gzMs(p['correct']) ?? 0);
      lanes.add(
        RushLane(
          label: me ? 'YOU' : '${p['name']}'.toUpperCase(),
          color: me ? GzC.brand : _laneColors[i % _laneColors.length],
          progress: c / target,
          me: me,
          nitro: me ? m.raceCombo >= 3 : (gzMs(p['combo']) ?? 0) >= 3,
          spin: me && m.now() < m.penaltyUntil,
        ),
      );
      standings.add((me ? 'YOU' : '${p['name']}', c, me));
    }
    standings.sort((a, b) => b.$2.compareTo(a.$2));
    final finished = m.me['finished'] == true || m.raceCorrect >= target;
    final spin = m.now() < m.penaltyUntil;
    final item = m.raceItem;
    final subject = (m.s?['subject'] as Map?)?['name'];

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: const Color(0xFF2E8B3E), child: Container()),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              GzTopBar(
                onLeave: widget.onLeave,
                center: Row(
                  children: [
                    for (final (i, s) in standings.take(3).indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _Standing(place: i + 1, name: s.$1, me: s.$3),
                      ),
                  ],
                ),
                right: m.raceCombo >= 3 ? GzTag('NITRO x${m.raceCombo}', color: GzC.pink, size: 13).animate().shake(hz: 3, duration: 400.ms) : null,
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(child: RushTrack(lanes: lanes)),
                    if (_pop != null)
                      Positioned(
                        top: 8,
                        child: KeyedSubtree(key: ValueKey('p$_fx'), child: _popFx()),
                      ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .56, minHeight: 220),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + MediaQuery.paddingOf(context).bottom),
                  decoration: const BoxDecoration(
                    color: GzC.navy,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                    border: Border(top: BorderSide(color: GzC.ink, width: 4)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          GzTag((subject ?? 'SPEED RUSH').toString().toUpperCase(), color: GzC.green, size: 12),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TimeBar(now: m.now, from: m.startsAt, to: m.endsAt, height: 12, color: GzC.goldLight),
                          ),
                          const SizedBox(width: 8),
                          SecondsLeft(now: m.now, to: m.endsAt),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: context.calm ? Duration.zero : const Duration(milliseconds: 220),
                          layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, ?cur]),
                          child: finished
                              ? _Finished(key: const ValueKey('fin'), place: standings.indexWhere((s) => s.$3) + 1)
                              : item == null
                              ? const Center(child: CircularProgressIndicator(color: GzC.goldLight))
                              : Stack(
                                  key: ValueKey('i${m.racePos}'),
                                  children: [
                                    _RaceQuestion(item: item, onPick: spin || m.sending ? null : _answer, flash: _flash),
                                    if (spin)
                                      Positioned.fill(
                                        child: _SpinOut(until: m.penaltyUntil, now: m.now),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${m.raceCorrect} of $target right · 3 right in a row = NITRO · a wrong answer spins you out',
                          textAlign: TextAlign.center,
                          style: gzBody(12, color: GzC.goldLight),
                        ),
                      ),
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

  Widget _popFx() => Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      if (_good) const Positioned(child: Burst(size: 200)),
      ScorePop(text: _pop!, color: _good ? GzC.goldLight : const Color(0xFFFF8FA8), size: 30),
    ],
  );

  // ---------------------------------------------------------------- Maths Blitz

  Widget _blitz(BuildContext context) {
    final players = m.players;
    final opp = players.firstWhere((p) => p['me'] != true, orElse: () => const {});
    final item = m.raceItem;
    final combo = m.raceCombo;
    final over = m.now() >= m.endsAt;
    final opts = asList(item?['options']);
    return Stack(
      children: [
        const Positioned.fill(child: NeonScene()),
        SafeArea(
          child: Column(
            children: [
              GzTopBar(
                onLeave: widget.onLeave,
                center: Text(
                  'MATHS BLITZ',
                  style: gzFont(22, color: GzC.goldLight).copyWith(shadows: const [Shadow(color: GzC.brand, blurRadius: 12)]),
                ),
                right: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: combo >= 2
                      ? GzTag(
                          'COMBO x${math.min(combo, 5)}',
                          key: ValueKey(combo),
                          color: GzC.pink,
                          size: 14,
                        ).animate().scale(begin: const Offset(1.4, 1.4), duration: 240.ms, curve: Curves.easeOutBack)
                      : const SizedBox(width: 10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: TimeBar(now: m.now, from: m.startsAt, to: m.endsAt, color: GzC.mint),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  children: [
                    TweenAnimationBuilder<int>(
                      tween: IntTween(end: m.raceScore),
                      duration: const Duration(milliseconds: 400),
                      builder: (_, v, _) => Text('YOU ${gzNum(v)}', style: gzFont(17, color: GzC.goldLight)),
                    ),
                    const Spacer(),
                    SecondsLeft(now: m.now, to: m.endsAt, size: 17),
                    const Spacer(),
                    if (opp.isNotEmpty)
                      Text(
                        '${'${opp['name']}'.toUpperCase()} ${gzNum(gzMs(opp['score']) ?? 0)}',
                        style: gzFont(17, color: GzC.blue.withValues(alpha: 1)).copyWith(color: const Color(0xFF98B6DB)),
                      ),
                  ],
                ),
              ),
              if (opp.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GzPortrait(face: GzFace.from(m.me['avatar']), size: 46, ring: GzC.goldLight, name: 'You'),
                      const SizedBox(width: 10),
                      Text('VS', style: gzFont(18, color: GzC.pink)),
                      const SizedBox(width: 10),
                      GzPortrait(face: GzFace.from(opp['avatar']), size: 46, ring: GzC.cyan, name: '${opp['name']}', bot: opp['bot'] == true),
                    ],
                  ),
                ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      child: over
                          ? const OutlinedText("TIME'S UP!", size: 44, color: GzC.goldLight)
                          : item == null
                          ? const CircularProgressIndicator(color: GzC.cyan)
                          : _NeonDisplay(key: ValueKey('n${m.racePos}'), text: '${item['body']}'),
                    ),
                    if (_pop != null)
                      Positioned(
                        top: 0,
                        right: 24,
                        child: KeyedSubtree(key: ValueKey('p$_fx'), child: _popFx()),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2,
                  children: [
                    for (final (i, o) in opts.indexed)
                      GameButton(
                        key: ValueKey('o${m.racePos}-$i'),
                        color: _flash != null && _flash!.key == '${o['key']}'
                            ? (_flash!.ok ? GzC.green : GzC.wrong)
                            : const [GzC.purple, GzC.green, GzC.cyan, GzC.red][i % 4],
                        glow: _flash != null && _flash!.key == '${o['key']}' && _flash!.ok ? GzC.mint : null,
                        height: 76,
                        radius: 18,
                        onTap: over || m.sending ? null : () => _answer('${o['key']}'),
                        child: FittedBox(child: Text('${o['text']}', style: gzFont(34))),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NeonDisplay extends StatelessWidget {
  const _NeonDisplay({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final w = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0620),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GzC.cyan, width: 3),
        boxShadow: [BoxShadow(color: GzC.cyan.withValues(alpha: .55), blurRadius: 20)],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text.toUpperCase(),
          style: gzFont(50, color: GzC.ice, shadow: 0, spacing: 1).copyWith(shadows: const [Shadow(color: GzC.cyan, blurRadius: 14)]),
        ),
      ),
    );
    return context.calm ? w : w.animate().scale(begin: const Offset(.85, .85), duration: 180.ms, curve: Curves.easeOutBack).fadeIn(duration: 120.ms);
  }
}

class _RaceQuestion extends StatelessWidget {
  const _RaceQuestion({required this.item, required this.onPick, required this.flash});
  final Json item;
  final void Function(String key)? onPick;
  final ({String key, bool ok})? flash;

  @override
  Widget build(BuildContext context) {
    final opts = asList(item['options']);
    final short = opts.every((o) => '${o['text']}'.length <= 6);
    final long = opts.any((o) => '${o['text']}'.length > 26);
    Widget opt(int i, Json o, double? h) {
      final k = '${o['key']}';
      final f = flash != null && flash!.key == k;
      return GameButton(
        color: f ? (flash!.ok ? GzC.green : GzC.wrong) : GzC.options[i % 4],
        height: h,
        radius: 16,
        depth: 6,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        onTap: onPick == null ? null : () => onPick!(k),
        child: short
            ? FittedBox(child: MathText('${o['text']}', style: gzFont(26)))
            : MathText('${o['text']}', style: gzBody(14, height: 1.2), textAlign: TextAlign.center),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            primary: false,
            child: MathText('${item['body'] ?? ''}', textAlign: TextAlign.center, style: gzBody(17, height: 1.4)),
          ),
        ),
        const SizedBox(height: 12),
        if (short)
          Row(
            children: [
              for (final (i, o) in opts.indexed) ...[Expanded(child: opt(i, o, 70)), if (i < opts.length - 1) const SizedBox(width: 8)],
            ],
          )
        else if (long)
          Column(
            children: [for (final (i, o) in opts.indexed) Padding(padding: const EdgeInsets.only(bottom: 2), child: opt(i, o, 54))],
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 2,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [for (final (i, o) in opts.indexed) opt(i, o, null)],
          ),
      ],
    );
  }
}

class _SpinOut extends StatefulWidget {
  const _SpinOut({required this.until, required this.now});
  final int until;
  final int Function() now;
  @override
  State<_SpinOut> createState() => _SpinOutState();
}

class _SpinOutState extends State<_SpinOut> {
  late final _t = Stream.periodic(const Duration(milliseconds: 100));
  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _t,
    builder: (_, _) {
      final left = math.max(0, widget.until - widget.now());
      if (left <= 0) return const SizedBox.shrink();
      return Container(
        decoration: BoxDecoration(color: GzC.ink.withValues(alpha: .75), borderRadius: BorderRadius.circular(18)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OutlinedText('SPIN OUT!', size: 36, color: Color(0xFFFF8FA8)),
              const SizedBox(height: 6),
              Text('Back on track in ${(left / 1000).toStringAsFixed(1)} s', style: gzBody(14, color: GzC.subLight)),
            ],
          ),
        ),
      );
    },
  );
}

class _Standing extends StatelessWidget {
  const _Standing({required this.place, required this.name, required this.me});
  final int place;
  final String name;
  final bool me;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(3, 3, 8, 3),
    decoration: BoxDecoration(
      color: GzC.ink.withValues(alpha: .8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: me ? GzC.brand : Colors.transparent, width: 2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: place == 1 ? GzC.brand : GzC.blue, shape: BoxShape.circle),
          child: Text('$place', style: gzFont(12, color: place == 1 ? GzC.navy : Colors.white, shadow: 0)),
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 60),
          child: Text(name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: gzFont(12, shadow: 0)),
        ),
      ],
    ),
  );
}

class _Finished extends StatelessWidget {
  const _Finished({super.key, required this.place});
  final int place;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedText(place == 1 ? 'FINISHED 1ST!' : 'FINISHED!', size: 36, color: GzC.goldLight),
        const SizedBox(height: 8),
        Text('Waiting for the others to cross the line…', style: gzBody(14, color: GzC.subLight)),
      ],
    ),
  );
}
