import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/updater.dart' show updatePopupsOpen;
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';

// Our WhatsApp channel (owner, 16 Nov 2026, D-174). Admin → Flags & settings → WhatsApp channel sets the link, the words
// and two switches. The app shows a card at the bottom of Home and News, and a pop-up each time the app opens until the
// student taps Join. A tap is kept on this phone and on the server (a new phone or a reinstall does not ask again);
// a new channel link asks again.

const _waDark = Color(0xFF0A3B2C), _waMid = Color(0xFF0E6B4B), _waGreen = Color(0xFF1FAF5F), _waBright = Color(0xFF25D366);

class WaChannel {
  const WaChannel({required this.url, required this.title, required this.text, required this.popup});
  final String url, title, text;
  final bool popup;
}

/// The channel the admin set, or null when it is off or has no link.
final waChannelProvider = Provider<WaChannel?>((ref) {
  final v = ref.watch(appSettingsProvider).value?['whatsapp_channel'];
  if (v is! Map || v['enabled'] == false) return null;
  final url = '${v['url'] ?? ''}'.trim();
  if (!url.startsWith('https://')) return null;
  String s(String k, String d) => '${v[k] ?? ''}'.trim().isEmpty ? d : '${v[k]}'.trim();
  return WaChannel(
    url: url,
    title: s('title', 'Join our WhatsApp channel'),
    text: s('text', 'Exam news, free study tips and class alerts, first. Free to join.'),
    popup: v['popup'] != false,
  );
});

/// Whether this student already tapped Join for the current link.
final waJoinedProvider = FutureProvider<bool>((ref) async {
  final ch = ref.watch(waChannelProvider);
  if (ch == null) return false;
  final db = ref.read(dbProvider);
  if (await db.kvGet('wa_joined') == ch.url) return true;
  try {
    final sb = ref.read(supabaseProvider);
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await sb.from('channel_joins').select('url').eq('user_id', uid).maybeSingle().timeout(const Duration(seconds: 8));
    if (row != null && row['url'] == ch.url) {
      await db.kvSet('wa_joined', ch.url);
      return true;
    }
  } catch (_) {}
  return false;
});

/// Opens the channel in WhatsApp (or the browser) and remembers the tap.
Future<void> joinWhatsAppChannel(BuildContext context, WidgetRef ref, WaChannel ch) async {
  final ok = await launchUrl(Uri.parse(ch.url), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok) {
    if (context.mounted) toast(context, 'Could not open WhatsApp. Check that WhatsApp is installed and try again.');
    return;
  }
  await ref.read(dbProvider).kvSet('wa_joined', ch.url).catchError((_) {});
  unawaited(ref.read(supabaseProvider).rpc('channel_joined', params: {'p_url': ch.url}).then((_) {}).catchError((_) {}));
  ref.invalidate(waJoinedProvider);
}

bool _shownThisLaunch = false;

/// The student came back to the app after a while: the join pop-up may show again.
void newAppOpen() => _shownThisLaunch = false;

/// Each app open, after the other pop-ups: the join pop-up, until the student taps Join. Returns true when shown.
Future<bool> maybeShowWhatsAppPopup(BuildContext context, WidgetRef ref) async {
  if (_shownThisLaunch) return false;
  try {
    await ref.read(appSettingsProvider.future).timeout(const Duration(seconds: 8));
  } catch (_) {}
  final ch = ref.read(waChannelProvider);
  if (ch == null || !ch.popup || !context.mounted) return false;
  if (await ref.read(waJoinedProvider.future).catchError((_) => false)) return false;
  // Never on top of the update pop-up: wait until it is closed (up to a minute).
  for (var i = 0; i < 60 && updatePopupsOpen.value > 0; i++) {
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  if (!context.mounted || updatePopupsOpen.value > 0) return false;
  _shownThisLaunch = true;
  await Future<void>.delayed(const Duration(milliseconds: 600));
  if (!context.mounted) return false;
  final rm = context.reduceMotion;
  await showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: .55),
    transitionDuration: rm ? Duration.zero : const Duration(milliseconds: 420),
    pageBuilder: (ctx, _, _) => WhatsAppPopup(ch: ch),
    transitionBuilder: (_, a, _, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween(begin: .88, end: 1.0).animate(c), child: child),
      );
    },
  );
  return true;
}

