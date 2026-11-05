import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';

// Shared payment pieces (D-095): the "Opening OPay" screen and the "Leave this payment?" pop-up.

/// The brand colour used for soft light behind a partner's logo.
Color payBrandColor(String? via) => switch (via) {
  'OPay' => const Color(0xFF1DCF9F),
  'Zap' => const Color(0xFF7B2CBF),
  _ => const Color(0xFF2563B3),
};

/// "OPay", "Zap" → the same; "Bank" → "your bank".
String payViaName(String via) => via == 'Bank' ? 'your bank' : via;

/// The partner's real logo (assets/third_party) in a rounded tile; a bank icon for "Bank"; a card icon otherwise.
class PayPartnerLogo extends StatelessWidget {
  const PayPartnerLogo({super.key, required this.via, this.size = 64});
  final String? via;
  final double size;
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(size * .28);
    switch (via) {
      case 'OPay':
        return Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * .17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: r,
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: SvgPicture.asset('assets/third_party/opay_mark.svg', semanticsLabel: 'OPay'),
        );
      case 'Zap':
        return ClipRRect(
          borderRadius: r,
          child: Image.asset('assets/third_party/zap_icon.png', width: size, height: size, semanticLabel: 'Zap', filterQuality: FilterQuality.medium),
        );
      default:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.navy900, Color(0xFF1C4C9C)]),
            borderRadius: r,
          ),
          child: Icon(
            via == 'Bank' ? PhosphorIcons.bank(PhosphorIconsStyle.fill) : PhosphorIcons.creditCard(PhosphorIconsStyle.fill),
            size: size * .48,
            color: Palette.gold400,
            semanticLabel: via == 'Bank' ? 'Bank' : 'Card',
          ),
        );
    }
  }
}

// ================================================================ "Opening OPay" screen
/// Our screen while Paystack's checkout opens the chosen option (OPay, Zap, Bank).
/// SolutionTee's icon and the partner's real logo, joined by a secure line with a light running along it; a lock in
/// the middle turns into a tick when the step is ready. Under it, three steps tick off one by one:
/// Secure connection → Opening OPay → Ready to pay. Follows light and dark mode; [still] stops every loop.
/// (The sweeping progress bar under the steps was removed after the phone test, 2026-11-05.)
class PayOpeningCover extends StatefulWidget {
  const PayOpeningCover({super.key, required this.via, required this.what, this.loaded = false, this.ready = false, this.still = false});
  final String via, what;

  /// Paystack's page has loaded (step 1 done).
  final bool loaded;

  /// The OPay / Zap / Bank step is open (all done).
  final bool ready;
  final bool still;
  @override
  State<PayOpeningCover> createState() => _PayOpeningCoverState();
}

