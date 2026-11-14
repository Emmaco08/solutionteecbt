import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
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

// Comprehension Clash (owner, 13 Nov 2026). Both players get the same passage. It scrolls up by itself like a teleprompter
// (a few lines show at a time, faster at higher ranks); when the reading time ends it disappears and the questions come (main idea, the writer's purpose, a word in
// context, a deduction, a detail). Most right answers wins; on a tie, who finished first. Trains the time-hungry Use of
// English comprehension section.

/// Teleprompter: where the passage's top sits in a window of height [view] when [frac] of the reading time has gone.
/// The first line starts on the reading line ([lineAt] of the window) and the last line ends on it, at a steady pace,
/// so the student can only see a few lines at a time (owner, 14 Nov 2026).
double gzPromptTop({required double frac, required double textH, required double lineH, required double view, double lineAt = .42}) {
  final line = view * lineAt - lineH / 2;
  return line - frac.clamp(0.0, 1.0) * math.max(0, textH - lineH);
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
  bool _wasReading = true;
  ({String key, bool ok})? _flash;
  String? _pop;
  bool _good = false;
  int _fx = 0;

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
    final left = ((_answerAt - t) / 1000).ceil();
    final title = '${_passage?['title'] ?? ''}'.trim();
    final body = '${_passage?['body'] ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();
    final wpm = gzMs(_passage?['wpm']);
    final words = gzMs(_passage?['words']) ?? (body.isEmpty ? 0 : body.split(' ').length);
    Widget chip(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: GzC.goldLight),
          const SizedBox(width: 6),
          Text(
            text,
            style: gzBody(12.5, color: Colors.white, weight: FontWeight.w700),
          ),
        ],
      ),
    );
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
          child: LayoutBuilder(
            builder: (context, c) {
              // About 7 lines: enough to read smoothly, never the whole passage.
              final win = math.max(120.0, math.min(c.maxHeight - 64, _Prompter.lineH * 7 + 24));
              final roomy = c.maxHeight - win > 220;
              final opp = m.players.where((p) => p['me'] != true).firstOrNull;
              Widget reader(Json p, String name, Color ring) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GzPortrait(face: GzFace.from(p['avatar']), size: 54, ring: ring, name: name, bot: p['bot'] == true, mood: 'focus'),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 110,
                    child: FitText(name, style: gzFont(13, shadow: 0), minScale: .7, textAlign: TextAlign.center),
                  ),
                ],
              );
              return Align(
                alignment: const Alignment(0, -.35),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (roomy && opp != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            reader(m.players.where((p) => p['me'] == true).firstOrNull ?? m.me, 'YOU', GzC.gold),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
                              child: Text('BOTH READING', style: gzFont(12, color: GzC.subLight, shadow: 0)),
                            ),
                            reader(opp, '${opp['name'] ?? 'Rival'}', GzC.cyan),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          if (wpm != null) chip(Icons.speed_rounded, '$wpm words a minute'),
                          if (words > 0) chip(Icons.notes_rounded, 'Word ${math.min(words, (frac * words).round() + 1)} of $words'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: win,
                        child: _Paper(
                          child: body.isEmpty
                              ? Center(
                                  child: Text('Get ready to read…', style: gzBody(16, color: GzC.navy)),
                                )
                              : _Prompter(text: body, now: m.now, from: m.startsAt, readMs: readMs),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
                  'Read along the gold line. The passage is gone in ${math.max(0, left)}s, then ${m.rounds} questions: main idea, purpose, words, deductions, details.',
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

/// The passage moving up on its own at a steady pace, synced to the match clock. It cannot be scrolled by hand. The text
/// is laid out once and painted at a new offset each frame (no rebuilds), so it stays smooth on small phones.
class _Prompter extends StatefulWidget {
  const _Prompter({required this.text, required this.now, required this.from, required this.readMs});
  final String text;
  final int Function() now;
  final int from, readMs;
  static const fontSize = 19.0, height = 1.6, lineH = fontSize * height;
  @override
  State<_Prompter> createState() => _PrompterState();
}

class _PrompterState extends State<_Prompter> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frac = ValueNotifier(0.0);
  TextPainter? _tp;
  String _key = '';

  double _now() => ((widget.now() - widget.from) / math.max(1, widget.readMs)).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _frac.value = _now();
    _ticker = createTicker((_) {
      final f = _now();
      if (f != _frac.value) _frac.value = f;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frac.dispose();
    _tp?.dispose();
    super.dispose();
  }

  TextPainter _layout(double w) {
    final k = '$w|${widget.text}';
    if (k != _key || _tp == null) {
      _key = k;
      _tp?.dispose();
      _tp = TextPainter(
        text: TextSpan(
          text: widget.text,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: _Prompter.fontSize,
            height: _Prompter.height,
            fontWeight: FontWeight.w600,
            color: GzC.navy,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w);
    }
    return _tp!;
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, c) {
        final tp = _layout(c.maxWidth - 44);
        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: CustomPaint(painter: _PromptPainter(tp, _frac))),
            // Soft fades so lines come in from below and leave at the top.
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: c.maxHeight * .34,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [GzC.cream, Color(0x00FFF7E6)]),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: c.maxHeight * .3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [GzC.cream, Color(0x00FFF7E6)]),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _PromptPainter extends CustomPainter {
  _PromptPainter(this.tp, this.frac) : super(repaint: frac);
  final TextPainter tp;
  final ValueNotifier<double> frac;
  static const lineAt = .42;

  @override
  void paint(Canvas canvas, Size size) {
    const lh = _Prompter.lineH;
    canvas.clipRect(Offset.zero & size);
    // The reading line: a gold band with a marker on the left.
    final y = size.height * lineAt;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(10, y - lh / 2 - 2, size.width - 20, lh + 4), const Radius.circular(8)),
      Paint()..color = const Color(0x40F2B233),
    );
    canvas.drawPath(
      Path()
        ..moveTo(4, y - 8)
        ..lineTo(14, y)
        ..lineTo(4, y + 8)
        ..close(),
      Paint()..color = GzC.brand,
    );
    final top = gzPromptTop(frac: frac.value, textH: tp.height, lineH: lh, view: size.height, lineAt: lineAt);
    tp.paint(canvas, Offset(22, top));
  }

  @override
  bool shouldRepaint(covariant _PromptPainter old) => old.tp != tp;
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
