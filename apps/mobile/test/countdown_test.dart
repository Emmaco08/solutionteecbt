import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/home/countdown.dart';
import 'package:solutiontee_cbt/features/home/home_screen.dart';
import 'package:solutiontee_cbt/features/home/top_card.dart';
import 'package:solutiontee_cbt/features/xp/streak_ui.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

String _in(int days) {
  final d = DateTime.now().add(Duration(days: days));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Future<ExamCountdown?> _pick(Map<String, dynamic> settings, List<String> exams) async {
  final c = ProviderContainer(
    overrides: [
      appSettingsProvider.overrideWith((_) async => {'exam_countdown': settings}),
      profileProvider.overrideWith((_) async => {'target_exams': exams}),
    ],
  );
  addTearDown(c.dispose);
  await c.read(appSettingsProvider.future);
  await c.read(profileProvider.future);
  return c.read(examCountdownProvider);
}

void main() {
  test('counts down to the student\'s own exam, the nearest one first', () async {
    final s = {
      'on': true,
      'dates': {'JAMB': _in(120), 'WAEC': _in(40), 'NECO': _in(10)},
    };
    expect((await _pick(s, ['WAEC', 'JAMB']))?.code, 'WAEC');
    expect((await _pick(s, ['JAMB']))?.daysLeft, 120);
    // No exam chosen: the nearest date of any exam.
    expect((await _pick(s, []))?.code, 'NECO');
  });

  test('no countdown when the admin turned it off, set no date, or the date has passed', () async {
    expect(
      await _pick(
        {
          'on': false,
          'dates': {'JAMB': _in(30)},
        },
        ['JAMB'],
      ),
      isNull,
    );
    expect(await _pick({'on': true, 'dates': {}}, ['JAMB']), isNull);
    expect(
      await _pick(
        {
          'on': true,
          'dates': {'JAMB': _in(-1)},
        },
        ['JAMB'],
      ),
      isNull,
    );
    // A passed date for the student's exam falls back to another exam's future date.
    expect(
      (await _pick(
        {
          'on': true,
          'dates': {'JAMB': _in(-1), 'WAEC': _in(5)},
        },
        ['JAMB'],
      ))?.code,
      'WAEC',
    );
  });

  testWidgets('the Home chip and the full-screen countdown show the days left', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith(
            (_) async => {
              'exam_countdown': {
                'on': true,
                'dates': {'JAMB': _in(143)},
              },
            },
          ),
          profileProvider.overrideWith(
            (_) async => {
              'target_exams': ['JAMB'],
            },
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(body: CountdownChip()),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('143 days'), findsOneWidget);
    expect(find.textContaining('UTME'), findsOneWidget);
  });

  testWidgets('full-screen countdown fits a small phone', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith(
            (_) async => {
              'exam_countdown': {
                'on': true,
                'dates': {'JAMB': _in(143)},
              },
            },
          ),
          profileProvider.overrideWith(
            (_) async => {
              'target_exams': ['JAMB'],
            },
          ),
          practiceStatsProvider.overrideWith((_) async => const PracticeStats(today: 8, streak: 3, week: {})),
          myStreakProvider.overrideWith((_) async => {'current': 5}),
          motivationProvider.overrideWith((_) async => {'body': 'Small steps every day beat one big push the night before the exam.'}),
        ],
        child: MaterialApp(theme: buildTheme(Brightness.dark), home: const ExamCountdownScreen()),
      ),
    );
    for (var k = 0; k < 30; k++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('143'), findsOneWidget);
    expect(find.text('Start today’s practice'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
