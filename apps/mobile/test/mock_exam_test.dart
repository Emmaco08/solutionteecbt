import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/compete/mock_exam.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

class FakeMock implements MockApi {
  final saves = <String>[];
  final events = <String>[];
  bool submitted = false;
  Map<String, dynamic> eventAnswer = {'status': 'playing', 'leaves': 1, 'allowed_exits': 3};
  @override
  Future<Map<String, dynamic>> start(String id) async => {
    'status': 'playing',
    'entry_id': 'e1',
    'now': DateTime.now().toUtc().toIso8601String(),
    'deadline': DateTime.now().toUtc().add(const Duration(hours: 2)).toIso8601String(),
    'candidate': 'Ada Obi',
    'title': 'UTME Mock 1',
    'exam_code': 'JAMB',
    'allow_calculator': true,
    'subjects': [
      {
        'id': 1,
        'name': 'Use of English',
        'questions': [
          {
            'id': 'q1',
            'body': 'According to the passage, the writer was',
            'options': {'A': 'happy', 'B': 'sad', 'C': 'angry', 'D': 'tired'},
            'passage_title': 'Passage I',
            'passage_body': 'It was a bright morning in Ibadan when the market opened.',
          },
          {
            'id': 'q2',
            'body': 'Choose the option nearest in meaning to: candid',
            'options': {'A': 'frank', 'B': 'shy', 'C': 'rude', 'D': 'quiet'},
          },
        ],
      },
      {
        'id': 2,
        'name': 'Mathematics',
        'questions': [
          {
            'id': 'q3',
            'body': r'Solve $2x + 3 = 7$',
            'options': {'A': '1', 'B': '2', 'C': '3', 'D': '4'},
          },
        ],
      },
    ],
  };
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

Widget app(FakeMock api) => ProviderScope(
  overrides: [mockApiProvider.overrideWithValue(api)],
  child: MaterialApp(
    theme: buildTheme(Brightness.dark),
    home: const MockExamScreen(id: 'c1'),
  ),
);

Future<void> pumpFor(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('JAMB mock: candidate bar, passage, choose, subjects, submit and the JAMB-style score', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final api = FakeMock();
    await t.pumpWidget(app(api));
    await pumpFor(t);
    expect(find.text('ADA OBI'), findsOneWidget);
    expect(find.text('TIME LEFT'), findsOneWidget);
    expect(find.text('USE OF ENGLISH'), findsOneWidget);
    expect(find.text('MATHEMATICS'), findsOneWidget);
    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(find.text('Passage I'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('mock-opt-B')));
    await pumpFor(t, 300);
    expect(api.saves, ['q1:B']);
    await t.tap(find.text('Next'));
    await pumpFor(t, 300);
    expect(find.text('Question 2 of 2'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('mock-subject-1')));
    await pumpFor(t, 300);
    expect(find.text('Question 1 of 1'), findsOneWidget);
    expect(find.text('1 of 3 answered'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('mock-submit')));
    await pumpFor(t, 300);
    expect(find.textContaining('2 questions not answered'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('mock-submit-yes')));
    await pumpFor(t);
    expect(api.submitted, isTrue);
    expect(find.text('150 / 200'), findsOneWidget);
    expect(find.text('Position 3 of 40'), findsOneWidget);
  });

  testWidgets('leaving the screen is reported and the student is warned', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final api = FakeMock();
    await t.pumpWidget(app(api));
    await pumpFor(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await pumpFor(t, 200);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpFor(t);
    expect(api.events, containsAllInOrder(['leave', 'return']));
    expect(find.text('Stay on the exam screen'), findsOneWidget);
    expect(find.textContaining('1 of 3 allowed'), findsOneWidget);
  });

  testWidgets('leaving too much ends the exam with a clear reason', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final api = FakeMock()..eventAnswer = {'status': 'finished', 'reason': 'left_too_much'};
    await t.pumpWidget(app(api));
    await pumpFor(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await pumpFor(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpFor(t);
    expect(find.textContaining('more than allowed'), findsOneWidget);
  });
}
