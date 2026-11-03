import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/nav.dart';
import 'package:solutiontee_cbt/features/invite/invite_screens.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

Map<String, dynamic> data({int unspent = 2, int counted = 7, bool canEnter = false, List<Map<String, dynamic>> rewards = const []}) => {
  'enabled': true,
  'code': 'TOLU-7K3P',
  'pct_per_friend': 10,
  'max_pct': 100,
  'count_on': 'test',
  'cash_every': 30,
  'cash_naira': 5000,
  'monthly_cap': 20,
  'counted': counted,
  'unspent': unspent,
  'discount_pct': unspent * 10,
  'friends': [
    {'name': 'Ada', 'status': 'counted', 'reason': null, 'used': false},
    {'name': 'Bayo', 'status': 'pending', 'reason': 'Counts when your friend finishes one practice test', 'used': false},
    {'name': 'Chi', 'status': 'blocked', 'reason': 'Same phone as yours. Friends must use their own phone.', 'used': false},
  ],
  'rewards': rewards,
  'my_referrer': null,
  'can_enter_code': canEnter,
};

Widget wrap(Widget child, {Map<String, dynamic>? d, Map<String, dynamic>? status}) => ProviderScope(
  overrides: [myReferralsProvider.overrideWith((ref) async => d ?? data()), if (status != null) accountStatusProvider.overrideWith(() => _Fixed(status))],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
);

class _Fixed extends AccountStatus {
  _Fixed(this.s);
  final Map<String, dynamic> s;
  @override
  Map<String, dynamic>? build() => s;
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  test('the share message carries the code and the download link', () {
    final m = inviteText('TOLU-7K3P');
    expect(m, contains('TOLU-7K3P'));
    expect(m, contains('https://admin.solutiontee.com/download'));
  });

  test('old /invite links open inside the Me tab', () {
    expect(tabRoute('/invite'), '/me/invite');
    expect(tabOf('/me/invite'), '/me');
  });

  testWidgets('invite: code, discount from the server, cash progress and friends with their status', (t) async {
    await t.pumpWidget(wrap(const InviteScreen()));
    await settle(t);
    expect(find.text('TOLU-7K3P'), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);
    expect(find.text('Share on WhatsApp'), findsOneWidget);
    expect(find.text('7 of 30 · 23 more to go'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Chi'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Counted'), findsOneWidget);
    expect(find.text('Waiting'), findsOneWidget);
    expect(find.text('Not counted'), findsOneWidget);
    expect(find.textContaining('Same phone as yours'), findsOneWidget);
  });

  testWidgets('invite: a new student can add a friend\'s code; a wrong code is caught before sending', (t) async {
    await t.pumpWidget(wrap(const InviteScreen(), d: data(canEnter: true)));
    await settle(t);
    await t.scrollUntilVisible(find.text('Add code'), 300, scrollable: find.byType(Scrollable).first);
    await t.enterText(find.widgetWithText(TextField, 'TOLU-7K3P').last, 'hello');
    await Scrollable.ensureVisible(t.element(find.text('Add code')), alignment: .5);
    await t.pump();
    await t.tap(find.text('Add code'));
    await settle(t);
    expect(find.textContaining('does not look right'), findsOneWidget);
  });

  testWidgets('invite: a cash reward asks for bank details, never a PIN', (t) async {
    await t.pumpWidget(
      wrap(
        const InviteScreen(),
        d: data(
          counted: 30,
          rewards: [
            {'id': 'w1', 'milestone': 30, 'amount': 5000, 'status': 'due'},
          ],
        ),
      ),
    );
    await settle(t);
    await t.scrollUntilVisible(find.text('Send my account details'), 300, scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(t.element(find.text('Send my account details')), alignment: .5);
    await t.pump();
    await t.tap(find.text('Send my account details'));
    await settle(t);
    expect(find.text('10-digit account number'), findsOneWidget);
    expect(find.text('We never ask for your PIN, card or password.'), findsOneWidget);
  });

  testWidgets('banned: the reason and one appeal', (t) async {
    await t.pumpWidget(wrap(const BannedScreen(), status: {'banned': true, 'ban_reason': 'Many fake accounts.', 'can_appeal': true, 'appeal': null}));
    await settle(t);
    expect(find.text('Your account is banned'), findsOneWidget);
    expect(find.textContaining('Many fake accounts.'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Send appeal'), 200, scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(t.element(find.text('Send appeal')), alignment: .5);
    await t.pump();
    await t.tap(find.text('Send appeal'));
    await settle(t);
    expect(find.textContaining('sentence or two'), findsOneWidget);
  });

  testWidgets('banned: after the appeal the student sees it is waiting', (t) async {
    await t.pumpWidget(
      wrap(
        const BannedScreen(),
        status: {
          'banned': true,
          'ban_reason': 'Many fake accounts.',
          'can_appeal': false,
          'appeal': {'status': 'pending'},
        },
      ),
    );
    await settle(t);
    expect(find.text('We have your appeal and will reply soon.'), findsOneWidget);
    expect(find.text('Send appeal'), findsNothing);
  });

  testWidgets('phone taken: explains one account per phone and how to get help', (t) async {
    await t.pumpWidget(wrap(const PhoneTakenScreen()));
    await settle(t);
    expect(find.text('This phone already has an account'), findsOneWidget);
    expect(find.text('Log in with another account'), findsOneWidget);
    expect(find.textContaining('brother or sister'), findsOneWidget);
  });
}
