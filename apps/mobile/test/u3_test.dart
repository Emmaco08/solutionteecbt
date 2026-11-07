import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/api.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/ai_repo.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:solutiontee_cbt/data/tests_repo.dart';
import 'package:solutiontee_cbt/features/ai/ai_cards.dart';
import 'package:solutiontee_cbt/features/ai/ai_screen.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

CachedQuestion q(String id, {String? passage}) => CachedQuestion(
  id: id,
  examId: 1,
  subjectId: 5,
  year: 2015,
  number: 1,
  body: 'b',
  optionsJson: '{}',
  answer: 'A',
  explanation: null,
  topic: 'Motion',
  imagePath: null,
  passageId: passage,
  passageTitle: null,
  passageBody: null,
  fetchedAt: DateTime(2026),
);

class FakeTests implements TestsRepo {
  TestRequest? got;
  Object? fail;
  @override
  Future<String> start(TestRequest r, {required int Function(int subjectId) countFor, required double minutesPerQuestion}) async {
    got = r;
    if (fail != null) throw fail!;
    return 'attempt-1';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeAi implements AiRepo {
  final asked = <Map<String, dynamic>>[];
  List<AiEvent> events = const [];
  @override
  Stream<AiEvent> ask({
    String? chatId,
    String text = '',
    String? imageBase64,
    int? subjectId,
    bool hint = false,
    String? questionId,
    bool explain = false,
    String? tool,
    Map<String, dynamic>? args,
  }) {
    asked.add({'text': text, 'tool': tool, 'args': args, 'questionId': questionId, 'explain': explain});
    return Stream.fromIterable(events);
  }

  @override
  void stop() {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const testCard = {
  'type': 'test',
  'exam_id': 1,
  'exam': 'JAMB',
  'subject_id': 5,
  'subject': 'Physics',
  'topics': ['Motion'],
  'years': [2015, 2016],
  'ids': ['a', 'b', 'c'],
  'count': 3,
  'minutes': 3,
  'difficulty': 'hard',
};
const quizCard = {
  'type': 'quiz',
  'subject': 'Physics',
  'subject_id': 5,
  'exam': 'JAMB',
  'questions': [
    {
      'id': 'q1',
      'body': 'What is speed?',
      'options': {'A': 'Distance over time', 'B': 'Mass'},
      'year': 2015,
    },
  ],
};
const notesCard = {
  'type': 'notes',
  'items': [
    {'id': 'n1', 'title': 'Motion', 'subtitle': 'Physics', 'locked': false},
    {'id': 'n2', 'title': 'Waves', 'subtitle': 'Physics', 'locked': true},
  ],
};
const weakCard = {
  'type': 'weak',
  'items': [
    {'subject': 'Physics', 'subject_id': 5, 'topic': 'Motion', 'answered': 12, 'correct': 4, 'pct': 33},
    {'subject': 'Physics', 'subject_id': 5, 'topic': 'Heat', 'answered': 10, 'correct': 5, 'pct': 50},
    {'subject': 'Physics', 'subject_id': 5, 'topic': 'Light', 'answered': 10, 'correct': 8, 'pct': 80},
  ],
};

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Widget host(Widget child, Brightness b, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: buildTheme(b),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  test('SSE parser reads tool events and done.free', () {
    final p = AiSseParser();
    final ev = p.add(
      'data: {"t":"tool","name":"practice_test","state":"run","label":"Building your test…"}\n\n'
      'data: {"t":"tool","name":"practice_test","state":"done","card":{"type":"test","ids":["a"]}}\n\n'
      'data: {"t":"tool","name":"quiz","state":"done","card":null}\n\n'
      'data: {"t":"done","message_id":"m1","left":null,"model":"quiz","free":true}\n\n'
      'data: {"t":"done","message_id":"m2","left":3,"model":"x"}\n\n'
      'data: {"t":"error","code":"locked","message":"Premium year"}\n\n',
    );
    final run = ev[0] as AiTool;
    expect((run.name, run.running, run.label, run.card), ('practice_test', true, 'Building your test…', null));
    final done = ev[1] as AiTool;
    expect(done.running, isFalse);
    expect(done.card?['type'], 'test');
    expect((ev[2] as AiTool).card, isNull);
    expect((ev[3] as AiDone).free, isTrue);
    expect((ev[3] as AiDone).left, isNull);
    expect((ev[4] as AiDone).free, isFalse);
    expect((ev[5] as AiFailed).code, 'locked');
  });

  test('chips are read from the server JSON', () {
    final c = AiChip.fromJson({
      'label': 'Quiz me on Motion',
      'tool': 'quiz',
      'args': {'subject': 'Physics', 'topic': 'Motion', 'count': 3},
    });
    expect((c.label, c.tool, c.text), ('Quiz me on Motion', 'quiz', null));
    expect(c.args['count'], 3);
    expect(AiChip.fromJson({'label': 'Hi', 'text': 'Hello'}).args, isEmpty);
  });

  test('TestsRepo.pickByIds keeps the picked questions in the server order and passages together', () {
    final pool = [q('x'), q('c'), q('a', passage: 'p1'), q('y'), q('b'), q('a2', passage: 'p1'), q('c')];
    final out = TestsRepo.pickByIds(pool, ['b', 'a', 'c', 'a2', 'missing']);
    // Server order is b, a, c, a2; a2 shares a passage with a, so it moves next to it. Duplicates are dropped.
    expect([for (final x in out) x.id], ['b', 'a', 'a2', 'c']);
    expect(TestsRepo.pickByIds(pool, const []), isEmpty);
  });

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('cards render in ${b.name} mode', (t) async {
      final fake = FakeTests();
      for (final card in [testCard, quizCard, notesCard, weakCard]) {
        await t.pumpWidget(
          host(
            AiCardView(card: card, send: ({text, tool, args, questionId, explain = false}) {}, check: (_, _) async => {'ok': false}),
            b,
            overrides: [testsRepoProvider.overrideWithValue(fake)],
          ),
        );
        await settle(t);
        expect(tester(t), isNull);
        switch (card['type']) {
          case 'test':
            expect(find.text('Physics test'), findsOneWidget);
            expect(find.text('Motion'), findsOneWidget);
            expect(find.text('Hard'), findsOneWidget);
            expect(find.text('Start test'), findsOneWidget);
          case 'quiz':
            expect(find.textContaining('Physics quiz'), findsOneWidget);
            expect(find.textContaining('What is speed'), findsWidgets);
          case 'notes':
            expect(find.text('Motion'), findsOneWidget);
            expect(find.text('Waves'), findsOneWidget);
          case 'weak':
            expect(find.text('33%'), findsOneWidget);
            expect(find.text('Quiz me'), findsNWidgets(3));
        }
      }
    });
  }

  testWidgets('Start test builds the exact test the tutor picked and opens it', (t) async {
    final fake = FakeTests();
    String? opened;
    await t.pumpWidget(
      host(
        TestCard(card: testCard, onStarted: (id) => opened = id),
        Brightness.light,
        overrides: [testsRepoProvider.overrideWithValue(fake)],
      ),
    );
    await t.tap(find.text('Start test'));
    await settle(t);
    final r = fake.got!;
    expect(r.mode, TestMode.topic);
    expect((r.examId, r.examCode, r.count, r.limitMinutes), (1, 'JAMB', 3, 3));
    expect(r.subjectIds, [5]);
    expect(r.ids, ['a', 'b', 'c']);
    expect(r.years, [2015, 2016]);
    expect(r.title, 'AI test · Physics · Motion');
    expect(opened, 'attempt-1');
  });

  testWidgets('Start test shows a friendly error when the test cannot be built', (t) async {
    final fake = FakeTests()..fail = ApiError('This year is part of Premium.', status: 402);
    await t.pumpWidget(host(const TestCard(card: testCard), Brightness.light, overrides: [testsRepoProvider.overrideWithValue(fake)]));
    await t.tap(find.text('Start test'));
    await settle(t);
    expect(find.text('This year is part of Premium.'), findsOneWidget);
  });

  testWidgets('quiz: a tap is marked by the server, shows the answer and the explanation; one answer per question', (t) async {
    final calls = <String>[];
    String? explained;
    await t.pumpWidget(
      host(
        AiCardView(
          card: quizCard,
          send: ({text, tool, args, questionId, explain = false}) => explained = questionId,
          check: (id, choice) async {
            calls.add('$id:$choice');
            return {'ok': true, 'correct': false, 'answer': 'A', 'explanation': 'Speed is distance over time.'};
          },
        ),
        Brightness.dark,
      ),
    );
    await t.tap(find.textContaining('Mass'));
    await settle(t);
    expect(calls, ['q1:B']);
    expect(find.text('The answer is A'), findsOneWidget);
    expect(find.textContaining('Speed is distance over time'), findsWidgets);
    await t.tap(find.textContaining('Distance over time'));
    await settle(t);
    expect(calls.length, 1);
    await t.tap(find.text('Explain with AI'));
    expect(explained, 'q1');
  });

  testWidgets('weak topics: Quiz me sends the quiz tool for that topic', (t) async {
    Map<String, dynamic>? gotArgs;
    String? gotTool;
    await t.pumpWidget(
      host(
        AiCardView(
          card: weakCard,
          send: ({text, tool, args, questionId, explain = false}) {
            gotTool = tool;
            gotArgs = args;
          },
          check: (_, _) async => {'ok': false},
        ),
        Brightness.light,
      ),
    );
    await t.tap(find.text('Quiz me').first);
    expect(gotTool, 'quiz');
    expect(gotArgs, {'subject': 'Physics', 'topic': 'Motion', 'count': 3});
  });

  testWidgets('chat: a chip with a tool is sent with tool and args; the tool card and the free caption show', (t) async {
    final ai = FakeAi()
      ..events = [
        AiStart('c1'),
        AiTool('weak_topics', 'run', label: 'Checking your results…'),
        AiTool('weak_topics', 'done', card: Map<String, dynamic>.from(weakCard)),
        AiDelta('Here are your weak topics.'),
        AiDone(messageId: 'm1', free: true),
      ];
    await t.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          aiRepoProvider.overrideWithValue(ai),
          aiQuotaProvider.overrideWith((_) async => {'used': 1, 'limit': 5, 'left': 4}),
          profileProvider.overrideWith((_) async => {'full_name': 'Ada Obi'}),
          subjectsProvider.overrideWith((_) async => <Map<String, dynamic>>[]),
          aiSuggestionsProvider.overrideWith(
            (_) async => const [AiChip('My weak topics', tool: 'weak_topics'), AiChip('Teach me Motion', text: 'Teach me Motion step by step.')],
          ),
        ],
        child: MaterialApp(theme: buildTheme(Brightness.light), home: const AiScreen()),
      ),
    );
    await settle(t);
    expect(find.text('My weak topics'), findsOneWidget);
    await t.tap(find.text('My weak topics'));
    await settle(t);
    expect(ai.asked.single['tool'], 'weak_topics');
    expect(ai.asked.single['text'], 'My weak topics');
    expect(find.text('Your weak topics'), findsOneWidget);
    expect(find.text('Free · no prompt used'), findsOneWidget);
    // Chips come back above the composer after the answer.
    expect(find.text('Teach me Motion'), findsOneWidget);
    await t.tap(find.text('Teach me Motion'));
    await settle(t);
    expect(ai.asked.last['text'], 'Teach me Motion step by step.');
    expect(ai.asked.last['tool'], isNull);
  });
}

// A tiny helper so each loop turn also surfaces any exception thrown while building.
Object? tester(WidgetTester t) => t.takeException();
