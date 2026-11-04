import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/study_repo.dart';
import 'package:solutiontee_cbt/features/premium/checkout.dart';
import 'package:solutiontee_cbt/features/premium/payments.dart';
import 'package:solutiontee_cbt/features/premium/paywall.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

const _plans = [
  {
    'id': 1,
    'code': 'monthly',
    'name': 'Monthly',
    'description': 'SAMPLE price.',
    'price_kobo': 150000,
    'duration_days': 30,
    'ends_on': null,
    'play_product_id': null,
  },
  {
    'id': 2,
    'code': 'three_months',
    'name': '3 Months',
    'description': 'SAMPLE price.',
    'price_kobo': 350000,
    'duration_days': 90,
    'ends_on': null,
    'play_product_id': 'premium_three_months',
  },
];

/// The server's quote_price / redeem_code, faked: TST20 is 20% off; FREEWEEK gives 7 days.
class FakeCodes implements CodeRepo {
  int quotes = 0;
  @override
  Future<Quote> quote(String plan, {String? code}) async {
    quotes++;
    final list = plan == 'monthly' ? 150000 : 350000;
    if (code == null) return Quote(listKobo: list, discountKobo: 0, amountKobo: list, periodEnd: DateTime(2027, 2, 1));
    if (code == 'TST20') {
      return Quote(listKobo: list, discountKobo: list ~/ 5, amountKobo: list - list ~/ 5, code: code, label: '20% off', periodEnd: DateTime(2027, 2, 1));
    }
    throw PayFailed(codeError('not_found'), code: 'not_found');
  }

  @override
  Future<(int, DateTime?)> redeem(String code) async {
    if (code == 'FREEWEEK') return (7, DateTime(2026, 11, 10));
    throw PayFailed(codeError('expired'), code: 'expired');
  }
}

/// A Paystack stand-in: "opens" checkout, then the check says success.
class FakePay implements PaymentProvider {
  String? boughtWith;
  int checks = 0;
  PayResult next = const PaySuccess(null);
  @override
  bool get takesCodes => true;
  @override
  Future<PayResult> buy(Map<String, dynamic> plan, {String? code, String? channel}) async {
    boughtWith = '${plan['code']}:${code ?? '-'}';
    return const PayPending('st_0123456789abcdef0123');
  }

  @override
  Future<PayResult> check(String reference) async {
    checks++;
    return next;
  }
}

List _overrides(FakeCodes codes) => [
  codeRepoProvider.overrideWithValue(codes),
  plansForSaleProvider.overrideWith((_) async => [for (final p in _plans) Map<String, dynamic>.from(p)]),
  plansProvider.overrideWith((_) async => [for (final p in _plans) Map<String, dynamic>.from(p)]),
  accessRulesProvider.overrideWith(
    (_) async => {
      'free': {'ai': 3, 'jamb': 3},
      'premium': {'ai': 100, 'jamb': 'all'},
    },
  ),
  profileProvider.overrideWith((_) async => {'full_name': 'Ada Obi'}),
  myPlanProvider.overrideWith((_) async => {'tier': 'free'}),
  openYearsProvider.overrideWith((_) async => const []),
];

Widget _app(GoRouter router, FakeCodes codes) => ProviderScope(
  overrides: [..._overrides(codes)],
  child: MaterialApp.router(theme: buildTheme(Brightness.light), routerConfig: router),
);

