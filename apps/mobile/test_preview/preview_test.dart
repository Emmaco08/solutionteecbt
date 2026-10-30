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
import 'package:solutiontee_cbt/data/study_repo.dart';
import 'package:solutiontee_cbt/features/premium/paywall.dart';
import 'package:solutiontee_cbt/features/setup/setup_screen.dart';
import 'package:solutiontee_cbt/features/study/doc_screens.dart';
import 'package:solutiontee_cbt/features/study/note_screens.dart';
import 'package:solutiontee_cbt/features/study/novel_screens.dart';
import 'package:solutiontee_cbt/features/study/pq_screens.dart';
import 'package:solutiontee_cbt/features/study/study_hub.dart';
import 'package:solutiontee_cbt/features/study/video_screens.dart';
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
  // KaTeX fonts from flutter_math_fork, so formulas render instead of boxes.
  const k = 'packages/flutter_math_fork/lib/katex_fonts/fonts';
  await load('packages/flutter_math_fork/KaTeX_Main', ['$k/KaTeX_Main-Regular.ttf', '$k/KaTeX_Main-Italic.ttf', '$k/KaTeX_Main-Bold.ttf']);
  await load('packages/flutter_math_fork/KaTeX_Math', ['$k/KaTeX_Math-Italic.ttf']);
  await load('packages/flutter_math_fork/KaTeX_AMS', ['$k/KaTeX_AMS-Regular.ttf']);
  for (final n in [1, 2, 3, 4]) {
    await load('packages/flutter_math_fork/KaTeX_Size$n', ['$k/KaTeX_Size$n-Regular.ttf']);
  }
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

// ---- Study (same shapes as public.study_catalog / public.study_item)
Map<String, dynamic> cat(
  String id,
  String kind,
  String title,
  int subject, {
  bool locked = true,
  Map<String, dynamic> meta = const {},
  String? subtitle,
  String? topic,
}) => {
  'id': id,
  'kind': kind,
  'title': title,
  'subtitle': subtitle,
  'subject_id': subject,
  'topic': topic,
  'meta': meta,
  'locked': locked,
  'is_free': !locked,
  'question_id': null,
};
final catalog = <String, List<Map<String, dynamic>>>{
  'video_solution': [
    cat('v1', 'video_solution', 'JAMB 2002 Chemistry Q14', 4, topic: 'Mole concept', meta: {'duration_s': 278}),
    cat('v2', 'video_solution', 'JAMB 2001 Physics Q3', 3, topic: 'Motion', meta: {'duration_s': 372}),
    cat('v3', 'video_solution', 'JAMB 2015 Maths Q22', 2, topic: 'Probability', meta: {'duration_s': 425}),
  ],
  'lesson': [
    cat('l1', 'lesson', 'Quadratic equations', 2, subtitle: 'Factorisation and the formula', meta: {'duration_s': 745}),
  ],
  'note': [
    cat('n1', 'note', 'Indices and logarithms', 2, locked: false, subtitle: 'Laws and worked examples', meta: {'minutes': 4}),
    cat('n2', 'note', 'Quadratic equations', 2, subtitle: 'The formula and the discriminant', meta: {'minutes': 8}),
    cat('n3', 'note', 'Motion', 3, subtitle: 'Equations of motion', meta: {'minutes': 5}),
  ],
  'novel': [
    cat('b1', 'novel', '[SAMPLE] The Lion and the Jewel', 8, meta: {'author': 'Wole Soyinka', 'chapters': 3}),
    cat('b2', 'novel', 'Prose text', 8, meta: {'author': 'WAEC prose'}),
    cat('b3', 'novel', 'Drama text', 8, meta: {'author': 'WAEC drama'}),
    cat('b4', 'novel', 'Poetry', 8, meta: {'author': 'Selected poems'}),
  ],
  'doc': [
    cat('d1', 'doc', 'JAMB brochure 2027', 1, locked: false, subtitle: 'Course requirements', meta: {'pages': 120}),
    cat('d2', 'doc', 'JAMB syllabus: Mathematics', 2, locked: false, meta: {'pages': 24}),
    cat('d3', 'doc', 'JAMB syllabus: Physics', 3, meta: {'pages': 22}),
    cat('d4', 'doc', 'WAEC syllabus: Mathematics', 2, meta: {'pages': 18}),
  ],
};
const noteBody =
    '# The quadratic formula\n\nA quadratic equation has the form \$ax^2 + bx + c = 0\$, where \$a \\neq 0\$. Use this when it does not factorise easily:\n\n'
    '\$\$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\$\$\n\n'
    '> **Exam tip.** Check the discriminant \$b^2 - 4ac\$ first. If it is negative, there are no real roots.\n\n'
    '## Sum and product of roots\n\n- \$\\alpha + \\beta = -\\frac{b}{a}\$\n- \$\\alpha\\beta = \\frac{c}{a}\$';
