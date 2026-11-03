import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:solutiontee_cbt/features/compete/challenge_play.dart';
import 'package:solutiontee_cbt/features/compete/challenges_screens.dart';
import 'package:solutiontee_cbt/features/compete/compete_data.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

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
}

Challenge sample({String status = 'live', Map<String, dynamic>? mine}) => Challenge({
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
});

Widget app(String initial, FakeApi api, {Challenge? ch}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/challenges', builder: (_, _) => const Scaffold(body: Text('LIST'))),
      GoRoute(path: '/challenges/:id', builder: (_, s) => ChallengeScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/challenges/:id/play', builder: (_, s) => ChallengePlayScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/challenges/:id/result', builder: (_, _) => const Scaffold(body: Text('RESULT'))),
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
    await t.pumpWidget(app('/challenges/c1', api));
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
}
