import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme.dart';
import '../theme/tokens.g.dart';
import '../ui/kit.dart';
import '../widgets/phosphor.g.dart';
import 'app_gate.dart' show GateStage, WhatsNew;
import 'platform.dart';
import 'updater.dart';

// The update screens of the website app and the Windows app (owner, 16 Nov 2026, D-181): the navy stage of the
// maintenance and Google Play screens, a ring that fills as the update downloads, the versions side by side, the
// admin's "What's new", three steps (Download, Install, Open) and one clear button for each moment.

const _muted = Color(0xFFC9D6EA);
const _subtle = Color(0xFF9FB0CC);

/// "28.4 MB".
String fmtMb(int bytes) => '${(bytes / 1048576).toStringAsFixed(bytes >= 10 * 1048576 ? 0 : 1)} MB';

/// "0.3.0-202611161107" → "0.3.0 · 16 Nov".
String prettyVersion(String v) {
  final p = v.trim().split('-');
  if (p.length < 2 || p[1].length < 8) return p.first;
  final s = p[1];
  final m = int.tryParse(s.substring(4, 6)) ?? 0, d = int.tryParse(s.substring(6, 8)) ?? 0;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  if (m < 1 || m > 12 || d < 1) return p.first;
  return '${p.first} · $d ${months[m - 1]}';
}

/// "about 2 min left".
String fmtLeft(Duration d) {
  if (d.inSeconds < 60) return 'about ${math.max(5, (d.inSeconds / 5).ceil() * 5)} s left';
  final m = (d.inSeconds / 60).ceil();
  return 'about $m min left';
}

/// What the screen says and offers at each moment.
class _Copy {
  const _Copy(this.title, this.text);
  final String title, text;
}

_Copy _copy(UpdState s, {required bool force}) {
  final desk = isDesktop;
  switch (s.phase) {
    case UpdPhase.idle:
      return _Copy(
        force ? 'Update needed' : 'New version ready',
        force
            ? 'This version of SolutionTee CBT is no longer supported. Update to keep practising. Your account, XP and saved tests stay.'
            : 'Get the newest features and fixes. Your account, XP and saved tests stay.',
      );
    case UpdPhase.starting:
      return const _Copy('Starting download', 'Connecting to SolutionTee…');
    case UpdPhase.downloading:
      return _Copy(
        'Downloading update',
        desk ? 'Keep SolutionTee open. It installs as soon as the download is done.' : 'You can use other apps. The download carries on in the background.',
      );
    case UpdPhase.waiting:
      return const _Copy('Waiting for internet', 'The download continues by itself when you are back online. Nothing is lost.');
    case UpdPhase.ready:
      return desk
          ? const _Copy('Ready to install', 'SolutionTee will close, update and open again in a few seconds.')
          : s.installAsked
          ? const _Copy('Almost done', 'Tap Install on Android\'s screen. If you closed it, tap Install update again.')
          : const _Copy('Ready to install', 'Tap Install update, then tap Install on the next screen.');
    case UpdPhase.permission:
      return const _Copy('One quick step', 'Android needs your OK to install updates from SolutionTee. You only do this once.');
    case UpdPhase.installing:
      return desk
          ? const _Copy('Installing update', 'SolutionTee closes now and opens again by itself.')
          : const _Copy('Opening the installer', 'Tap Install on the next screen.');
    case UpdPhase.failed:
      return _Copy('Download paused', s.error ?? UpdateError.internet.message);
  }
}

// ---------------------------------------------------------------------------------------------------- full screen

/// The update screen: forced (no way back), opened from the pop-up or the card (optional: the student can go back to
/// the app while it downloads), or Me → App update ([embedded]: a back arrow).
class UpdateScreen extends ConsumerStatefulWidget {
  const UpdateScreen({super.key, required this.info, this.optional = false, this.startNow = false, this.embedded = false});
  final UpdateInfo info;

  /// The student may leave ("Later" / "Keep using the app") and the app stays usable.
  final bool optional;

  /// Start the download as soon as the screen opens ("Update now" on the pop-up).
  final bool startNow;

  /// Me → App update: a back arrow at the top.
  final bool embedded;

