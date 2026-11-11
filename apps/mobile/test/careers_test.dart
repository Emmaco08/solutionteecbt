import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/careers/careers.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

final _careers = [
  {
    'id': 1,
    'name': 'Medical Doctor',
    'field': 'Health',
    'course': 'Medicine and Surgery (MBBS)',
    'years': 6,
    'summary': 'Doctors find out what is wrong with sick people and treat them.',
    'skills': ['Biology and chemistry'],
    'universities': ['University of Ibadan'],
    'earnings': 'Rough guide only.',
    'jamb_subjects': ['bio', 'chm', 'phy'],
    'jamb_note': null,
    'olevel': 'Five credits in sciences.',
    'after_school': 'Housemanship, then NYSC.',
  },
  {
    'id': 2,
    'name': 'Lawyer',
    'field': 'Law and Social Sciences',
    'course': 'Law (LLB)',
    'years': 5,
    'summary': 'Lawyers advise people and companies about the law.',
    'skills': <String>[],
    'universities': <String>[],
    'earnings': null,
    'jamb_subjects': ['lit', 'gov', 'crs'],
    'jamb_note': 'Literature in English is a must.',
    'olevel': null,
    'after_school': null,
  },
];

final _subjects = [
  {'id': 1, 'code': 'eng', 'name': 'Use of English'},
  {'id': 2, 'code': 'bio', 'name': 'Biology'},
  {'id': 3, 'code': 'chm', 'name': 'Chemistry'},
  {'id': 4, 'code': 'phy', 'name': 'Physics'},
  {'id': 5, 'code': 'lit', 'name': 'Literature in English'},
  {'id': 6, 'code': 'gov', 'name': 'Government'},
  {'id': 7, 'code': 'crs', 'name': 'Christian Religious Studies'},
];

Widget _app(Widget home, {Map<String, dynamic>? profile}) => ProviderScope(
  overrides: [
    careersProvider.overrideWith((_) async => _careers),
    subjectsProvider.overrideWith((_) async => _subjects),
    profileProvider.overrideWith((_) async => profile),
  ],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
);

void main() {
  test('combination always starts with English, then the three subjects', () {
    final names = {for (final s in _subjects) s['code'] as String: s['name'] as String};
    expect(combination(_careers.first, (c) => names[c] ?? c), 'Use of English, Biology, Chemistry, Physics');
    expect(careerSubjects(_careers[1]), ['lit', 'gov', 'crs']);
  });

  test('career search matches the name, the course or the group', () {
    expect(careerMatch('doctor', _careers.first), isTrue);
    expect(careerMatch('mbbs', _careers.first), isTrue);
    expect(careerMatch('health', _careers.first), isTrue);
    expect(careerMatch('doctor law', _careers.first), isFalse);
    expect(careerMatch('', _careers[1]), isTrue);
  });

  testWidgets('careers list shows each combination and filters by search', (t) async {
    await t.pumpWidget(_app(const CareersScreen()));
    await t.pumpAndSettle();
    expect(find.text('Medical Doctor'), findsOneWidget);
    expect(find.text('Use of English, Biology, Chemistry, Physics'), findsOneWidget);
    expect(find.text('Lawyer'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'law');
    await t.pumpAndSettle();
    expect(find.text('Medical Doctor'), findsNothing);
    expect(find.text('Lawyer'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'astronaut');
    await t.pumpAndSettle();
    expect(find.text('No career matches'), findsOneWidget);
  });

  testWidgets('a career shows the job, the JAMB subjects, the path and the pick button', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _app(
        const CareerScreen(id: 1),
        profile: {
          'id': 'u',
          'jamb_subjects': ['eng', 'mth', 'phy', 'chm'],
        },
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Medical Doctor'), findsOneWidget);
    expect(find.text('Biology'), findsOneWidget);
    expect(find.text('Secondary school'), findsOneWidget);
    expect(find.text('University'), findsOneWidget);
    expect(find.text('This is my dream career'), findsOneWidget);
  });

  testWidgets('my own career offers to use its subjects when they differ', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _app(
        const CareerScreen(id: 1),
        profile: {
          'id': 'u',
          'career_id': 1,
          'jamb_subjects': ['eng', 'mth', 'phy', 'chm'],
        },
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('My career'), findsOneWidget);
    expect(find.text('Use these as my JAMB subjects'), findsOneWidget);
  });

  testWidgets('a removed career shows a friendly message', (t) async {
    await t.pumpWidget(_app(const CareerScreen(id: 99)));
    await t.pumpAndSettle();
    expect(find.text('This career is not available'), findsOneWidget);
  });
}
