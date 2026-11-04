import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/compete/compete_data.dart';
import 'package:solutiontee_cbt/features/premium/pay_methods.dart';
import 'package:solutiontee_cbt/features/premium/pay_ui.dart';
import 'package:solutiontee_cbt/features/premium/payments.dart';
import 'package:solutiontee_cbt/features/premium/paystack_web.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Paystack's sheet stand-in.
class FakeSheet extends PaystackSheet {
  FakeSheet(this.answer, {this.ok = true});
  final Map<String, dynamic> answer;
  final bool ok;
  int launches = 0;
  @override
  Future<bool> available() async => ok;
  @override
  Future<Map<String, dynamic>> launch({required String publicKey, required String accessCode, bool dark = false}) async {
    launches++;
    return answer;
  }
}

class FakeProvider extends PaystackProvider {
  // ignore: use_super_parameters
  FakeProvider({PaystackSheet sheet = const PaystackSheet(), Future<bool> Function(Uri)? open})
    : super(
        SupabaseClient('http://localhost', 'test', authOptions: const AuthClientOptions(autoRefreshToken: false)),
        sheet: sheet,
        open: open ?? ((_) async => true),
      );
  PayResult next = const PayPending('st_0123456789abcdef0123');
  int checks = 0;
  @override
  Future<PayResult> check(String reference) async {
    checks++;
    return next;
  }

  final cancels = <String>[];
  PayResult cancelAnswer = const PayCancelled();
  @override
  Future<PayResult> cancel(String reference, {String? reason}) async {
    cancels.add(reason ?? '');
    return cancelAnswer;
  }
}

const card = {
  'reference': 'st_0123456789abcdef0123',
  'url': 'https://checkout.paystack.com/abc',
  'access_code': 'abc',
  'public_key': 'pk_test_x',
  'amount_kobo': 350000,
};