final items = <String, Map<String, dynamic>>{
  'n2': {'id': 'n2', 'kind': 'note', 'title': 'Quadratic equations', 'subject_id': 2, 'body': noteBody, 'files': {}, 'data': {}, 'is_free': false},
  'b1': {
    'id': 'b1',
    'kind': 'novel',
    'title': '[SAMPLE] The Lion and the Jewel',
    'subject_id': 8,
    'body': 'Sidi, the village belle of Ilujinle, is courted by Lakunle the schoolteacher and by Baroka the old Bale.',
    'files': {},
    'is_free': false,
    'data': {
      'author': 'Wole Soyinka',
      'chapters': [
        {'title': 'Morning', 'summary': 'Lakunle tries to win Sidi.'},
        {'title': 'Noon', 'summary': 'Sidi sees her pictures in a magazine.'},
        {'title': 'Night', 'summary': 'Baroka outwits Sidi.'},
      ],
      'themes': [
        {'title': 'Tradition and modernity', 'text': 'Baroka stands for the old ways and Lakunle for foreign ideas.'},
      ],
      'characters': [
        {'name': 'Sidi', 'text': 'The village belle.'},
      ],
    },
  },
  'v1': {
    'id': 'v1',
    'kind': 'video_solution',
    'title': 'JAMB 2002 Chemistry Q14',
    'subtitle': 'Mrs. Okonkwo',
    'subject_id': 4,
    'files': {},
    'data': {'duration_s': 278},
    'is_free': false,
  },
};
const rulesSeed = {
  'free': {
    'ai': 3,
    'pq': 2,
    'jamb': 3,
    'neco': 3,
    'waec': 3,
    'notes': false,
    'novels': false,
    'videos': false,
    'lessons': false,
    'offline': false,
    'syllabus': 2,
  },
  'premium': {
    'ai': 100,
    'pq': 'all',
    'jamb': 'all',
    'neco': 'all',
    'waec': 'all',
    'notes': true,
    'novels': true,
    'videos': true,
    'lessons': true,
    'offline': true,
    'syllabus': 'all',
  },
};
const plansSeed = [
  {'id': 1, 'code': 'monthly', 'name': 'Monthly', 'description': 'SAMPLE price. Billed once. No auto-renew.', 'price_kobo': 150000, 'duration_days': 30},
  {'id': 2, 'code': 'three_months', 'name': '3 Months', 'description': 'SAMPLE price. Save ₦1,000.', 'price_kobo': 350000, 'duration_days': 90},
  {
    'id': 3,
    'code': 'exam_season',
    'name': 'Exam Season',
    'description': 'SAMPLE price. Covers JAMB, WAEC and NECO 2027.',
    'price_kobo': 600000,
    'ends_on': '2027-07-31',
  },
];

/// Opens the paywall over the past-questions screen (as in the prototype's `paywall` screen).
class _PaywallDemo extends StatefulWidget {
  const _PaywallDemo();
  @override
  State<_PaywallDemo> createState() => _PaywallDemoState();
}

class _PaywallDemoState extends State<_PaywallDemo> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => showPaywall(context, reason: 'JAMB 2004'));
  }

  @override
  Widget build(BuildContext context) => const PqBrowseScreen();
}

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
    studyCatalogProvider.overrideWith((ref, kind) async => catalog[kind] ?? const []),
    studyItemProvider.overrideWith((ref, id) async => items[id]!),
    accessRulesProvider.overrideWith((_) async => rulesSeed.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)))),
    plansProvider.overrideWith((_) async => [for (final p in plansSeed) Map<String, dynamic>.from(p)]),
    bookmarksProvider.overrideWith(
      (_) async => [
        {'kind': 'question', 'ref': '1/2/2001/q2_1', 'label': 'JAMB 2001 Mathematics Q7'},
        {'kind': 'item', 'ref': 'note:n2', 'label': 'Quadratic equations'},
      ],
    ),
    studyProgressProvider.overrideWith(
      (_) async => [
        {
          'item_id': 'n2',
          'progress': .64,
          'position': {'kind': 'note', 'title': 'Quadratic equations', 'subject_id': 2},
        },
        {
          'item_id': 'v1',
          'progress': .32,
          'position': {'kind': 'video_solution', 'title': 'JAMB 2002 Chemistry Q14', 'subject_id': 4},
        },
      ],
    ),
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
    'study': () => const StudyScreen(),
    'pq': () => const PqBrowseScreen(),
    'pq_study': () => const PqStudyScreen(examId: 1, subjectId: 2, year: 2001),
    'paywall': () => const _PaywallDemo(),
    'videos': () => const VideoListScreen(kind: 'video_solution'),
    'video': () => const VideoPlayerScreen(id: 'v1'),
    'notes': () => const NotesListScreen(),
    'note': () => const NoteScreen(id: 'n2'),
    'novels': () => const NovelsScreen(),
    'novel': () => const NovelScreen(id: 'b1'),
    'docs': () => const DocsScreen(),
    'bookmarks': () => const BookmarksScreen(),
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