class _Perk {
  const _Perk(this.icon, this.text, this.short);
  final IconData icon;
  final String text, short;
}

final _perks = [
  _Perk(PhosphorIcons.megaphone(PhosphorIconsStyle.fill), 'JAMB, WAEC and NECO news first', 'Exam news first'),
  _Perk(PhosphorIcons.lightbulb(PhosphorIconsStyle.fill), 'Free study tips and past question drills', 'Free study tips'),
  _Perk(PhosphorIcons.bellRinging(PhosphorIconsStyle.fill), 'Class, challenge and offer alerts', 'Class alerts'),
];

// ---------------------------------------------------------------------------------------------------- pop-up

/// The join pop-up (public for the screenshot check).
class WhatsAppPopup extends ConsumerWidget {
  const WhatsAppPopup({super.key, required this.ch});
  final WaChannel ch;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final rm = context.reduceMotion;
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget enter(Widget w, int i) => rm ? w : w.animate(delay: (260 + 70 * i).ms).fadeIn(duration: 320.ms).slideY(begin: .25, curve: Motion.out);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.s5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .28), blurRadius: 40, offset: const Offset(0, 18))],
            ),
            child: Material(
              color: dark ? const Color(0xFF111A2B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 190,
                      child: Stack(
                        children: [
                          const Positioned.fill(child: _WaStage(big: true)),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: IconBtn(PhosphorIcons.x(), label: 'Close', glass: true, onPressed: () => Navigator.of(context).pop()),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s5, Space.s5, Space.s4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          enter(Text(ch.title, textAlign: TextAlign.center, style: context.ty.h2), 0),
                          const Gap(Space.s2),
                          enter(Text(ch.text, textAlign: TextAlign.center, style: context.ty.body.col(c.textMuted)), 1),
                          const Gap(Space.s4),
                          for (var i = 0; i < _perks.length; i++)
                            enter(
                              Padding(
                                padding: const EdgeInsets.only(bottom: Space.s2),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(color: _waBright.withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
                                      child: Icon(_perks[i].icon, size: 18, color: dark ? _waBright : _waMid),
                                    ),
                                    const Gap(Space.s3),
                                    Expanded(child: Text(_perks[i].text, style: context.ty.sm)),
                                  ],
                                ),
                              ),
                              2 + i,
                            ),
                          const Gap(Space.s3),
                          enter(
                            _JoinButton(
                              label: 'Join the channel',
                              onTap: () async {
                                Navigator.of(context).pop();
                                await joinWhatsAppChannel(context, ref, ch);
                              },
                            ),
                            6,
                          ),
                          const Gap(Space.s1),
                          enter(
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                              child: Text('Maybe later', style: context.ty.label.col(c.textMuted)),
                            ),
                            7,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The big green "Join" button with a soft shine.
class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    Widget b = Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_waGreen, _waBright]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _waGreen.withValues(alpha: .4), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill), color: Colors.white, size: 22),
          const Gap(Space.s2),
          Text(label, style: context.ty.label.bold.col(Colors.white).copyWith(fontSize: 16)),
        ],
      ),
    );
    if (!context.reduceMotion) {
      b = b.animate(onPlay: (a) => a.repeat()).shimmer(delay: 1800.ms, duration: 1100.ms, color: Colors.white.withValues(alpha: .35));
    }
    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: b),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------- card

/// "Join our WhatsApp channel" at the bottom of Home and News. Nothing when the admin turned it off or set no link.
/// How the three perks show under the words (owner choosing, 16 Nov 2026): as pills, not at all, or on one plain line.
enum WaPerks { pills, none, line }