  @override
  ConsumerState<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<UpdateScreen> {
  late final UpdateController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = ref.read(updateCtlProvider.notifier);
    updateScreensOpen.value++;
    Future.microtask(() async {
      await _ctl.restore(widget.info.release);
      if (widget.startNow) {
        await _ctl.start(widget.info.release);
      } else if (ref.read(updateCtlProvider).active) {
        _ctl.autoInstall = true; // the student is watching: install when it is done
      }
    });
  }

  @override
  void dispose() {
    // Back to the app: the download finishes in the background and the small card offers the install.
    if (widget.optional) _ctl.autoInstall = false;
    updateScreensOpen.value--;
    super.dispose();
  }

  void _leave() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(updateCtlProvider);
    final r = widget.info.release;
    final force = !widget.optional;
    final copy = _copy(s, force: force);
    final mine = ref.watch(myVersionNameProvider).value ?? '';
    final rm = context.reduceMotion;

    Widget enter(Widget w, int i) => rm ? w : w.animate(delay: (80 * i).ms).fadeIn(duration: 320.ms).slideY(begin: .12, curve: Motion.out);

    final top = Padding(
      padding: const EdgeInsets.fromLTRB(Space.s2, Space.s2, Space.s2, 0),
      child: Row(
        children: [
          if (widget.optional)
            IconButton(
              tooltip: widget.embedded ? 'Back' : 'Close',
              onPressed: _leave,
              icon: Icon(widget.embedded ? PhosphorIcons.arrowLeft() : PhosphorIcons.x(), color: Colors.white),
            )
          else
            const SizedBox(height: 48),
          const Spacer(),
          if (r.sizeText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: Space.s3),
              child: _Chip(icon: PhosphorIcons.downloadSimple(PhosphorIconsStyle.fill), text: r.sizeText),
            ),
        ],
      ),
    );

    // The picture and what is happening now.
    final head = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        enter(_UpdateRing(state: s, size: 176), 0),
        const Gap(Space.s5),
        AnimatedSwitcher(
          duration: rm ? Duration.zero : Motion.base,
          child: Column(
            key: ValueKey('${s.phase}${s.installAsked}'),
            children: [
              Text(copy.title, textAlign: TextAlign.center, style: context.ty.h1.col(Colors.white)),
              const Gap(Space.s2),
              Text(copy.text, textAlign: TextAlign.center, style: context.ty.body.col(s.phase == UpdPhase.failed ? const Color(0xFFFFC9C9) : _muted)),
            ],
          ),
        ),
        if (s.active || (s.phase == UpdPhase.idle && s.got > 0)) ...[const Gap(Space.s3), _Stats(state: s)],
      ],
    );
    // The versions, what's new and the three steps.
    final details = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        enter(_Versions(mine: mine, next: r.version), 1),
        if (s.phase == UpdPhase.permission) ...[const Gap(Space.s4), const _PermissionGuide()],
        if (widget.info.notes.trim().isNotEmpty && s.phase != UpdPhase.permission) ...[const Gap(Space.s4), enter(WhatsNew(widget.info.notes), 2)],
        const Gap(Space.s5),
        enter(_Steps(state: s), 3),
      ],
    );
    final actions = Column(mainAxisSize: MainAxisSize.min, children: _actions(s, r, force));

    return PopScope(
      canPop: widget.optional,
      child: GateStage(
        child: Column(
          children: [
            top,
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  // Laptops (wide, not very tall): two columns, so everything fits a 1366 × 768 screen.
                  if (box.maxWidth >= 900) {
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(Space.s6, 0, Space.s6, Space.s5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: head),
                            const SizedBox(width: 64),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [details, const Gap(Space.s5), actions]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: Space.s5, vertical: Space.s3),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [head, const Gap(Space.s5), details]),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s4),
                        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: actions),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(UpdState s, AppRelease r, bool force) {
    final desk = isDesktop;
    final out = <Widget>[];
    switch (s.phase) {
      case UpdPhase.idle:
        final part = s.got > 0 && s.total > 0;
        out.add(
          _StageBtn(
            part ? 'Continue download (${(s.progress! * 100).round()}%)' : 'Update now',
            icon: PhosphorIcons.downloadSimple(PhosphorIconsStyle.fill),
            onTap: () => _ctl.start(r),
            shine: true,
          ),
        );
        if (widget.optional && !widget.embedded) out.add(_StageBtn('Later', kind: _BtnKind.text, onTap: _leave));
      case UpdPhase.starting:
      case UpdPhase.downloading:
      case UpdPhase.waiting:
        if (widget.optional) {
          out.add(_StageBtn('Keep using the app', icon: PhosphorIcons.arrowRight(), kind: _BtnKind.secondary, onTap: _leave));
        } else {
          out.add(_StageBtn(s.phase == UpdPhase.waiting ? 'Waiting for internet…' : 'Downloading…', loading: true, onTap: null));
        }
        out.add(_StageBtn('Cancel download', kind: _BtnKind.text, onTap: _ctl.cancel));
      case UpdPhase.ready:
        out.add(
          _StageBtn(
            desk ? 'Restart and update' : 'Install update',
            icon: desk ? PhosphorIcons.arrowsClockwise() : PhosphorIcons.arrowCircleUp(PhosphorIconsStyle.fill),
            onTap: () {
              _ctl.autoInstall = true;
              _ctl.install();
            },
            shine: true,
          ),
        );
        if (widget.optional && !widget.embedded) out.add(_StageBtn('Install later', kind: _BtnKind.text, onTap: _leave));
      case UpdPhase.permission:
        out.add(_StageBtn('Open settings', icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), onTap: _ctl.askPermission, shine: true));
        out.add(_StageBtn('I have turned it on', kind: _BtnKind.text, onTap: _ctl.onResume));
      case UpdPhase.installing:
        out.add(_StageBtn(desk ? 'Installing…' : 'Opening installer…', loading: true, onTap: null));
      case UpdPhase.failed:
        out.add(_StageBtn('Try again', icon: PhosphorIcons.arrowClockwise(), onTap: () => _ctl.start(r), shine: true));
        if (widget.optional && !widget.embedded) out.add(_StageBtn('Later', kind: _BtnKind.text, onTap: _leave));
    }
    out.add(const Gap(Space.s2));
    out.add(
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.lockSimple(PhosphorIconsStyle.fill), size: 14, color: _subtle),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              s.phase == UpdPhase.idle && r.size > 0 && !desk
                  ? 'Your progress stays safe · uses about ${r.sizeText}'
                  : 'Your account, XP and saved tests stay safe',
              textAlign: TextAlign.center,
              style: context.ty.cap.col(_subtle),
            ),
          ),
        ],
      ),
    );
    return out;
  }
}

