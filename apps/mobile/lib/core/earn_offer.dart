import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The "watch to earn" offer shown at a break (owner, 2026-11-07: better design and motion). AdMob requires that a
/// rewarded interstitial is introduced and can be skipped: the student sees what they get, a countdown ring, "Watch
/// now" and "No thanks". Used for "+5 XP" and for "open JAMB 2005 for 1 hour".
enum EarnKind { xp, unlock }

Future<bool> showEarnOffer(
  BuildContext context, {
  required EarnKind kind,
  required String headline,
  required String body,
  int need = 1,
  int progress = 0,
  int seconds = 5,
}) async {
  final go = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: .6),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, _, _) => _EarnOffer(kind: kind, headline: headline, body: body, need: need, progress: progress, seconds: seconds),
    transitionBuilder: (ctx, anim, _, child) {
      final rm = MediaQuery.of(ctx).disableAnimations;
      final a = CurvedAnimation(parent: anim, curve: rm ? Curves.linear : Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: anim,
        child: rm ? child : ScaleTransition(scale: Tween(begin: .86, end: 1.0).animate(a), child: child),
      );
    },
  );
  return go == true;
}

const _navy = Color(0xFF0B1F44), _navy2 = Color(0xFF16346E), _gold = Color(0xFFF2B233), _goldLight = Color(0xFFFFD47A);

class _EarnOffer extends StatefulWidget {
  const _EarnOffer({required this.kind, required this.headline, required this.body, required this.need, required this.progress, required this.seconds});
  final EarnKind kind;
  final String headline, body;
  final int need, progress, seconds;
  @override
  State<_EarnOffer> createState() => _EarnOfferState();
}

class _EarnOfferState extends State<_EarnOffer> with TickerProviderStateMixin {
  late final AnimationController _count =
      AnimationController(
        vsync: this,
        duration: Duration(seconds: widget.seconds),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) _close(true);
      });
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _count.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.of(context).disableAnimations) _float.repeat(reverse: true);
    });
  }

  void _close(bool go) {
    if (_closed) return;
    _closed = true;
    if (go) HapticFeedback.lightImpact();
    Navigator.of(context).pop(go);
  }

  @override
  void dispose() {
    _count.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final unlock = widget.kind == EarnKind.unlock;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(colors: [_navy2, _navy], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
              boxShadow: [BoxShadow(color: _gold.withValues(alpha: .18), blurRadius: 40, spreadRadius: -8)],
            ),
            child: Stack(
              children: [
                // Soft gold glow in the corner.
                Positioned(
                  top: -60,
                  right: -40,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [_gold.withValues(alpha: .22), _gold.withValues(alpha: 0)]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _float,
                        builder: (_, child) => Transform.translate(offset: Offset(0, -6 * math.sin(_float.value * math.pi)), child: child),
                        child: _Badge(unlock: unlock),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.headline,
                        textAlign: TextAlign.center,
                        style: t.headlineSmall?.copyWith(color: _goldLight, fontWeight: FontWeight.w800, height: 1.15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.body,
                        textAlign: TextAlign.center,
                        style: t.bodyMedium?.copyWith(color: const Color(0xFFDCE4F2), height: 1.4),
                      ),
                      if (widget.need > 1) ...[
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < widget.need; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: i == widget.progress ? 22 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: i < widget.progress
                                      ? _gold
                                      : i == widget.progress
                                      ? _goldLight
                                      : Colors.white.withValues(alpha: .18),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Video ${widget.progress + 1} of ${widget.need}', style: t.labelSmall?.copyWith(color: const Color(0xFFAFC0DD))),
                      ],
                      const SizedBox(height: 22),
                      _WatchButton(count: _count, onTap: () => _close(true)),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => _close(false),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFAFC0DD), minimumSize: const Size(120, 44)),
                        child: const Text('No thanks'),
                      ),
                      Text('A short video ad · you can skip', style: t.labelSmall?.copyWith(color: Colors.white.withValues(alpha: .45))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The gold XP coin, or a lock opening, with a soft halo.
class _Badge extends StatelessWidget {
  const _Badge({required this.unlock});
  final bool unlock;
  @override
  Widget build(BuildContext context) {
    final rm = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: rm ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: .5 + .5 * v, child: child),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [_goldLight, _gold], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: _gold.withValues(alpha: .45), blurRadius: 24)],
        ),
        alignment: Alignment.center,
        child: unlock
            ? const Icon(Icons.lock_open_rounded, size: 42, color: _navy)
            : const Text(
                'XP',
                style: TextStyle(color: _navy, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1),
              ),
      ),
    );
  }
}

/// "Watch now" with a ring that fills while the countdown runs; it starts by itself when the ring is full.
class _WatchButton extends StatelessWidget {
  const _WatchButton({required this.count, required this.onTap});
  final AnimationController count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: _navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: count,
            builder: (_, _) {
              final left = ((1 - count.value) * (count.duration!.inSeconds)).ceil();
              return SizedBox(
                width: 28,
                height: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(value: count.value, strokeWidth: 3, color: _navy, backgroundColor: _navy.withValues(alpha: .15)),
                    Text(
                      '$left',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _navy),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          const Text('Watch now'),
        ],
      ),
    ),
  );
}
