import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:solutiontee_cbt/features/cbt/cbt_screen.dart';
import 'package:solutiontee_cbt/features/compete/mock_exam.dart';

import 'widgets_test.dart' show app;

class FakeMock implements MockApi {
  final saves = <String>[];
  final events = <String>[];
  bool submitted = false;
  Map<String, dynamic> eventAnswer = {'status': 'playing', 'leaves': 1, 'allowed_exits': 3};
  @override
  Future<Map<String, dynamic>> start(String id) async => paper;
  @override
  Future<Map<String, dynamic>> save(String entry, String question, String? choice, int ms) async {
    saves.add('$question:$choice');
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> event(String entry, String kind, {int? ms}) async {
    events.add(kind);
    return eventAnswer;
  }

  @override
  Future<Map<String, dynamic>> submit(String entry) async {
    submitted = true;
    return {'status': 'finished'};
  }

  @override
  Future<Map<String, dynamic>> result(String id) async => {
    'status': 'finished',
    'visible': true,
    'score': 150,
    'rank': 3,
    'players': 40,
    'subjects': [
      {'name': 'Use of English', 'correct': 1, 'total': 2, 'score': 50},
      {'name': 'Mathematics', 'correct': 1, 'total': 1, 'score': 100},
    ],
  };
  @override
  Future<Map<String, dynamic>> unlock(String id, String code) async => {'ok': code == 'ABCD-EFGH'};
}

final paper = <String, dynamic>{
  'status': 'playing',
  'entry_id': 'e1',
  'now': DateTime.now().toUtc().toIso8601String(),
  'deadline': DateTime.now().toUtc().add(const Duration(hours: 2)).toIso8601String(),
  'title': 'UTME Mock 1',
  'exam_code': 'JAMB',
  'subjects': [
    {
      'id': 10,
      'name': 'Use of English',
      'questions': [
        {
          'id': 'q1',
          'number': 1,
          'body': 'In the passage, nightmare means',
          'options': {'A': 'a bad dream', 'B': 'a horse', 'C': 'a night', 'D': 'a mare'},
          'passage_key': 'P1',
          'passage_title': 'Passage I',
          'passage_body': 'In the past, famine checked population growth.',
          'choice': 'B',
        },
        {
          'id': 'q2',
          'number': 2,
          'body': 'Choose the option nearest in meaning to: candid',
          'options': {'A': 'frank', 'B': 'shy', 'C': 'rude', 'D': 'quiet'},
        },
      ],
    },
    {
      'id': 20,
      'name': 'Mathematics',
      'questions': [
        {
          'id': 'q3',
          'number': 1,
          'body': r'Solve $2x + 3 = 7$',
          'options': {'A': '1', 'B': '2', 'C': '3', 'D': '4'},
        },
      ],
    },
  ],
};

void main() {
  late AppDb db;
  setUp(() => db = AppDb(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('the mock paper is saved on the phone without answers, with the saved choices, as attempt = entry', () async {
    final id = await saveMockPaper(db, 'c1', paper);
    expect(id, 'e1');
    final a = await (db.select(db.localAttempts)..where((x) => x.id.equals('e1'))).getSingle();
    expect(a.mode, 'mock');
    expect(jsonDecode(a.configJson)['mock'], 'c1');
    expect((jsonDecode(a.questionIdsJson) as List), ['q1', 'q2', 'q3']);
    expect(a.limitSeconds, greaterThan(7000));
    final qs = await db.questionsByIds(['q1', 'q2', 'q3']);
    expect(qs.map((q) => q.answer).toSet(), {''}); // no answers on the phone
    expect(qs.first.passageBody, contains('famine'));
    expect((await db.answersFor('e1')).single.choice, 'B');
  });

  Future<FakeMock> open(WidgetTester t) async {
    final api = FakeMock();
    await t.runAsync(() => saveMockPaper(db, 'c1', paper));
    await t.runAsync(() async {
      await t.pumpWidget(
        app(
          const CbtScreen(attemptId: 'e1'),
          overrides: [
            dbProvider.overrideWithValue(db),
            mockApiProvider.overrideWithValue(api),
            subjectsProvider.overrideWith(
              (_) async => [
                {'id': 10, 'code': 'eng', 'name': 'Use of English'},
                {'id': 20, 'code': 'mth', 'name': 'Mathematics'},
              ],
            ),
            profileProvider.overrideWith((_) async => {'full_name': 'Ada Obi'}),
          ],
        ),
      );
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await t.pump();
      }
    });
    await t.pump(const Duration(milliseconds: 500));
    return api;
  }

  testWidgets('a mock runs in our CBT screen: choices go to the server, submit shows the JAMB-style score', (t) async {
    t.view.physicalSize = const Size(1600, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final api = await open(t);
    expect(find.text('In the passage, nightmare means'), findsOneWidget);
    await t.tap(find.text('a bad dream'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump(const Duration(milliseconds: 300));
    expect(api.saves, contains('q1:A'));
    await t.tap(find.text('Submit').first);
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Submit now'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(api.submitted, isTrue);
    expect(find.text('150 / 200'), findsOneWidget);
    expect(find.text('See the leaderboard'), findsOneWidget);
    expect(await t.runAsync(() => (db.select(db.localAttempts)..where((x) => x.id.equals('e1'))).getSingleOrNull()), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('leaving the screen is reported once per absence and the student is warned on return', (t) async {
    t.view.physicalSize = const Size(1600, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final api = await open(t);
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      t.binding.handleAppLifecycleStateChanged(s);
    }
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      t.binding.handleAppLifecycleStateChanged(s);
    }
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump(const Duration(milliseconds: 500));
    expect(api.events, ['leave', 'return']);
    expect(find.text('Stay on the exam screen'), findsOneWidget);
    expect(find.textContaining('1 of 3 allowed'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
