// Renders key screens to PNG for a side-by-side check with the Phase 1 prototype (not part of the normal test run).
// Run: flutter test test_preview/preview_test.dart --update-goldens   → PNGs in test_preview/out/
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:solutiontee_cbt/data/tests_repo.dart';
import 'package:solutiontee_cbt/features/auth/auth_screens.dart';
import 'package:solutiontee_cbt/features/cbt/cbt_screen.dart';
import 'package:solutiontee_cbt/features/home/home_screen.dart';
import 'package:solutiontee_cbt/features/onboarding/onboarding_screens.dart';
import 'package:solutiontee_cbt/features/profile/profile_screens.dart';
import 'package:solutiontee_cbt/features/results/results_screens.dart';
import 'package:solutiontee_cbt/features/setup/setup_screen.dart';
import 'package:solutiontee_cbt/features/test/test_screens.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

class OfflineRepo extends TestsRepo {
  OfflineRepo(super.ref);
  @override
  Future<int> syncPending() async => 0;
}

Future<void> loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(rootBundle.load(f));
    }
    await l.load();
  }

  await load('PlusJakartaSans', ['assets/fonts/PlusJakartaSans-Medium.ttf', 'assets/fonts/PlusJakartaSans-Bold.ttf']);
  await load('PhosphorRegular', ['assets/fonts/Phosphor-Regular.ttf']);
  await load('PhosphorFill', ['assets/fonts/Phosphor-Fill.ttf']);
}

const exams = [
  {
    'id': 1,
    'code': 'JAMB',
    'name': 'JAMB UTME',
    'exam_configs': {'subjects_per_candidate': 4, 'total_minutes': 120, 'score_scale': 400},
  },
  {'id': 2, 'code': 'WAEC', 'name': 'WAEC WASSCE', 'exam_configs': {}},
  {'id': 3, 'code': 'NECO', 'name': 'NECO SSCE', 'exam_configs': {}},
];
const subjects = [
  {'id': 1, 'code': 'eng', 'name': 'Use of English'},
  {'id': 2, 'code': 'mth', 'name': 'Mathematics'},
  {'id': 3, 'code': 'phy', 'name': 'Physics'},
  {'id': 4, 'code': 'chm', 'name': 'Chemistry'},
  {'id': 5, 'code': 'bio', 'name': 'Biology'},
  {'id': 6, 'code': 'eco', 'name': 'Economics'},
  {'id': 7, 'code': 'gov', 'name': 'Government'},
  {'id': 8, 'code': 'lit', 'name': 'Literature in English'},
];
final links = [
  for (final s in subjects) {'exam_id': 1, 'subject_id': s['id'], 'question_count': s['code'] == 'eng' ? 60 : 40, 'minutes': null},
  for (final e in [2, 3])
    for (final s in subjects) {'exam_id': e, 'subject_id': s['id'], 'question_count': 50, 'minutes': 60},
];
final years = [
  for (final s in [1, 2, 3, 4])
    for (final y in [2001, 2002, 2003, 2004]) {'exam_id': 1, 'subject_id': s, 'year': y, 'cbt_open': y < 2004, 'pq_open': y < 2004},
  for (final y in [2001, 2002]) {'exam_id': 2, 'subject_id': 2, 'year': y, 'cbt_open': true, 'pq_open': true},
];
const profile = {
  'full_name': 'Tolu Adeyemi',
  'state': 'Oyo',
  'target_exams': ['JAMB', 'WAEC'],
  'jamb_subjects': ['eng', 'mth', 'phy', 'chm'],
  'target_score': 290,
};

