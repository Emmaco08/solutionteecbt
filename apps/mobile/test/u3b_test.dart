import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/ai_repo.dart';
import 'package:solutiontee_cbt/features/ai/ai_actions.dart';
import 'package:solutiontee_cbt/features/ai/ai_cards.dart';
import 'package:solutiontee_cbt/features/ai/ai_screen.dart';
import 'package:solutiontee_cbt/features/home/top_card.dart';
import 'package:solutiontee_cbt/ui/kit.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:solutiontee_cbt/widgets/phosphor.g.dart';

/// A tutor that plays back scripted events and records what the screen asked.
class FakeAi implements AiRepo {
  final asked = <Map<String, dynamic>>[];
  final reacted = <(String, String?)>[];
  List<AiEvent> Function(int call) script = (_) => const [];
  List<Map<String, dynamic>> saved = [];
  int messagesCalls = 0;
  final plans = <Map<String, dynamic>>[];
  bool failPlan = false;

  @override
  Stream<AiEvent> ask({
    String? chatId,
    String text = '',
    String? imageBase64,
    int? subjectId,
    bool hint = false,
    int? hintLevel,
    String? questionId,
    bool explain = false,
    String? tool,
    Map<String, dynamic>? args,
    bool readFirst = false,
    List<Map<String, dynamic>>? then,
  }) {
    asked.add({'text': text, 'hint': hint, 'hintLevel': hintLevel, 'tool': tool, 'args': args, 'chatId': chatId});
    return Stream.fromIterable(script(asked.length - 1));
  }

  @override
  Future<List<Map<String, dynamic>>> messages(String chatId) async {
    messagesCalls++;
    return saved;
  }

  @override
  Future<void> planUpdate(String planId, {int? doneDay, bool? reminders}) async {
    if (failPlan) throw Exception('offline');
    plans.add({'plan': planId, 'day': doneDay, 'reminders': reminders});
  }

  @override
  Future<void> react(String messageId, String? reaction) async => reacted.add((messageId, reaction));

  @override
  Future<Map<String, dynamic>> quizCheck(String questionId, String choice) async => const {'ok': false};

  @override
  void stop() {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> settle(WidgetTester t, [int ms = 800]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> chat(
  WidgetTester t,
  FakeAi ai, {
  List<AiChip> chips = const [AiChip('Ask it', text: 'What is speed?')],
  AiScreen screen = const AiScreen(),
}) async {
  await t.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        aiRepoProvider.overrideWithValue(ai),
        aiQuotaProvider.overrideWith((_) async => {'used': 1, 'limit': 5, 'left': 4}),
        profileProvider.overrideWith((_) async => {'full_name': 'Ada Obi'}),
        subjectsProvider.overrideWith((_) async => <Map<String, dynamic>>[]),
        aiSuggestionsProvider.overrideWith((_) async => chips),
      ],
      child: MaterialApp(theme: buildTheme(Brightness.light), home: screen),
    ),
  );
  await settle(t, 2000);
}

Future<void> end(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(milliseconds: 50));
}

Widget host(Widget child, {Brightness b = Brightness.light, double width = 800}) => ProviderScope(
  child: MaterialApp(
    theme: buildTheme(b),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  ),
);

Widget routed(Widget child) => ProviderScope(
  child: MaterialApp.router(
    theme: buildTheme(Brightness.light),
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: SingleChildScrollView(child: child)),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) => const Scaffold(body: Text('Leaderboard page')),
        ),
      ],
    ),
  ),
);

Future<void> sendFromComposer(WidgetTester t, String text) async {
  await t.enterText(find.byType(TextField), text);
  await t.tap(find.byIcon(PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill)));
  await settle(t, 400);
}

const _ok = {'ok': true};

