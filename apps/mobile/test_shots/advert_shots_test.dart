// ignore_for_file: invalid_use_of_visible_for_testing_member
// Phone screenshots for the two major adverts (D-183): real screens with the real bottom bar at 390 × 844 (×3 =
// 1170 × 2532). Supabase points at a closed local port, so nothing reaches the live server; data is made up.
// Not part of `flutter test`. Run: flutter test test_shots/advert_shots_test.dart --update-goldens
// One screen: SHOTS=ai flutter test test_shots/advert_shots_test.dart --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solutiontee_cbt/core/house_ads.dart' show rootNavKey;
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/ai_repo.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:solutiontee_cbt/data/tests_repo.dart';
import 'package:solutiontee_cbt/features/ai/ai_screen.dart';
import 'package:solutiontee_cbt/features/cbt/cbt_screen.dart';
import 'package:solutiontee_cbt/features/home/home_screen.dart';
import 'package:solutiontee_cbt/features/profile/profile_screens.dart';
import 'package:solutiontee_cbt/features/results/results_screens.dart';
import 'package:solutiontee_cbt/features/shell/shell.dart';
import 'package:solutiontee_cbt/features/study/study_hub.dart';
import 'package:solutiontee_cbt/features/test/test_screens.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'desktop_fixtures.dart' show OfflineRepo, fixtureOverrides;

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    final file = File(f);
    if (file.existsSync()) l.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await l.load();
}

/// The Material icon font from this computer's Flutter SDK (Windows laptop or the Linux cloud machine).
String get _materialIcons {
  final root = File(Platform.resolvedExecutable).parent.parent.parent.parent.path; // …/flutter/bin/cache/dart-sdk/bin/dart
  for (final p in [
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]) {
    if (File(p).existsSync()) return p;
  }
  return '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
}

/// The KaTeX fonts that flutter_math_fork bundles (the app's maths), found through the package config.
Future<void> _katex() async {
  final cfg = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync()) as Map<String, dynamic>;
  final pkg = (cfg['packages'] as List).cast<Map<String, dynamic>>().firstWhere((p) => p['name'] == 'flutter_math_fork');
  final root = Uri.parse(pkg['rootUri'] as String).toFilePath();
  final dir = Directory('$root/lib/katex_fonts/fonts');
  final byFamily = <String, List<String>>{};
  for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
    final name = f.uri.pathSegments.last; // KaTeX_Main-Regular.ttf
    byFamily.putIfAbsent(name.split('-').first, () => []).add(f.path);
  }
  for (final e in byFamily.entries) {
    await _font('packages/flutter_math_fork/${e.key}', e.value);
  }
}

/// A chat the AI tutor already answered, as the server would return it (the screen and its Markdown/maths are real).
class _ChatRepo extends AiRepo {
  _ChatRepo(super.ref);
  @override
  Future<List<Map<String, dynamic>>> messages(String chatId) async => [
    {'id': 'm1', 'role': 'user', 'content': 'Solve x² − 5x + 6 = 0 step by step', 'has_image': false},
    {
      'id': 'm2',
      'role': 'assistant',
      'content':
          "Let's solve it together.\n\n"
          '**Step 1.** Find two numbers that multiply to \$6\$ and add up to \$-5\$. They are \$-2\$ and \$-3\$.\n\n'
          '**Step 2.** Factorise: \$(x - 2)(x - 3) = 0\$\n\n'
          '**Step 3.** Set each bracket to zero: \$x - 2 = 0\$ or \$x - 3 = 0\$\n\n'
          '**Answer:** \$x = 2\$ or \$x = 3\$',
      'card': {
        'followups': ['Give me a similar question', 'Explain step 1 more simply', 'Quiz me on this'],
      },
    },
  ];
}

late AppDb db;

Future<void> shot(WidgetTester t, String path, String name, {bool dark = false}) async {
  t.view.physicalSize = const Size(390 * 3, 844 * 3);
  t.view.devicePixelRatio = 3;
  final router = GoRouter(
    initialLocation: path,
    navigatorKey: rootNavKey,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/study', builder: (_, _) => const StudyScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/test', builder: (_, _) => const TestHubScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai',
                builder: (_, s) => AiScreen(chatId: s.uri.queryParameters['chat']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/me', builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/cbt/:id',
        builder: (_, s) => CbtScreen(attemptId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/results/:id',
        builder: (_, s) => ResultsScreen(attemptId: s.pathParameters['id']!),
      ),
    ],
  );
  await t.runAsync(() async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          testsRepoProvider.overrideWith((ref) => OfflineRepo(ref)),
          ...fixtureOverrides(),
          tabsProvider.overrideWith((_) async => const []),
          aiQuotaProvider.overrideWith((_) async => {'left': 18, 'limit': 20}),
          aiChatsProvider.overrideWith((_) async => const []),
          aiSuggestionsProvider.overrideWith((_) async => const []),
          aiRepoProvider.overrideWith((ref) => _ChatRepo(ref)),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          routerConfig: router,
        ),
      ),
    );
    // 6 s of app time: long enough for toasts such as "Welcome back. We saved your answers." to go away.
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 110));
      await t.pump(const Duration(milliseconds: 120));
    }
  });
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/advert/$name.png'));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 8));
}

