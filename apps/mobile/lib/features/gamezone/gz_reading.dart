import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../widgets/fit_text.dart';
import '../../widgets/math_text.dart';
import '../community/community_data.dart' show Json, asJson, asList;
import 'gz_avatar.dart';
import 'gz_data.dart';
import 'gz_fx.dart';
import 'gz_match.dart';
import 'gz_sound.dart';
import 'gz_theme.dart';

// Comprehension Clash (owner, 13 Nov 2026). Both players get the same passage. It appears quickly, a part at a time, on a
// paper card; when the reading time ends it disappears and the questions come (main idea, the writer's purpose, a word in
// context, a deduction, a detail). Most right answers wins; on a tie, who finished first. Trains the time-hungry Use of
// English comprehension section.

/// The passage split into parts of about one or two sentences, with the share of reading time each part starts at.
List<({String text, double at})> gzReadingParts(String body) {
  final sentences = body.replaceAll(RegExp(r'\s+'), ' ').trim().split(RegExp(r'(?<=[.!?…])\s+(?=[A-Z"“‘\x27(])'));
  final parts = <String>[];
  var cur = '';
  for (final s in sentences) {
    cur = cur.isEmpty ? s : '$cur $s';
    if (cur.split(' ').length >= 14) {
      parts.add(cur);
      cur = '';
    }
  }
  if (cur.isNotEmpty) {
    if (parts.isNotEmpty && cur.split(' ').length < 6) {
      parts[parts.length - 1] = '${parts.last} $cur';
    } else {
      parts.add(cur);
    }
  }
  final total = math.max(1, parts.fold<int>(0, (n, p) => n + p.split(' ').length));
  var before = 0;
  return [
    for (final p in parts)
      (
        text: p,
        at: () {
          final a = before / total;
          before += p.split(' ').length;
          return a;
        }(),
      ),
  ];
}

/// Name of the question type, shown above each question.
String gzReadingKind(String? k) => switch (k) {
  'main' => 'MAIN IDEA',
  'intent' => "WRITER'S PURPOSE",
  'vocab' => 'WORD IN CONTEXT',
  'inference' => 'DEDUCTION',
  'detail' => 'DETAIL',
  _ => 'COMPREHENSION',
};

class GzReadingPlay extends StatefulWidget {
  const GzReadingPlay({super.key, required this.m, required this.onLeave});
  final GzMatch m;
  final VoidCallback onLeave;
  @override
  State<GzReadingPlay> createState() => _GzReadingPlayState();
}

class _GzReadingPlayState extends State<GzReadingPlay> {
  GzMatch get m => widget.m;
  Timer? _tick;
  final _scroll = ScrollController();
  int _shown = -1;
  bool _wasReading = true;
  ({String key, bool ok})? _flash;
  String? _pop;
  bool _good = false;
  int _fx = 0;
  List<({String text, double at})> _parts = const [];
  String _body = '';

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Json? get _passage => m.s?['passage'] == null ? null : asJson(m.s!['passage']);
  int get _answerAt => gzMs(m.s?['answer_at']) ?? m.startsAt;

