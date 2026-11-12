import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_avatar.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_data.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_hub.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_result.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_sync.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_theme.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

// Game Zone v2 (D-157): ranks, avatars, the server clock, the hub and a live round.

int get _now => DateTime.now().millisecondsSinceEpoch;

Map<String, dynamic> _p(int id, String name, {bool me = false, int score = 0, int correct = 0, int answered = 0, int? place, int xp = 0}) => {
  'id': id,
  'me': me,
  'bot': !me,
  'name': name,
  'avatar': {'photo': null, 'preset': null},
  'team': 0,
  'score': score,
  'correct': correct,
  'answered': answered,
  'lives': 3,
  'alive': true,
  'pos': 0,
  'combo': 0,
  'place': place,
  'rating': 1000,
  'xp': xp,
};

Widget _app(Widget w, {List overrides = const [], bool reduce = false}) => ProviderScope(
  overrides: [...overrides],
  child: MaterialApp(
    theme: buildTheme(Brightness.dark),
    home: MediaQuery(
      data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduce),
      child: w,
    ),
  ),
);

void main() {
  setUp(() => GzClock.set(0));

  test('ranks: tiers, divisions and points to the next one', () {
    expect(GzRank.of(800).name, 'Bronze');
    expect(GzRank.of(1000).label, 'BRONZE II');
    final g = GzRank.of(1260);
    expect(g.name, 'Gold');
    expect(g.label, 'GOLD III');
    expect(g.next, 'GOLD II');
    expect(g.toNext, 40);
    expect(GzRank.of(1399).next, 'PLATINUM III');
    expect(GzRank.of(1700).label, 'DIAMOND');
    expect(GzRank.of(1700).toNext, 0);
  });

  test('avatar look survives a round trip and ignores bad values', () {
    const look = GzLook(hair: 'hijab', glasses: true, face: 'cool', photo: false);
    final back = GzLook.from(look.toJson());
    expect(back, look);
    final bad = GzLook.from({'hair': 'mohawk', 'skin': 'red', 'face': 'evil'});
    expect(bad.hair, 'afro');
    expect(bad.face, 'grin');
    expect(GzFace.from({'photo': '', 'has_photo': true}).photo, isNull);
  });

  test('server clock uses the quickest round trip', () {
    GzClock.sample(10000, 1000, 1200); // 200 ms trip: offset = 10000 - 1100
    final a = GzClock.now() - DateTime.now().millisecondsSinceEpoch;
    expect(a, 8900);
    GzClock.sample(50000, 1000, 3000); // slower trip is ignored
    expect(GzClock.now() - DateTime.now().millisecondsSinceEpoch, 8900);
  });

  test('numbers and errors read well', () {
    expect(gzNum(1240), '1,240');
    expect(gzNum(-1500), '-1,500');
    expect(gzErrorText('too_many'), contains('Come back tomorrow'));
    expect(gzOrdinal(2), '2ND');
    expect(gzOrdinal(11), '11TH');
  });

  testWidgets('hub shows the games, modes and the battle button', (t) async {
    final home = {
      'me': {
        'name': 'Tolu',
        'avatar': {'photo': null},
        'rating': 1240,
      },
      'games': [
        {'id': 'duel', 'on': true, 'ready': true, 'online': 12},
        {'id': 'words', 'on': false, 'ready': false, 'online': 0},
      ],
      'subjects': [
        {'id': 1, 'code': 'eng', 'name': 'English'},
        {'id': 5, 'code': 'bio', 'name': 'Biology'},
      ],
      'week': {'played': 3, 'won': 2, 'xp': 40},
      'recent': [],
    };
    await t.pumpWidget(_app(const GzHubScreen(), overrides: [gzHomeProvider.overrideWith((_) async => home)], reduce: true));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('BATTLE!'), findsOneWidget);
    expect(find.text('BIOLOGY'), findsOneWidget);
    await t.tap(find.text('VS AI'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('PRACTISE'), findsOneWidget);
    expect(find.text('HARD'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a live round shows the question, and a picked answer locks the others', (t) async {
    final s = {
      'id': 'm1',
      'game': 'duel',
      'mode': 'quick',
      'status': 'playing',
      'starts_at': _now - 30000,
      'ends_at': _now + 60000,
      'seconds': 15,
      'rounds': 10,
      'players': [_p(1, 'Tolu', me: true), _p(2, 'Kemi')],
      'me': _p(1, 'Tolu', me: true),
      'round': {
        'idx': 2,
        'open_at': _now - 2000,
        'close_at': _now + 13000,
        'item': {
          'body': 'Which organelle makes energy?',
          'options': [
            {'key': 'A', 'text': 'Ribosome'},
            {'key': 'B', 'text': 'Mitochondrion'},
          ],
        },
        'mine': {'choice': 'A', 'correct': false, 'points': 0, 'key': 'B'},
      },
    };
    final m = GzMatch('m1')..s = s;
    await t.pumpWidget(
      _app(
        Scaffold(
          body: GzSyncPlay(m: m, onLeave: () {}),
        ),
        reduce: true,
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Which organelle makes energy?'), findsOneWidget);
    expect(find.textContaining('ROUND 3'), findsOneWidget);
    // Answered: every option is locked (no second answer).
    final buttons = t.widgetList<GameButton>(find.byType(GameButton)).where((b) => b.semantics?.startsWith('Option') ?? false);
    expect(buttons.length, 2);
    expect(buttons.every((b) => b.onTap == null), isTrue);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  test('results: stars follow accuracy, places and XP', () {
    final v = GzMatchView({
      'id': 'm',
      'game': 'duel',
      'mode': 'ranked',
      'me': {..._p(1, 'Tolu', me: true, correct: 9, answered: 10, place: 1, xp: 35), 'rating_delta': 18},
      'players': [_p(1, 'Tolu', me: true, place: 1), _p(2, 'Kemi', place: 2)],
      'review': [],
    });
    expect(v.stars, 3);
    expect(v.myPlace, 1);
    expect(v.xp, 35);
    expect(v.ratingDelta, 18);
    expect(v.draw, isFalse);
  });
}
