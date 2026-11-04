import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/xp/xp_screens.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

Map<String, dynamic> wallet({bool enabled = true, bool claimed = false}) => {
  'enabled': enabled,
  'balance': 1250,
  'earned': 1050,
  'bought': 200,
  'claimed_today': claimed,
  'daily_claim': 10,
  'today': 45,
  'daily_cap': 300,
  'rules': {'daily_claim': 10, 'test': 5, 'mock': 30, 'qotd': 2, 'qotd_right': 3, 'challenge_finish': 20, 'referral': 50},
  'history': [
    {'amount': 10, 'kind': 'earned', 'reason': 'daily_claim', 'note': null, 'at': '2026-11-04T07:00:00Z'},
    {'amount': -100, 'kind': 'earned', 'reason': 'entry', 'note': null, 'at': '2026-11-03T18:00:00Z'},
  ],
};

Widget wrap(Widget child, Map<String, dynamic> d) => ProviderScope(
  overrides: [myXpProvider.overrideWith((ref) async => d)],
  child: MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(body: child),
  ),
);

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  test('XP numbers are written with thousands separators', () {
    expect(xpText(1250), '1,250');
    expect(xpText(14000), '14,000');
    expect(xpText(-100), '-100');
  });

  testWidgets('wallet: balance, earned vs bought, today against the cap, ways to earn, history', (t) async {
    await t.pumpWidget(wrap(const XpWalletScreen(), wallet()));
    await settle(t);
    expect(find.text('1,250'), findsOneWidget);
    expect(find.text('200 bought · 1,050 earned'), findsOneWidget);
    expect(find.text('45 / 300'), findsOneWidget);
    expect(find.text('Claim +10'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Challenge entry'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Daily claim'), findsOneWidget);
    expect(find.text('-100'), findsOneWidget);
  });

  testWidgets('the claim card hides once today is claimed', (t) async {
    await t.pumpWidget(wrap(const Column(children: [XpChip(), DailyClaimCard()]), wallet(claimed: true)));
    await settle(t);
    expect(find.text('1,250'), findsOneWidget);
    expect(find.textContaining('Claim +'), findsNothing);
  });

  testWidgets('XP switched off by the admin: no chip, no claim', (t) async {
    await t.pumpWidget(wrap(const Column(children: [XpChip(), DailyClaimCard()]), wallet(enabled: false)));
    await settle(t);
    expect(find.text('1,250'), findsNothing);
    expect(find.textContaining('Claim +'), findsNothing);
  });
}