void main() {
  test('SSE parser reads steps, follow-ups and chip icons', () {
    final ev = AiSseParser().add(
      'data: {"t":"tool","name":"quiz","state":"run","label":"Picking…","steps":["Reading","Picking","Ready"]}\n\n'
      'data: {"t":"followups","items":["Why?","Example?"]}\n\n',
    );
    expect((ev[0] as AiTool).steps, ['Reading', 'Picking', 'Ready']);
    expect((ev[1] as AiFollowups).items, ['Why?', 'Example?']);
    final c = AiChip.fromJson({'label': 'Continue: Motion', 'chat_id': 'c9', 'icon': 'chatsCircle'});
    expect((c.chatId, c.icon, c.tool), ('c9', 'chatsCircle', null));
    expect(aiSplitQuote('> a quote\n\nmy text'), ('a quote', 'my text'));
    expect(aiSplitQuote('plain'), (null, 'plain'));
    expect(aiQuoteOf('x' * 200).length, 121);
  });

  testWidgets('background: the stream dies after start, the saved answer fills the bubble and no error shows', (t) async {
    final ai = FakeAi()
      ..script = ((_) => [AiStart('c1'), AiFailed('No internet connection.', code: 'net')])
      ..saved = [
        {'id': 'm9', 'role': 'assistant', 'content': 'The saved answer is forty two.', 'card': null, 'reaction': null},
      ];
    await chat(t, ai);
    await t.tap(find.text('Ask it'));
    await settle(t, 600);
    expect(find.text('Finishing in the background…'), findsOneWidget);
    expect(find.textContaining('No internet'), findsNothing);
    expect(ai.messagesCalls, 0);
    await settle(t, 3200);
    expect(ai.messagesCalls, greaterThan(0));
    expect(find.textContaining('forty two', findRichText: true), findsOneWidget);
    expect(find.text('Finishing in the background…'), findsNothing);
    expect(find.textContaining('did not arrive'), findsNothing);
    await end(t);
  });

  testWidgets('no internet shows the error when the request never started', (t) async {
    final ai = FakeAi()..script = (_) => [AiFailed('No internet connection.', code: 'net')];
    await chat(t, ai);
    await t.tap(find.text('Ask it'));
    await settle(t, 600);
    expect(find.textContaining('No internet'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await end(t);
  });

  testWidgets('hint ladder: dots, Next hint (level 2), Show the answer (level 3), Check my working fills the composer', (t) async {
    final ai = FakeAi()..script = (i) => [AiStart('c1'), AiDelta('Think about the forces.'), AiDone(messageId: 'm$i')];
    await chat(t, ai);
    await t.tap(find.text('Hint mode'));
    await t.pump();
    await sendFromComposer(t, 'Why does a ball fall?');
    expect(ai.asked.last['hint'], true);
    expect(ai.asked.last['hintLevel'], 1);
    expect(find.text('Hint 1 of 3'), findsOneWidget);
    expect(find.text('Next hint'), findsOneWidget);
    expect(find.text('Show the answer'), findsOneWidget);

    await t.tap(find.text('Next hint'));
    await settle(t, 600);
    expect(ai.asked.last['hintLevel'], 2);
    expect(ai.asked.last['text'], 'Why does a ball fall?');
    expect(find.text('Hint 2 of 3'), findsOneWidget);

    await t.tap(find.text('Check my working'));
    await settle(t, 200);
    expect(find.widgetWithText(TextField, 'My working: '), findsOneWidget);
    await sendFromComposer(t, 'My working: g pulls it down');
    expect(ai.asked.last['hintLevel'], 2);
    await settle(t, 600);

    await t.tap(find.text('Show the answer'));
    await settle(t, 600);
    expect(ai.asked.last['hintLevel'], 3);
    expect(find.text('Hint 3 of 3'), findsOneWidget);
    expect(find.text('Next hint'), findsOneWidget); // only the earlier user bubble: the chip is gone at level 3

    // A new question starts again at level 1.
    await sendFromComposer(t, 'Another question');
    expect(ai.asked.last['hintLevel'], 1);
    await end(t);
  });

  testWidgets('choices card: a tool item sends the tool with its label, a text item sends the text, a chat item opens the chat', (t) async {
    final sent = <Map<String, dynamic>>[];
    String? opened;
    const card = {
      'type': 'choices',
      'title': 'Choose a subject',
      'items': [
        {
          'label': 'Physics',
          'tool': 'quiz',
          'args': {'subject': 'Physics'},
        },
        {'label': 'Explain motion', 'text': 'Explain motion simply.'},
        {'label': 'Continue: Waves', 'chat_id': 'c7', 'icon': 'chatsCircle'},
      ],
    };
    await t.pumpWidget(
      host(
        AiCardView(
          card: card,
          send: ({text, tool, args, questionId, explain = false}) => sent.add({'text': text, 'tool': tool, 'args': args}),
          check: (_, _) async => _ok,
          onOpenChat: (id) => opened = id,
        ),
      ),
    );
    await settle(t, 600);
    expect(find.text('Choose a subject'), findsOneWidget);
    await t.tap(find.text('Physics'));
    await t.tap(find.text('Explain motion'));
    await t.tap(find.text('Continue: Waves'));
    expect(sent[0], {
      'text': 'Physics',
      'tool': 'quiz',
      'args': {'subject': 'Physics'},
    });
    expect(sent[1]['text'], 'Explain motion simply.');
    expect(sent[1]['tool'], isNull);
    expect(opened, 'c7');
    await end(t);
  });

  testWidgets('choices card: a route item pushes the page', (t) async {
    await t.pumpWidget(
      routed(
        AiCardView(
          card: const {
            'type': 'choices',
            'title': 'Open a page',
            'items': [
              {'label': 'Leaderboard', 'route': '/leaderboard', 'icon': 'ranking'},
            ],
          },
          send: ({text, tool, args, questionId, explain = false}) {},
          check: (_, _) async => _ok,
        ),
      ),
    );
    await settle(t, 600);
    await t.tap(find.text('Leaderboard'));
    await settle(t, 600);
    expect(find.text('Leaderboard page'), findsOneWidget);
    await end(t);
  });

  testWidgets('open card: shows the title, subtitle and button, and the button opens the route', (t) async {
    await t.pumpWidget(
      routed(
        const OpenCard(
          card: {
            'type': 'open',
            'title': 'Leaderboard',
            'subtitle': 'See where you rank this week',
            'route': '/leaderboard',
            'icon': 'ranking',
            'button': 'Open',
          },
        ),
      ),
    );
    await settle(t, 300);
    expect(find.text('See where you rank this week'), findsOneWidget);
    await t.tap(find.text('Open'));
    await settle(t, 600);
    expect(find.text('Leaderboard page'), findsOneWidget);
    await end(t);
  });

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('test card shows the year, and the cards fit a 360 px phone in ${b.name} mode', (t) async {
      await t.pumpWidget(
        host(
          Column(
            children: [
              AiCardView(
                card: const {
                  'type': 'test',
                  'exam': 'JAMB',
                  'subject': 'Physics',
                  'year': 2004,
                  'count': 60,
                  'minutes': 54,
                  'topics': <String>[],
                  'ids': <String>[],
                },
                send: ({text, tool, args, questionId, explain = false}) {},
                check: (_, _) async => _ok,
              ),
              AiCardView(
                card: const {
                  'type': 'open',
                  'title': 'Full JAMB mock (UTME)',
                  'subtitle': 'Use of English + 3 subjects · 180 questions · 2 hours',
                  'route': 'paywall',
                  'icon': 'exam',
                  'button': 'Start mock',
                },
                send: ({text, tool, args, questionId, explain = false}) {},
                check: (_, _) async => _ok,
              ),
              AiFollowupChips(items: const ['What is the unit of force in the SI system?', 'Show me an example'], onTap: (_) {}),
            ],
          ),
          b: b,
          width: 360,
        ),
      );
      await settle(t, 800);
      expect(t.takeException(), isNull);
      expect(find.text('JAMB 2004 · Physics'), findsOneWidget);
      await end(t);
    });
  }

  testWidgets('quiz v2: one question at a time, score screen, retry only the wrong ones, more like this, explain', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final calls = <String>[];
    final sent = <Map<String, dynamic>>[];
    const card = {
      'type': 'quiz',
      'source': 'ai',
      'subject': 'Physics',
      'topic': 'Motion',
      'questions': [
        {
          'id': 'q1',
          'body': 'What is speed?',
          'options': {'A': 'Distance over time', 'B': 'Mass'},
        },
        {
          'id': 'q2',
          'body': 'What is mass?',
          'options': {'A': 'Matter amount', 'B': 'Colour'},
        },
      ],
    };
    await t.pumpWidget(
      host(
        AiCardView(
          card: card,
          send: ({text, tool, args, questionId, explain = false}) => sent.add({'text': text, 'tool': tool, 'args': args, 'questionId': questionId}),
          check: (id, choice) async {
            calls.add('$id:$choice');
            // q1 right the first time; q2 is wrong on the first try (B) and right on the retry (A).
            final right = id == 'q1' ? 'A' : 'A';
            return {'ok': true, 'correct': choice == right, 'answer': right, 'explanation': 'Because $right.'};
          },
        ),
      ),
    );
    await settle(t);
    expect(find.text('AI-written'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.textContaining('What is speed'), findsWidgets);
    expect(find.textContaining('What is mass'), findsNothing);

    await t.tap(find.textContaining('Distance over time'));
    await settle(t);
    expect(find.text('Correct!'), findsOneWidget);
    await t.tap(find.text('Explain with AI'));
    expect(sent.last['text'], startsWith('Explain this question: What is speed'));
    await t.tap(find.text('Next'));
    await settle(t);
    expect(find.text('2 of 2'), findsOneWidget);

    await t.tap(find.textContaining('Colour'));
    await settle(t);
    expect(find.text('The answer is A'), findsOneWidget);
    await t.tap(find.text('See my score'));
    await settle(t, 1600);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    await t.tap(find.text('Try the wrong ones again'));
    await settle(t);
    expect(find.text('1 of 1'), findsOneWidget);
    expect(find.textContaining('What is mass'), findsWidgets);
    await t.tap(find.textContaining('Matter amount'));
    await settle(t);
    expect(calls, ['q1:A', 'q2:B', 'q2:A']);
    await t.tap(find.text('See my score'));
    await settle(t, 1600);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Try the wrong ones again'), findsNothing);

    await t.tap(find.text('More like this'));
    expect(sent.last['tool'], 'ai_quiz');
    expect(sent.last['args'], {'subject': 'Physics', 'topic': 'Motion', 'count': 5});
    await end(t);
  });

  testWidgets('quiz v2: a past-question quiz says so and explains by question id', (t) async {
    final sent = <Map<String, dynamic>>[];
    await t.pumpWidget(
      host(
        AiCardView(
          card: const {
            'type': 'quiz',
            'source': 'past',
            'subject': 'Physics',
            'questions': [
              {
                'id': 'q1',
                'body': 'What is speed?',
                'options': {'A': 'Distance over time', 'B': 'Mass'},
              },
            ],
          },
          send: ({text, tool, args, questionId, explain = false}) => sent.add({'questionId': questionId, 'explain': explain}),
          check: (id, choice) async => {'ok': true, 'correct': false, 'answer': 'A', 'explanation': 'Speed is distance over time.'},
        ),
      ),
    );
    await settle(t);
    expect(find.text('Real past question'), findsOneWidget);
    await t.tap(find.textContaining('Mass'));
    await settle(t);
    await t.tap(find.text('Explain with AI'));
    expect(sent.single, {'questionId': 'q1', 'explain': true});
    await end(t);
  });

  testWidgets('follow-ups: "What next?" chips show under the reply and tapping one sends it', (t) async {
    final ai = FakeAi()
      ..script = (i) => i == 0
          ? [
              AiStart('c1'),
              AiDelta('Speed is how fast something moves, and it is a long answer.'),
              AiDone(messageId: 'm1'),
              AiFollowups(['Why is that?', 'Show me an example', 'What about heat?']),
            ]
          : [AiStart('c1'), AiDelta('Sure.'), AiDone(messageId: 'm2')];
    await chat(t, ai);
    await t.tap(find.text('Ask it'));
    await settle(t, 1000);
    expect(find.text('What next?'), findsOneWidget);
    expect(find.text('Why is that?'), findsOneWidget);
    await t.tap(find.text('Show me an example'));
    await settle(t, 600);
    expect(ai.asked.last['text'], 'Show me an example');
    await end(t);
  });

  testWidgets('reaction: long-press opens the bar, a tap saves it, the badge shows, tapping the badge removes it', (t) async {
    final ai = FakeAi()..script = (_) => [AiStart('c1'), AiDelta('Speed is distance over time.'), AiDone(messageId: 'm1')];
    await chat(t, ai);
    await t.tap(find.text('Ask it'));
    await settle(t, 600);
    await t.longPress(find.textContaining('distance over time', findRichText: true));
    await settle(t, 600);
    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Copy'), findsWidgets);
    await t.tap(find.text('👍'));
    await settle(t, 600);
    expect(ai.reacted, [('m1', '👍')]);
    expect(find.text('👍'), findsOneWidget);
    await t.tap(find.text('👍'));
    await settle(t, 600);
    expect(ai.reacted.last, ('m1', null));
    expect(find.text('👍'), findsNothing);
    await end(t);
  });

  testWidgets('reply: the quote bar shows above the composer, the sent text carries the quote and the bubble draws it', (t) async {
    final ai = FakeAi()..script = (i) => [AiStart('c1'), AiDelta(i == 0 ? 'Speed is distance over time.' : 'Ok.'), AiDone(messageId: 'm$i')];
    await chat(t, ai);
    await t.tap(find.text('Ask it'));
    await settle(t, 600);
    await t.longPress(find.textContaining('distance over time', findRichText: true));
    await settle(t, 600);
    await t.tap(find.text('Reply'));
    await settle(t, 400);
    expect(find.text('Speed is distance over time.'), findsNWidgets(2)); // the reply and the quote bar
    expect(find.byTooltip('Cancel reply'), findsOneWidget);
    await sendFromComposer(t, 'Give an example');
    expect(ai.asked.last['text'], '> Speed is distance over time.\n\nGive an example');
    await settle(t, 600);
    expect(find.text('Give an example'), findsOneWidget);
    expect(find.byTooltip('Cancel reply'), findsNothing);
    await end(t);
  });

  testWidgets('steps: the current step spins, done steps tick one by one, and finishing ticks the rest', (t) async {
    Widget card({bool finishing = false}) => host(
      AiWorkingCard(
        name: 'quiz',
        label: 'Picking quiz questions…',
        steps: const ['Reading your request', 'Picking questions', 'Quiz ready'],
        finishing: finishing,
      ),
    );
    final tick = find.byIcon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
    await t.pumpWidget(card());
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tick, findsNothing);
    await t.pump(const Duration(milliseconds: 1150));
    expect(tick, findsOneWidget);
    await t.pump(const Duration(milliseconds: 1150));
    expect(tick, findsNWidgets(2));
    await t.pumpWidget(card(finishing: true));
    await t.pump(const Duration(milliseconds: 100));
    expect(tick, findsNWidgets(3));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await end(t);
  });

  testWidgets('welcome: the greeting types in, the suggestion with a chat id opens that chat, reduce motion keeps it still', (t) async {
    final ai = FakeAi()..saved = [];
    await chat(
      t,
      ai,
      chips: const [AiChip('Continue: Waves', chatId: 'c5', icon: 'chatsCircle')],
    );
    expect(find.text('Hi Ada, what are we solving today?'), findsWidgets);
    expect(find.text('Continue: Waves'), findsOneWidget);
    await t.tap(find.text('Continue: Waves'));
    await settle(t, 600);
    expect(ai.messagesCalls, 1);
    expect(ai.asked, isEmpty);
    await end(t);
  });

  // ---------------------------------------------------------------- study plan, Home today card, deep link
  const planCard = {
    'type': 'plan',
    'plan_id': 'p1',
    'title': 'My JAMB week',
    'starts_on': '2026-11-07',
    'reminders': true,
    'days': [
      {
        'day': 1,
        'focus': 'Physics · Motion',
        'tasks': ['Read the note', 'Do 5 questions'],
        'minutes': 30,
      },
      {
        'day': 2,
        'focus': 'Maths · Angles',
        'tasks': ['Watch a video', 'Quiz yourself'],
        'minutes': 45,
        'action': {
          'tool': 'quiz',
          'args': {'subject': 'Mathematics', 'topic': 'Angles'},
          'label': 'Quiz me on Angles',
        },
      },
      {
        'day': 3,
        'focus': 'English · Lexis',
        'tasks': ['Learn 10 words'],
        'minutes': 20,
      },
    ],
  };

  testWidgets('plan card: today is selected, day chips switch the day, the action sends its tool, reminders and Mark today done save', (t) async {
    final ai = FakeAi();
    final sent = <Map<String, dynamic>>[];
    await t.pumpWidget(
      ProviderScope(
        overrides: [aiRepoProvider.overrideWithValue(ai)],
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlanCard(
                card: planCard,
                today: DateTime(2026, 11, 8),
                send: ({text, tool, args, questionId, explain = false}) => sent.add({'text': text, 'tool': tool, 'args': args}),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(t);
    expect(find.text('My JAMB week'), findsOneWidget);
    expect(find.text('Maths · Angles'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    await t.tap(find.text('Quiz me on Angles'));
    expect(sent.single, {
      'text': 'Quiz me on Angles',
      'tool': 'quiz',
      'args': {'subject': 'Mathematics', 'topic': 'Angles'},
    });
    await t.tap(find.text('1').first);
    await settle(t);
    expect(find.text('Physics · Motion'), findsOneWidget);
    await t.tap(find.text('Read the note'));
    await t.pump();
    expect(find.byIcon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)), findsWidgets);

    await t.ensureVisible(find.byType(AppSwitch));
    await t.tap(find.byType(AppSwitch));
    await settle(t, 200);
    expect(ai.plans.last, {'plan': 'p1', 'day': null, 'reminders': false});
    await t.ensureVisible(find.text('Mark today done'));
    await t.tap(find.text('Mark today done'));
    await settle(t, 200);
    expect(ai.plans.last, {'plan': 'p1', 'day': 2, 'reminders': null});
    expect(find.text('Today is done'), findsOneWidget);
    await end(t);
  });

  testWidgets('plan card: an old plan reply without days keeps the small header pill', (t) async {
    await t.pumpWidget(host(AiCardView(card: const {'type': 'plan'}, send: ({text, tool, args, questionId, explain = false}) {}, check: (_, _) async => _ok)));
    await settle(t, 300);
    expect(find.text('Your 7-day plan'), findsOneWidget);
    await end(t);
  });

  Widget homeHost(FakeAi ai, Map<String, dynamic>? plan, List<String> visited, {Brightness b = Brightness.light}) => ProviderScope(
    overrides: [aiRepoProvider.overrideWithValue(ai), todayPlanProvider.overrideWith((_) async => plan)],
    child: MaterialApp.router(
      theme: buildTheme(b),
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: SingleChildScrollView(child: TodayPlan())),
          ),
          GoRoute(
            path: '/ai',
            builder: (_, s) {
              visited.add(s.uri.toString());
              return const Scaffold(body: Text('AI page'));
            },
          ),
        ],
      ),
    ),
  );

  const todayPlan = {
    'plan_id': 'p1',
    'title': 'My JAMB week',
    'day': 2,
    'of': 7,
    'done': false,
    'reminders': true,
    'item': {
      'focus': 'Maths · Angles',
      'tasks': ['Watch a video', 'Do 5 questions', 'Quiz yourself', 'A fourth task'],
      'minutes': 45,
      'action': {
        'tool': 'quiz',
        'args': {'subject': 'Mathematics', 'topic': 'Angles'},
        'label': 'Quiz me on Angles',
      },
    },
  };

  testWidgets('home today plan: shows day, focus and 3 tasks; Start opens the AI deep link; Done ticks the day', (t) async {
    final ai = FakeAi();
    final visited = <String>[];
    await t.pumpWidget(homeHost(ai, todayPlan, visited, b: Brightness.dark));
    await settle(t);
    expect(find.text('Day 2 of 7 · Maths · Angles'), findsOneWidget);
    expect(find.text('Watch a video'), findsOneWidget);
    expect(find.text('A fourth task'), findsNothing);
    await t.tap(find.text('Done ✓'));
    await settle(t, 600);
    expect(ai.plans.single, {'plan': 'p1', 'day': 2, 'reminders': null});
    expect(find.text('Day 2 done. Well done!'), findsOneWidget);
    await end(t);
    // A fresh card: Start opens /ai with the tool, label and args.
    await t.pumpWidget(homeHost(ai, todayPlan, visited));
    await settle(t);
    await t.tap(find.text('Start'));
    await settle(t, 600);
    final uri = Uri.parse(visited.last);
    expect(uri.queryParameters['tool'], 'quiz');
    expect(uri.queryParameters['label'], 'Quiz me on Angles');
    expect(AiScreen.parseArgs(uri.queryParameters['args']), {'subject': 'Mathematics', 'topic': 'Angles'});
    await end(t);
  });

  testWidgets('home today plan: nothing shows without a plan, and Start without an action opens /ai', (t) async {
    final ai = FakeAi();
    final visited = <String>[];
    await t.pumpWidget(homeHost(ai, null, visited));
    await settle(t);
    expect(find.textContaining('Day '), findsNothing);
    await end(t);
    final noAction = {
      ...todayPlan,
      'item': {'focus': 'Rest', 'tasks': <String>[], 'minutes': 0},
    };
    await t.pumpWidget(homeHost(ai, noAction, visited));
    await settle(t);
    await t.tap(find.text('Start'));
    await settle(t, 600);
    expect(visited.last, '/ai');
    await end(t);
  });

  testWidgets('deep link: /ai?tool=... sends that chip once, with the label as its text', (t) async {
    final ai = FakeAi()..script = ((_) => [AiStart('c1'), AiDelta('Here you go.'), AiDone(messageId: 'm1')]);
    const screen = AiScreen(tool: 'quiz', toolArgs: {'subject': 'Mathematics', 'topic': 'Angles'}, questionLabel: 'Quiz me on Angles');
    await chat(t, ai, screen: screen);
    await settle(t, 600);
    expect(ai.asked, hasLength(1));
    expect(ai.asked.single['tool'], 'quiz');
    expect(ai.asked.single['text'], 'Quiz me on Angles');
    expect(ai.asked.single['args'], {'subject': 'Mathematics', 'topic': 'Angles'});
    // Rebuilding with the same link does not send again.
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          aiRepoProvider.overrideWithValue(ai),
          aiQuotaProvider.overrideWith((_) async => {'used': 1, 'limit': 5, 'left': 4}),
          profileProvider.overrideWith((_) async => {'full_name': 'Ada Obi'}),
          subjectsProvider.overrideWith((_) async => <Map<String, dynamic>>[]),
          aiSuggestionsProvider.overrideWith((_) async => const <AiChip>[]),
        ],
        child: MaterialApp(theme: buildTheme(Brightness.light), home: screen),
      ),
    );
    await settle(t, 600);
    expect(ai.asked, hasLength(1));
    expect(AiScreen.parseArgs('{"a":1}'), {'a': 1});
    expect(AiScreen.parseArgs('nope'), isNull);
    await end(t);
  });
}