// ---------------------------------------------------------------------------------------------------- pieces

/// The ring around the picture: fills as the update downloads, turns while it connects or installs.
class _UpdateRing extends StatefulWidget {
  const _UpdateRing({required this.state, required this.size});
  final UpdState state;
  final double size;
  @override
  State<_UpdateRing> createState() => _UpdateRingState();
}

class _UpdateRingState extends State<_UpdateRing> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  bool get _turning => widget.state.phase == UpdPhase.starting || widget.state.phase == UpdPhase.installing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _UpdateRing old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_turning && !context.reduceMotion) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state, size = widget.size;
    final rm = context.reduceMotion;
    final p = switch (s.phase) {
      UpdPhase.ready || UpdPhase.permission => 1.0,
      _ => s.progress ?? 0.0,
    };
    final color = switch (s.phase) {
      UpdPhase.failed => Palette.red300,
      UpdPhase.waiting => Palette.amber300,
      UpdPhase.ready => Palette.green300,
      _ => Palette.gold400,
    };
    Widget centre;
    switch (s.phase) {
      case UpdPhase.downloading:
      case UpdPhase.waiting:
        centre = Column(
          key: const ValueKey('pct'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (s.phase == UpdPhase.waiting) Icon(PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill), size: 22, color: Palette.amber300),
            Text('${(p * 100).floor()}%', style: context.ty.h1.tnum.copyWith(fontSize: 38, height: 1.1).col(Colors.white)),
            if (s.total > 0) Text('of ${fmtMb(s.total)}', style: context.ty.cap.tnum.col(_subtle)),
          ],
        );
      case UpdPhase.ready:
        centre = Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), key: const ValueKey('ok'), size: 66, color: Palette.green300);
        if (!rm) centre = centre.animate(key: const ValueKey('ok')).scaleXY(begin: .5, end: 1, duration: 420.ms, curve: Curves.easeOutBack);
      case UpdPhase.permission:
        centre = Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), key: const ValueKey('perm'), size: 62, color: Palette.gold400);
      case UpdPhase.installing:
        centre = Icon(PhosphorIcons.gearSix(PhosphorIconsStyle.fill), key: const ValueKey('inst'), size: 58, color: Palette.gold400);
      case UpdPhase.failed:
        centre = Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.fill), key: const ValueKey('fail'), size: 60, color: Palette.red300);
      case UpdPhase.starting:
      case UpdPhase.idle:
        centre = Icon(PhosphorIcons.arrowCircleUp(PhosphorIconsStyle.fill), key: const ValueKey('idle'), size: 66, color: Palette.gold400);
        if (!rm && s.phase == UpdPhase.idle) {
          centre = centre
              .animate(key: const ValueKey('idle'), onPlay: (a) => a.repeat(reverse: true))
              .moveY(begin: 4, end: -6, duration: 1200.ms, curve: Curves.easeInOut);
        }
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft glow.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color.withValues(alpha: .18), color.withValues(alpha: 0)]),
            ),
          ),
          AnimatedBuilder(
            animation: _spin,
            builder: (_, _) => TweenAnimationBuilder<double>(
              tween: Tween(end: p),
              duration: rm ? Duration.zero : const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              builder: (_, v, _) => CustomPaint(
                size: Size.square(size * .86),
                painter: _RingPainter(progress: _turning ? null : v, turn: _spin.value, color: color),
              ),
            ),
          ),
          Container(
            width: size * .64,
            height: size * .64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .07),
              border: Border.all(color: Colors.white.withValues(alpha: .12)),
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(duration: rm ? Duration.zero : Motion.base, child: centre),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.turn, required this.color});

  /// null: turning (connecting or installing).
  final double? progress;
  final double turn;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    const stroke = 9.0;
    final rect = Offset.zero & s;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: .10),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final p = progress;
    if (p == null) {
      final start = turn * 2 * math.pi - math.pi / 2;
      paint.shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: [color.withValues(alpha: 0), color],
        transform: GradientRotation(start),
      ).createShader(rect);
      canvas.drawArc(arcRect, start, math.pi * .9, false, paint);
      return;
    }
    if (p <= 0) return;
    paint.shader = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: [Color.lerp(color, Colors.white, .35)!, color],
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);
    canvas.drawArc(arcRect, -math.pi / 2, 2 * math.pi * p.clamp(0.0, 1.0), false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.progress != progress || o.turn != turn || o.color != color;
}

