import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/xp/streak_ui.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

Map<String, dynamic> streak({int current = 5, bool todayDone = false, Map<String, dynamic>? repair, int freezes = 1}) => {
  'current': current,
  'longest': 12,
  'today_done': todayDone,
  'week': [
    for (var k = 0; k < 7; k++) {'day': '2026-11-0${k + 2}', 'done': k < 2, 'saved': k == 1 ? null : (k == 0 ? null : null), 'today': k == 2},
  ],
  'freezes': freezes,
  'freeze_max': 2,
  'freeze_price': 50,
  'repair': repair,
  'milestones': [
    {'days': 3, 'xp': 20, 'reached': current >= 3},
    {'days': 7, 'xp': 50, 'reached': current >= 7},
  ],
  'next': {'days': 7, 'xp': 50, 'left': 7 - current},
  'celebrate': null,
  'xp': {'enabled': true, 'balance': 300, 'daily_claim': 10, 'claimed_today': false},
  'name': 'Emmanuel Akinbola',
  'avatar': null,
};

Widget wrap(Widget child, Map<String, dynamic> st) => ProviderScope(
  overrides: [
    myStreakProvider.overrideWith((ref) async => st),
    profileProvider.overrideWith((ref) async => {'full_name': 'Emmanuel Akinbola'}),
  ],
  child: MaterialApp(theme: buildTheme(Brightness.dark), home: child),
);

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  testWidgets('streak page: days, longest, freezes, bonuses', (t) async {
    await t.pumpWidget(wrap(const StreakScreen(), streak()));
    await settle(t);
    expect(find.text('5'), findsWidgets);
    expect(find.text('Longest: 12 days'), findsOneWidget);
    expect(find.text('Streak freezes: 1 of 2'), findsOneWidget);
    expect(find.text('50 XP'), findsOneWidget);
    await t.scrollUntilVisible(find.text('7-day streak'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('+20 XP'), findsOneWidget);
  });

  testWidgets('a streak lost yesterday offers a repair for XP', (t) async {
    await t.pumpWidget(wrap(const StreakScreen(), streak(current: 0, repair: {'lost': 9, 'price': 200})));
    await settle(t);
    expect(find.text('Repair your 9-day streak'), findsOneWidget);
    expect(find.text('200 XP'), findsOneWidget);
  });

  testWidgets('daily claim pop-up: name, streak, next bonus and the Claim button', (t) async {
    await t.pumpWidget(wrap(Scaffold(body: DailyClaimSheet(st: streak())), streak()));
    await settle(t);
    expect(find.text('Welcome back, Emmanuel!'), findsOneWidget);
    expect(find.textContaining('5-day streak'), findsOneWidget);
    expect(find.textContaining('2 days to your 7-day bonus'), findsOneWidget);
    expect(find.text('Claim +10 XP'), findsOneWidget);
  });
}