class _PayOpeningCoverState extends State<PayOpeningCover> with TickerProviderStateMixin {
  late final AnimationController _run = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final AnimationController _fill = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  // Step 1 shows for a moment even on a fast phone, so the ticks read as progress, not a flash.
  bool _minShown = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (!widget.still) {
      _run.repeat();
      _float.repeat(reverse: true);
    }
    _t = Timer(const Duration(milliseconds: 800), () => mounted ? setState(() => _minShown = true) : null);
    if (widget.ready) _fill.value = 1;
  }

  @override
  void didUpdateWidget(PayOpeningCover old) {
    super.didUpdateWidget(old);
    if (widget.ready && !old.ready) {
      HapticFeedback.lightImpact();
      widget.still ? _fill.value = 1 : _fill.forward();
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _run.dispose();
    _float.dispose();
    _fill.dispose();
    super.dispose();
  }

  /// 0: connecting, 1: opening the option, 3: all done.
  int get _step => widget.ready ? 3 : (widget.loaded && _minShown ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final still = widget.still;
    final dark = context.isDark;
    final brand = payBrandColor(widget.via);
    final name = payViaName(widget.via);
    final step = _step;
    final title = widget.ready ? 'All set' : 'Opening $name';
    return ColoredBox(
      color: c.bg,
      child: Stack(
        children: [
          // Soft light in the partner's colour, top and bottom
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -.55),
                  radius: .95,
                  colors: [
                    brand.withValues(alpha: dark ? .22 : .14),
                    brand.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 1.1),
                  radius: .8,
                  colors: [
                    Palette.gold400.withValues(alpha: dark ? .10 : .12),
                    Palette.gold400.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Space.s6, vertical: Space.s5),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Handshake(via: widget.via, run: _run, float: _float, fill: _fill, ready: widget.ready, still: still, brand: brand),
                      const Gap(Space.s6),
                      AnimatedSwitcher(
                        duration: still ? Duration.zero : const Duration(milliseconds: 320),
                        transitionBuilder: (w, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, .35), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Motion.out)),
                            child: w,
                          ),
                        ),
                        child: Text(title, key: ValueKey(title), style: context.ty.h2, textAlign: TextAlign.center),
                      ),
                      const Gap(Space.s1),
                      Text(widget.what, style: context.ty.sm.col(c.textMuted), textAlign: TextAlign.center),
                      const Gap(Space.s5),
                      _StepsCard(
                        still: still,
                        step: step,
                        steps: [
                          ('Secure connection', 'Talking to Paystack'),
                          ('Opening $name', 'Choosing ${widget.via == 'Bank' ? 'Pay with Bank' : widget.via} for you'),
                          ('Ready to pay', 'Finish in the next step'),
                        ],
                      ),
                      const Gap(Space.s5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), size: 13, color: c.success),
                          const Gap(6),
                          Flexible(
                            child: Text('Secured by Paystack · We never see your PIN', style: context.ty.cap.col(c.textSubtle), textAlign: TextAlign.center),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// SolutionTee ⟶ partner, joined by the secure line.
class _Handshake extends StatelessWidget {
  const _Handshake({
    required this.via,
    required this.run,
    required this.float,
    required this.fill,
    required this.ready,
    required this.still,
    required this.brand,
  });
  final String via;
  final AnimationController run, float, fill;
  final bool ready, still;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const tile = 68.0;
    Widget bob(Widget w, double phase) => AnimatedBuilder(
      animation: float,
      builder: (_, child) => Transform.translate(offset: Offset(0, still ? 0 : math.sin((float.value + phase) * math.pi) * 3 - 1.5), child: child),
      child: w,
    );
    List<BoxShadow> shadowOf(Color col) => [
      BoxShadow(
        color: col.withValues(alpha: context.isDark ? .45 : .22),
        blurRadius: 22,
        offset: const Offset(0, 8),
      ),
    ];
    return SizedBox(
      height: 104,
      child: Row(
        children: [
          bob(
            DecoratedBox(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(tile * .28), boxShadow: shadowOf(Palette.navy900)),
              child: const AppIconArt(size: tile),
            ),
            0,
          ).animate().fadeIn(duration: still ? 1.ms : 300.ms).slideX(begin: still ? 0 : -.35, end: 0, duration: still ? 1.ms : 480.ms, curve: Motion.out),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([run, fill]),
                    builder: (_, _) => CustomPaint(
                      painter: _LinePainter(t: run.value, fill: fill.value, dash: c.borderStrong, glow: Palette.gold400, done: c.success, still: still),
                    ),
                  ),
                ),
                _LockBadge(ready: ready, still: still, run: run),
              ],
            ),
          ),
          bob(
            DecoratedBox(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(tile * .28), boxShadow: shadowOf(brand)),
              child: PayPartnerLogo(via: via, size: tile),
            ),
            .5,
          ).animate().fadeIn(duration: still ? 1.ms : 300.ms).slideX(begin: still ? 0 : .35, end: 0, duration: still ? 1.ms : 480.ms, curve: Motion.out),
        ],
      ),
    );
  }
}

/// Dashed line with a gold light running from us to the partner; it fills green when ready.
class _LinePainter extends CustomPainter {
  _LinePainter({required this.t, required this.fill, required this.dash, required this.glow, required this.done, required this.still});
  final double t, fill;
  final Color dash, glow, done;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 10.0;
    final y = size.height / 2, x0 = pad, x1 = size.width - pad, w = x1 - x0;
    if (w <= 0) return;
    final p = Paint()
      ..color = dash
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var x = x0; x < x1; x += 9) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, x1), y), p);
    }
    if (fill > 0) {
      canvas.drawLine(
        Offset(x0, y),
        Offset(x0 + w * fill, y),
        Paint()
          ..color = done
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    if (still) return;
    // The running light: a short gradient tail and a bright head.
    final head = x0 + w * Curves.easeInOut.transform(t);
    final tail = math.max(x0, head - 46);
    canvas.drawLine(
      Offset(tail, y),
      Offset(head, y),
      Paint()
        ..shader = LinearGradient(colors: [glow.withValues(alpha: 0), glow]).createShader(Rect.fromLTRB(tail, y - 2, head + .1, y + 2))
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(head, y), 7, Paint()..color = glow.withValues(alpha: .25));
    canvas.drawCircle(Offset(head, y), 3.6, Paint()..color = glow);
  }

  @override
  bool shouldRepaint(_LinePainter o) => o.t != t || o.fill != fill || o.dash != dash || o.done != done;
}

