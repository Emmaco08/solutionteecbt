// Screenshots of the new challenge cards in every situation (owner, 14 Nov 2026), dark and light, plus frames of the
// live card's animation. Not part of `flutter test`. Run: flutter test test_shots/cards_shots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart' show cashPrizesOn;
import 'package:solutiontee_cbt/features/compete/challenge_cards.dart';
import 'package:solutiontee_cbt/features/compete/challenges_screens.dart' show NoChallengeCard;
import 'package:solutiontee_cbt/features/compete/compete_data.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

final _now = DateTime.now();
String _t(Duration d) => _now.add(d).toUtc().toIso8601String();

Challenge _c({
  String title = 'Maths Challenge',
  String status = 'live',
  String kind = 'cash',
  List<int> prizes = const [50000, 20000, 10000],
  String? reward,
  int joined = 128,
  int xp = 0,
  Map<String, dynamic>? mine,
  String style = 'quiz',
  int? max,
  String icon = 'function',
  Duration start = const Duration(hours: -10),
  Duration end = const Duration(days: 1, hours: 12, minutes: 5),
}) => Challenge({
  'id': title,
  'title': title,
  'status': status,
  'kind': kind,
  'prizes': prizes,
  'reward': reward,
  'joined': joined,
  'xp_fee': xp,
  'mine': mine,
  'style': style,
  'max_players': max,
  'icon': icon,
  'questions': 10,
  'seconds': 60,
  'duration_minutes': 30,
  'starts_at': _t(start),
  'ends_at': _t(end),
});

Widget _label(BuildContext context, String s) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
  child: Text(
    s,
    style: TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .7),
    ),
  ),
);

Future<void> _shot(
  WidgetTester t,
  Widget Function(BuildContext) b,
  String name, {
  Brightness mode = Brightness.dark,
  double height = 2600,
  int frames = 20,
}) async {
  t.view.physicalSize = Size(411 * 3, height * 3);
  t.view.devicePixelRatio = 3;
  await t.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(mode),
        home: Scaffold(
          body: SafeArea(child: Builder(builder: b)),
        ),
      ),
    ),
  );
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
}

void main() {
  setUpAll(() async {
    cashPrizesOn = true;
    await _font('PlusJakartaSans', ['assets/fonts/PlusJakartaSans-Medium.ttf', 'assets/fonts/PlusJakartaSans-Bold.ttf']);
    await _font('PhosphorRegular', ['assets/fonts/Phosphor-Regular.ttf']);
    await _font('PhosphorFill', ['assets/fonts/Phosphor-Fill.ttf']);
    await _font('MaterialIcons', ['/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  Widget big(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
    children: [
      _label(context, '1. Live, cash prize, not joined yet'),
      ChallengeLiveCard(c: _c()),
      _label(context, '2. Live, you took part (rank shown)'),
      ChallengeLiveCard(c: _c(mine: {'status': 'finished', 'rank': 3})),
      _label(context, '3. Live practice (no prize), few places left, XP entry'),
      ChallengeLiveCard(
        c: _c(title: 'Physics Sprint', kind: 'practice', prizes: const [], joined: 46, max: 60, xp: 50, icon: 'atom'),
      ),
      _label(context, '4. Live JAMB mock, you are still writing'),
      ChallengeLiveCard(
        c: _c(title: 'Mini JAMB Mock', kind: 'practice', prizes: const [], style: 'jamb_mock', joined: 2, mine: {'status': 'playing'}),
      ),
      _label(context, '5. Live event with a reward, disqualified'),
      ChallengeLiveCard(
        c: _c(title: 'Biology Week', kind: 'event', prizes: const [], reward: '1 month Premium', joined: 1240, mine: {'status': 'disqualified'}, icon: 'flask'),
      ),
      _label(context, '6. Live, full'),
      ChallengeLiveCard(
        c: _c(title: 'English Masters', joined: 100, max: 100, icon: 'book-open-text'),
      ),
    ],
  );

  Widget rest(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
    children: [
      _label(context, '7. Coming up (big card)'),
      ChallengeSoonCard(
        c: _c(status: 'upcoming', start: const Duration(hours: 5, minutes: 42, seconds: 17), end: const Duration(days: 2)),
      ),
      _label(context, '8. Coming up in more than a day'),
      ChallengeSoonCard(
        c: _c(
          title: 'Chemistry Cup',
          status: 'upcoming',
          kind: 'event',
          prizes: const [],
          reward: '500 XP',
          start: const Duration(days: 3, hours: 4),
          end: const Duration(days: 4),
          icon: 'flask',
        ),
      ),
      _label(context, '9. Small cards (live · coming up · ended)'),
      SizedBox(
        height: 168,
        child: ListView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: 232,
              child: ChallengeMiniCard(
                c: _c(title: 'Mini JAMB Mock', kind: 'practice', prizes: const [], style: 'jamb_mock', joined: 2),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 232,
              child: ChallengeMiniCard(
                c: _c(title: 'Physics Sprint', status: 'upcoming', start: const Duration(hours: 2, minutes: 10), prizes: const [5000], icon: 'atom'),
                index: 1,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 168,
        child: Row(
          children: [
            SizedBox(
              width: 232,
              child: ChallengeMiniCard(
                c: _c(title: 'October Maths Cup', status: 'ended', joined: 812, start: const Duration(days: -9), end: const Duration(days: -2)),
                index: 2,
              ),
            ),
          ],
        ),
      ),
      _label(context, '10. Test → Challenges list rows'),
      ChallengeListCard(c: _c()),
      const SizedBox(height: 8),
      ChallengeListCard(
        c: _c(title: 'Mini JAMB Mock', kind: 'practice', prizes: const [], style: 'jamb_mock', joined: 2, mine: {'status': 'finished', 'rank': 1}),
        index: 1,
      ),
      const SizedBox(height: 8),
      ChallengeListCard(
        c: _c(title: 'Physics Sprint', status: 'upcoming', start: const Duration(hours: 2, minutes: 10), prizes: const [5000], icon: 'atom'),
        index: 2,
      ),
      _label(context, '11. Nothing live or coming (unchanged)'),
      const NoChallengeCard(),
    ],
  );

  for (final m in Brightness.values) {
    final tag = m == Brightness.dark ? 'dark' : 'light';
    testWidgets('cards live $tag', (t) => _shot(t, big, 'cards_live_$tag', mode: m, height: 2700));
    testWidgets('cards rest $tag', (t) => _shot(t, rest, 'cards_rest_$tag', mode: m, height: 2300));
  }

  // Frames of the live card moving (for a short animation preview).
  testWidgets('cards frames', (t) async {
    t.view.physicalSize = const Size(411 * 2, 380 * 2);
    t.view.devicePixelRatio = 2;
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.dark),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ChallengeLiveCard(c: _c()),
            ),
          ),
        ),
      ),
    );
    for (var f = 0; f < 48; f++) {
      await t.pump(const Duration(milliseconds: 125));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/frames/f${f.toString().padLeft(2, '0')}.png'));
    }
  });
}
