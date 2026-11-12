import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/community/community.dart';
import 'package:solutiontee_cbt/features/community/community_data.dart';
import 'package:solutiontee_cbt/features/community/community_shell.dart';
import 'package:solutiontee_cbt/features/community/community_widgets.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

// Community v2 (D-155): post cell states, feed list, grouped notes, compose limit.
Map<String, dynamic> _post(String id, {String status = 'shown', String body = 'How do I find the gradient? #JAMB2027', String? reason, bool mine = false}) => {
  'id': id,
  'user_id': 'u-$id',
  'name': 'Ada Obi',
  'handle': 'ada_o',
  'avatar_path': null,
  'body': body,
  'images': const [],
  'subject_id': 2,
  'status': status,
  'reason': reason,
  'likes': 4,
  'comments': 2,
  'reposts': 1,
  'created_at': DateTime.now().subtract(const Duration(hours: 3)).toUtc().toIso8601String(),
  'mine': mine,
  'liked': false,
  'reposted': false,
  'bookmarked': false,
  'following': false,
};

Widget _wrap(Widget child, {bool reduce = false}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    subjectsProvider.overrideWith(
      (_) async => [
        {'id': 2, 'code': 'MTH', 'name': 'Mathematics', 'sort': 2},
      ],
    ),
    communityMeProvider.overrideWith((_) async => {'name': 'Tolu Adeyemi', 'handle': 'tolu'}),
  ],
  child: MaterialApp(
    theme: buildTheme(Brightness.dark),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce, size: const Size(400, 1400)),
      child: Scaffold(body: child),
    ),
  ),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 16; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

void _big(WidgetTester t) {
  t.view.physicalSize = const Size(1200, 4200);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

void main() {
  test('time, counts and errors', () {
    final now = DateTime(2026, 11, 11, 12);
    expect(agoText(now.subtract(const Duration(seconds: 20)).toIso8601String(), now), 'now');
    expect(agoText(now.subtract(const Duration(minutes: 5)).toIso8601String(), now), '5m');
    expect(agoText(now.subtract(const Duration(hours: 3)).toIso8601String(), now), '3h');
    expect(agoText(now.subtract(const Duration(days: 2)).toIso8601String(), now), '2d');
    expect(agoText(DateTime(2026, 10, 1).toIso8601String(), now), '1 Oct');
    expect(countText(999), '999');
    expect(countText(1200), '1.2K');
    expect(countText(15000), '15K');
    expect(communityError('too_many'), contains('tomorrow'));
    expect(communityError('wait'), contains('once a month'));
  });

  test('grouped note words', () {
    expect(
      noteText({
        'kind': 'like',
        'count': 5,
        'actors': [
          {'name': 'Chidinma O.'},
        ],
      }),
      'Chidinma O. and 4 others liked your post',
    );
    expect(
      noteText({
        'kind': 'follow',
        'count': 1,
        'actors': [
          {'name': 'Musa Sani'},
        ],
      }),
      'Musa Sani followed you',
    );
    expect(noteText({'kind': 'ai', 'actors': const []}), 'SolutionTee AI answered your question');
  });

  testWidgets('post cell: shown post with handle, subject, #topic and actions', (t) async {
    _big(t);
    await t.pumpWidget(_wrap(PostCell(post: _post('a'))));
    await _settle(t);
    expect(find.text('Ada Obi'), findsOneWidget);
    expect(find.textContaining('@ada_o'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.textContaining('#JAMB2027', findRichText: true), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // likes
    expect(find.bySemanticsLabel(RegExp('^Like, 4')), findsOneWidget);
  });

  testWidgets('post cell: my waiting post and my rejected post with the reason', (t) async {
    _big(t);
    await t.pumpWidget(
      _wrap(
        Column(
          children: [
            PostCell(post: _post('b', status: 'pending', mine: true)),
            PostCell(
              post: _post('c', status: 'rejected', mine: true, reason: 'Community is for school, so sports chat is not shown.'),
            ),
          ],
        ),
        reduce: true,
      ),
    );
    await _settle(t);
    expect(find.textContaining('Being checked'), findsOneWidget);
    expect(find.text('Not shown'), findsOneWidget);
    expect(find.textContaining('sports chat is not shown'), findsOneWidget);
    expect(find.text('Delete post'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Like')), findsNothing); // no actions until shown
  });

  testWidgets('quote, repost line and AI answer', (t) async {
    _big(t);
    await t.pumpWidget(
      _wrap(
        PostCell(
          post: {
            ..._post('d'),
            'reposted_by': {'id': 'x', 'name': 'Kemi Eze', 'handle': 'kemi'},
            'quote': {
              'id': 'q',
              'name': 'Amaka E.',
              'handle': 'amaka.e',
              'body': 'Speed = frequency x wavelength',
              'images': const [],
              'created_at': DateTime.now().toIso8601String(),
            },
            'ai_answer': 'Balance the other elements first and leave oxygen for last.',
          },
        ),
        reduce: true,
      ),
    );
    await _settle(t);
    expect(find.text('Kemi Eze reposted'), findsOneWidget);
    expect(find.text('Amaka E.'), findsOneWidget);
    expect(find.text('SolutionTee AI'), findsOneWidget);
    expect(find.text('Read the full answer'), findsOneWidget);
  });

  testWidgets('feed list: loads, then shows the empty state', (t) async {
    _big(t);
    final full = Pager((_) async => [_post('a'), _post('e')]);
    final none = Pager((_) async => const []);
    await t.pumpWidget(_wrap(FeedList(pager: full, empty: const Text('Nothing here'))));
    await full.refresh();
    await _settle(t);
    expect(find.text('Ada Obi'), findsNWidgets(2));
    await t.pumpWidget(_wrap(FeedList(pager: none, empty: const Text('Nothing here'))));
    await none.refresh();
    await _settle(t);
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('compose: Post is off until you write, and the ring counts down near 500', (t) async {
    _big(t);
    await t.pumpWidget(_wrap(const ComposeScreen(), reduce: true));
    await _settle(t);
    expect(find.text('Post'), findsOneWidget);
    expect(find.textContaining('@solutiontee', findRichText: true), findsWidgets);
    await t.enterText(find.byType(TextField), 'a' * 470);
    await _settle(t);
    expect(find.text('30'), findsOneWidget);
    expect(find.bySemanticsLabel('30 characters left'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Hello @solutiontee what is osmosis?');
    await _settle(t);
    expect(find.textContaining('SolutionTee AI will answer'), findsOneWidget);
  });
}
