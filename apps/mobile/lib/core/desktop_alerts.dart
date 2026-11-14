import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notifications_repo.dart';
import 'providers.dart';

/// Live notifications on Windows (D-166). Windows has no Firebase push, but every message the phone gets by push is a
/// row the student can read through `my_notifications` (classes, tutor, games, community, countdown, broadcasts). While
/// the app is open this checks for new ones every [every] and when the window comes back to the front:
/// - window in front: the same in-app toast the phone shows;
/// - window behind or minimised: a Windows notification with the app icon and a flashing taskbar button
///   (windows/runner/flutter_window.cpp); clicking it brings the app forward and opens the message.
/// The student's notification switches (Settings → Notifications) still apply. Messages that arrived before the app
/// opened are not announced (they are in the bell list).
class DesktopAlerts {
  DesktopAlerts(this.ref, {MethodChannel? channel, this.every = const Duration(seconds: 45), this.fetch})
    : _ch = channel ?? const MethodChannel('solutiontee/desktop');

  final Ref ref;
  final Duration every;
  final MethodChannel _ch;

  /// For tests: replaces the server call.
  final Future<List<dynamic>> Function()? fetch;

  /// Opens a message (same as tapping a push on the phone): id, link type, link target.
  void Function(String id, String type, String target)? onOpen;

  /// Shows the in-app toast.
  void Function(String title)? onForeground;

  Timer? _timer;
  AppLifecycleListener? _life;
  Set<String>? _seen;
  String? _uid;
  bool _busy = false;
  final _byId = <String, AppNotification>{};

  bool get running => _timer != null;

  void start() {
    if (_timer != null) return;
    _ch.setMethodCallHandler(_onNative);
    _timer = Timer.periodic(every, (_) => poll());
    _life = AppLifecycleListener(onResume: () => poll());
    poll();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _life?.dispose();
    _life = null;
    _seen = null;
  }

  Future<List<dynamic>> _rows() {
    final f = fetch;
    if (f != null) return f();
    return ref.read(supabaseProvider).rpc('my_notifications', params: {'p_limit': 20}).then((r) => r as List);
  }

  /// One check. The first check after start (or after another student signs in) only remembers what is there.
  Future<void> poll() async {
    if (_busy) return;
    _busy = true;
    try {
      final uid = fetch != null ? 'test' : ref.read(supabaseProvider).auth.currentUser?.id;
      if (uid == null) return;
      if (uid != _uid) {
        _uid = uid;
        _seen = null;
      }
      final list = [for (final r in await _rows()) AppNotification.fromJson(Map<String, dynamic>.from(r as Map))];
      final seen = _seen;
      _seen = {...?seen, ...list.map((n) => n.id)};
      if (seen == null) return;
      final fresh = [
        for (final n in list)
          if (!seen.contains(n.id) && !n.read) n,
      ];
      if (fresh.isEmpty) return;
      ref.invalidate(notificationsProvider);
      final prefs = await ref.read(notificationPrefsProvider.future).catchError((_) => const <String, bool>{});
      final show = [
        for (final n in fresh)
          if (n.topic == 'account' || (prefs[n.topic] ?? true)) n,
      ];
      if (show.isEmpty) return;
      final n = show.first; // newest first
      _byId[n.id] = n;
      final title = show.length == 1 ? n.title : '${show.length} new messages';
      final body = show.length == 1 ? n.body : show.take(3).map((e) => e.title).join(' · ');
      final background = await _ch.invokeMethod<bool>('notify', {'id': show.length == 1 ? n.id : '', 'title': title, 'body': body}).catchError((_) => false);
      if (background != true) onForeground?.call(title);
    } catch (e) {
      debugPrint('Desktop alerts: $e');
    } finally {
      _busy = false;
    }
  }

  Future<dynamic> _onNative(MethodCall call) async {
    if (call.method != 'open') return null;
    final id = '${call.arguments ?? ''}';
    final n = _byId[id];
    onOpen?.call(id, n == null ? '' : '${n.link['type'] ?? ''}', n == null ? '' : '${n.link['target'] ?? ''}');
    return null;
  }
}

final desktopAlertsProvider = Provider<DesktopAlerts>((ref) {
  final a = DesktopAlerts(ref);
  ref.onDispose(a.stop);
  return a;
});
