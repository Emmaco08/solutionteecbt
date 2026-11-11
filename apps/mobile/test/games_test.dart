import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/games/games.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

// Games (C14, D-150).
Widget _app({List<Map<String, dynamic>> arenas = const [], List<Map<String, dynamic>> mine = const []}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    arenasProvider.overrideWith((_) async => arenas),
    gamesMineProvider.overrideWith((_) async => mine),
    subjectsProvider.overrideWith(
      (_) async => [
        {'id': 1, 'code': 'ENG', 'name': 'Use of English', 'sort': 1},
        {'id': 3, 'code': 'PHY', 'name': 'Physics', 'sort': 3},
      ],
    ),
  ],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: const GamesScreen()),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 14; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  test('game outcome lines', () {
    expect(gameOutcome({'finished': false}), 'Not finished');
    expect(gameOutcome({'finished': true, 'opp': null}), 'Waiting for a friend');
    expect(
      gameOutcome({
        'finished': true,
        'won': null,
        'opp': {'name': 'Ada'},
      }),
      'Waiting for Ada',
    );
    expect(
      gameOutcome({
        'finished': true,
        'won': true,
        'draw': false,
        'opp': {'name': 'Bot'},
      }),
      'You won',
    );
    expect(
      gameOutcome({
        'finished': true,
        'won': false,
        'draw': true,
        'opp': {'name': 'Bot'},
      }),
      'Draw',
    );
    expect(gameError('too_many'), contains('tomorrow'));
  });

  testWidgets('games hub shows the modes, a friend duel and the empty arena state', (t) async {
    t.view.physicalSize = const Size(1200, 4200);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app());
    await _settle(t);
    expect(find.text('Speed Quiz Duel'), findsOneWidget);
    expect(find.text('Beat the AI Tutor'), findsOneWidget);
    expect(find.text('Duel a friend'), findsOneWidget);
    expect(find.text('Join with a code'), findsOneWidget);
    expect(find.textContaining('No arena is planned yet'), findsOneWidget);
  });

  testWidgets('arenas and recent games are listed', (t) async {
    t.view.physicalSize = const Size(1200, 4200);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final start = DateTime.now().add(const Duration(hours: 2));
    await t.pumpWidget(
      _app(
        arenas: [
          {
            'id': 'a1',
            'title': 'Friday JAMB English Arena',
            'subject_id': 1,
            'starts_at': start.toUtc().toIso8601String(),
            'ends_at': start.add(const Duration(minutes: 9)).toUtc().toIso8601String(),
            'players': 12,
            'max_players': 50,
            'joined': true,
          },
        ],
        mine: [
          {
            'id': 'g1',
            'mode': 'duel_ai',
            'subject_id': 3,
            'result': {
              'finished': true,
              'won': true,
              'draw': false,
              'score': 820,
              'opp': {'name': 'SolutionTee Bot'},
            },
          },
        ],
      ),
    );
    await _settle(t);
    expect(find.text('Friday JAMB English Arena'), findsOneWidget);
    expect(find.text('Joined'), findsOneWidget);
    expect(find.textContaining('12/50 players'), findsOneWidget);
    expect(find.text('Physics vs SolutionTee Bot'), findsOneWidget);
    expect(find.text('You won · 820 points'), findsOneWidget);
  });
}
