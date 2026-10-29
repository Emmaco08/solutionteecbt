import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:solutiontee_cbt/core/api.dart';
import 'package:solutiontee_cbt/core/config.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:solutiontee_cbt/data/tests_repo.dart';
import 'package:solutiontee_cbt/features/auth/auth_screens.dart';
import 'package:solutiontee_cbt/features/cbt/cbt_screen.dart';
import 'package:solutiontee_cbt/features/onboarding/onboarding_screens.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

/// Records sign-ups instead of calling the website.
class FakeApi extends WebApi {
  final calls = <String>[];
  @override
  Future<int> signUp({required String email, required String password, required String fullName, String? referralCode}) async {
    calls.add(email);
    return 6;
  }
}

/// Real marking on the phone, no network sync.
class OfflineRepo extends TestsRepo {
  OfflineRepo(super.ref);
  @override
  Future<int> syncPending() async => 0;
}

Widget app(Widget home, {List overrides = const [], Map<String, Widget> routes = const {}}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      for (final e in routes.entries) GoRoute(path: e.key, builder: (_, _) => e.value),
    ],
  );
  return ProviderScope(
    overrides: [...overrides],
    child: MaterialApp.router(theme: buildTheme(Brightness.light), routerConfig: router),
  );
}

void main() {
  testWidgets('onboarding welcome shows the exam bodies, both actions and the disclaimer', (t) async {
    await t.pumpWidget(app(const WelcomeScreen()));
    await t.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
    expect(find.text(Config.disclaimer), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('JAMB|WAEC|NECO')), findsWidgets);
  });

  testWidgets('sign-up needs consent before anything is sent', (t) async {
    final api = FakeApi();
    await t.pumpWidget(app(const SignUpScreen(), overrides: [apiProvider.overrideWithValue(api)], routes: {'/verify': const Text('VERIFY')}));
    await t.pumpAndSettle();

    await t.enterText(find.widgetWithText(TextField, 'Full name'), 'Ada Obi');
    await t.enterText(find.widgetWithText(TextField, 'Email'), 'ada@example.com');
    await t.enterText(find.byType(TextField).at(2), 'secret123');
    await t.ensureVisible(find.text('Create account'));
    await t.tap(find.text('Create account'));
    await t.pumpAndSettle();
    expect(find.text('Please accept the Terms and Privacy Policy to continue.'), findsOneWidget);
    expect(api.calls, isEmpty);

    await t.tap(find.byType(Checkbox));
    await t.tap(find.text('Create account'));
    await t.pumpAndSettle();
    expect(api.calls, ['ada@example.com']);
    expect(find.text('VERIFY'), findsOneWidget);
  });

  group('CBT screen', () {
    late AppDb db;
    const ids = ['q1', 'q2', 'q3'];

    setUp(() async {
      db = AppDb(NativeDatabase.memory());
      for (final (i, id) in ids.indexed) {
        await db
            .into(db.cachedQuestions)
            .insert(
              CachedQuestionsCompanion.insert(
                id: id,
                examId: 1,
                subjectId: 10,
                year: 2020,
                body: 'Question body ${i + 1}',
                optionsJson: jsonEncode({'A': 'Alpha', 'B': 'Bravo', 'C': 'Charlie', 'D': 'Delta'}),
                answer: 'B',
              ),
            );
      }
      await db
          .into(db.localAttempts)
          .insert(
            LocalAttemptsCompanion.insert(
              id: 'att1',
              examId: 1,
              examCode: 'WAEC',
              mode: 'subject',
              configJson: jsonEncode({'title': 'WAEC Maths 2020'}),
              questionIdsJson: jsonEncode(ids),
              limitSeconds: 600,
              startedAt: DateTime.now(),
              currentIndex: const Value(0),
            ),
          );
    });
    tearDown(() => db.close());

    List overrides() => [
      dbProvider.overrideWithValue(db),
      subjectsProvider.overrideWith(
        (_) async => [
          {'id': 10, 'code': 'mth', 'name': 'Mathematics'},
        ],
      ),
      testsRepoProvider.overrideWith((ref) => OfflineRepo(ref)),
    ];

    testWidgets('answers are saved at once, flags work, and submitting marks the test', (t) async {
      await t.runAsync(() async {
        await t.pumpWidget(
          app(
            const CbtScreen(attemptId: 'att1'),
            overrides: overrides(),
            routes: {'/results/:id': const Text('RESULTS')},
          ),
        );
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await t.pump();
        }
      });
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Question body 1'), findsOneWidget);
      expect(find.text('Question 1'), findsOneWidget);

      // Choose B (correct), saved to SQLite straight away.
      await t.tap(find.text('Bravo'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump();
      final saved = await t.runAsync(() => db.answersFor('att1'));
      expect(saved!.single.choice, 'B');

      // Flag, then go to question 2.
      await t.tap(find.byTooltip('Flag for review'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump();
      expect(find.text('Flagged'), findsOneWidget);
      await t.tap(find.text('Next'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Question body 2'), findsOneWidget);

      // Submit from the header and confirm.
      await t.tap(find.widgetWithText(FilledButton, 'Submit').first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Submit your test?'), findsOneWidget);
      await t.tap(find.text('Submit now'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('RESULTS'), findsOneWidget);

      final a = await t.runAsync(() => (db.select(db.localAttempts)..where((x) => x.id.equals('att1'))).getSingle());
      expect(a!.submittedAt, isNotNull);
      final score = jsonDecode(a.clientScoreJson!) as Map<String, dynamic>;
      expect(score['correct'], 1);
      expect(score['total'], 33); // 1 of 3 correct -> round(33.3)
    });
  });
}
