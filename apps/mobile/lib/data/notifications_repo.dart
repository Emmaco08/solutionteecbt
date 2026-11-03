import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';

/// Push topics a student can switch off (Settings → Notifications), in the prototype's order.
/// `account` messages (e.g. "You are now Premium") are always on.
const notificationTopics = <(String, String, String)>[
  ('announcements', 'Announcements', 'News and important updates from SolutionTee'),
  ('new_questions', 'New questions added', 'When new past questions are ready to practise'),
  ('streak', 'Streak reminders', 'One reminder in the evening if you have not practised'),
  ('classes', 'Class reminders', 'Before a live class you joined starts'),
  ('challenges', 'Challenges', 'When a challenge opens or results are out'),
];

/// One message in the inbox (`my_notifications`).
class AppNotification {
  AppNotification({
    required this.id,
    required this.topic,
    required this.title,
    required this.body,
    required this.link,
    required this.sentAt,
    required this.read,
  });
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    topic: j['topic'] as String? ?? 'announcements',
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    link: Map<String, dynamic>.from((j['link'] as Map?) ?? const {}),
    sentAt: DateTime.tryParse('${j['sent_at']}')?.toLocal() ?? DateTime.now(),
    read: j['read'] == true,
  );
  final String id, topic, title, body;
  final Map<String, dynamic> link;
  final DateTime sentAt;
  final bool read;

  /// The prototype's filter chips: Challenges, Classes, Updates (everything else).
  String get category => switch (topic) {
    'challenges' => 'Challenges',
    'classes' => 'Classes',
    _ => 'Updates',
  };

  AppNotification copyRead() => AppNotification(id: id, topic: topic, title: title, body: body, link: link, sentAt: sentAt, read: true);
}

/// The inbox, cached on the phone so it opens offline.
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const [];
  return cached(
    ref,
    'notifications:$uid',
    (s) => s.rpc('my_notifications', params: {'p_limit': 100}),
    (j) => [for (final r in rows(j)) AppNotification.fromJson(r)],
  );
});

/// Unread count for the bell on Home.
final unreadCountProvider = Provider<int>((ref) => (ref.watch(notificationsProvider).value ?? const []).where((n) => !n.read).length);

/// The student's topic switches (missing = on).
final notificationPrefsProvider = FutureProvider<Map<String, bool>>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const {};
  return cached(
    ref,
    'notif_prefs:$uid',
    (s) => s.from('notification_prefs').select('topic, enabled'),
    (j) => {for (final r in rows(j)) r['topic'] as String: r['enabled'] == true},
  );
});

class NotificationsRepo {
  NotificationsRepo(this.ref);
  final Ref ref;

  Future<void> markRead(List<String>? ids) async {
    await ref.read(supabaseProvider).rpc('mark_notifications_read', params: {'p_ids': ids});
    ref.invalidate(notificationsProvider);
  }

  Future<void> setPref(String topic, bool on) async {
    final sb = ref.read(supabaseProvider);
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;
    await sb.from('notification_prefs').upsert({'user_id': uid, 'topic': topic, 'enabled': on, 'updated_at': DateTime.now().toUtc().toIso8601String()});
    ref.invalidate(notificationPrefsProvider);
  }
}

final notificationsRepoProvider = Provider<NotificationsRepo>((ref) => NotificationsRepo(ref));

/// "2 min ago", "3 h ago", "Yesterday", "4 days ago" (prototype `ago`).
String agoText(DateTime t, {DateTime? now}) {
  final m = (now ?? DateTime.now()).difference(t).inMinutes;
  if (m < 1) return 'Just now';
  if (m < 60) return '$m min ago';
  if (m < 1440) return '${(m / 60).round()} h ago';
  if (m < 2880) return 'Yesterday';
  return '${(m / 1440).round()} days ago';
}

/// Where a notification's link goes inside the app (null = nowhere).
String? linkRoute(Map<String, dynamic> link) {
  final type = '${link['type'] ?? ''}', target = '${link['target'] ?? ''}';
  if (target.isEmpty) return null;
  return switch (type) {
    'news' => '/news/$target',
    'screen' when target.startsWith('/') => target,
    _ => null,
  };
}
