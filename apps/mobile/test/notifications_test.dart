import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:solutiontee_cbt/data/notifications_repo.dart';
import 'package:solutiontee_cbt/features/notifications/notifications_screen.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

AppNotification n(String id, String topic, String title, Duration ago, {bool read = false, Map<String, dynamic> link = const {}}) =>
    AppNotification(id: id, topic: topic, title: title, body: 'Body of $title', link: link, sentAt: DateTime.now().subtract(ago), read: read);

/// Records markRead calls instead of calling the server.
class FakeRepo implements NotificationsRepo {
  final List<List<String>?> marked = [];
  @override
  Ref get ref => throw UnimplementedError();
  @override
  Future<void> markRead(List<String>? ids) async => marked.add(ids);
  @override
  Future<void> setPref(String topic, bool on) async {}
}

void main() {
  test('time labels', () {
    final now = DateTime(2026, 11, 3, 12);
    expect(agoText(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
    expect(agoText(now.subtract(const Duration(minutes: 2)), now: now), '2 min ago');
    expect(agoText(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
    expect(agoText(now.subtract(const Duration(hours: 30)), now: now), 'Yesterday');
    expect(agoText(now.subtract(const Duration(days: 4)), now: now), '4 days ago');
  });

  test('links open the right screen', () {
    expect(linkRoute({'type': 'news', 'target': 'abc'}), '/news/abc');
    expect(linkRoute({'type': 'screen', 'target': '/test/setup?exam=JAMB&mode=quick'}), '/test/setup?exam=JAMB&mode=quick');
    expect(linkRoute({'type': 'screen', 'target': 'https://evil.example'}), isNull);
    expect(linkRoute({}), isNull);
  });

  test('filter chips: Challenges, Classes, everything else is Updates', () {
    expect(n('1', 'challenges', 'a', Duration.zero).category, 'Challenges');
    expect(n('1', 'classes', 'a', Duration.zero).category, 'Classes');
    expect(n('1', 'streak', 'a', Duration.zero).category, 'Updates');
  });

  testWidgets('inbox: Today and Earlier, filters, unread count, mark all read, tap opens the link', (t) async {
    final repo = FakeRepo();
    String? opened;
    final list = [
      n('1', 'challenges', 'Weekly Challenge is live', const Duration(minutes: 5)),
      n('2', 'announcements', 'JAMB dates are out', const Duration(hours: 2), link: {'type': 'news', 'target': 'reg'}),
      n('3', 'new_questions', 'New: JAMB 2026 Physics', const Duration(days: 2), read: true),
    ];
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
        GoRoute(
          path: '/news/:id',
          builder: (_, s) {
            opened = s.pathParameters['id'];
            return const Scaffold(body: Text('NEWS'));
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(body: Text('SETTINGS')),
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [notificationsProvider.overrideWith((_) async => list), notificationsRepoProvider.overrideWithValue(repo)],
        child: MaterialApp.router(theme: buildTheme(Brightness.light), routerConfig: router),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('2 unread'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
    expect(find.text('Weekly Challenge is live'), findsOneWidget);

    await t.tap(find.text('Classes'));
    await t.pumpAndSettle();
    expect(find.text('You are all caught up'), findsOneWidget);
    await t.tap(find.text('All'));
    await t.pumpAndSettle();

    await t.tap(find.text('Mark all read'));
    await t.pumpAndSettle();
    expect(repo.marked.last, isNull);
    expect(find.text('2 unread'), findsNothing);

    await t.tap(find.text('JAMB dates are out'));
    await t.pumpAndSettle();
    expect(opened, 'reg');
  });
}
