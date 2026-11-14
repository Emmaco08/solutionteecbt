// ignore_for_file: invalid_use_of_visible_for_testing_member
// Game Zone screenshots (D-157): renders every Game Zone screen with the real fonts at phone size so they can be
// checked by eye. Not part of `flutter test` (it lives outside test/). Run:
//   flutter test test_shots/gz_shots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_data.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_find.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_hub.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_match.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_memory.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_race.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_ranks.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_reading.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_result.dart';
import 'package:solutiontee_cbt/features/gamezone/gz_sync.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

int get _now => DateTime.now().millisecondsSinceEpoch;

Map<String, dynamic> _avatar(String skin, String hair, String shirt, {String face = 'grin', bool glasses = false, String bg = '#5887C5'}) => {
  'photo': null,
  'has_photo': false,
  'preset': {'skin': skin, 'hair': hair, 'shirt': shirt, 'hairColor': '#1A1206', 'face': face, 'glasses': glasses, 'bg': bg},
};

final _me = _avatar('#8D5524', 'afro', '#2563B3');

Map<String, dynamic> _p(
  int id,
  String name, {
  bool me = false,
  bool bot = false,
  int score = 0,
  int correct = 0,
  int answered = 0,
  Map<String, dynamic>? avatar,
  int team = 0,
  bool alive = true,
  int lives = 3,
  int pos = 0,
  int? place,
  bool cur = false,
  int? rating,
  int? delta,
  int xp = 0,
  int combo = 0,
}) => {
  'id': id,
  'me': me,
  'bot': bot,
  'name': name,
  'avatar': avatar ?? _avatar('#C68642', 'braids', '#E0335A', face: 'focus'),
  'team': team,
  'score': score,
  'correct': correct,
  'answered': answered,
  'lives': lives,
  'alive': alive,
  'pos': pos,
  'combo': combo,
  'finished': false,
  'place': place,
  'rating': rating ?? 1240,
  'rating_delta': delta,
  'xp': xp,
  'level': bot ? 'medium' : null,
  'cur': cur,
};

const _q = {
  'body': 'Which organelle is the site of aerobic respiration in a cell?',
  'options': [
    {'key': 'A', 'text': 'Ribosome'},
    {'key': 'B', 'text': 'Mitochondrion'},
    {'key': 'C', 'text': 'Golgi body'},
    {'key': 'D', 'text': 'Lysosome'},
  ],
};

Map<String, dynamic> _match(
  String game,
  List<Map<String, dynamic>> players, {
  Map<String, dynamic>? round,
  Map<String, dynamic>? last,
  Map<String, dynamic>? item,
  String status = 'playing',
  String mode = 'quick',
  int rounds = 10,
  List<Map<String, dynamic>>? review,
  List<dynamic>? levels,
  String? code,
}) {
  final me = players.firstWhere((p) => p['me'] == true);
  return {
    'id': 'm1',
    'game': game,
    'mode': mode,
    'status': status,
    'level': 'medium',
    'code': code,
    'subject': {'id': 5, 'code': 'bio', 'name': 'Biology'},
    'host': true,
    'now': _now,
    'starts_at': _now - 60000,
    'ends_at': _now + 35000,
    'lobby_until': _now + 9000,
    'seconds': 15,
    'gap_ms': 3500,
    'rounds': rounds,
    'target': 10,
    'max': players.length,
    'players': players,
    'me': {...me, 'penalty_until': null},
    'round': round,
    'last': last,
    'item': item,
    'levels': levels,
    'review': review,
  };
}

GzMatch _m(Map<String, dynamic> s) => GzMatch('m1')..s = s;

Map<String, dynamic> _leaders() => {
  'rows': [
    for (var i = 0; i < 9; i++)
      {
        'rank': i + 1,
        'name': ['Amaka', 'Chidi', 'Tolu', 'Zainab', 'Emeka', 'Fola', 'Ibrahim', 'Ngozi', 'Seyi'][i],
        'me': i == 2,
        'avatar': i == 2
            ? _me
            : _avatar(
                ['#5C3A1E', '#C68642', '#F1C27D'][i % 3],
                ['bun', 'fade', 'afro', 'hijab', 'cap', 'braids'][i % 6],
                ['#E0335A', '#1FA463', '#7A4FD6'][i % 3],
              ),
        'rating': 1720 - i * 60,
        'played': 20,
        'won': 14 - i,
      },
  ],
  'me': {'rating': 1600, 'played': 20},
};

