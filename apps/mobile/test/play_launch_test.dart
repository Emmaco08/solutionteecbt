import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/ads.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/compete/compete_data.dart';
import 'package:solutiontee_cbt/features/setup/age_gate.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:solutiontee_cbt/widgets/exam_logo.dart';

/// Play launch part A (D-109 to D-111): age rules, cash prizes switch, exam logos switch, no ads in sign-up.
void main() {
  test('age from the year of birth: under 13 blocked, 13 to 17 need the parent step, 18+ normal', () {
    final now = DateTime.now().year;
    expect(ageFromYear(now - 12) < minAge, isTrue);
    expect(ageFromYear(now - 13), minAge);
    expect(ageFromYear(now - 17) < adultAge, isTrue);
    expect(ageFromYear(now - 18), adultAge);
  });

  test('cash prizes off (default): a cash challenge shows no naira prize and counts as an event', () {
    final c = Challenge({
      'kind': 'cash',
      'prizes': [10000, 5000],
      'reward': 'Premium for 7 days',
    });
    expect(cashPrizesOn, isFalse);
    expect(c.prizes, isEmpty);
    expect(c.kind, 'event');
    expect(c.rewardText, 'Premium for 7 days');
    cashPrizesOn = true;
    addTearDown(() => cashPrizesOn = false);
    expect(c.prizes, [10000, 5000]);
    expect(c.kind, 'cash');
  });

  testWidgets('exam logos off (default): our own badge with the exam name, never the official logo image', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(
          body: Row(
            children: [
              ExamLogo('JAMB'),
              ExamLogo('WAEC', size: LogoSize.sm),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(ExamBadge), findsNWidgets(2));
    expect(find.text('JAMB'), findsOneWidget);
    expect(find.text('WAEC'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  test('no ads on the sign-up and setup screens', () {
    for (final p in ['/welcome', '/signup', '/verify', '/setup', '/guardian', '/age-blocked']) {
      expect(StickyPlace.noAdPaths.contains(p), isTrue, reason: p);
    }
    expect(StickyPlace.noAdPaths.contains('/home'), isFalse);
  });
}
