import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/ads.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/news/news_screens.dart';
import 'package:solutiontee_cbt/features/news/news_social.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

// News v2 (B7, D-141).
final _news = [
  {
    'id': 'a',
    'title': 'JAMB registration opens',
    'summary': 'Dates and steps',
    'body': 'Long text',
    'category': 'exam',
    'publish_at': '2026-11-10T09:00:00Z',
    'comments_on': true,
  },
  {'id': 'b', 'title': 'Five ways to read faster', 'body': 'Tips', 'category': 'tips', 'publish_at': '2026-11-09T09:00:00Z', 'comments_on': true},
  {'id': 'c', 'title': 'Mock exam this Saturday', 'body': 'Mock', 'category': 'exam', 'publish_at': '2026-11-08T09:00:00Z', 'comments_on': false},
];

Widget _app(Widget home) => ProviderScope(
  overrides: [
    adsConfigProvider.overrideWith((_) async => AdsConfig.off),
    newsProvider.overrideWith((_) async => _news),
    newsMetaProvider.overrideWith(
      (_) async => {
        'a': (likes: 12, comments: 2, liked: true, saved: false),
        'b': (likes: 0, comments: 0, liked: false, saved: true),
        'c': (likes: 1, comments: 0, liked: false, saved: false),
      },
    ),
    newsCommentsProvider.overrideWith(
      (ref, id) async => id == 'a'
          ? [
              {'id': 'x', 'name': 'Ada O.', 'body': 'Thank you for this!', 'created_at': '2026-11-10T10:00:00Z', 'mine': false, 'hidden': false},
              {'id': 'y', 'name': 'Tunde B.', 'body': 'Very helpful', 'created_at': '2026-11-10T11:00:00Z', 'mine': true, 'hidden': false},
            ]
          : <Map<String, dynamic>>[],
    ),
  ],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 15; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets('news list: group chips and Saved filter the posts', (t) async {
    t.view.physicalSize = const Size(2400, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const NewsListScreen()));
    await _settle(t);
    expect(find.text('JAMB registration opens'), findsOneWidget);
    expect(find.textContaining('12 likes'), findsOneWidget);

    await t.tap(find.text('Study tips'));
    await _settle(t);
    expect(find.text('JAMB registration opens'), findsNothing);
    expect(find.text('Five ways to read faster'), findsOneWidget);

    await t.tap(find.text('Saved'));
    await _settle(t);
    expect(find.text('Five ways to read faster'), findsOneWidget);
    expect(find.text('Mock exam this Saturday'), findsNothing);
  });

  testWidgets('article: likes, comments, share and related news from the same group first', (t) async {
    t.view.physicalSize = const Size(1080, 6000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const NewsDetailScreen(id: 'a')));
    await _settle(t);
    expect(find.text('12'), findsWidgets); // likes
    expect(find.text('Share'), findsWidgets);
    expect(find.text('Comments (2)'), findsOneWidget);
    expect(find.text('Thank you for this!'), findsOneWidget);
    expect(find.textContaining('You ·'), findsOneWidget); // my own comment
    expect(find.text('Related news'), findsOneWidget);
    // The same group (exam) comes before the other one.
    final mock = t.getTopLeft(find.text('Mock exam this Saturday')).dy;
    final tips = t.getTopLeft(find.text('Five ways to read faster')).dy;
    expect(mock < tips, isTrue);
  });

  testWidgets('a post with comments off shows no comments box', (t) async {
    t.view.physicalSize = const Size(1080, 6000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(const NewsDetailScreen(id: 'c')));
    await _settle(t);
    expect(find.text('Write a comment…'), findsNothing);
    expect(find.textContaining('Comments'), findsNothing);
  });
}