class _LockBadge extends StatelessWidget {
  const _LockBadge({required this.ready, required this.still, required this.run});
  final bool ready, still;
  final AnimationController run;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedBuilder(
      animation: run,
      builder: (_, child) {
        // A soft ring that breathes out from the lock while connecting.
        final k = still || ready ? 0.0 : run.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            if (!ready && !still)
              Container(
                width: 40 + 22 * k,
                height: 40 + 22 * k,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.secondary.withValues(alpha: (1 - k) * .45), width: 2),
                ),
              ),
            child!,
          ],
        );
      },
      child: AnimatedContainer(
        duration: still ? Duration.zero : Motion.base,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: ready ? c.success : c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: ready ? c.success : c.border, width: 1.5),
          boxShadow: context.shadow(2),
        ),
        child: AnimatedSwitcher(
          duration: still ? Duration.zero : const Duration(milliseconds: 360),
          transitionBuilder: (w, a) => ScaleTransition(
            scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: a, child: w),
          ),
          child: ready
              ? Icon(PhosphorIcons.check(), key: const ValueKey('ok'), size: 20, color: Colors.white)
              : Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), key: const ValueKey('lock'), size: 20, color: c.secondary),
        ),
      ),
    );
  }
}

/// The three steps, ticking off one by one.
class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.steps, required this.step, required this.still});
  final List<(String, String)> steps;
  final int step;
  final bool still;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
        boxShadow: context.shadow(1),
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _StepRow(
                  label: steps[i].$1,
                  sub: steps[i].$2,
                  state: i < step ? _S.done : (i == step ? _S.active : _S.waiting),
                  last: i == steps.length - 1,
                  lineDone: i < step,
                  still: still,
                )
                .animate(delay: still ? 0.ms : (120 + 90 * i).ms)
                .fadeIn(duration: still ? 1.ms : 260.ms)
                .slideY(begin: still ? 0 : .25, end: 0, curve: Motion.out),
        ],
      ),
    );
  }
}

enum _S { done, active, waiting }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.sub, required this.state, required this.last, required this.lineDone, required this.still});
  final String label, sub;
  final _S state;
  final bool last, lineDone, still;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = still ? Duration.zero : Motion.base;
    final Widget dot = switch (state) {
      _S.done => Container(
        key: const ValueKey('done'),
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
        child: Icon(PhosphorIcons.check(), size: 15, color: Colors.white),
      ),
      _S.active => SizedBox(
        key: const ValueKey('active'),
        width: 26,
        height: 26,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: c.secondarySoft, shape: BoxShape.circle),
            ),
            SizedBox(
              width: 18,
              height: 18,
              child: still
                  ? Icon(PhosphorIcons.circle(PhosphorIconsStyle.fill), size: 10, color: c.secondary)
                  : CircularProgressIndicator(strokeWidth: 2.4, color: c.secondary, strokeCap: StrokeCap.round),
            ),
          ],
        ),
      ),
      _S.waiting => Container(
        key: const ValueKey('wait'),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.borderStrong, width: 2),
        ),
      ),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: still ? Duration.zero : const Duration(milliseconds: 380),
                  transitionBuilder: (w, a) => ScaleTransition(
                    scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                    child: w,
                  ),
                  child: dot,
                ),
                if (!last)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: AnimatedContainer(
                        duration: d,
                        width: 2,
                        decoration: BoxDecoration(color: lineDone ? c.success : c.border, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Gap(Space.s3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2, bottom: last ? 0 : Space.s3),
              child: AnimatedOpacity(
                duration: d,
                opacity: state == _S.waiting ? .55 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.ty.sm.bold.col(c.text)),
                    Text(sub, style: context.ty.cap.col(c.textMuted)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================ "Leave this payment?" pop-up
/// What the student chose in [confirmLeavePayment].
enum LeaveChoice { stay, paid, leave }

/// Asked when the student presses back (or our back arrow) on a payment screen that is still waiting (D-095).
/// "Stay and pay" closes the pop-up; "I have paid" checks with Paystack now; "Leave and cancel" cancels the payment on
/// the server, so the app stops saying "checking" and the admin page does not show it waiting. Tapping outside = stay.
Future<LeaveChoice> confirmLeavePayment(BuildContext context, {String? via, required String what, bool transfer = false}) async {
  HapticFeedback.selectionClick();
  final rm = context.reduceMotion;
  final r = await showGeneralDialog<LeaveChoice>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Stay and pay',
    barrierColor: Colors.black.withValues(alpha: .55),
    transitionDuration: rm ? Duration.zero : const Duration(milliseconds: 340),
    pageBuilder: (_, _, _) => LeavePaymentDialog(via: via, what: what, transfer: transfer),
    transitionBuilder: (_, a, _, child) {
      final curve = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: .88, end: 1.0).animate(curve),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(curve),
            child: child,
          ),
        ),
      );
    },
  );
  return r ?? LeaveChoice.stay;
}