void main() {
  test('friendly code errors, including which plans a code works on', () {
    expect(codeError('expired'), 'This code has expired.');
    expect(codeError('wrong_plan', plans: ['3 Months', 'Exam Season']), 'This code only works on the 3 Months or Exam Season plan.');
    expect(codeError('days_code'), contains('Redeem a code'));
    expect(codeError('whatever'), 'That code cannot be used.');
  });

  test('the Play account id matches the server (sha256 of the user id)', () {
    // Same value as supabase/functions/_shared/paycrypto.ts playAccountId().
    expect(playAccountId('00000000-0000-4000-8000-0000000000d1'), '1c2a3b2a2495fd02ef1524dca9969e5cc9cd4d59f56b7cfff1a7b4ab1c549145');
  });

  test('plan period text', () {
    expect(planPeriod({'duration_days': 30}), '1 month');
    expect(planPeriod({'duration_days': 90}), '3 months');
    expect(planPeriod({'duration_days': 7}), '7 days');
    expect(planPeriod({'duration_days': null, 'ends_on': '2027-07-31'}), 'Until 31 Jul 2027');
  });

  test('this test build pays with Paystack (direct flavor is the default)', () {
    expect(store, Store.direct);
  });

  testWidgets('checkout: server price, discount code, Paystack, checking, then success', (t) async {
    final codes = FakeCodes();
    final pay = FakePay();
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (_, _) => CheckoutScreen(planCode: 'three_months', provider: pay),
        ),
        GoRoute(
          path: '/pay-success',
          builder: (_, s) => PaySuccessScreen(info: (s.extra as Map<String, Object?>?) ?? const {}),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );
    await t.pumpWidget(_app(router, codes));
    await t.pumpAndSettle();

    expect(find.text('SolutionTee Premium'), findsOneWidget);
    expect(find.text('Until 1 Feb 2027'), findsOneWidget);
    expect(find.text('Pay ₦3,500 with card'), findsOneWidget);

    // A wrong code shows the server's reason; the right one lowers the total.
    await t.tap(find.text('Have a discount code?'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'nope');
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    expect(find.textContaining('could not find that code'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'tst20');
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    expect(find.text('TST20 applied'), findsOneWidget);
    expect(find.text('Pay ₦2,800 with card'), findsOneWidget);

    await t.tap(find.text('Pay ₦2,800 with card'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500)); // the checking card spins, so no pumpAndSettle
    expect(pay.boughtWith, 'three_months:TST20');
    expect(find.text('Checking payment'), findsOneWidget);

    pay.next = PaySuccess(DateTime(2027, 2, 1));
    await t.tap(find.text('I have paid, check now'));
    await t.pump();
    await t.pump(const Duration(seconds: 3));
    expect(find.text('You are now Premium!'), findsOneWidget);
    expect(find.text('1 Feb 2027'), findsOneWidget);
    expect(find.text('You saved ₦700'), findsOneWidget);
    expect(find.textContaining('Thank you, Ada'), findsOneWidget);
    expect(find.textContaining('100 AI prompts a day'), findsOneWidget);
  });

  testWidgets('checkout: a failed payment shows why and lets the student try again', (t) async {
    final pay = FakePay()..next = const PayFailed('The payment did not go through.', code: 'failed');
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (_, _) => CheckoutScreen(planCode: 'monthly', provider: pay),
        ),
      ],
    );
    await t.pumpWidget(_app(router, FakeCodes()));
    await t.pumpAndSettle();
    await t.tap(find.text('Pay ₦1,500 with card'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.text('I have paid, check now'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('The payment did not go through.'), findsOneWidget);
    expect(find.text('Pay ₦1,500 with card'), findsOneWidget);
  });

  testWidgets('redeem a code: free days added, or the reason it failed', (t) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (c, _) => Scaffold(
            body: Builder(
              builder: (c) => TextButton(onPressed: () => showRedeemSheet(c), child: const Text('open')),
            ),
          ),
        ),
      ],
    );
    await t.pumpWidget(_app(router, FakeCodes()));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'old1');
    await t.tap(find.text('Redeem'));
    await t.pumpAndSettle();
    expect(find.text('This code has expired.'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'freeweek');
    await t.tap(find.text('Redeem'));
    await t.pumpAndSettle();
    expect(find.text('7 days of Premium added!'), findsOneWidget);
    expect(find.textContaining('10 Nov 2026'), findsOneWidget);
  });

  testWidgets('paywall Continue opens checkout for the chosen plan', (t) async {
    String? opened;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (c, _) => Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () => showPaywall(c, reason: 'WAEC'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/checkout',
          builder: (_, s) {
            opened = s.uri.queryParameters['plan'];
            return const Scaffold(body: Text('CHECKOUT'));
          },
        ),
      ],
    );
    await t.pumpWidget(_app(router, FakeCodes()));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('SAMPLE PRICES'), findsOneWidget);
    await t.tap(find.textContaining('Continue with 3 Months'));
    await t.pumpAndSettle();
    expect(opened, 'three_months');
    expect(find.text('CHECKOUT'), findsOneWidget);
  });
}
