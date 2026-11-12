import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import 'tutor.dart';
import 'tutor_chat.dart';
import 'tutor_live.dart';
import 'tutor_quiz.dart';

// The tutor's messages reach the student anywhere in the app (D-154): a banner slides down from the top with the tutor's
// photo, name and message; tap it to open the chat, swipe it up to close. It comes from the student's own private
// channel (user:<id>), which the database fills the moment a tutor writes, so it is as fast as the chat itself.
// Only students with a paid or active tutor plan open this channel. Never shown on the tutor screens or during a test.

class TutorLiveBanner extends ConsumerStatefulWidget {
  const TutorLiveBanner({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<TutorLiveBanner> createState() => _TutorLiveBannerState();
}

class _TutorLiveBannerState extends ConsumerState<TutorLiveBanner> {
  LiveChannel? _ch;
  String? _topic;
  ResumeWatcher? _resume;
  Map<String, dynamic>? _msg;
  Timer? _hide, _soon;

  @override
  void dispose() {
    _ch?.close();
    _resume?.dispose();
    _hide?.cancel();
    _soon?.cancel();
    super.dispose();
  }

  /// Opens (or closes) the student's channel to match their tutor plan.
  void _sync(String? uid, bool active) {
    final topic = uid != null && active ? 'user:$uid' : null;
    if (topic == _topic) return;
    _ch?.close();
    _ch = null;
    _topic = topic;
    if (topic == null) return;
    _ch = LiveChannel(
      topic,
      private: true,
      (ch) => ch
        ..onBroadcast(event: 'tutor_msg', callback: (p) => _onMessage(broadcastPayload(p)))
        ..onBroadcast(event: 'tutor_req', callback: (_) => _refreshSoon()),
    )..open();
    _resume ??= ResumeWatcher(() => _ch?.restart());
  }

  void _refreshSoon() {
    _soon?.cancel();
    _soon = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.invalidate(tutorProvider);
      ref.invalidate(tutorQuizzesProvider);
    });
  }

  String get _where {
    try {
      final cfg = ref.read(routerProvider).routerDelegate.currentConfiguration;
      return cfg.isEmpty ? '' : cfg.last.matchedLocation; // the top-most screen, pushed ones included
    } catch (_) {
      return '';
    }
  }

  void _onMessage(Map<String, dynamic> m) {
    _refreshSoon();
    if (!mounted || m['role'] == 'student' || m['role'] == 'system') return;
    final at = _where;
    // Never over the chat itself, and never during a test, a challenge or a quiz.
    final busy = at.startsWith('/tutor') || at.startsWith('/cbt') || at.contains('/play') || at.contains('/mock') || at.startsWith('/test/setup');
    if (tutorChatsOpen > 0 || busy) return;
    HapticFeedback.lightImpact();
    setState(() => _msg = m);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 5), () => mounted ? setState(() => _msg = null) : null);
  }

  void _open() {
    final m = _msg;
    setState(() => _msg = null);
    final ref_ = m?['ref'] is Map ? m!['ref'] as Map : null;
    try {
      ref.read(routerProvider).push(ref_?['type'] == 'quiz' && ref_?['id'] != null ? '/tutor/quiz/${ref_!['id']}' : '/tutor');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    String? uid;
    try {
      uid = ref.watch(sessionProvider).value?.user.id ?? Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {} // not set up (tests)
    final status = (ref.watch(tutorProvider).value?['request'] as Map?)?['status'];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(uid, status == 'paid' || status == 'matched');
    });
    final m = _msg;
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: top + 8,
          left: 10,
          right: 10,
          child: AnimatedSwitcher(
            duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 420),
            reverseDuration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (w, a) => FadeTransition(
              opacity: CurvedAnimation(parent: a, curve: const Interval(0, .6)),
              child: SlideTransition(
                position: Tween(begin: const Offset(0, -1.2), end: Offset.zero).animate(a),
                child: ScaleTransition(scale: Tween(begin: .92, end: 1.0).animate(a), child: w),
              ),
            ),
            child: m == null
                ? const SizedBox.shrink(key: ValueKey('none'))
                : _SwipeAway(
                    key: ValueKey(m['id']),
                    onDismiss: () => setState(() => _msg = null),
                    onTap: _open,
                    child: _BannerCard(m: m),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Follows the finger: swipe up or sideways to close, tap to open the chat.
class _SwipeAway extends StatefulWidget {
  const _SwipeAway({super.key, required this.child, required this.onDismiss, required this.onTap});
  final Widget child;
  final VoidCallback onDismiss, onTap;
  @override
  State<_SwipeAway> createState() => _SwipeAwayState();
}

class _SwipeAwayState extends State<_SwipeAway> {
  Offset _d = Offset.zero;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    onPanUpdate: (e) => setState(() => _d = Offset(_d.dx + e.delta.dx, math.min(0, _d.dy + e.delta.dy))),
    onPanEnd: (e) {
      if (_d.dy < -30 || _d.dx.abs() > 90 || e.velocity.pixelsPerSecond.dy < -300) {
        widget.onDismiss();
      } else {
        setState(() => _d = Offset.zero);
      }
    },
    child: AnimatedContainer(
      duration: _d == Offset.zero ? const Duration(milliseconds: 200) : Duration.zero,
      transform: Matrix4.translationValues(_d.dx, _d.dy, 0),
      child: Opacity(opacity: (1 - _d.dx.abs() / 240).clamp(.2, 1.0), child: widget.child),
    ),
  );
}

/// The banner: navy glass card, the tutor's photo with a gold ring, name, a "Tutor" tag, two lines of the message,
/// and a gold bar that runs down while it is shown.
class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.m});
  final Map<String, dynamic> m;
  @override
  Widget build(BuildContext context) {
    final from = '${m['from'] ?? 'Your tutor'}';
    final msg = ChatMsg.from(m);
    final quiz = msg.kind == 'ref' && msg.ref?['type'] == 'quiz';
    final text = quiz ? 'Sent you a quiz: ${msg.ref?['title'] ?? msg.body}' : chatPreview(msg);
    return Semantics(
      liveRegion: true,
      button: true,
      label: 'New message from $from: $text. Tap to open.',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Palette.navy900, Palette.blue950], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Palette.gold400, shape: BoxShape.circle),
                      child: TutorAvatar(name: from, photo: m['photo'] as String?, size: 42),
                    ),
                    const Gap(Space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(from, style: context.ty.sm.bold.col(Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              const Gap(6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: Palette.gold400.withValues(alpha: .18), borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  quiz ? 'QUIZ' : 'TUTOR',
                                  style: context.ty.cap.bold.col(Palette.gold400).copyWith(fontSize: 9.5, letterSpacing: .6),
                                ),
                              ),
                              const Spacer(),
                              Text('now', style: context.ty.cap.col(Palette.navy200)),
                            ],
                          ),
                          const Gap(2),
                          Text(text, style: context.ty.sm.col(Palette.navy100).copyWith(height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const Gap(6),
                          Text(quiz ? 'Tap to open the quiz' : 'Tap to reply', style: context.ty.cap.bold.col(Palette.gold300)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Time left before it hides by itself.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1, end: 0),
                duration: const Duration(seconds: 5),
                builder: (_, v, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: context.reduceMotion ? 1 : v,
                    child: Container(height: 3, color: Palette.gold400),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
