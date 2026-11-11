import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/compete/compete_data.dart';
import 'package:solutiontee_cbt/features/test/leaderboard_screen.dart';
import 'package:solutiontee_cbt/features/test/test_screens.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:solutiontee_cbt/widgets/exam_logo.dart';

// More exams created by the admin (D-138).
final _exams = [
  {'id': 1, 'code': 'JAMB', 'name': 'JAMB UTME', 'sort': 1},
  {'id': 2, 'code': 'WAEC', 'name': 'WAEC WASSCE', 'sort': 2},
  {'id': 3, 'code': 'NECO', 'name': 'NECO SSCE', 'sort': 3},
  {'id': 4, 'code': 'BECE', 'name': 'BECE (Junior WAEC)', 'subtitle': 'Objective papers per subject', 'sort': 4},
];

void main() {
  test('other exams keep the admin order and leave JAMB out', () {
    expect(otherExams(_exams).map((e) => e['code']), ['WAEC', 'NECO', 'BECE']);
  });

  testWidgets('an added exam shows on the Test tab with its badge and lock', (t) async {
    t.view.physicalSize = const Size(1080, 3200);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          examsProvider.overrideWith((_) async => _exams),
          openYearsProvider.overrideWith(
            (_) async => [
              {'exam_id': 2, 'subject_id': 1, 'year': 2020, 'cbt_open': true},
              {'exam_id': 4, 'subject_id': 1, 'year': 2021, 'cbt_open': false},
            ],
          ),
          challengesProvider.overrideWith((_) async => const <String, dynamic>{}),
          leaderboardOnProvider.overrideWith((_) async => false),
        ],
        child: MaterialApp(theme: buildTheme(Brightness.light), home: const TestHubScreen()),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('BECE'), findsWidgets);
    expect(find.byType(ExamBadge), findsWidgets);
    expect(find.text('Premium'), findsOneWidget); // BECE has a year, none open for free
    expect(find.text('No papers yet'), findsOneWidget); // NECO
  });
}
