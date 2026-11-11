import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/study_repo.dart';
import 'package:solutiontee_cbt/features/search/search_screen.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

void main() {
  test('every word must match, in any order', () {
    expect(searchMatch('physics 2015', 'JAMB Physics 2015 past questions'), isTrue);
    expect(searchMatch('2015 physics', 'JAMB Physics 2015'), isTrue);
    expect(searchMatch('physics 2016', 'JAMB Physics 2015'), isFalse);
  });

  testWidgets('search finds pages, a past paper by year, a topic and a note', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          subjectsProvider.overrideWith((_) async => [
            {'id': 3, 'name': 'Physics'},
            {'id': 2, 'name': 'Mathematics'},
          ]),
          examsProvider.overrideWith((_) async => [
            {'id': 1, 'code': 'JAMB', 'name': 'JAMB UTME'},
          ]),
          openYearsProvider.overrideWith((_) async => [
            {'exam_id': 1, 'subject_id': 3, 'year': 2015, 'pq_open': true},
            {'exam_id': 1, 'subject_id': 3, 'year': 2016, 'pq_open': false},
          ]),
          topicsProvider.overrideWith((_) async => [
            {'id': 9, 'subject_id': 2, 'name': 'Logarithms'},
          ]),
          studyCatalogProvider.overrideWith((ref, kind) async => kind == 'note'
              ? [
                  {'id': 'n1', 'kind': 'note', 'title': 'Logarithms made easy', 'subject_id': 2},
                ]
              : const <Map<String, dynamic>>[]),
        ],
        child: MaterialApp(theme: buildTheme(Brightness.light), home: const AppSearchScreen()),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'physics 2015');
    await t.pumpAndSettle();
    expect(find.text('Physics 2015'), findsOneWidget);
    expect(find.text('Physics 2016'), findsNothing);

    await t.enterText(find.byType(TextField), 'logarithms');
    await t.pumpAndSettle();
    expect(find.text('Logarithms'), findsOneWidget); // topic drill
    expect(find.text('Logarithms made easy'), findsOneWidget); // note

    await t.enterText(find.byType(TextField), 'streak');
    await t.pumpAndSettle();
    expect(find.text('My streak'), findsOneWidget);
  });
}
