import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/community/community.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

// Community (C15, D-151).
Map<String, dynamic> _post(String id, {String status = 'shown', String body = 'How do I find the gradient?', String? reason, bool mine = false}) => {
  'id': id,
  'user_id': 'u-$id',
  'name': 'Ada Obi',
  'body': body,
  'image_path': null,
  'subject_id': 2,
  'status': status,
  'reason': reason,
  'likes': 4,
  'comments': 2,
  'created_at': DateTime.now().subtract(const Duration(hours: 3)).toUtc().toIso8601String(),
  'mine': mine,
  'liked': false,
  'following': false,
};

Widget _app(List<Map<String, dynamic>> feed) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    communityFeedProvider.overrideWith((ref, k) async => k.tab == 'for_you' ? feed : const []),
    subjectsProvider.overrideWith(
      (_) async => [
        {'id': 2, 'code': 'MTH', 'name': 'Mathematics', 'sort': 2},
      ],
    ),
  ],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: const CommunityScreen()),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 14; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  test('time ago', () {
    final now = DateTime(2026, 11, 11, 12);
    expect(agoText(now.subtract(const Duration(seconds: 20)).toIso8601String(), now), 'now');
    expect(agoText(now.subtract(const Duration(minutes: 5)).toIso8601String(), now), '5 min');
    expect(agoText(now.subtract(const Duration(hours: 3)).toIso8601String(), now), '3 h');
    expect(agoText(now.subtract(const Duration(days: 2)).toIso8601String(), now), '2 d');
    expect(agoText(DateTime(2026, 10, 1).toIso8601String(), now), '1 Oct');
    expect(communityError('too_many'), contains('tomorrow'));
  });

  testWidgets('feed shows posts, my waiting post and my rejected post with the reason', (t) async {
    t.view.physicalSize = const Size(1200, 4200);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _app([
        _post('a'),
        _post('b', status: 'pending', mine: true, body: 'My new question'),
        _post('c', status: 'rejected', mine: true, body: 'Off topic', reason: 'This is not about learning.'),
      ]),
    );
    await _settle(t);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('New post'), findsOneWidget);
    expect(find.text('Ada Obi'), findsNWidgets(3));
    expect(find.textContaining('Mathematics'), findsWidgets);
    expect(find.text('Being checked. Only you can see it for now.'), findsOneWidget);
    expect(find.text('Not shared: This is not about learning.'), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // likes only on the shown post
  });

  testWidgets('empty feed invites the first post', (t) async {
    t.view.physicalSize = const Size(1200, 3000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const []));
    await _settle(t);
    expect(find.text('No posts here yet'), findsOneWidget);
  });
}