  Future<void> _answer(String key) async {
    final r = await m.answerRace(key);
    if (!mounted || r == null || r['ok'] != true) return;
    final ok = r['correct'] == true;
    setState(() {
      _fx++;
      _good = ok;
      _flash = (key: key, ok: ok);
      _pop = ok ? '+100' : 'MISSED';
    });
    ok ? GzFeel.right() : GzFeel.wrong();
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = m.now();
    final reading = t < _answerAt;
    if (!reading && _wasReading) {
      _wasReading = false;
      GzFeel.sfx(GzSfx.go, volume: .8);
    }
    final body = '${_passage?['body'] ?? ''}';
    if (body.isNotEmpty && body != _body) {
      _body = body;
      _parts = gzReadingParts(body);
    }
    return Stack(
      children: [
        const Positioned.fill(child: _LibraryBackdrop()),
        SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .05), end: Offset.zero).animate(a),
                child: c,
              ),
            ),
            child: reading
                ? KeyedSubtree(key: const ValueKey('read'), child: _read(context, t))
                : KeyedSubtree(key: const ValueKey('ask'), child: _ask(context)),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- reading

  Widget _read(BuildContext context, int t) {
    final readMs = gzMs(_passage?['read_ms']) ?? math.max(1, _answerAt - m.startsAt);
    final frac = ((t - m.startsAt) / math.max(1, readMs)).clamp(0.0, 1.0);
    var cur = -1;
    for (final (i, p) in _parts.indexed) {
      if (frac >= p.at) cur = i;
    }
    if (cur != _shown) {
      _shown = cur;
      if (cur > 0) GzFeel.sfx(GzSfx.flip, volume: .25);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
        }
      });
    }
    final left = ((_answerAt - t) / 1000).ceil();
    final title = '${_passage?['title'] ?? ''}'.trim();
    return Column(
      children: [
        GzTopBar(
          onLeave: widget.onLeave,
          center: Row(
            children: [
              GzTag('READ FAST', color: GzC.purple, size: 14),
              const SizedBox(width: 8),
              Expanded(child: FitText(title.isEmpty ? 'THE PASSAGE' : title.toUpperCase(), style: gzFont(15), minScale: .7)),
            ],
          ),
          right: TimerRing(now: m.now, from: m.startsAt, to: _answerAt, size: 52),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: .12),
              valueColor: const AlwaysStoppedAnimation(GzC.goldLight),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: _Paper(
              child: _parts.isEmpty
                  ? Center(
                      child: Text('Get ready to read…', style: gzBody(16, color: GzC.navy)),
                    )
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
                      children: [
                        for (final (i, p) in _parts.indexed)
                          if (i <= cur) _Part(text: p.text, now: i == cur, key: ValueKey(i)),
                      ],
                    ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + MediaQuery.paddingOf(context).bottom),
          child: Row(
            children: [
              Icon(Icons.auto_stories_rounded, color: GzC.goldLight.withValues(alpha: .9), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The passage disappears in ${math.max(0, left)}s. Then ${m.rounds} questions: main idea, purpose, words, deductions, details.',
                  style: gzBody(12.5, color: GzC.subLight, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- questions

  Widget _ask(BuildContext context) {
    final players = m.players;
    final opp = players.where((p) => p['me'] != true).firstOrNull;
    final n = math.max(1, m.rounds);
    final finished = m.me['finished'] == true || m.racePos >= n;
    final item = m.raceItem;
    return Column(
      children: [
        GzTopBar(
          onLeave: widget.onLeave,
          center: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Pips(label: 'YOU', done: m.racePos, right: m.raceCorrect, total: n, color: GzC.goldLight),
              const SizedBox(height: 4),
              if (opp != null)
                _Pips(label: '${opp['name']}'.toUpperCase(), done: gzMs(opp['pos']) ?? gzMs(opp['answered']) ?? 0, right: null, total: n, color: GzC.cyan),
            ],
          ),
          right: TimerRing(now: m.now, from: _answerAt, to: m.endsAt, size: 52, frozen: finished),
        ),
        Expanded(
          child: finished
              ? _Done(correct: m.raceCorrect, total: n, opp: opp)
              : item == null
              ? Center(child: Text('Here come the questions…', style: gzFont(20)))
              : Stack(
                  children: [
                    ListView(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + MediaQuery.paddingOf(context).bottom),
                      children: [
                        Row(
                          children: [
                            GzTag(gzReadingKind(item['kind'] as String?), color: GzC.brand, textColor: GzC.navy, size: 13),
                            const Spacer(),
                            Text('QUESTION ${m.racePos + 1} OF $n', style: gzFont(14, color: GzC.subLight, shadow: 0)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GzPanel(
                          padding: const EdgeInsets.all(16),
                          child: MathText('${item['body'] ?? ''}', style: gzBody(17, height: 1.4)),
                        ).animate(key: ValueKey('q${m.racePos}')).fadeIn(duration: 260.ms).slideX(begin: .06, curve: Curves.easeOutCubic),
                        const SizedBox(height: 14),
                        for (final (i, o) in asList(item['options']).indexed)
                          Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _Option(
                                  letter: String.fromCharCode(65 + i),
                                  text: '${o['text']}',
                                  color: _flash != null && _flash!.key == '${o['key']}' ? (_flash!.ok ? GzC.green : GzC.wrong) : GzC.options[i % 4],
                                  onTap: m.sending ? null : () => _answer('${o['key']}'),
                                ),
                              )
                              .animate(key: ValueKey('o${m.racePos}:$i'))
                              .fadeIn(delay: (60 * i).ms, duration: 220.ms)
                              .slideY(begin: .2, curve: Curves.easeOutBack),
                      ],
                    ),
                    if (_pop != null)
                      Positioned(
                        top: 60,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Center(
                            child: ScorePop(key: ValueKey(_fx), text: _pop!, color: _good ? GzC.goldLight : GzC.pink),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- parts

class _LibraryBackdrop extends StatelessWidget {
  const _LibraryBackdrop();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF241552), Color(0xFF0B1F44)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
    ),
    child: CustomPaint(painter: _LettersPainter(), child: SizedBox.expand()),
  );
}

/// Faint letters scattered on the background (drawn once; nothing moves, so scrolling stays smooth).
class _LettersPainter extends CustomPainter {
  const _LettersPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(7);
    const glyphs = ['A', 'b', 'C', 'd', 'E', 'f', 'G', '?', '!', 'Q', 'r', 'S', 'w', 'Y', '“', '”'];
    for (var i = 0; i < 26; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: glyphs[r.nextInt(glyphs.length)],
          style: TextStyle(
            fontFamily: 'LilitaOne',
            fontSize: 22 + r.nextDouble() * 40,
            color: Colors.white.withValues(alpha: .035 + r.nextDouble() * .03),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(r.nextDouble() * size.width, r.nextDouble() * size.height);
      canvas.rotate((r.nextDouble() - .5) * .6);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _LettersPainter old) => false;
}

class _Paper extends StatelessWidget {
  const _Paper({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: GzC.cream,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: GzC.ink, width: 3),
      boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 6))],
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

/// One part of the passage: the newest is bold with a gold marker; earlier parts fade to grey.
class _Part extends StatelessWidget {
  const _Part({super.key, required this.text, required this.now});
  final String text;
  final bool now;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 17,
      height: 1.55,
      fontWeight: now ? FontWeight.w700 : FontWeight.w500,
      color: now ? GzC.navy : const Color(0xFF6B7690),
    );
    final w = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: now ? const Color(0x33F2B233) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: now ? GzC.brand : Colors.transparent, width: 4)),
      ),
      child: Text(text, style: style),
    );
    return now ? w.animate().fadeIn(duration: 260.ms).slideY(begin: .25, curve: Curves.easeOutCubic) : w;
  }
}

class _Pips extends StatelessWidget {
  const _Pips({required this.label, required this.done, required this.right, required this.total, required this.color});
  final String label;
  final int done;
  final int? right;
  final int total;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 74,
        child: FitText(label, style: gzFont(12, color: color, shadow: 0), minScale: .7),
      ),
      for (var i = 0; i < total; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < done ? color : Colors.white.withValues(alpha: .14),
            border: Border.all(color: GzC.ink, width: 1.5),
          ),
        ),
      if (right != null) ...[const SizedBox(width: 4), Text('$right RIGHT', style: gzFont(11, color: GzC.mint, shadow: 0))],
    ],
  );
}

