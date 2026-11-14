import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/notifications_repo.dart';
import 'config.dart';
import 'desktop_alerts.dart';
import 'providers.dart';
import 'platform.dart';

/// Push notifications through Firebase Cloud Messaging (milestone 4D, D-063).
///
/// The app works without Firebase: a build with no `google-services.json` simply has push off, and the
/// inbox still fills from the server. Sending happens only on the server (`push` Edge Function).
class PushService {
  PushService(this.ref);
  final Ref ref;
  bool _ready = false;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _openSub, _fgSub;

  /// Called with an in-app route when a notification is tapped (set by the app shell).
  void Function(String route)? onOpen;

  /// Called when a message arrives while the app is open (the shell shows a toast).
  void Function(String title)? onForeground;

  bool get available => _ready;

  /// Starts Firebase once per app run. Safe to call often.
  Future<bool> init() async {
    if (_ready) return true;
    if (isDesktop) return false; // Windows has no Firebase push: DesktopAlerts covers it (desktop_alerts.dart, D-166)
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _ready = true;
    } catch (e) {
      debugPrint('Push off: $e');
      return false;
    }
    final fm = FirebaseMessaging.instance;
    _openSub = FirebaseMessaging.onMessageOpenedApp.listen(_opened);
    _fgSub = FirebaseMessaging.onMessage.listen((m) {
      ref.invalidate(notificationsProvider);
      onForeground?.call(m.notification?.title ?? 'New notification');
    });
    final first = await fm.getInitialMessage();
    if (first != null) Future.delayed(const Duration(milliseconds: 600), () => _opened(first));
    return true;
  }

  void _opened(RemoteMessage m) => openLink('${m.data['id'] ?? ''}', '${m.data['link_type'] ?? ''}', '${m.data['link_target'] ?? ''}');

  /// Opens a tapped message (a phone push, or a Windows notification, D-166): marks it read, then its link.
  void openLink(String id, String type, String target) {
    ref.invalidate(notificationsProvider);
    if (id.isNotEmpty) ref.read(notificationsRepoProvider).markRead([id]).ignore();
    if (type == 'url' && target.startsWith('https://')) {
      launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication).ignore();
      return;
    }
    onOpen?.call(linkRoute({'type': type, 'target': target}) ?? '/notifications');
  }

  /// After sign-in: saves this phone's token and matches FCM topics to the student's switches and plan.
  Future<void> register({required bool premium}) async {
    if (isDesktop) {
      // Windows: live notifications while the app is open, from the same inbox (D-166).
      ref.read(desktopAlertsProvider)
        ..onOpen = openLink
        ..onForeground = ((title) => onForeground?.call(title))
        ..start();
      return;
    }
    if (!await init()) return;
    final fm = FirebaseMessaging.instance;
    final sb = ref.read(supabaseProvider);
    if (sb.auth.currentUser == null) return;
    Future<void> save(String t) => sb.rpc('register_push_token', params: {'p_token': t, 'p_platform': 'android', 'p_version': Config.appVersion});
    try {
      // The classic registration token is what the FCM HTTP v1 `token` field takes (D-063); the newer
      // register()/onRegistered installation id is not used until the server sends to it.
      // ignore: deprecated_member_use
      final token = await fm.getToken();
      if (token != null) await save(token);
      // ignore: deprecated_member_use
      _tokenSub ??= fm.onTokenRefresh.listen((t) => save(t).ignore());
      await syncTopics(premium: premium);
    } catch (e) {
      debugPrint('Push register failed: $e');
    }
  }

  /// FCM topics: `t_<topic>` for each switch that is on, and `tier_free` or `tier_premium`.
  Future<void> syncTopics({required bool premium, Map<String, bool>? prefs}) async {
    if (!_ready) return;
    final fm = FirebaseMessaging.instance;
    final p = prefs ?? await ref.read(notificationPrefsProvider.future).catchError((_) => const <String, bool>{});
    for (final (topic, _, _) in notificationTopics) {
      final on = p[topic] ?? true;
      try {
        on ? await fm.subscribeToTopic('t_$topic') : await fm.unsubscribeFromTopic('t_$topic');
      } catch (_) {}
    }
    try {
      await fm.subscribeToTopic(premium ? 'tier_premium' : 'tier_free');
      await fm.unsubscribeFromTopic(premium ? 'tier_free' : 'tier_premium');
    } catch (_) {}
  }

  static const _ch = MethodChannel('solutiontee/notify');

  /// Whether this app may show notifications on the phone right now (Android's own switch for the app).
  Future<bool> enabled() async {
    try {
      return await _ch.invokeMethod<bool>('enabled') ?? true;
    } catch (_) {
      return true; // tests and other platforms
    }
  }

  /// Opens the phone's notification settings for SolutionTee.
  Future<void> openSettings() async {
    try {
      await _ch.invokeMethod<bool>('openSettings');
    } catch (_) {}
  }

  Future<int> _sdk() async {
    try {
      return await _ch.invokeMethod<int>('sdk') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Asked already in this app run (the app asks once per opening, D-064).
  bool askedThisRun = false;

  /// Like a normal app: while notifications are off, every opening of the app asks again.
  /// Android 13+ shows its own "Allow notifications?" box (it stops showing it after two "Don't allow"),
  /// so we ask Android while it still shows the box. Returns true when notifications are on; false means the
  /// caller should show our own "Turn on notifications" sheet, which opens the phone's settings.
  Future<bool> ensureAllowed({required Future<int> Function() timesAsked, required Future<void> Function(int) setTimesAsked}) async {
    if (await enabled()) return true;
    if (!await init()) return true; // push is not set up in this build: do not nag
    if (await _sdk() >= 33) {
      final n = await timesAsked();
      if (n < 2) {
        await setTimesAsked(n + 1);
        await FirebaseMessaging.instance.requestPermission();
        if (await enabled()) return true;
      }
    }
    return false;
  }

  /// On log-out: this phone stops getting the old account's messages.
  Future<void> signOut() async {
    if (!_ready) return;
    try {
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  void dispose() {
    _tokenSub?.cancel();
    _openSub?.cancel();
    _fgSub?.cancel();
  }
}

final pushProvider = Provider<PushService>((ref) {
  final p = PushService(ref);
  ref.onDispose(p.dispose);
  return p;
});
