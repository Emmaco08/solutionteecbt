import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/home/qotd_card.dart';
import 'package:solutiontee_cbt/features/test/leaderboard_screen.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

/// Plays the server: the answer only comes back after answering (milestone 4E1).
class FakeQotd extends QotdNotifier {
  final List<String> sent = [];
  static Map<String, dynamic> question = {
    'id': '11111111-1111-4111-8111-111111111111',
    'body': 'What is 5 minus 3?',
    'options': {'A': '1', 'B': '2', 'C': '3', 'D': '5'},
    'exam': 'JAMB',
    'subject': 'Mathematics',
    'year': 2019,
  };
  @override
  Future<Qotd?> build() async => Qotd(day: '2026-11-03', nextAt: DateTime.now().add(const Duration(hours: 3, minutes: 5)), streak: 4, question: question);
  @override
  Future<bool> answer(String choice) async {
    sent.add(choice);
    state = AsyncData(
      Qotd(
        day: '2026-11-03',
        nextAt: DateTime.now().add(const Duration(hours: 3)),
        streak: 5,
        question: question,
        result: {'choice': choice, 'correct': choice == 'B', 'answer': 'B', 'explanation': 'Because 5 - 3 = 2.', 'answers': 10, 'pct_right': 62},
      ),
    );
    return true;
  }
}

Widget app(Widget child, List overrides) => ProviderScope(
  overrides: [...overrides.cast()],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
);

void main() {
  test('countdown text', () {
    final now = DateTime(2026, 11, 3, 20, 0);
    expect(untilText(DateTime(2026, 11, 4), now: now), '4h 00m');
    expect(untilText(DateTime(2026, 11, 3, 20, 9), now: now), '0h 09m');
    expect(untilText(DateTime(2026, 11, 3, 19), now: now), '0h 00m');
  });

  testWidgets('question of the day: one try, then right/wrong, % right and the explanation', (t) async {
    final fake = FakeQotd();
    await t.pumpWidget(app(const Scaffold(body: SingleChildScrollView(child: QotdCard())), [qotdProvider.overrideWith(() => fake)]));
    await t.pumpAndSettle();
    expect(find.text('Question of the day'), findsOneWidget);
    expect(find.text('Mathematics · from JAMB 2019'), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // streak
    expect(find.textContaining('Students who got it right'), findsNothing);

    await t.tap(find.text('3'));
    await t.pumpAndSettle();
    expect(fake.sent, ['C']);
    expect(find.text('Not this time'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('Because 5 - 3 = 2.'), findsOneWidget); // open after a wrong answer

    // One try: tapping another option sends nothing.
    await t.tap(find.text('2'));
    await t.pumpAndSettle();
    expect(fake.sent, ['C']);
  });

  testWidgets('leaderboard: off message', (t) async {
    await t.pumpWidget(
      app(const LeaderboardScreen(), [
        leaderboardProvider.overrideWith((ref, k) async => {'on': false}),
      ]),
    );
    await t.pumpAndSettle();
    expect(find.text('Leaderboards are switched off'), findsOneWidget);
  });

  testWidgets('leaderboard: podium, ranks and my own rank pinned', (t) async {
    final top = [
      for (final (i, n, s) in [(1, 'Abdullahi M.', 372), (2, 'Chiamaka O.', 366), (3, 'Temi', 361), (4, 'Zainab Y.', 348), (5, 'Ebuka C.', 344)])
        {'rank': i, 'name': n, 'state': 'Lagos', 'score': s, 'me': i == 4},
    ];
    await t.pumpWidget(
      app(const LeaderboardScreen(), [
        profileProvider.overrideWith((_) async => {'full_name': 'Zainab Yusuf'}),
        leaderboardProvider.overrideWith(
          (ref, k) async => {
            'on': true,
            'seasons': [2027, 2026],
            'season': 2027,
            'current': true,
            'scope': 'ng',
            'my_state': 'Lagos',
            'min_mocks': 1,
            'top': top,
            'me': {'rank': 4, 'score': 348, 'mocks': 3, 'ahead': 13},
            'best': null,
          },
        ),
      ]),
    );
    await t.pumpAndSettle();
    expect(find.text('JAMB UTME 2027'), findsOneWidget);
    expect(find.text('Abdullahi M.'), findsOneWidget);
    expect(find.text('Zainab Y. (you)'), findsOneWidget);
    expect(find.text('13 points to reach #3'), findsOneWidget);
    expect(find.text('My state (Lagos)'), findsOneWidget);
    expect(find.text('JAMB 2026'), findsOneWidget);
  });
}