class WhatsAppChannelCard extends ConsumerWidget {
  const WhatsAppChannelCard({super.key, this.perks = WaPerks.pills});
  final WaPerks perks;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ch = ref.watch(waChannelProvider);
    if (ch == null) return const SizedBox.shrink();
    final joined = ref.watch(waJoinedProvider).value ?? false;
    final rm = context.reduceMotion;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 600;
        final words = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LiveDot(animate: !rm),
                      const SizedBox(width: 6),
                      Text(joined ? 'YOU ARE IN' : 'FREE · WHATSAPP', style: context.ty.cap.bold.col(Colors.white).copyWith(fontSize: 10.5, letterSpacing: .8)),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(Space.s2),
            Text(joined ? 'Thanks for joining our channel' : ch.title, style: context.ty.h3.col(Colors.white)),
            const Gap(Space.s1),
            Text(
              joined ? 'New posts show in WhatsApp under Updates. Tap to open the channel.' : ch.text,
              style: context.ty.sm.col(Colors.white.withValues(alpha: .82)),
            ),
            if (perks == WaPerks.line) ...[
              const Gap(Space.s3),
              // One straight line, shrinking to fit instead of wrapping.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    for (final (i, p) in _perks.indexed) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .45), shape: BoxShape.circle),
                          ),
                        ),
                      Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), size: 14, color: _waBright),
                      const SizedBox(width: 5),
                      Text(p.short, style: context.ty.cap.bold.col(Colors.white.withValues(alpha: .9))),
                    ],
                  ],
                ),
              ),
            ],
            if (perks == WaPerks.pills) const Gap(Space.s3),
            if (perks == WaPerks.pills)
              Wrap(
                spacing: Space.s2,
                runSpacing: Space.s2,
                children: [
                  for (final p in _perks)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white.withValues(alpha: .14)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(p.icon, size: 14, color: _waBright),
                          const SizedBox(width: 6),
                          Text(p.short, style: context.ty.cap.col(Colors.white)),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        );
        final button = _CardButton(joined: joined, onTap: () => joinWhatsAppChannel(context, ref, ch));
        return Semantics(
          container: true,
          label: ch.title,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.lg),
            child: Stack(
              children: [
                const Positioned.fill(child: _WaStage(big: false)),
                Padding(
                  padding: EdgeInsets.all(wide ? Space.s6 : Space.s5),
                  child: wide
                      ? Row(
                          children: [
                            const _WaBadge(size: 72),
                            const Gap(Space.s5),
                            Expanded(child: words),
                            const Gap(Space.s5),
                            button,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: words),
                                const Gap(Space.s3),
                                const _WaBadge(size: 56),
                              ],
                            ),
                            const Gap(Space.s4),
                            button,
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardButton extends StatefulWidget {
  const _CardButton({required this.joined, required this.onTap});
  final bool joined;
  final VoidCallback onTap;
  @override
  State<_CardButton> createState() => _CardButtonState();
}

class _CardButtonState extends State<_CardButton> {
  bool _down = false, _hover = false;
  @override
  Widget build(BuildContext context) {
    final label = widget.joined ? 'Open channel' : 'Join channel';
    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down ? Motion.pressScale : (_hover ? 1.03 : 1),
            duration: Motion.fast,
            curve: Motion.out,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: Space.s5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.joined ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
                    size: 20,
                    color: _waMid,
                  ),
                  const Gap(Space.s2),
                  Text(label, style: context.ty.label.bold.col(_waDark)),
                  const Gap(Space.s2),
                  Icon(PhosphorIcons.arrowRight(), size: 16, color: _waDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The white circle with the WhatsApp mark and two soft rings that pulse out.
class _WaBadge extends StatelessWidget {
  const _WaBadge({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    Widget ring(int delay) {
      final r = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _waBright.withValues(alpha: .7), width: 2),
        ),
      );
      return rm
          ? const SizedBox.shrink()
          : r
                .animate(onPlay: (a) => a.repeat(), delay: delay.ms)
                .scaleXY(begin: 1, end: 1.6, duration: 1800.ms, curve: Curves.easeOut)
                .fadeOut(duration: 1800.ms, curve: Curves.easeOut);
    }

    Widget core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: _waBright.withValues(alpha: .45), blurRadius: 22)],
      ),
      child: Icon(PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill), size: size * .56, color: _waGreen),
    );
    if (!rm) {
      core = core
          .animate(onPlay: (a) => a.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.06, duration: 1200.ms, curve: Curves.easeInOut)
          .rotate(begin: -.012, end: .012, duration: 1200.ms);
    }
    return SizedBox(
      width: size * 1.6,
      height: size * 1.6,
      child: Stack(alignment: Alignment.center, children: [ring(0), ring(900), core]),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.animate});
  final bool animate;
  @override
  Widget build(BuildContext context) {
    final d = Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(color: _waBright, shape: BoxShape.circle),
    );
    return animate ? d.animate(onPlay: (a) => a.repeat(reverse: true)).fadeOut(begin: 1, duration: 900.ms) : d;
  }
}

