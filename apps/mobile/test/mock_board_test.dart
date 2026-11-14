import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/compete/compete_data.dart';
import 'package:solutiontee_cbt/features/compete/results_screens.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

// Owner, 14 Nov 2026: "See the leaderboard" after a JAMB mock showed a blank screen. This is the server's real answer.
const _res =
    '{"id":"e4d","top":[{"me":true,"max":400,"name":"Emmanuel A.","rank":1,"prize":null,"score":10,"state":"Oyo","time_ms":15294,"subjects":[{"name":"Use of English","score":10,"total":10,"correct":1,"subject_id":1},{"name":"Mathematics","score":0,"total":5,"correct":0,"subject_id":2}],"started_at":"2026-11-14T09:01:00.280712+00:00"},{"me":false,"max":400,"name":"Emmanuel A.","rank":2,"prize":null,"score":0,"state":"Oyo","time_ms":24976,"subjects":[],"started_at":"2026-11-12T22:08:02.710529+00:00"}],"exam":null,"icon":"trophy","kind":"practice","mine":{"rank":1,"prize":null,"score":10,"appeal":null,"status":"finished","time_ms":15294,"answered":0,"dq_reason":null,"can_review":false,"started_at":"2026-11-14T09:01:00.280712+00:00","finished_at":"2026-11-14T09:01:15.574887+00:00"},"mode":"fixed","claim":null,"style":"jamb_mock","title":"Mini JAMB Mock - Test","access":"open","joined":2,"my_max":400,"prizes":[],"ranked":2,"reward":null,"status":"live","xp_fee":0,"bg_dark":null,"ends_at":"2026-11-15T21:00:00+00:00","my_rank":1,"results":"instant","seconds":30,"subject":null,"bg_light":null,"eligible":true,"subtitle":"Small test mock","unlocked":true,"per_level":{"easy":3,"hard":3,"medium":3,"very_hard":1},"questions":20,"starts_at":"2026-11-12T22:00:00+00:00","calculator":false,"claim_until":null,"exit_action":"flag","max_players":null,"min_win_pct":null,"premium_top":0,"allow_review":true,"board_hidden":false,"premium_days":0,"allowed_exits":2,"same_questions":false,"xp_earned_only":false,"duration_minutes":30,"max_away_seconds":null}';

void main() {
  testWidgets('JAMB mock leaderboard renders the real server answer', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.6;
    await t.pumpWidget(
      ProviderScope(
        overrides: [challengeResultProvider.overrideWith((ref, id) async => Map<String, dynamic>.from(jsonDecode(_res) as Map))],
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (c) => Center(
                child: TextButton(onPressed: () => openChallengeBoard(c, 'e4d'), child: const Text('See the leaderboard')),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('See the leaderboard'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(t.takeException(), isNull);
    expect(find.text('Mini JAMB Mock - Test'), findsWidgets);
    // Back closes the board and returns to the result.
    await t.tap(find.byTooltip('Back').first);
    await t.pumpAndSettle();
    expect(find.text('See the leaderboard'), findsOneWidget);
  });
}
