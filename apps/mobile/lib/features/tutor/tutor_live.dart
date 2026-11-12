import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Live updates for the tutor pages that heal themselves (D-153).
//
// Why: the first join of a private channel can fail on the server ("MissingPartition" while Realtime wakes up), and
// supabase_flutter does not join a failed channel again. Students then saw new messages only after reopening the app.
// Now every channel joins again with a back-off (1, 2, 4 … 30 s), the screen refreshes what it missed each time the
// channel is up again and when the app comes back to the front, and a slow poll runs as a safety net.

/// One Realtime channel that joins again by itself after an error, a time-out or a close.
class LiveChannel {
  LiveChannel(this.topic, this.configure, {this.private = false, this.presenceKey = '', this.onUp, this.onDown});

  final String topic;

  /// Adds the listeners (onPostgresChanges, onBroadcast, onPresenceSync…) to a fresh channel.
  final void Function(RealtimeChannel ch) configure;
  final bool private;
  final String presenceKey;

  /// Joined (also after each re-join): fetch what was missed, track presence.
  final void Function(RealtimeChannel ch)? onUp;

  /// Lost the channel; it joins again by itself.
  final VoidCallback? onDown;

  RealtimeChannel? _ch;
  Timer? _retry;
  int _fails = 0;
  bool _closed = false;
  bool up = false;

  RealtimeChannel? get channel => _ch;
  SupabaseClient get _db => Supabase.instance.client;

  void open() {
    if (_closed) return;
    final c = _db.channel(
      topic,
      opts: RealtimeChannelConfig(private: private, key: presenceKey),
    );
    configure(c);
    _ch = c;
    c.subscribe((status, _) {
      if (_closed || _ch != c) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        _fails = 0;
        up = true;
        onUp?.call(c);
      } else {
        up = false;
        onDown?.call();
        _again(c);
      }
    });
  }

  /// Seconds to wait before joining again: 1, 2, 4, 8, 16, 30, 30…
  static int backoff(int fails) => math.min(30, 1 << math.min(fails, 5));

  void _again(RealtimeChannel c) {
    if (_retry?.isActive ?? false) return;
    _retry = Timer(Duration(seconds: backoff(_fails++)), () {
      if (_closed || _ch != c) return;
      _ch = null; // the "closed" callback of the old channel is ignored from here
      _db.removeChannel(c).catchError((_) => 'error');
      open();
    });
  }

  /// Join again now (the app came back to the front with the channel down).
  void restart() {
    if (_closed || up) return;
    _retry?.cancel();
    final c = _ch;
    _ch = null;
    if (c != null) _db.removeChannel(c).catchError((_) => 'error');
    open();
  }

  Future<void> close() async {
    _closed = true;
    up = false;
    _retry?.cancel();
    final c = _ch;
    _ch = null;
    if (c != null) await _db.removeChannel(c).catchError((_) => 'error');
  }
}

/// Calls [onResume] when the app comes back to the front.
class ResumeWatcher with WidgetsBindingObserver {
  ResumeWatcher(this.onResume) {
    WidgetsBinding.instance.addObserver(this);
  }
  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);
}