class LeavePaymentDialog extends StatelessWidget {
  const LeavePaymentDialog({super.key, this.via, required this.what, this.transfer = false});
  final String? via;
  final String what;
  final bool transfer;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    void choose(LeaveChoice v) {
      HapticFeedback.selectionClick();
      Navigator.of(context).pop(v);
    }

    final body = transfer
        ? 'Sent the money already? Tap “I have paid” and we will check it. If you leave, we cancel this payment.'
        : 'You have not finished paying for $what. If you leave now, we cancel it and you are not charged.';
    final items = <Widget>[
      _LeaveArt(via: via, still: rm),
      const Gap(Space.s4),
      Text('Leave this payment?', style: context.ty.h2, textAlign: TextAlign.center),
      const Gap(Space.s2),
      Text(body, style: context.ty.sm.col(c.textMuted), textAlign: TextAlign.center),
      const Gap(Space.s5),
      Btn(
        'Stay and pay',
        key: const ValueKey('leave-stay'),
        block: true,
        leading: PhosphorIcons.wallet(PhosphorIconsStyle.fill),
        onPressed: () => choose(LeaveChoice.stay),
      ),
      const Gap(Space.s2),
      Btn(
        'I have paid · check now',
        key: const ValueKey('leave-paid'),
        kind: BtnKind.outline,
        block: true,
        leading: PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
        onPressed: () => choose(LeaveChoice.paid),
      ),
      const Gap(Space.s1),
      TextButton.icon(
        key: const ValueKey('leave-cancel'),
        onPressed: () => choose(LeaveChoice.leave),
        style: TextButton.styleFrom(foregroundColor: c.error, minimumSize: const Size.fromHeight(48)),
        icon: Icon(PhosphorIcons.signOut(), size: 18),
        label: Text('Leave and cancel payment', style: context.ty.sm.bold.col(c.error)),
      ),
    ];
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.s5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              color: c.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: c.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // A thin gold-to-blue band on top
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [Palette.gold400, c.secondary])),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.s5, Space.s6, Space.s5, Space.s3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          rm || items[i] is Gap
                              ? items[i]
                              : items[i].animate(delay: (80 + 45 * i).ms).fadeIn(duration: 240.ms).slideY(begin: .2, end: 0, curve: Motion.out),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An hourglass that turns over every couple of seconds in a breathing amber circle, with the partner's logo.
class _LeaveArt extends StatefulWidget {
  const _LeaveArt({this.via, this.still = false});
  final String? via;
  final bool still;
  @override
  State<_LeaveArt> createState() => _LeaveArtState();
}

class _LeaveArtState extends State<_LeaveArt> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    if (!widget.still) _a.repeat();
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: 112,
      height: 96,
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, _) {
          final v = widget.still ? 0.0 : _a.value;
          // Turn over in the last third of each loop, then rest.
          final flip = v < .66 ? 0.0 : Curves.easeInOutBack.transform((v - .66) / .34);
          final ring = (v * 2) % 1;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (!widget.still)
                Container(
                  width: 76 + 20 * ring,
                  height: 76 + 20 * ring,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.warning.withValues(alpha: (1 - ring) * .5), width: 2),
                  ),
                ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [c.warningSoft, c.warningSoft.withValues(alpha: .7)]),
                  border: Border.all(color: c.warning.withValues(alpha: .35)),
                ),
                child: Transform.rotate(
                  angle: flip * math.pi,
                  child: Icon(PhosphorIcons.hourglassMedium(PhosphorIconsStyle.fill), size: 38, color: c.warning),
                ),
              ),
              Positioned(
                right: 6,
                bottom: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.surface, width: 3),
                    boxShadow: context.shadow(2),
                  ),
                  child: PayPartnerLogo(via: widget.via, size: 34),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A small "Cancelling…" card over the screen while we tell the server.
class PayBusyVeil extends StatelessWidget {
  const PayBusyVeil({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    // Material: this card can sit above a screen's Scaffold, where text would otherwise get Flutter's yellow
    // "no Material" underlines (phone test, 2026-11-05).
    return Material(
      color: Colors.black.withValues(alpha: .45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.s5, vertical: Space.s4),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), boxShadow: context.shadow(3)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: c.secondary)),
              const Gap(Space.s3),
              Text(text, style: context.ty.sm.bold),
            ],
          ),
        ).animate().fadeIn(duration: rm ? 1.ms : 200.ms).scaleXY(begin: rm ? 1 : .92, end: 1, curve: Motion.out),
      ),
    ).animate().fadeIn(duration: rm ? 1.ms : 160.ms);
  }
}