void main() {
  setUpAll(() async {
    await _font('LilitaOne', ['assets/fonts/LilitaOne-Regular.ttf']);
    await _font('PlusJakartaSans', ['assets/fonts/PlusJakartaSans-Medium.ttf', 'assets/fonts/PlusJakartaSans-Bold.ttf']);
    await _font('PhosphorRegular', ['assets/fonts/Phosphor-Regular.ttf']);
    await _font('PhosphorFill', ['assets/fonts/Phosphor-Fill.ttf']);
    await _font('MaterialIcons', [_materialIcons]);
    await _katex();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage(), autoRefreshToken: false),
    );
  });
  setUp(() async {
    db = AppDb(NativeDatabase.memory());
    await _seedCbt(db);
    await _seedMock(db);
  });
  tearDown(() => db.close());

  final screens = Platform.environment['SHOTS']?.split(',');
  bool want(String n) => screens == null || screens.contains(n);

  for (final (path, name) in const [
    ('/home', 'home'),
    ('/study', 'study'),
    ('/test', 'test'),
    ('/ai?chat=c1', 'ai'),
    ('/me', 'me'),
    ('/cbt/att1', 'cbt'),
    ('/results/mock1', 'results'),
  ]) {
    if (want(name)) testWidgets(name, (t) => shot(t, path, name));
  }
}

/// One JAMB Mathematics test in progress, on question 2 (like test_shots/desktop_shots_test.dart).
Future<void> _seedCbt(AppDb db) async {
  const ids = ['q1', 'q2', 'q3', 'q4', 'q5'];
  const bodies = [
    'If log₁₀ 2 = 0.3010, find log₁₀ 8.',
    'Find the roots of x² − 5x + 6 = 0.',
    'Simplify (2³ × 2⁴) ÷ 2⁵.',
    'Make r the subject of the formula V = πr²h.',
    'Evaluate 0.0025 ÷ 0.05.',
  ];
  const opts = [
    {'A': '0.6020', 'B': '0.9030', 'C': '2.4080', 'D': '0.0753'},
    {'A': 'x = 2 or 3', 'B': 'x = −2 or −3', 'C': 'x = 1 or 6', 'D': 'x = −1 or 6'},
    {'A': '2', 'B': '4', 'C': '8', 'D': '16'},
    {'A': 'r = √(V/πh)', 'B': 'r = V/πh', 'C': 'r = √(Vπh)', 'D': 'r = πh/V'},
    {'A': '0.5', 'B': '0.05', 'C': '0.005', 'D': '5'},
  ];
  const keys = ['B', 'A', 'B', 'A', 'B'];
  for (final (i, id) in ids.indexed) {
    await db
        .into(db.cachedQuestions)
        .insert(
          CachedQuestionsCompanion.insert(id: id, examId: 1, subjectId: 10, year: 2020, body: bodies[i], optionsJson: jsonEncode(opts[i]), answer: keys[i]),
        );
  }
  await db
      .into(db.localAttempts)
      .insert(
        LocalAttemptsCompanion.insert(
          id: 'att1',
          examId: 1,
          examCode: 'JAMB',
          mode: 'subject',
          configJson: jsonEncode({'title': 'JAMB Mathematics 2020'}),
          questionIdsJson: jsonEncode(ids),
          limitSeconds: 3600,
          startedAt: DateTime.now().subtract(const Duration(minutes: 4)),
          currentIndex: const Value(1),
        ),
      );
  await db.into(db.localAnswers).insert(LocalAnswersCompanion.insert(attemptId: 'att1', questionId: 'q1', choice: const Value('B')));
}

/// A finished full JAMB mock (4 subjects, 180 questions), marked on this phone.
Future<void> _seedMock(AppDb db) async {
  // subject id, questions, right answers, topics
  const plan = [
    (11, 60, 47, ['Comprehension', 'Lexis and structure', 'Oral English']),
    (10, 40, 29, ['Quadratic equations', 'Logarithms', 'Probability']),
    (12, 40, 28, ['Motion', 'Waves', 'Electricity']),
    (13, 40, 30, ['Mole concept', 'Organic chemistry', 'Electrolysis']),
  ];
  final ids = <String>[
    for (final (sid, n, _, _) in plan)
      for (var i = 0; i < n; i++) 'm$sid-$i',
  ];
  final start = DateTime.now().subtract(const Duration(hours: 2));
  await db
      .into(db.localAttempts)
      .insert(
        LocalAttemptsCompanion.insert(
          id: 'mock1',
          examId: 1,
          examCode: 'JAMB',
          mode: 'full',
          configJson: jsonEncode({'title': 'JAMB UTME Mock'}),
          questionIdsJson: jsonEncode(ids),
          limitSeconds: 7200,
          usedMs: const Value(6420000),
          startedAt: start,
          submittedAt: Value(start.add(const Duration(minutes: 107))),
          synced: const Value(true),
        ),
      );
  for (final (sid, n, right, topics) in plan) {
    for (var i = 0; i < n; i++) {
      final id = 'm$sid-$i';
      await db
          .into(db.cachedQuestions)
          .insert(
            CachedQuestionsCompanion.insert(
              id: id,
              examId: 1,
              subjectId: sid,
              year: 2023,
              body: 'Question ${i + 1}',
              optionsJson: jsonEncode({'A': 'a', 'B': 'b', 'C': 'c', 'D': 'd'}),
              answer: 'A',
              topic: Value(topics[i % topics.length]),
            ),
          );
      await db.into(db.localAnswers).insert(LocalAnswersCompanion.insert(attemptId: 'mock1', questionId: id, choice: Value(i < right ? 'A' : 'C')));
    }
  }
}