Future<AppDb> seededDb() async {
  final db = AppDb(NativeDatabase.memory());
  final qs = <String>[];
  for (final sid in [1, 2]) {
    for (var i = 1; i <= 5; i++) {
      final id = 'q${sid}_$i';
      qs.add(id);
      await db
          .into(db.cachedQuestions)
          .insert(
            CachedQuestionsCompanion.insert(
              id: id,
              examId: 1,
              subjectId: sid,
              year: 2001,
              body: sid == 2
                  ? r'Simplify $\frac{2}{3} + \frac{1}{6}$.'
                  : 'Choose the word nearest in meaning to the word in capitals: The teacher was ADAMANT.',
              optionsJson: jsonEncode(
                sid == 2
                    ? {'A': r'$\frac{1}{2}$', 'B': r'$\frac{5}{6}$', 'C': r'$\frac{3}{9}$', 'D': r'$1$'}
                    : {'A': 'firm', 'B': 'angry', 'C': 'tired', 'D': 'happy'},
              ),
              answer: sid == 2 ? 'B' : 'A',
              explanation: Value(sid == 2 ? r'$\frac{2}{3} = \frac{4}{6}$, so the sum is $\frac{5}{6}$.' : 'Adamant means firm.'),
              topic: Value(sid == 2 ? 'Fractions' : 'Vocabulary'),
              passageId: Value(sid == 1 && i <= 2 ? 'p1' : null),
              passageTitle: Value(sid == 1 && i <= 2 ? 'Morning bus' : null),
              passageBody: Value(
                sid == 1 && i <= 2
                    ? 'Ade woke up before dawn. He packed his books, ate a quick breakfast and left the house early to catch the first bus to school.'
                    : null,
              ),
            ),
          );
    }
  }
  final cfg = jsonEncode({'title': 'JAMB UTME Mock'});
  await db
      .into(db.localAttempts)
      .insert(
        LocalAttemptsCompanion.insert(
          id: 'run',
          examId: 1,
          examCode: 'JAMB',
          mode: 'full',
          configJson: cfg,
          questionIdsJson: jsonEncode(qs),
          limitSeconds: 7200,
          startedAt: DateTime.now(),
          usedMs: const Value(1000 * 60 * 23),
        ),
      );
  await db.saveAnswer('run', 'q1_1', choice: 'A');
  await db.saveAnswer('run', 'q1_2', choice: 'B', flagged: true);
  // a finished one for results
  final score = {
    'questions': 10,
    'answered': 9,
    'correct': 7,
    'total': 140,
    'max': 200,
    'subjects': [
      {'subject_id': 1, 'total': 5, 'correct': 3, 'answered': 4, 'score': 60},
      {'subject_id': 2, 'total': 5, 'correct': 4, 'answered': 5, 'score': 80},
    ],
  };
  await db
      .into(db.localAttempts)
      .insert(
        LocalAttemptsCompanion.insert(
          id: 'done',
          examId: 1,
          examCode: 'JAMB',
          mode: 'full',
          configJson: cfg,
          questionIdsJson: jsonEncode(qs),
          limitSeconds: 7200,
          startedAt: DateTime.now().subtract(const Duration(hours: 1)),
          submittedAt: Value(DateTime.now()),
          usedMs: const Value(1000 * 60 * 54),
          clientScoreJson: Value(jsonEncode(score)),
        ),
      );
  for (var i = 1; i <= 5; i++) {
    await db.saveAnswer('done', 'q1_$i', choice: i <= 3 ? 'A' : (i == 4 ? 'B' : null), flagged: i == 4, addMs: 40000);
    await db.saveAnswer('done', 'q2_$i', choice: i == 5 ? 'C' : 'B', addMs: 50000);
  }
  return db;
}

void main() {
  late AppDb db;
  setUpAll(() async {
    await loadFonts();
  });
  setUp(() async => db = await seededDb());
  tearDown(() => db.close());

  List overrides() => [
    dbProvider.overrideWithValue(db),
    examsProvider.overrideWith((_) async => exams),
    subjectsProvider.overrideWith((_) async => subjects),
    examSubjectsProvider.overrideWith((_) async => links),
    openYearsProvider.overrideWith((_) async => years),
    profileProvider.overrideWith((_) async => profile),
    myPlanProvider.overrideWith((_) async => {'tier': 'free'}),
    newsProvider.overrideWith((_) async => <Map<String, dynamic>>[]),
    appSettingsProvider.overrideWith((_) async => <String, dynamic>{}),
    onboardingProvider.overrideWith((_) async => <Map<String, dynamic>>[]),
    topicsProvider.overrideWith((_) async => <Map<String, dynamic>>[]),
    testsRepoProvider.overrideWith((ref) => OfflineRepo(ref)),
  ];

  final screens = <String, Widget Function()>{
    'welcome': () => const WelcomeScreen(),
    'onboarding': () => const OnboardingScreen(),
    'signup': () => const SignUpScreen(),
    'login': () => const LoginScreen(),
    'otp': () => VerifyCodeScreen(
      args: const VerifyArgs(email: 'tolu.adeyemi@gmail.com', type: OtpType.signup, codeLength: 6),
    ),
    'setup': () => const SetupScreen(),
    'welcome_new': () => const WelcomeNewScreen(),
    'welcome_back': () => const WelcomeBackScreen(),
    'home': () => const HomeScreen(),
    'test_hub': () => const TestHubScreen(),
    'test_setup': () => const TestSetupScreen(examCode: 'JAMB'),
    'cbt': () => const CbtScreen(attemptId: 'run'),
    'results': () => const ResultsScreen(attemptId: 'done'),
    'review': () => const ReviewScreen(attemptId: 'done'),
    'me': () => const ProfileScreen(),
    'settings': () => const SettingsScreen(),
    'help': () => const HelpScreen(),
  };

  for (final dark in [false, true]) {
    for (final e in screens.entries) {
      testWidgets('${e.key} ${dark ? 'dark' : 'light'}', (t) async {
        t.view.physicalSize = const Size(780, 1688);
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        final router = GoRouter(
          routes: [GoRoute(path: '/', builder: (_, _) => e.value())],
        );
        await t.runAsync(() async {
          await t.pumpWidget(
            ProviderScope(
              overrides: [...overrides()],
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: buildTheme(Brightness.light),
                darkTheme: buildTheme(Brightness.dark),
                themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                routerConfig: router,
              ),
            ),
          );
          for (var i = 0; i < 12; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 60));
            await t.pump(const Duration(milliseconds: 200));
          }
          for (final el in find.byType(Image).evaluate()) {
            await precacheImage((el.widget as Image).image, el);
          }
          await t.pump(const Duration(milliseconds: 200));
        });
        for (var i = 0; i < 12; i++) {
          await t.pump(const Duration(milliseconds: 300));
        }
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/${e.key}_${dark ? 'dark' : 'light'}.png'));
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 5));
      });
    }
  }
}
