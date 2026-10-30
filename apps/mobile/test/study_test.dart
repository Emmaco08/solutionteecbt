import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/data/study_repo.dart';
import 'package:solutiontee_cbt/features/premium/paywall.dart';
import 'package:solutiontee_cbt/features/study/note_screens.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

// The Free and Premium rules as seeded on the server (admin: Free vs Premium).
const rules = {
  'free': {'ai': 3, 'pq': 2, 'jamb': 3, 'neco': 3, 'waec': 3, 'notes': false, 'novels': false, 'videos': false, 'lessons': false, 'offline': false, 'syllabus': 2},
  'premium': {'ai': 100, 'pq': 'all', 'jamb': 'all', 'neco': 'all', 'waec': 'all', 'notes': true, 'novels': true, 'videos': true, 'lessons': true, 'offline': true, 'syllabus': 'all'},
};

const plans = [
  {'id': 1, 'code': 'monthly', 'name': 'Monthly', 'description': 'SAMPLE price. Billed once. No auto-renew.', 'price_kobo': 150000, 'duration_days': 30, 'ends_on': null},
  {'id': 2, 'code': 'three_months', 'name': '3 Months', 'description': 'SAMPLE price. Save ₦1,000.', 'price_kobo': 350000, 'duration_days': 90, 'ends_on': null},
  {'id': 3, 'code': 'exam_season', 'name': 'Exam Season', 'description': 'SAMPLE price.', 'price_kobo': 600000, 'duration_days': null, 'ends_on': '2027-07-31'},
];

Widget host(Widget child, {List overrides = const []}) => ProviderScope(
  overrides: [...overrides],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: child)),
);

void main() {
  test('paywall benefits are written from the Free vs Premium rules', () {
    final b = premiumBenefits(rules);
    expect(b, contains('JAMB CBT: every year (Free: 3 years)'));
    expect(b, contains('Past questions with answers: every year (Free: 2 years)'));
    expect(b, contains('Video solutions, Topic video lessons, Lesson notes, Novel summaries'));
    expect(b, contains('100 AI tutor prompts a day (Free: 3)'));
    expect(b.length, lessThanOrEqualTo(7));
    // A feature the admin also gives Free is not sold as a Premium benefit.
    final free = {...rules, 'free': {...rules['free']!, 'videos': true}};
    expect(premiumBenefits(free).join(), isNot(contains('Video solutions')));
  });

  test('naira formats kobo with thousands separators', () {
    expect(naira(150000), '₦1,500');
    expect(naira(600000), '₦6,000');
    expect(naira(12500000), '₦125,000');
  });

  testWidgets('paywall sheet shows the reason, the plans with SAMPLE prices, and picks 3 Months', (t) async {
    await t.pumpWidget(
      host(
        Builder(builder: (c) => TextButton(onPressed: () => showPaywall(c, reason: 'video_solution'), child: const Text('open'))),
        overrides: [
          accessRulesProvider.overrideWith((_) async => rules.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)))),
          plansProvider.overrideWith((_) async => [for (final p in plans) Map<String, dynamic>.from(p)]),
        ],
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('This video is Premium'), findsOneWidget);
    expect(find.text('SAMPLE PRICES'), findsOneWidget);
    expect(find.text('Best value'), findsOneWidget);
    expect(find.text('Until 31 Jul 2027'), findsOneWidget);
    expect(find.text('Continue with 3 Months · ₦3,500'), findsOneWidget);
    await t.tap(find.text('Monthly'));
    await t.pumpAndSettle();
    expect(find.text('Continue with Monthly · ₦1,500'), findsOneWidget);
  });

  testWidgets('note body renders headings, lists, tips and bold text', (t) async {
    const note = '# Laws of indices\n\nFor any base:\n\n- first law\n- second law\n\n## Worked example\n\n> Exam tip: check the **sign**.';
    await t.pumpWidget(host(const SingleChildScrollView(child: NoteBody(text: note))));
    expect(find.text('Laws of indices', findRichText: true), findsOneWidget);
    expect(find.text('Worked example', findRichText: true), findsOneWidget);
    expect(find.text('first law', findRichText: true), findsOneWidget);
    expect(find.text('second law', findRichText: true), findsOneWidget);
    expect(find.text('Exam tip: check the sign.', findRichText: true), findsOneWidget);
  });
}