class _Option extends StatelessWidget {
  const _Option({required this.letter, required this.text, required this.color, required this.onTap});
  final String letter;
  final String text;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // Tall enough for the whole answer (long comprehension options wrap to two or three lines).
      final tp = TextPainter(
        text: TextSpan(text: text, style: gzBody(15, height: 1.25)),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: math.max(80, box.maxWidth - 70));
      final h = math.max(58.0, tp.height + 30);
      tp.dispose();
      return _button(h);
    },
  );

  Widget _button(double h) => GameButton(
    color: color,
    height: h,
    radius: 16,
    depth: 6,
    padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), shape: BoxShape.circle),
          child: Text(letter, style: gzFont(16, shadow: 0)),
        ),
        const SizedBox(width: 10),
        Expanded(child: MathText(text, style: gzBody(15, height: 1.25))),
      ],
    ),
  );
}

class _Done extends StatelessWidget {
  const _Done({required this.correct, required this.total, required this.opp});
  final int correct;
  final int total;
  final Json? opp;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedText(
          '$correct / $total',
          size: 54,
          color: GzC.goldLight,
        ).animate().scale(begin: const Offset(.6, .6), curve: Curves.easeOutBack, duration: 450.ms),
        const SizedBox(height: 6),
        OutlinedText('ALL ANSWERED!', size: 26),
        const SizedBox(height: 14),
        if (opp != null) ...[
          GzPortrait(face: GzFace.from(opp!['avatar']), size: 64, ring: GzC.cyan, name: '${opp!['name']}', bot: opp!['bot'] == true),
          const SizedBox(height: 8),
          Text('Waiting for ${opp!['name']} to finish…', style: gzBody(14, color: GzC.subLight)),
        ],
      ],
    ),
  );
}