/// "12.4 of 28.0 MB · 1.3 MB/s · about 20 s left".
class _Stats extends StatelessWidget {
  const _Stats({required this.state});
  final UpdState state;
  @override
  Widget build(BuildContext context) {
    final s = state;
    final parts = <String>[
      if (s.total > 0) '${(s.got / 1048576).toStringAsFixed(1)} of ${fmtMb(s.total)}' else if (s.got > 0) fmtMb(s.got),
      if (s.phase == UpdPhase.downloading && s.speed > 0) '${(s.speed / 1048576).toStringAsFixed(s.speed >= 10 * 1048576 ? 0 : 1)} MB/s',
      if (s.phase == UpdPhase.downloading && s.left != null) fmtLeft(s.left!),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(parts.join('  ·  '), textAlign: TextAlign.center, style: context.ty.sm.tnum.bold.col(Colors.white));
  }
}

/// Installed version → new version.
class _Versions extends StatelessWidget {
  const _Versions({required this.mine, required this.next});
  final String mine, next;
  @override
  Widget build(BuildContext context) {
    Widget box(String label, String v, {bool hot = false}) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hot ? Palette.gold400.withValues(alpha: .12) : Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hot ? Palette.gold400.withValues(alpha: .45) : Colors.white.withValues(alpha: .10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.ty.cap.bold.col(hot ? Palette.gold300 : _subtle)),
            const SizedBox(height: 2),
            Text(v.isEmpty ? '…' : prettyVersion(v), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty.sm.bold.tnum.col(Colors.white)),
          ],
        ),
      ),
    );
    return Row(
      children: [
        box(isDesktop ? 'ON THIS COMPUTER' : 'ON THIS PHONE', mine),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(PhosphorIcons.arrowRight(), size: 18, color: _subtle),
        ),
        box('NEW VERSION', next, hot: true),
      ],
    );
  }
}

