import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/profile/badges.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

// Badges v2 (B8, D-142).
Map<String, dynamic> _b(String name, int tier, num value, {String icon = 'fire'}) => {
  'id': name.hashCode,
  'key': name,
  'name': name,
  'description': 'How to win $name',
  'icon': icon,
  'metric': 'tests',
  'targets': {'bronze': 5, 'silver': 25, 'gold': 100, 'diamond': 500},
  'rewards': {
    'bronze': {'xp': 20},
    'silver': {'xp': 50},
    'gold': {'xp': 100},
    'diamond': {'xp': 250, 'days': 7},
  },
  'value': value,
  'tier': tier,
};

Widget _app(Widget home, Map<String, dynamic> data) => ProviderScope(
  overrides: [badgesProvider.overrideWith((_) async => data)],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
);

void main() {
  test('progress runs from the level reached to the next one', () {
    expect(badgeProgress(_b('a', 0, 0)), 0);
    expect(badgeProgress(_b('a', 1, 15)), closeTo(.5, .001)); // 5 → 25
    expect(badgeProgress(_b('a', 4, 900)), 1);
  });

  testWidgets('Me: badges with levels won, most progress first', (t) async {
    t.view.physicalSize = const Size(1200, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _app(const Scaffold(body: SingleChildScrollView(child: BadgesSection())), {
        'on': true,
        'badges': [_b('Daily habit', 2, 10), _b('Night owl', 0, 0, icon: 'moonStars'), _b('Test taker', 4, 600, icon: 'exam')],
        'won': [],
      }),
    );
    await t.pumpAndSettle();
    expect(find.text('Badges'), findsOneWidget);
    expect(find.text('6 of 12 levels'), findsOneWidget);
    expect(find.text('Test taker'), findsOneWidget);
    expect(find.text('Night owl'), findsOneWidget);
  });

  testWidgets('a badge sheet lists the four levels with their rewards', (t) async {
    t.view.physicalSize = const Size(1200, 2600);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (c) => TextButton(onPressed: () => showBadgeSheet(c, _b('Daily habit', 1, 15)), child: const Text('open')),
          ),
        ),
        {},
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('You have 15 of 25 for Silver'), findsOneWidget);
    expect(find.text('Diamond · 500'), findsOneWidget);
    expect(find.text('250 XP + 7 days of Premium'), findsOneWidget);
  });

  testWidgets('the badge-won moment shows the level and the reward', (t) async {
    t.view.physicalSize = const Size(1200, 2600);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: BadgeWonDialog(win: {'name': 'Daily habit', 'icon': 'fire', 'tier': 3, 'description': 'Practise many days in a row.'}, xp: 100, days: 0),
        ),
      ),
    );
    await t.pump();
    expect(find.text('BADGE WON'), findsOneWidget);
    expect(find.text('Gold level'), findsOneWidget);
    expect(find.text('+100 XP'), findsOneWidget);
  });
}
