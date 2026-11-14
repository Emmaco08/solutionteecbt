import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';

// Shared pieces for online classes v2 (owner, 14 Nov 2026): a live countdown with sliding numbers, a beating LIVE pill
// and a progress bar for a running session. Light on the phone: one 1-second timer per countdown, no images.

/// Counts down to [to]; between [to] and [endsAt] it counts down to the end instead ("Ends in"). Numbers slide when
/// they change. [dark] for navy surfaces.
class ClassCountdown extends StatefulWidget {
  const ClassCountdown({super.key, required this.to, this.endsAt, this.big = false, this.dark = false, this.label = true});
  final DateTime to;
  final DateTime? endsAt;
  final bool big, dark, label;
  @override
  State<ClassCountdown> createState() => _ClassCountdownState();
}

class _ClassCountdownState extends State<ClassCountdown> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final end = widget.endsAt ?? widget.to;
    final live = !now.isBefore(widget.to) && now.isBefore(end);
    final left = (live ? end : widget.to).difference(now);
    final s = left.isNegative ? 0 : left.inSeconds;
    final d = s ~/ 86400, h = s % 86400 ~/ 3600, m = s % 3600 ~/ 60, sec = s % 60;
    final parts = d > 0 ? [(d, 'DAYS'), (h, 'HRS'), (m, 'MIN')] : [(h, 'HRS'), (m, 'MIN'), (sec, 'SEC')];
    final sub = widget.dark ? const Color(0xFFB9C7DE) : context.c.textMuted;
    final boxBg = widget.dark ? Colors.white.withValues(alpha: .12) : Palette.navy900;
    final num = (widget.big ? context.ty.h1 : context.ty.h3).bold.tnum.copyWith(height: 1).col(Colors.white);
    final rm = context.reduceMotion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label) ...[
          Text(live ? 'Ends in' : 'Starts in', style: context.ty.cap.bold.col(live ? const Color(0xFFFF8A8E) : sub)),
          const SizedBox(height: 6),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, (n, u)) in parts.indexed) ...[
              if (i > 0)
                Padding(
                  padding: EdgeInsets.fromLTRB(4, widget.big ? 10 : 6, 4, 0),
                  child: Text(':', style: (widget.big ? context.ty.h2 : context.ty.label).bold.col(Palette.gold400)),
                ),
              Column(
                children: [
                  Container(
                    constraints: BoxConstraints(minWidth: widget.big ? 56 : 40),
                    padding: EdgeInsets.symmetric(horizontal: widget.big ? 10 : 6, vertical: widget.big ? 10 : 6),
                    decoration: BoxDecoration(color: boxBg, borderRadius: BorderRadius.circular(widget.big ? 14 : 10)),
                    alignment: Alignment.center,
                    child: ClipRect(
                      child: AnimatedSwitcher(
                        duration: rm ? Duration.zero : const Duration(milliseconds: 300),
                        transitionBuilder: (c, a) => SlideTransition(
                          position: Tween(begin: const Offset(0, .7), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                          child: FadeTransition(opacity: a, child: c),
                        ),
                        child: Text(n.toString().padLeft(2, '0'), key: ValueKey('$u$n'), style: num),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(u, style: context.ty.cap.copyWith(fontSize: 9, letterSpacing: 1, height: 1).col(sub)),
                ],
              ),
            ],
          ],
        ),
        if (live && widget.endsAt != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: widget.big ? 220 : 150,
            child: ClassProgress(start: widget.to, end: widget.endsAt!, dark: widget.dark),
          ),
        ],
      ],
    );
  }
}

/// How much of a running session has gone.
class ClassProgress extends StatelessWidget {
  const ClassProgress({super.key, required this.start, required this.end, this.dark = false});
  final DateTime start, end;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final total = end.difference(start).inSeconds;
    final f = total <= 0 ? 1.0 : (DateTime.now().difference(start).inSeconds / total).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Container(color: dark ? Colors.white.withValues(alpha: .14) : context.c.border),
            FractionallySizedBox(
              widthFactor: f,
              child: Container(
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Palette.gold500, Palette.gold300])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// LIVE in a red pill with a beating dot and a ring rippling out.
class LivePulse extends StatelessWidget {
  const LivePulse({super.key, this.text = 'LIVE', this.small = false});
  final String text;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    final d = small ? 6.0 : 7.0;
    final dot = Container(
      width: d,
      height: d,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );
    final ring = Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
    );
    return Container(
      height: small ? 22 : 26,
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10),
      decoration: BoxDecoration(color: const Color(0xFFE5484D), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: d * 2,
            height: d * 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!rm) ring.animate(onPlay: (a) => a.repeat()).scaleXY(begin: 1, end: 2, duration: 1400.ms, curve: Curves.easeOut).fadeOut(duration: 1400.ms),
                dot,
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(text, style: context.ty.cap.bold.copyWith(letterSpacing: 1, height: 1).col(Colors.white)),
        ],
      ),
    );
  }
}