/// Download → Install → Open.
class _Steps extends StatelessWidget {
  const _Steps({required this.state});
  final UpdState state;
  @override
  Widget build(BuildContext context) {
    final at = switch (state.phase) {
      UpdPhase.ready || UpdPhase.permission || UpdPhase.installing => 1,
      _ => 0,
    };
    const labels = ['Download', 'Install', 'Open'];
    Widget dot(int i) {
      final done = i < at, now = i == at;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: Motion.base,
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? Palette.green500 : (now ? Palette.gold400 : Colors.white.withValues(alpha: .08)),
              border: Border.all(color: done || now ? Colors.transparent : Colors.white.withValues(alpha: .18)),
            ),
            child: done
                ? Icon(PhosphorIcons.check(), size: 14, color: Colors.white)
                : Text('${i + 1}', style: context.ty.cap.bold.col(now ? Palette.navy900 : _subtle)),
          ),
          const SizedBox(height: 6),
          Text(labels[i], style: context.ty.cap.bold.col(done || now ? Colors.white : _subtle)),
        ],
      );
    }

    Widget line(int i) => Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: AnimatedContainer(
          duration: Motion.base,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          color: i < at ? Palette.green500 : Colors.white.withValues(alpha: .14),
        ),
      ),
    );
    return Row(children: [dot(0), line(0), dot(1), line(1), dot(2)]);
  }
}

/// How to allow installs from SolutionTee, in three short steps.
class _PermissionGuide extends StatelessWidget {
  const _PermissionGuide();
  @override
  Widget build(BuildContext context) {
    const steps = ['Tap Open settings below', 'Turn on "Allow from this source"', 'Come back here. The update installs by itself'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          for (final (i, t) in steps.indexed)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 10),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Palette.gold400, borderRadius: BorderRadius.circular(8)),
                    child: Text('${i + 1}', style: context.ty.cap.bold.col(Palette.navy900)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(t, style: context.ty.sm.col(Colors.white))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(99)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _muted),
        const SizedBox(width: 5),
        Text(text, style: context.ty.cap.bold.tnum.col(_muted)),
      ],
    ),
  );
}

enum _BtnKind { primary, secondary, text }

/// The buttons on the navy stage: gold (main), glass (second) and plain words.
class _StageBtn extends StatelessWidget {
  const _StageBtn(this.label, {required this.onTap, this.icon, this.kind = _BtnKind.primary, this.loading = false, this.shine = false});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final _BtnKind kind;
  final bool loading, shine;

