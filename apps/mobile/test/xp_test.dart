import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
  'packs': [
    {'xp': 550, 'naira': 500},
    {'xp': 1200, 'naira': 1000},
  ],
  'premium_options': [
    {'code': 'monthly', 'name': 'Monthly', 'xp': 3000},
    {'code': 'three_months', 'name': '3 Months', 'xp': 800},
  ],
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

  testWidgets('Premium with XP: affordable plans can be bought, others show how much more is needed', (t) async {
    await t.pumpWidget(wrap(const XpWalletScreen(), wallet()));
    await settle(t);
    await t.scrollUntilVisible(find.text('Get Premium with XP'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('1,750 XP more needed'), findsOneWidget);
    expect(find.text('You have enough XP'), findsOneWidget);
  });

  testWidgets('XP cannot be bought (D-110): no Buy XP even when the server still lists packs', (t) async {
    await t.pumpWidget(wrap(const XpWalletScreen(), wallet()));
    await settle(t);
    for (var i = 0; i < 6; i++) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await t.pump();
      expect(find.text('Buy XP'), findsNothing);
      expect(find.text('₦500'), findsNothing);
    }
  });

  testWidgets('inside the tabs (like the app), the Premium-with-XP pop-up opens and Cancel closes it', (t) async {
    final router = GoRouter(
      initialLocation: '/me/xp',
      routes: [
        ShellRoute(
          builder: (_, _, child) => Scaffold(
            body: child,
            bottomNavigationBar: const SizedBox(height: 56, child: Text('TABS')),
          ),
          routes: [GoRoute(path: '/me/xp', builder: (_, _) => const XpWalletScreen())],
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [myXpProvider.overrideWith((ref) async => wallet())],
        child: MaterialApp.router(theme: buildTheme(Brightness.light), routerConfig: router),
      ),
    );
    await settle(t);
    await t.scrollUntilVisible(find.text('You have enough XP'), 300, scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(t.element(find.text('800 XP')), alignment: .5);
    await t.pump();
    await t.tap(find.text('800 XP'));
    await settle(t);
    expect(find.text('Get 3 Months for 800 XP?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await settle(t);
    expect(find.text('Get 3 Months for 800 XP?'), findsNothing);
    expect(find.byType(XpWalletScreen), findsOneWidget);
  });
}
