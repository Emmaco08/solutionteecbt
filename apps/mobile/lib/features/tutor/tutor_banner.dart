import 'dart:async';

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
      return ref.read(routerProvider).routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return '';
    }
  }

  void _onMessage(Map<String, dynamic> m) {
    _refreshSoon();
    if (!mounted || m['role'] == 'student' || m['role'] == 'system') return;
    final at = _where;
    // Not over the chat itself, and never during a test, a challenge or a quiz.
    if (at.startsWith('/tutor') || at.startsWith('/cbt') || at.contains('/play') || at.contains('/mock') || at.startsWith('/test/setup')) return;
    HapticFeedback.lightImpact();
    setState(() => _msg = m);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 5), () => mounted ? setState(() => _msg = null) : null);
  }

  void _open() {
    setState(() => _msg = null);
    try {
      ref.read(routerProvider).push('/tutor');
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
        AnimatedPositioned(
          duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          top: m == null ? -160 : top + 8,
          left: 12,
          right: 12,
          child: m == null
              ? const SizedBox.shrink()
              : GestureDetector(
                  onTap: _open,
                  onVerticalDragEnd: (d) => (d.primaryVelocity ?? 0) < -100 ? setState(() => _msg = null) : null,
                  child: _BannerCard(m: m),
                ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.m});
  final Map<String, dynamic> m;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final from = '${m['from'] ?? 'Your tutor'}';
    final msg = ChatMsg.from(m);
    final quiz = msg.kind == 'ref' && msg.ref?['type'] == 'quiz';
    return Semantics(
      liveRegion: true,
      label: 'New message from $from',
      child: Material(
        color: context.isDark ? const Color(0xFF13233F) : Colors.white,
        elevation: 8,
        shadowColor: Colors.black38,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(
            children: [
              TutorAvatar(name: from, photo: m['photo'] as String?, size: 42),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(from, style: context.ty.sm.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Text('now', style: context.ty.cap.col(c.textSubtle)),
                      ],
                    ),
                    Text(
                      quiz ? 'New quiz: ${msg.ref?['title'] ?? msg.body}' : chatPreview(msg),
                      style: context.ty.sm.col(c.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Gap(Space.s2),
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(color: Palette.gold400, borderRadius: BorderRadius.circular(2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
