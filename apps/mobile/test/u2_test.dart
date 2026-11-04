import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/compete/compete_data.dart';
import 'package:solutiontee_cbt/features/premium/pay_methods.dart';
import 'package:solutiontee_cbt/features/premium/payments.dart';
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
    expect(await FakeProvider(sheet: cancelled).openResult(card), isA<PayCancelled>());
    expect(cancelled.launches, 1);

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
}
