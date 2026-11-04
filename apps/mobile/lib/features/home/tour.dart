import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';

/// One coach mark. [key] points at a widget on Home (scrolled into view first); [rect] at something fixed,
/// like a bottom tab. With neither (or when the target cannot be found) the tip shows in the middle.
class TourStep {
  const TourStep({this.key, this.rect, required this.icon, required this.title, required this.text});
  final GlobalKey? key;
  final Rect? Function()? rect;
  final IconData icon;
  final String title, text;
}

/// Guided tour: a spotlight that glides from target to target with a pulsing gold ring, and a tip card
/// that always stays on screen (Back / Next / Done, Skip tour). Respects reduce motion.
class TourOverlay extends StatefulWidget {
  const TourOverlay({super.key, required this.steps, required this.onDone});
  final List<TourStep> steps;
  final VoidCallback onDone;
  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> {
  int _k = 0;
  Rect? _rect; // spotlight for the current step (null: centred tip, no spotlight)
  bool _moving = true; // scrolling to the next target
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go(0));
  }

  Rect? _find(TourStep s) {
    if (s.key != null) {
      final box = s.key!.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.attached && box.hasSize) return box.localToGlobal(Offset.zero) & box.size;
    }
    return s.rect?.call();
  }

  /// Scrolls the target into view, then measures it. Never leaves the student stuck: an unknown target gets a centred tip.
  Future<void> _go(int k) async {
    final seq = ++_seq;
    setState(() {
      _k = k;
      _moving = true;
    });
    final s = widget.steps[k];
    final ctx = s.key?.currentContext;
    if (ctx != null) {
      final rm = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      try {
        await Scrollable.ensureVisible(ctx, alignment: .3, duration: rm ? Duration.zero : const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
      } catch (_) {}
    }
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted || seq != _seq) return;
    final size = MediaQuery.sizeOf(context);
    var r = _find(s);
    // Only spotlight what is really on screen.
    if (r != null && (r.bottom < 0 || r.top > size.height || r.height < 4)) r = null;
    if (r != null) r = r.intersect(Offset.zero & size).inflate(6);
    setState(() {
      _rect = r;
      _moving = false;
    });
  }

  void _next() => _k == widget.steps.length - 1 ? widget.onDone() : _go(_k + 1);
  void _back() => _k == 0 ? null : _go(_k - 1);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final steps = widget.steps;
    final s = steps[_k];
    final r = _rect;
    final last = _k == steps.length - 1;

    final card = Container(
      key: ValueKey('tip$_k'),
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
        boxShadow: context.shadow(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Palette.gold400, borderRadius: BorderRadius.circular(12)),
                child: Icon(s.icon, size: 22, color: Palette.navy900),
              ).animate(key: ValueKey('ic$_k')).scaleXY(begin: rm ? 1 : .5, end: 1, duration: rm ? 1.ms : 320.ms, curve: Curves.easeOutBack),
              const Gap(Space.s3),
              Expanded(child: Text('Step ${_k + 1} of ${steps.length}', style: context.ty.over.col(c.textMuted))),
              Btn('Skip tour', kind: BtnKind.ghost, sm: true, onPressed: widget.onDone),
            ],
          ),
          const Gap(Space.s3),
          Text(s.title, style: context.ty.h3),
          const Gap(Space.s1),
          Text(s.text, style: context.ty.sm.col(c.textMuted)),
          const Gap(Space.s4),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (_k + 1) / steps.length),
              duration: rm ? Duration.zero : Motion.slow,
              curve: Motion.out,
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 5, color: Palette.gold400, backgroundColor: c.surfaceSunken),
            ),
          ),
          const Gap(Space.s3),
          Row(
            children: [
              if (_k > 0) Btn('Back', kind: BtnKind.ghost, sm: true, leading: PhosphorIcons.arrowLeft(), onPressed: _moving ? null : _back),
              const Spacer(),
              Btn(
                last ? 'Done' : 'Next',
                kind: last ? BtnKind.accent : BtnKind.primary,
                sm: true,
                icon: last ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.arrowRight(),
                onPressed: _moving ? null : _next,
              ),
            ],
          ),
        ],
      ),
    );

    // Place the tip in the bigger free area above or below the spotlight, inside the safe area; else in the middle.
    final top = pad.top + 12, bottom = size.height - pad.bottom - 12;
    Widget placed;
    if (r == null) {
      placed = Positioned(
        left: 20,
        right: 20,
        top: top,
        bottom: size.height - bottom,
        child: Center(child: card),
      );
    } else {
      final above = r.top - 16 - top, below = bottom - (r.bottom + 16);
      placed = below >= above
          ? Positioned(
              left: 20,
              right: 20,
              top: r.bottom + 16,
              bottom: size.height - bottom,
              child: Align(alignment: Alignment.topCenter, child: card),
            )
          : Positioned(
              left: 20,
              right: 20,
              top: top,
              bottom: size.height - (r.top - 16),
              child: Align(alignment: Alignment.bottomCenter, child: card),
            );
      if ((below >= above ? below : above) < 200) {
        placed = Positioned(
          left: 20,
          right: 20,
          top: top,
          bottom: size.height - bottom,
          child: Center(child: card),
        );
      }
    }

    final hole = r ?? Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => didPop ? null : widget.onDone(),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Dark layer with a hole; taps on it do nothing (the tip's buttons move the tour).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: TweenAnimationBuilder<Rect?>(
                  tween: RectTween(end: hole),
                  duration: rm ? Duration.zero : const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => CustomPaint(painter: HolePainter(v ?? hole, c.scrim)),
                ),
              ),
            ),
            if (r != null)
              AnimatedPositioned(
                duration: rm ? Duration.zero : const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                left: r.left - 6,
                top: r.top - 6,
                width: r.width + 12,
                height: r.height + 12,
                child: IgnorePointer(child: _PulseRing(still: rm)),
              ),
            if (!_moving)
              rm
                  ? placed
                  : Positioned.fill(
                      child: Stack(children: [placed])
                          .animate(key: ValueKey('card$_k'))
                          .fadeIn(duration: 240.ms)
                          .slideY(begin: .04, end: 0, duration: 300.ms, curve: Curves.easeOutCubic),
                    ),
          ],
        ),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({this.still = false});
  final bool still;
  @override
  Widget build(BuildContext context) {
    final ring = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.gold400, width: 2.5),
        boxShadow: [BoxShadow(color: Palette.gold400.withValues(alpha: .35), blurRadius: 16)],
      ),
    );
    if (still) return ring;
    return ring
        .animate(onPlay: (a) => a.repeat(reverse: true))
        .scaleXY(begin: 1, end: 1.035, duration: 900.ms, curve: Curves.easeInOut)
        .fade(begin: 1, end: .7, duration: 900.ms);
  }
}

class HolePainter extends CustomPainter {
  HolePainter(this.hole, this.scrim);
  final Rect hole;
  final Color scrim;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(p, Paint()..color = scrim);
  }

  @override
  bool shouldRepaint(HolePainter old) => old.hole != hole || old.scrim != scrim;
}