/// Deep green stage with slowly rising chat bubbles (one painter, cheap to draw). In the pop-up: the big badge in the
/// middle with little icons floating around it.
class _WaStage extends StatefulWidget {
  const _WaStage({required this.big});
  final bool big;
  @override
  State<_WaStage> createState() => _WaStageState();
}

class _WaStageState extends State<_WaStage> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(seconds: 14));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _a.stop();
    } else if (!_a.isAnimating) {
      _a.repeat();
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    Widget float(IconData icon, Alignment at, int delay) {
      final w = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .2)),
        ),
        child: Icon(icon, size: 19, color: Colors.white),
      );
      return Align(
        alignment: at,
        child: rm
            ? w
            : w
                  .animate(onPlay: (a) => a.repeat(reverse: true))
                  .moveY(begin: 0, end: -8, duration: (1400 + delay).ms, curve: Curves.easeInOut)
                  .animate(delay: delay.ms)
                  .fadeIn(duration: 400.ms)
                  .scaleXY(begin: .4, curve: Curves.easeOutBack),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_waDark, _waMid, _waGreen]),
          ),
        ),
        RepaintBoundary(child: CustomPaint(painter: _BubblesPainter(_a))),
        if (widget.big) ...[
          const Center(child: _WaBadge(size: 78)),
          float(PhosphorIcons.megaphone(PhosphorIconsStyle.fill), const Alignment(-.72, -.45), 200),
          float(PhosphorIcons.bellRinging(PhosphorIconsStyle.fill), const Alignment(.78, .02), 350),
          float(PhosphorIcons.lightbulb(PhosphorIconsStyle.fill), const Alignment(-.62, .62), 500),
          float(PhosphorIcons.graduationCap(PhosphorIconsStyle.fill), const Alignment(.5, .72), 650),
        ],
      ],
    );
  }
}

class _BubblesPainter extends CustomPainter {
  _BubblesPainter(this.t) : super(repaint: t);
  final Animation<double> t;
  static final _seeds = List.generate(14, (i) {
    final r = math.Random(i * 7919 + 3);
    return (x: r.nextDouble(), size: 6 + r.nextDouble() * 22, speed: .4 + r.nextDouble() * .8, phase: r.nextDouble());
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: .07);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: .09);
    for (final s in _seeds) {
      final y = 1 - ((t.value * s.speed + s.phase) % 1.0);
      final cx = s.x * size.width + math.sin((t.value * 2 * math.pi) + s.phase * 6) * 10;
      final cy = y * (size.height + 60) - 30;
      canvas.drawCircle(Offset(cx, cy), s.size / 2, s.size > 18 ? ring : p);
    }
    // A big soft circle in the corner.
    canvas.drawCircle(Offset(size.width * .92, size.height * 1.05), size.height * .55, Paint()..color = Colors.white.withValues(alpha: .06));
  }

  @override
  bool shouldRepaint(_BubblesPainter old) => false;
}