Future<void> _shot(
  WidgetTester t,
  Widget w,
  String name, {
  Map<String, dynamic>? home,
  Map<String, dynamic>? leaders,
  Duration settle = const Duration(milliseconds: 1600),
  double height = 2532,
}) async {
  t.view.physicalSize = Size(1170, height);
  t.view.devicePixelRatio = 3;
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        if (home != null) gzHomeProvider.overrideWith((_) async => home),
        if (leaders != null) gzLeadersProvider.overrideWith((_, _) async => leaders),
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(Brightness.dark), home: w),
    ),
  );
  for (var i = 0; i < 16; i++) {
    await t.pump(Duration(milliseconds: settle.inMilliseconds ~/ 16));
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 3));
}

void main() {
  setUpAll(() async {
    await _font('LilitaOne', ['assets/fonts/LilitaOne-Regular.ttf']);
    await _font('PlusJakartaSans', ['assets/fonts/PlusJakartaSans-Medium.ttf', 'assets/fonts/PlusJakartaSans-Bold.ttf']);
    await _font('PhosphorRegular', ['assets/fonts/Phosphor-Regular.ttf']);
    await _font('PhosphorFill', ['assets/fonts/Phosphor-Fill.ttf']);
    await _font('MaterialIcons', ['/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    GzClock.set(0);
  });

  final home = {
    'me': {'name': 'Tolu', 'avatar': _me, 'rating': 1240},
    'games': [
      for (final g in ['duel', 'rush', 'survival', 'blitz', 'words', 'memory', 'relay'])
        {
          'id': g,
          'on': g != 'words',
          'ready': g != 'words',
          'online': g == 'duel' ? 128 : (g == 'rush' ? 34 : 0),
          'rating': 1240,
          'played': 4,
          'won': 3,
          'streak': 2,
        },
    ],
    'subjects': [
      {'id': 1, 'code': 'eng', 'name': 'English'},
      {'id': 5, 'code': 'bio', 'name': 'Biology'},
      {'id': 4, 'code': 'chm', 'name': 'Chemistry'},
      {'id': 3, 'code': 'phy', 'name': 'Physics'},
    ],
    'active': null,
    'week': {'played': 14, 'won': 9, 'xp': 2480},
    'recent': [
      {'id': 'a', 'game': 'duel', 'mode': 'ranked', 'place': 1, 'score': 1180, 'xp': 35, 'rating_delta': 18, 'players': 2, 'vs': 'Kemi'},
      {'id': 'b', 'game': 'survival', 'mode': 'quick', 'place': 3, 'score': 900, 'xp': 5, 'players': 12},
    ],
  };

  testWidgets('01 hub', (t) async => _shot(t, const GzHubScreen(), '01_hub', home: home, leaders: _leaders()));

  testWidgets(
    '02 finding',
    (t) async => _shot(
      t,
      const GzFindScreen(game: 'duel', mode: 'quick', autoStart: false),
      '02_find',
      home: home,
    ),
  );

  final duelPlayers = [
    _p(1, 'Tolu', me: true, score: 620, correct: 4, answered: 4, avatar: _me),
    _p(2, 'Kemi', score: 455, correct: 3, answered: 4, cur: true),
  ];

  testWidgets('03 vs', (t) async {
    final s = _match('duel', duelPlayers, mode: 'ranked');
    s['starts_at'] = _now + 3000;
    await _shot(t, Scaffold(body: GzVsIntro(m: _m(s))), '03_vs');
  });

  testWidgets('04 duel live', (t) async {
    final s = _match('duel', duelPlayers, round: {'idx': 4, 'open_at': _now - 4000, 'close_at': _now + 11000, 'item': _q, 'mine': null});
    await _shot(
      t,
      Scaffold(
        body: GzSyncPlay(m: _m(s), onLeave: () {}),
      ),
      '04_duel',
    );
  });

  testWidgets('05 duel answered', (t) async {
    final s = _match(
      'duel',
      duelPlayers,
      round: {
        'idx': 4,
        'open_at': _now - 4000,
        'close_at': _now + 11000,
        'item': _q,
        'mine': {'choice': 'B', 'correct': true, 'points': 142, 'key': 'B'},
      },
    );
    await _shot(
      t,
      Scaffold(
        body: GzSyncPlay(m: _m(s), onLeave: () {}),
      ),
      '05_duel_right',
    );
  });

  testWidgets('06 word war', (t) async {
    final s = _match(
      'words',
      [_p(1, 'Tolu', me: true, score: 410, avatar: _me), _p(2, 'Ada', bot: true, score: 290, avatar: _avatar('#F1C27D', 'bun', '#E0335A'))],
      round: {
        'idx': 3,
        'open_at': _now - 2000,
        'close_at': _now + 8000,
        'item': {
          'kind': 'antonym',
          'word': 'generous',
          'body': 'Opposite of',
          'options': [
            {'key': 'kind', 'text': 'kind'},
            {'key': 'stingy', 'text': 'stingy'},
            {'key': 'lavish', 'text': 'lavish'},
            {'key': 'gentle', 'text': 'gentle'},
          ],
        },
      },
    );
    await _shot(
      t,
      Scaffold(
        body: GzSyncPlay(m: _m(s), onLeave: () {}),
      ),
      '06_words',
    );
  });

  testWidgets('07 survival', (t) async {
    final names = ['Chidi', 'Amaka', 'Tunde', 'Zainab', 'Emeka', 'Fola', 'Ibrahim', 'Ngozi', 'Seyi', 'Halima', 'Obinna'];
    final hairs = ['afro', 'bun', 'braids', 'low', 'fade', 'puffs', 'cap', 'hijab'];
    final shirts = ['#2563B3', '#E0335A', '#1FA463', '#7A4FD6', '#22A6C4', '#F2B233'];
    final skins = ['#5C3A1E', '#8D5524', '#C68642', '#F1C27D'];
    final players = [
      _p(1, 'Tolu', me: true, lives: 2, avatar: _me),
      for (var i = 0; i < names.length; i++)
        _p(
          i + 2,
          names[i],
          bot: true,
          alive: i % 4 != 3,
          lives: i % 3 + 1,
          avatar: _avatar(skins[i % 4], hairs[i % 8], shirts[i % 6], face: i.isEven ? 'grin' : 'focus', glasses: i % 5 == 0),
        ),
    ];
    final s = _match(
      'survival',
      players,
      rounds: 20,
      round: {
        'idx': 5,
        'open_at': _now - 3000,
        'close_at': _now + 9000,
        'item': {
          'body': r'A body moving in a circle at constant speed has',
          'options': [
            {'key': 'A', 'text': 'no acceleration'},
            {'key': 'B', 'text': 'acceleration towards the centre'},
            {'key': 'C', 'text': 'acceleration along the path'},
            {'key': 'D', 'text': 'constant velocity'},
          ],
        },
      },
    );
    await _shot(
      t,
      Scaffold(
        body: GzSyncPlay(m: _m(s), onLeave: () {}),
      ),
      '07_survival',
    );
  });

  testWidgets('08 relay', (t) async {
    final players = [
      _p(1, 'Tolu', me: true, team: 1, score: 540, avatar: _me),
      _p(2, 'Ibrahim', bot: true, team: 1, score: 380, avatar: _avatar('#5C3A1E', 'low', '#1FA463', glasses: true)),
      _p(3, 'Kemi', bot: true, team: 1, score: 260),
      _p(4, 'Seyi', bot: true, team: 2, score: 470, avatar: _avatar('#C68642', 'fade', '#7A4FD6')),
      _p(5, 'Hauwa', bot: true, team: 2, score: 300, avatar: _avatar('#8D5524', 'hijab', '#22A6C4', face: 'smile')),
      _p(6, 'Dayo', bot: true, team: 2, score: 330, avatar: _avatar('#F1C27D', 'cap', '#F2B233')),
    ];
    final s = _match('relay', players, rounds: 12, round: {'idx': 6, 'open_at': _now - 5000, 'close_at': _now + 10000, 'item': _q});
    await _shot(
      t,
      Scaffold(
        body: GzSyncPlay(m: _m(s), onLeave: () {}),
      ),
      '08_relay',
    );
  });

  testWidgets('09 rush', (t) async {
    final players = [
      _p(1, 'Tolu', me: true, correct: 7, avatar: _me),
      _p(2, 'Kemi', bot: true, correct: 6),
      _p(3, 'Musa', bot: true, correct: 4),
      _p(4, 'Ada', bot: true, correct: 3),
    ];
    final s = _match('rush', players);
    s['starts_at'] = _now - 40000;
    s['ends_at'] = _now + 80000;
    final m = _m(s)
      ..raceCorrect = 7
      ..raceCombo = 3
      ..racePos = 8
      ..raceItem = {
        'body': r'The pH of a neutral solution at 25 °C is',
        'options': [
          {'key': 'A', 'text': '0'},
          {'key': 'B', 'text': '7'},
          {'key': 'C', 'text': '14'},
          {'key': 'D', 'text': '1'},
        ],
      };
    await _shot(
      t,
      Scaffold(
        body: GzRacePlay(m: m, onLeave: () {}),
      ),
      '09_rush',
    );
  });

  testWidgets('10 blitz', (t) async {
    final players = [_p(1, 'Tolu', me: true, score: 1180, avatar: _me), _p(2, 'Kemi', bot: true, score: 960)];
    final s = _match('blitz', players);
    s['starts_at'] = _now - 25000;
    s['ends_at'] = _now + 35000;
    final m = _m(s)
      ..raceScore = 1180
      ..raceCombo = 4
      ..racePos = 22
      ..raceItem = {
        'body': '15% of 240',
        'options': [
          {'key': '32', 'text': '32'},
          {'key': '36', 'text': '36'},
          {'key': '24', 'text': '24'},
          {'key': '42', 'text': '42'},
        ],
      };
    await _shot(
      t,
      Scaffold(
        body: GzRacePlay(m: m, onLeave: () {}),
      ),
      '10_blitz',
    );
  });

  testWidgets('11 memory', (t) async {
    final cards = [
      for (final (i, f) in const [('Na', 'Sodium'), ('Fe', 'Iron'), ('K', 'Potassium'), ('Mg', 'Magnesium')].indexed) ...[
        {'pair': i, 'text': f.$1},
        {'pair': i, 'text': f.$2},
      ],
    ]..shuffle();
    final players = [_p(1, 'Tolu', me: true, avatar: _me), _p(2, 'Kemi', bot: true, pos: 1)];
    final s = _match(
      'memory',
      players,
      levels: [
        {'level': 1, 'pairs': 4, 'cards': cards},
        {'level': 2, 'pairs': 5, 'cards': cards},
        {'level': 3, 'pairs': 6, 'cards': cards},
      ],
    );
    s['ends_at'] = _now + 150000;
    s['subject'] = {'id': 4, 'code': 'chm', 'name': 'Chemistry'};
    await _shot(
      t,
      Scaffold(
        body: GzMemoryPlay(m: _m(s), onLeave: () {}),
      ),
      '11_memory',
      settle: const Duration(milliseconds: 1200),
    );
  });

  testWidgets('12 victory', (t) async {
    final players = [
      _p(1, 'Tolu', me: true, score: 1180, correct: 9, answered: 10, place: 1, rating: 1240, delta: 18, xp: 35, avatar: _me),
      _p(2, 'Kemi', score: 960, correct: 7, answered: 10, place: 2),
    ];
    final review = [
      for (var i = 0; i < 10; i++)
        {'idx': i, 'item': _q, 'key': 'B', 'choice': i == 2 ? 'A' : 'B', 'correct': i != 2, 'ms': 2800, 'points': 140, 'answered': true},
    ];
    final s = _match('duel', players, status: 'done', mode: 'ranked', review: review);
    await _shot(
      t,
      Scaffold(body: GzResults(m: _m(s))),
      '12_victory',
      settle: const Duration(milliseconds: 2400),
    );
  });

  testWidgets('13 survival result', (t) async {
    final players = [
      _p(1, 'Tolu', me: true, score: 900, correct: 6, answered: 8, place: 3, xp: 5, avatar: _me),
      _p(2, 'Amaka', bot: true, score: 1500, place: 1),
      _p(3, 'Chidi', bot: true, score: 1200, place: 2),
      _p(4, 'Zainab', bot: true, score: 700, place: 4),
    ];
    final s = _match(
      'survival',
      players,
      status: 'done',
      review: [
        for (var i = 0; i < 8; i++) {'idx': i, 'item': _q, 'key': 'B', 'choice': 'B', 'correct': i % 3 != 0, 'ms': 4000, 'answered': true},
      ],
    );
    await _shot(
      t,
      Scaffold(body: GzResults(m: _m(s))),
      '13_result_group',
      settle: const Duration(milliseconds: 2000),
    );
  });

  testWidgets('14 lobby', (t) async {
    final s = _match(
      'duel',
      [_p(1, 'Tolu', me: true, avatar: _me)],
      status: 'lobby',
      mode: 'friend',
      code: 'K7QX2M',
    );
    s['max'] = 2;
    await _shot(
      t,
      Scaffold(
        body: SafeArea(
          child: GzLobbyView(m: _m(s), onShare: () {}, onStart: () {}, onLeave: () {}),
        ),
      ),
      '14_lobby',
    );
  });

  testWidgets('15 ranks', (t) async {
    final leaders = _leaders();
    await _shot(t, const GzRanksScreen(), '15_ranks', leaders: leaders);
  });

  testWidgets('16 reveal', (t) async {
    final players = [_p(1, 'Tolu', me: true, score: 604, correct: 6, answered: 9, avatar: _me), _p(2, 'Akinbola', score: 212, correct: 2, answered: 9)];
    final s = _match(
      'duel',
      players,
      round: {'idx': 9, 'open_at': _now + 2600, 'close_at': _now + 17600, 'item': null, 'mine': null},
      last: {
        'idx': 8,
        'key': 'B',
        'item': {
          'body': r'Choose the option nearest in meaning to the underlined words: He took a $\underline{\text{quick look}}$ at the poor man',
          'options': [
            {'key': 'A', 'text': 'Gazed at'},
            {'key': 'B', 'text': 'Glanced at'},
            {'key': 'C', 'text': 'Viewed'},
            {'key': 'D', 'text': 'Observed'},
          ],
        },
        'results': [
          {'p': 1, 'correct': true, 'points': 138, 'ms': 3100},
          {'p': 2, 'correct': false, 'points': 0, 'ms': 9000},
        ],
      },
    );
    await _shot(
      t,
      Scaffold(
        body: GzSyncPlay(m: _m(s), onLeave: () {}),
      ),
      '16_reveal',
    );
  });

  testWidgets('17 underline', (t) async {
    final s = _match(
      'duel',
      duelPlayers,
      round: {
        'idx': 5,
        'open_at': _now - 4000,
        'close_at': _now + 11000,
        'item': {
          'body': r'Choose the option nearest in meaning to the underlined words: He took a $\underline{\text{quick look}}$ at the poor man, shook his head and took to his heels',
          'options': [
            {'key': 'A', 'text': 'Gazed at'},
            {'key': 'B', 'text': 'Glanced at'},
            {'key': 'C', 'text': 'Viewed'},
            {'key': 'D', 'text': 'Observed'},
          ],
        },
        'mine': null,
      },
    );
    s['subject'] = {'id': 1, 'code': 'eng', 'name': 'Use of English'};
    await _shot(
      t,
      Scaffold(
        body: GzSyncPlay(m: _m(s), onLeave: () {}),
      ),
      '17_underline',
    );
  });

  const passage =
      'Mama Bisi has sold pepper and tomatoes at Oja Oba market for twenty-two years. For most of that time she kept her accounts in her head. '
      'She knew who owed her, who paid on time and who always begged for small reduction. Then, three years ago, her granddaughter Tolani gave her '
      'a cheap exercise book and taught her to write down every sale. At first Mama Bisi laughed. My memory is my bank, she said. But after one month '
      'the book told a story her memory had hidden. On rainy days she sold far less, yet she still bought the same quantity of tomatoes from the farmers.';

  testWidgets('18 reading passage', (t) async {
    final players = [_p(1, 'Emmanuel Oluwanifemi', me: true, avatar: _me), _p(2, 'Ngozi', bot: true)];
    final s = _match('reading', players, rounds: 5);
    s['starts_at'] = _now - 26000;
    s['answer_at'] = _now + 18000;
    s['ends_at'] = _now + 93000;
    s['passage'] = {'title': 'The Market Ledger', 'body': passage, 'words': 110, 'read_ms': 44000, 'wpm': 240};
    await _shot(
      t,
      Scaffold(
        body: GzReadingPlay(m: _m(s), onLeave: () {}),
      ),
      '18_reading_passage',
    );
  });

  testWidgets('19 reading questions', (t) async {
    final players = [_p(1, 'Emmanuel Oluwanifemi', me: true, avatar: _me), _p(2, 'Ngozi', bot: true, pos: 3)];
    final s = _match('reading', players, rounds: 5);
    s['starts_at'] = _now - 60000;
    s['answer_at'] = _now - 16000;
    s['ends_at'] = _now + 59000;
    s['passage'] = {'title': 'The Market Ledger', 'words': 110, 'read_ms': 44000};
    final m = _m(s)
      ..racePos = 2
      ..raceCorrect = 2
      ..raceItem = {
        'body': "'My memory is my bank' suggests that Mama Bisi",
        'kind': 'vocab',
        'options': [
          {'key': 'A', 'text': 'kept her money in a bank'},
          {'key': 'B', 'text': 'forgot most of her sales'},
          {'key': 'C', 'text': 'trusted her memory to keep her accounts'},
          {'key': 'D', 'text': 'wanted to open a bank'},
        ],
      };
    await _shot(
      t,
      Scaffold(
        body: GzReadingPlay(m: m, onLeave: () {}),
      ),
      '19_reading_questions',
    );
  });

  test('teleprompter moves the passage up at a steady pace', () {
    double top(double f) => gzPromptTop(frac: f, textH: 600, lineH: 30, view: 200, lineAt: .5);
    expect(top(0), 85); // first line on the reading line
    expect(top(1), 85 - 570); // last line on the reading line
    expect(top(.5), closeTo((top(0) + top(1)) / 2, .001));
    expect(top(2), top(1));
  });
}
