import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:solutiontee_cbt/core/nav.dart';
import 'package:solutiontee_cbt/core/secure_screen.dart';
import 'package:solutiontee_cbt/features/compete/challenge_play.dart';
import 'package:solutiontee_cbt/features/compete/challenges_screens.dart';
import 'package:solutiontee_cbt/features/compete/compete_data.dart';
import 'package:solutiontee_cbt/features/compete/results_screens.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:solutiontee_cbt/ui/kit.dart';

/// Plays the server: two questions, answers checked "on the server", exits reported.
class FakeApi implements ChallengeApi {
  final answers = <String?>[];
  final exits = <String>[];
  int i = 0;
  Map<String, dynamic> q(int n) => {
    'entry_id': 'e1',
    'index': n,
    'total': 2,
    'question_id': 'q$n',
    'body': 'Question number ${n + 1}?',
    'options': [
      {'key': 'B', 'text': 'Option bee'},
      {'key': 'A', 'text': 'Option ay'},
      {'key': 'C', 'text': 'Option see'},
      {'key': 'D', 'text': 'Option dee'},
    ],
    'seconds': 20,
    'allowed_exits': 0,
    'exits': 0,
  };
  @override
  Future<Map<String, dynamic>> start(String id, String? device, List<String> flags) async => {'status': 'playing', 'question': q(0)};
  @override
  Future<Map<String, dynamic>> answer(String entryId, String questionId, String? choice) async {
    answers.add(choice);
    i++;
    return i >= 2 ? {'status': 'finished'} : {'status': 'playing', 'question': q(i)};
  }

  @override
  Future<Map<String, dynamic>> exit(String entryId, String reason) async {
    exits.add(reason);
    return {'status': 'disqualified'};
  }

  final reports = <String>[];
  @override
  Future<void> report(String entryId, String what) async => reports.add(what);
}

Challenge sample({String status = 'live', Map<String, dynamic>? mine, Map<String, dynamic> extra = const {}}) => Challenge({
  'id': 'c1',
  'title': 'Weekly Challenge #1',
  'subtitle': 'Mixed JAMB subjects',
  'kind': 'cash',
  'icon': 'trophy',
  'status': status,
  'starts_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
  'ends_at': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
  'questions': 2,
  'seconds': 20,
  'prizes': [20000, 10000, 5000],
  'joined': 12,
  'allowed_exits': 0,
  'mine': mine,
  ...extra,
});