  @override
  Widget build(BuildContext context) {
    final primary = kind == _BtnKind.primary;
    final fg = primary ? Palette.navy900 : Colors.white;
    final text = kind == _BtnKind.text;
    Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg)),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(label, textAlign: TextAlign.center, style: (text ? context.ty.sm.bold : context.ty.label.bold).col(text ? _muted : fg)),
        ),
      ],
    );
    Widget b = Container(
      height: text ? 48 : 56,
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: text
          ? null
          : BoxDecoration(
              color: primary ? Palette.gold400 : Colors.white.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(16),
              border: primary ? null : Border.all(color: Colors.white.withValues(alpha: .18)),
              boxShadow: primary && onTap != null
                  ? [BoxShadow(color: Palette.gold400.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 6))]
                  : null,
            ),
      child: child,
    );
    if (primary && onTap == null && !loading) b = Opacity(opacity: .6, child: b);
    if (shine && primary && onTap != null && !context.reduceMotion) {
      b = b.animate(onPlay: (a) => a.repeat()).shimmer(delay: 2400.ms, duration: 900.ms, color: Colors.white.withValues(alpha: .45));
    }
    return Padding(
      padding: const EdgeInsets.only(top: Space.s2),
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        child: Pressable(onTap: onTap, borderRadius: BorderRadius.circular(16), child: b),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------- small card

/// The small card over the app: "New version ready" (quiet style), the progress of a download running in the
/// background, and "Update downloaded · Install" when it is done. Tapping it opens the update screen.
class UpdateFloatCard extends ConsumerWidget {
  const UpdateFloatCard({super.key, required this.info, required this.onOpen, this.onClose});
  final UpdateInfo info;
  final VoidCallback onOpen;

  /// null: no close button (a download is running or ready).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(updateCtlProvider);
    final ctl = ref.read(updateCtlProvider.notifier);
    final desk = isDesktop;
    final pct = s.progress == null ? null : '${(s.progress! * 100).floor()}%';
    final (String title, String sub, String? btn, VoidCallback? act) = switch (s.phase) {
      UpdPhase.idle when s.got > 0 => ('Update paused', '${pct ?? ''} downloaded · tap to continue', 'Continue', () => ctl.start(info.release, install: false)),
      UpdPhase.idle => (
        'New version ready',
        '${prettyVersion(info.release.version)}${info.release.sizeText.isEmpty ? '' : ' · ${info.release.sizeText}'}',
        'Update',
        onOpen,
      ),
      UpdPhase.starting => ('Starting download', 'Connecting…', null, null),
      UpdPhase.downloading => ('Downloading update', '${pct ?? ''}${s.left != null ? ' · ${fmtLeft(s.left!)}' : ''}', null, null),
      UpdPhase.waiting => ('Waiting for internet', '${pct ?? ''} · continues by itself', null, null),
      UpdPhase.ready => (
        'Update downloaded',
        desk ? 'Restart SolutionTee to finish' : 'Install it now. It takes a minute',
        desk ? 'Restart' : 'Install',
        () {
          ctl.autoInstall = true;
          ctl.install();
        },
      ),
      UpdPhase.permission => ('One quick step', 'Allow installs from SolutionTee', 'Open', onOpen),
      UpdPhase.installing => ('Installing update', desk ? 'SolutionTee opens again by itself' : 'Opening the installer…', null, null),
      UpdPhase.failed => ('Download paused', 'Check your internet and try again', 'Retry', () => ctl.start(info.release, install: false)),
    };
    final showBar = s.active || (s.phase == UpdPhase.idle && s.got > 0);
    final card = Material(
      color: Colors.transparent,
      child: Pressable(
        onTap: onOpen,
        scale: .98,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Palette.navy900, Color(0xFF13306A)]),
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size.square(40),
                          painter: _MiniRing(
                            s.phase == UpdPhase.ready ? 1 : (s.progress ?? 0),
                            s.phase == UpdPhase.ready ? Palette.green300 : (s.phase == UpdPhase.failed ? Palette.red300 : Palette.gold400),
                          ),
                        ),
                        Icon(
                          switch (s.phase) {
                            UpdPhase.ready => PhosphorIcons.check(),
                            UpdPhase.waiting => PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill),
                            UpdPhase.failed => PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                            UpdPhase.permission => PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                            _ => PhosphorIcons.arrowCircleUp(PhosphorIconsStyle.fill),
                          },
                          size: 20,
                          color: s.phase == UpdPhase.ready ? Palette.green300 : Palette.gold400,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty.sm.bold.col(Colors.white)),
                        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ty.cap.tnum.col(_muted)),
                      ],
                    ),
                  ),
                  if (btn != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Btn(btn, kind: BtnKind.accent, sm: true, onPressed: act),
                    ),
                  if (onClose != null && s.phase == UpdPhase.idle && s.got == 0)
                    IconBtn(PhosphorIcons.x(), label: 'Later', color: _subtle, onPressed: onClose)
                  else
                    const SizedBox(width: 4),
                ],
              ),
              if (showBar) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: s.phase == UpdPhase.starting ? null : s.progress,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: .12),
                    color: s.phase == UpdPhase.waiting ? Palette.amber300 : Palette.gold400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final animated = context.reduceMotion ? card : card.animate().fadeIn(duration: 260.ms).slideY(begin: .4, curve: Motion.out);
    // Phone: across the bottom, above the tab bar. Computer: a card in the bottom-right corner.
    return Positioned(
      left: w >= 900 ? null : Space.s4,
      right: Space.s4,
      bottom: Space.s4 + mq.padding.bottom + (w >= 900 ? 0 : 64),
      width: w >= 900 ? 400 : null,
      child: animated,
    );
  }
}