void main() {
  test('pay method → what the server gets', () {
    expect(PaystackProvider.methodBody(null), {'method': 'card'});
    expect(PaystackProvider.methodBody('transfer'), {'method': 'transfer'});
    expect(PaystackProvider.methodBody('ussd:919'), {'method': 'ussd', 'bank': '919'});
    expect(payChannel(PayMethod.ussd, '737'), 'ussd:737');
  });

  test('bank transfer and USSD answers go to our own screen', () async {
    final p = FakeProvider();
    final t = await p.openResult({
      'reference': 'st_1',
      'amount_kobo': 350000,
      'transfer': {'account_number': '1234567890', 'account_name': 'PAYSTACK-TITAN', 'bank': 'Titan Bank'},
    });
    expect(t, isA<PayOffline>());
    expect((t as PayOffline).transfer?['account_number'], '1234567890');
    final u = await p.openResult({
      'reference': 'st_2',
      'amount_kobo': 150000,
      'ussd': {'code': '*737*33*4*18791#', 'bank': 'GTBank'},
    });
    expect((u as PayOffline).ussd?['code'], '*737*33*4*18791#');
  });

  test('card: Paystack sheet cancelled or failed; no sheet → in-app page', () async {
    final cancelled = FakeSheet({'status': 'cancelled'});
    final cp = FakeProvider(sheet: cancelled);
    expect(await cp.openResult(card), isA<PayCancelled>());
    expect(cancelled.launches, 1);
    expect(cp.cancels, ['closed the card sheet']); // the server is told at once (D-095)

    final failed = await FakeProvider(sheet: FakeSheet({'status': 'failed', 'message': 'Declined'})).openResult(card);
    expect((failed as PayFailed).message, 'Declined');

    Uri? opened;
    final page = await FakeProvider(
      sheet: FakeSheet({}, ok: false),
      open: (u) async {
        opened = u;
        return true;
      },
    ).openResult(card);
    expect(page, isA<PayPending>());
    expect(opened.toString(), 'https://checkout.paystack.com/abc');

    // Without a public key from the server the sheet is not used either.
    final noKey = FakeSheet({'status': 'success'});
    await FakeProvider(sheet: noKey).openResult({...card, 'public_key': null});
    expect(noKey.launches, 0);
  });

  test('card: sheet says paid → the server is asked (verify) before Premium shows', () async {
    final p = FakeProvider(sheet: FakeSheet({'status': 'success', 'reference': 'st_0123456789abcdef0123'}))..next = PaySuccess(DateTime(2027));
    expect(await p.openResult(card), isA<PaySuccess>());
    expect(p.checks, 1);
  });

  testWidgets('transfer screen shows the account and closes by itself when the payment is confirmed', (t) async {
    final p = FakeProvider();
    PayResult? got;
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => got = await showPayOffline(
                  context,
                  const PayOffline(
                    'st_0123456789abcdef0123',
                    amountKobo: 350000,
                    transfer: {'account_number': '1234567890', 'account_name': 'PAYSTACK-TITAN', 'bank': 'Titan Bank'},
                  ),
                  p,
                  what: 'Premium · 3 Months',
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('1234567890'), findsOneWidget);
    expect(find.text('Titan Bank'), findsOneWidget);
    expect(find.text('₦3,500'), findsWidgets);
    await t.tap(find.text('I have sent the money'));
    await t.pump(const Duration(milliseconds: 100));
    expect(p.checks, greaterThan(0));
    p.next = PaySuccess(DateTime(2027));
    await t.pump(const Duration(seconds: 6)); // the 5-second check
    await t.pump(const Duration(milliseconds: 500));
    expect(got, isA<PaySuccess>());
    expect(find.text('1234567890'), findsNothing);
  });

  test('challenge rules: places left, full, minimum winning score', () {
    final open = Challenge({'max_players': 50, 'joined': 48, 'min_win_pct': 60});
    expect(open.placesLeft, 2);
    expect(open.full, isFalse);
    expect(open.minWinPct, 60);
    expect(Challenge({'max_players': 50, 'joined': 50}).full, isTrue);
    // A student who already joined is never "locked out" by the limit.
    expect(
      Challenge({
        'max_players': 50,
        'joined': 50,
        'mine': {'status': 'finished'},
      }).full,
      isFalse,
    );
    expect(Challenge({'joined': 999}).full, isFalse);
    expect(Challenge({'min_win_pct': 0}).minWinPct, isNull);
  });

  test('OPay, PocketApp, Zap and bank apps open Paystack\'s own screen (all methods); card opens straight on the card form', () {
    for (final m in [PayMethod.opay, PayMethod.pocketapp, PayMethod.zap, PayMethod.bankApp]) {
      expect(payChannel(m, '737'), 'page');
      expect(m.inPaystackScreen, isTrue);
    }
    expect(PaystackProvider.methodBody('page'), {'method': 'page'});
    expect(PaystackProvider.methodBody('card'), {'method': 'card'});
    expect(PayMethod.card.inPaystackScreen, isFalse);
  });

  testWidgets('the picker lists every way to pay and explains the Paystack screen for apps', (t) async {
    var picked = PayMethod.card;
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, set) => SingleChildScrollView(
              child: PayMethodPicker(method: picked, bank: '737', onChanged: (m, _) => set(() => picked = m)),
            ),
          ),
        ),
      ),
    );
    for (final name in ['Card', 'Bank transfer', 'USSD', 'OPay', 'Zap', 'Bank app']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('PocketApp'), findsNothing); // hidden: not on this account's Paystack checkout
    await t.tap(find.text('OPay'));
    await t.pump(const Duration(milliseconds: 300));
    expect(picked, PayMethod.opay);
    expect(find.textContaining('Opens straight on OPay'), findsOneWidget);
  });

  test('OPay / Zap / PocketApp / bank apps: Paystack\'s web checkout in our own screen', () async {
    final w = await FakeProvider().openResult({'reference': 'st_1', 'url': 'https://checkout.paystack.com/abc'}, web: true);
    expect(w, isA<PayWeb>());
    expect((w as PayWeb).url.host, 'checkout.paystack.com');
    expect(PayMethod.opay.viaName, 'OPay');
    expect(PayMethod.card.viaName, isNull);
  });

  test('embedded checkout: app links open the app, Paystack close cancels, our done page checks', () {
    expect(paystackNav(Uri.parse('https://checkout.paystack.com/abc')), WebNav.stay);
    expect(paystackNav(Uri.parse('https://standard.paystack.co/close')), WebNav.cancel);
    expect(paystackNav(Uri.parse('https://admin.solutiontee.com/pay/done?reference=st_1')), WebNav.closeAndCheck);
    expect(paystackNav(Uri.parse('intent://pay?x=1#Intent;scheme=opay;package=team.opay.pay;end')), WebNav.openApp);
    expect(paystackNav(Uri.parse('tel:*737#')), WebNav.openApp);
    final t = intentTargets(Uri.parse('intent://pay?x=1#Intent;scheme=opay;package=team.opay.pay;S.browser_fallback_url=https%3A%2F%2Fopay.ng%2Fpay;end'));
    expect(t.map((u) => u.toString()).toList(), ['opay://pay?x=1', 'https://opay.ng/pay', 'market://details?id=team.opay.pay']);
  });

  test('the tap script looks for the chosen option by name and reports back', () {
    final js = autoTapScript('OPay');
    expect(js, contains("new RegExp('(^| )(pay with +)?OPay *\$', 'i')"));
    expect(js, contains("StApp.postMessage('clicked')"));
    // The tap goes to the link itself: Paystack listens on the <a> inside each row (phone test 2026-11-04).
    expect(js, contains("document.querySelectorAll('a, button, [role=\"button\"]')"));
    expect(js, contains("StApp.postMessage('notfound')"));
    expect(autoTapScript('Pocket App!'), contains('PocketApp')); // only letters reach the page
  });

  Future<void> openTransfer(WidgetTester t, FakeProvider p, void Function(PayResult?) got) async {
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => got(
                  await showPayOffline(
                    context,
                    const PayOffline(
                      'st_0123456789abcdef0123',
                      amountKobo: 350000,
                      transfer: {'account_number': '1234567890', 'account_name': 'PAYSTACK-TITAN', 'bank': 'Titan Bank'},
                    ),
                    p,
                    what: 'Premium · 3 Months',
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pressBack(WidgetTester t) async {
    await t.binding.handlePopRoute();
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('back on a payment asks first: Stay keeps it, Leave cancels it on the server (D-095)', (t) async {
    final p = FakeProvider();
    var closed = false;
    PayResult? got;
    await openTransfer(t, p, (r) => (closed = true, got = r));
    await pressBack(t);
    expect(find.text('Leave this payment?'), findsOneWidget);
    expect(find.text('Stay and pay'), findsOneWidget);
    expect(find.text('I have paid · check now'), findsOneWidget);
    expect(find.text('Leave and cancel payment'), findsOneWidget);

    // Stay: the pop-up closes, the payment screen is still there, nothing is cancelled.
    await t.tap(find.text('Stay and pay'));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Leave this payment?'), findsNothing);
    expect(find.text('1234567890'), findsOneWidget);
    expect(p.cancels, isEmpty);
    expect(closed, isFalse);

    // Our own back arrow asks too; Leave cancels and closes with "cancelled".
    await t.tap(find.byTooltip('Back').first);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Leave this payment?'), findsOneWidget);
    await t.tap(find.text('Leave and cancel payment'));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(p.cancels, ['left the bank transfer']);
    expect(got, isA<PayCancelled>());
    expect(find.text('1234567890'), findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('back, then "I have paid": checks now and keeps checking outside (no cancel)', (t) async {
    final p = FakeProvider();
    PayResult? got;
    await openTransfer(t, p, (r) => got = r);
    final before = p.checks;
    await pressBack(t);
    await t.tap(find.text('I have paid · check now'));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(p.checks, greaterThan(before));
    expect(p.cancels, isEmpty);
    expect(got, isA<PayPending>());
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('leaving after paying in the bank app: the server finds the payment and it counts', (t) async {
    final p = FakeProvider()..cancelAnswer = PaySuccess(DateTime(2027));
    PayResult? got;
    await openTransfer(t, p, (r) => got = r);
    await pressBack(t);
    await t.tap(find.text('Leave and cancel payment'));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(got, isA<PaySuccess>());
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('opening screen: steps tick off as Paystack loads and the option opens', (t) async {
    Widget at({bool loaded = false, bool ready = false}) => MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: PayOpeningCover(via: 'OPay', what: 'Premium · 3 Months', loaded: loaded, ready: ready),
      ),
    );
    await t.pumpWidget(at());
    await t.pump(const Duration(milliseconds: 900));
    expect(find.text('Opening OPay'), findsWidgets);
    expect(find.text('Secure connection'), findsOneWidget);
    expect(find.text('Ready to pay'), findsOneWidget);
    await t.pumpWidget(at(loaded: true, ready: true));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('All set'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });
}