Widget app(String initial, FakeApi api, {Challenge? ch}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/test/challenges',
        builder: (_, _) => const Scaffold(body: Text('LIST')),
      ),
      GoRoute(
        path: '/test/challenges/:id',
        builder: (_, s) => ChallengeScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/challenges/:id/play',
        builder: (_, s) => ChallengePlayScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/test/challenges/:id/result',
        builder: (_, _) => const Scaffold(body: Text('RESULT')),
      ),
      GoRoute(
        path: '/test/challenges/:id/appeal',
        builder: (_, _) => const Scaffold(body: Text('APPEAL')),
      ),
      GoRoute(
        path: '/subjects',
        builder: (_, _) => const Scaffold(body: Text('SUBJECTS')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      challengeApiProvider.overrideWithValue(api),
      challengeProvider.overrideWith((ref, id) async => ch ?? sample()),
      challengesProvider.overrideWith((ref) async => {'on': true, 'items': [], 'past': []}),
    ],
    child: MaterialApp.router(theme: buildTheme(Brightness.light), routerConfig: router),
  );
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(DeviceCheck.ch, (call) async => call.method == 'id' ? 'android-id-1' : <Object?>[]);
    m.setMockMethodCallHandler(const MethodChannel('solutiontee/secure'), (call) async => null);
  });

  test('money and time labels', () {
    expect(nairaWhole(20000), '₦20,000');
    expect(nairaWhole(1250000), '₦1,250,000');
    expect(mmss(192000), '3:12');
    final now = DateTime(2026, 11, 3, 12);
    expect(untilShort(DateTime(2026, 11, 3, 14, 5), now: now), '2h 05m');
    expect(untilShort(DateTime(2026, 11, 5, 16), now: now), '2d 4h');
    expect(untilShort(DateTime(2026, 11, 3, 12, 9), now: now), '9m');
  });

  testWidgets('details: prizes, fair-play rules, and Start needs the agreement', (t) async {
    final api = FakeApi();
    await t.pumpWidget(app('/test/challenges/c1', api));
    await settle(t);
    expect(find.text('Weekly Challenge #1'), findsOneWidget);
    expect(find.text('₦20,000'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Stay on the challenge screen'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Stay on the challenge screen'), findsOneWidget);
    await t.tap(find.text('Start challenge'));
    await settle(t);
    expect(find.text('Tick the fair-play box first.'), findsOneWidget);
    expect(find.text('Question number 1?', findRichText: true), findsNothing);
  });

  testWidgets('play: one question at a time, answers go to the server, then the result', (t) async {
    final api = FakeApi();
    await t.pumpWidget(app('/challenges/c1/play', api));
    await settle(t);
    expect(find.text('Question number 1?', findRichText: true), findsOneWidget);
    expect(find.text('Fair play on'), findsOneWidget);
    await t.tap(find.text('Option bee', findRichText: true));
    await settle(t);
    expect(api.answers, ['B']);
    expect(find.text('Question number 2?', findRichText: true), findsOneWidget);
    await t.tap(find.text('Option dee', findRichText: true));
    await settle(t);
    expect(api.answers, ['B', 'D']);
    expect(find.text('RESULT'), findsOneWidget);
  });

  testWidgets('play: leaving the app is reported and disqualifies', (t) async {
    final api = FakeApi();
    await t.pumpWidget(app('/challenges/c1/play', api));
    await settle(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await settle(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(api.exits.length, 1);
    expect(find.text('Entry disqualified'), findsOneWidget);
  });

  testWidgets('play: when the timer runs out, no answer is sent for that question', (t) async {
    final api = FakeApi();
    await t.pumpWidget(app('/challenges/c1/play', api));
    await settle(t);
    await t.pump(const Duration(seconds: 21));
    await settle(t);
    expect(api.answers, [null]);
    expect(find.text('Question number 2?', findRichText: true), findsOneWidget);
  });

  testWidgets('weekly mixed: says the questions come from your JAMB subjects, with the same level mix for all', (t) async {
    final api = FakeApi();
    final ch = sample(
      extra: {
        'mode': 'mixed',
        'per_level': {'easy': 3, 'medium': 3, 'hard': 3, 'very_hard': 1},
        'eligible': true,
      },
    );
    await t.pumpWidget(app('/test/challenges/c1', api, ch: ch));
    await settle(t);
    expect(find.text('Your JAMB subjects'), findsOneWidget);
    expect(find.text('Questions from your 4 JAMB subjects, mixed.'), findsOneWidget);
    expect(find.textContaining('From each subject: 3 easy, 3 medium, 3 hard, 1 very hard'), findsOneWidget);
    expect(find.text('Start challenge'), findsOneWidget);
  });

  testWidgets('subject challenge for another subject: no Start, and it says why', (t) async {
    final api = FakeApi();
    final ch = sample(
      extra: {
        'mode': 'subject',
        'subject': 'Biology',
        'per_level': {'easy': 5},
        'eligible': false,
      },
    );
    await t.pumpWidget(app('/test/challenges/c1', api, ch: ch));
    await settle(t);
    expect(find.text('Biology'), findsOneWidget);
    expect(find.textContaining('only for students who take Biology'), findsOneWidget);
    expect(find.text('Start challenge'), findsNothing);
    expect(find.text('Not one of your subjects'), findsOneWidget);
  });

  testWidgets('no JAMB subjects yet: the weekly challenge asks the student to choose them', (t) async {
    final api = FakeApi();
    final ch = sample(
      extra: {
        'mode': 'mixed',
        'per_level': {'easy': 2},
        'eligible': false,
      },
    );
    await t.pumpWidget(app('/test/challenges/c1', api, ch: ch));
    await settle(t);
    await t.tap(find.text('Choose my JAMB subjects'));
    await settle(t);
    expect(find.text('SUBJECTS'), findsOneWidget);
  });

  testWidgets('disqualified: the student can send an appeal', (t) async {
    final api = FakeApi();
    await t.pumpWidget(app('/challenges/c1/play', api));
    await settle(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await settle(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    await t.scrollUntilVisible(find.text('Send an appeal'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Send an appeal'));
    await settle(t);
    expect(find.text('APPEAL'), findsOneWidget);
  });

  test('challenge screens open inside the tabs; old links still work', () {
    expect(tabRoute('/challenges'), '/test/challenges');
    expect(tabRoute('/challenges/abc'), '/test/challenges/abc');
    expect(tabRoute('/challenges/abc/result'), '/test/challenges/abc/result');
    expect(tabRoute('/challenges/abc/play'), '/challenges/abc/play');
    expect(tabRoute('/winnings'), '/me/winnings');
    expect(tabOf('/test/challenges/abc/result'), '/test');
    expect(tabOf('/me/winnings'), '/me');
    expect(tabOf('/home'), '/home');
    expect(tabOf('/test/setup'), isNull);
    expect(tabOf('/challenges/abc/play'), isNull);
    expect(tabOf('/notifications'), isNull);
  });

  testWidgets('same questions: the details say everyone gets the same questions', (t) async {
    final api = FakeApi();
    final ch = sample(
      extra: {
        'mode': 'subject',
        'subject': 'Physics',
        'per_level': {'easy': 2},
        'eligible': true,
        'same_questions': true,
      },
    );
    await t.pumpWidget(app('/test/challenges/c1', api, ch: ch));
    await settle(t);
    expect(find.textContaining('Everyone gets the same questions'), findsOneWidget);
    expect(find.textContaining('Every student gets the same mix.'), findsOneWidget);
  });

  testWidgets('after the end: review shows the right answer, the student\'s choice and the explanation', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          challengeReviewProvider.overrideWith(
            (ref, id) async => {
              'score': 0,
              'total': 1,
              'items': [
                {
                  'n': 1,
                  'body': 'What is two plus two?',
                  'options': {'A': 'Three', 'B': 'Four', 'C': 'Five', 'D': 'Six'},
                  'answer': 'B',
                  'choice': 'C',
                  'correct': false,
                  'subject': 'Mathematics',
                  'level': 'very_hard',
                  'explanation': 'Add them: four.',
                },
              ],
            },
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const ChallengeReviewScreen(id: 'c1'),
        ),
      ),
    );
    await settle(t);
    expect(find.text('0/1 right'), findsOneWidget);
    expect(find.text('Wrong'), findsOneWidget);
    expect(find.text('Mathematics · Very hard'), findsOneWidget);
    expect(find.text('Add them: four.', findRichText: true), findsOneWidget);
  });

  testWidgets('play: a screenshot attempt is reported for the fair-play review and the student is told', (t) async {
    final api = FakeApi();
    await t.pumpWidget(app('/challenges/c1/play', api));
    await settle(t);
    DeviceEvents.debugSend('screenshot');
    await settle(t);
    expect(api.reports, ['screenshot']);
    expect(find.textContaining('Screenshots are not allowed in challenges'), findsOneWidget);
    expect(api.exits, isEmpty);
  });

  test('the app-wide screenshot message stays quiet where a screen has its own', () {
    expect(DeviceEvents.ownMessage('/cbt/abc'), isTrue);
    expect(DeviceEvents.ownMessage('/challenges/abc/play'), isTrue);
    expect(DeviceEvents.ownMessage('/test/challenges/abc/review'), isTrue);
    expect(DeviceEvents.ownMessage('/home'), isFalse);
    expect(DeviceEvents.ownMessage('/test/challenges/abc/result'), isFalse);
  });

  testWidgets('an XP entry fee is shown and confirmed before the challenge starts (earned XP only for cash prizes)', (t) async {
    final api = FakeApi();
    await t.pumpWidget(app('/test/challenges/c1', api, ch: sample(extra: {'xp_fee': 100, 'xp_earned_only': true})));
    await settle(t);
    expect(find.text('100 XP'), findsOneWidget);
    await t.scrollUntilVisible(find.byType(CheckRow), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byType(CheckRow));
    await settle(t);
    await t.tap(find.text('Start challenge'));
    await settle(t);
    expect(find.text('Join for 100 XP?'), findsOneWidget);
    expect(find.textContaining('only XP you earned'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await settle(t);
    expect(find.text('Question number 1?', findRichText: true), findsNothing);
  });
}