class _MiniRing extends CustomPainter {
  _MiniRing(this.p, this.color);
  final double p;
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final r = (Offset.zero & s).deflate(2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, 2 * math.pi, false, paint..color = Colors.white.withValues(alpha: .12));
    if (p > 0) canvas.drawArc(r, -math.pi / 2, 2 * math.pi * p.clamp(0.0, 1.0), false, paint..color = color);
  }

  @override
  bool shouldRepaint(covariant _MiniRing o) => o.p != p || o.color != color;
}

// ---------------------------------------------------------------------------------------------------- Me → App update

/// Me → App update: the update screen when there is one; otherwise "You're up to date" with a fresh check.
class AppUpdateScreen extends ConsumerStatefulWidget {
  const AppUpdateScreen({super.key});
  @override
  ConsumerState<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends ConsumerState<AppUpdateScreen> {
  DateTime? _checked;

  @override
  void initState() {
    super.initState();
    Future.microtask(_check);
  }

  void _check() {
    ref.invalidate(appUpdateProvider);
    if (mounted) setState(() => _checked = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final play = appFlavor == 'play';
    final v = ref.watch(appUpdateProvider);
    final u = v.value;
    if (!play && u != null) return UpdateScreen(info: u, optional: !u.force, embedded: !u.force);
    final mine = ref.watch(myVersionNameProvider).value ?? '';
    final loading = v.isLoading;
    final rm = context.reduceMotion;
    Widget hero = Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .07),
        border: Border.all(color: Palette.green300.withValues(alpha: .5), width: 3),
      ),
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3, color: Palette.gold400))
          : Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill), size: 64, color: Palette.green300),
    );
    if (!rm) hero = hero.animate().fadeIn(duration: 300.ms).scaleXY(begin: .9, end: 1, curve: Curves.easeOutBack);
    return GateStage(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s2, Space.s2, Space.s2, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(PhosphorIcons.arrowLeft(), color: Colors.white),
                ),
                Text('App update', style: context.ty.h3.col(Colors.white)),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Space.s5),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      hero,
                      const Gap(Space.s5),
                      Text(
                        loading ? 'Checking for updates…' : (v.hasError ? 'Could not check' : 'You are up to date'),
                        textAlign: TextAlign.center,
                        style: context.ty.h1.col(Colors.white),
                      ),
                      const Gap(Space.s2),
                      Text(
                        play
                            ? 'This copy of the app updates through the Google Play Store.'
                            : v.hasError
                            ? 'Check your internet and try again.'
                            : 'You have the newest SolutionTee CBT. We will tell you when a new version is ready.',
                        textAlign: TextAlign.center,
                        style: context.ty.body.col(_muted),
                      ),
                      const Gap(Space.s5),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(Space.s4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            _InfoRow(isDesktop ? 'On this computer' : 'On this phone', mine.isEmpty ? '…' : prettyVersion(mine)),
                            const Gap(Space.s2),
                            _InfoRow('Last checked', _checked == null || loading ? '…' : 'Just now'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!play)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s5, 0, Space.s5, Space.s4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _StageBtn(
                  loading ? 'Checking…' : 'Check again',
                  icon: PhosphorIcons.arrowsClockwise(),
                  kind: _BtnKind.secondary,
                  loading: loading,
                  onTap: loading ? null : _check,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(label, style: context.ty.sm.col(_muted)),
      const Spacer(),
      Text(value, style: context.ty.sm.bold.tnum.col(Colors.white)),
    ],
  );
}
