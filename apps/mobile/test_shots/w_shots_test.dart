// ignore_for_file: invalid_use_of_visible_for_testing_member
// Screenshots for the owner's 13 Nov 2026 fixes (names in full, menu on the right, countdown card). Not part of
// `flutter test`. Run: flutter test test_shots/w_shots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/engagement.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/community/community_data.dart';
import 'package:solutiontee_cbt/features/community/community_widgets.dart';
import 'package:solutiontee_cbt/features/home/countdown.dart';
import 'package:solutiontee_cbt/features/home/play_connect_cards.dart';
import 'package:solutiontee_cbt/features/onboarding/onboarding_art.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

Map<String, dynamic> _post(String id, String name, String handle, {String? badge, String? page, String body = 'Why is tomato red? @solutiontee'}) => {
  'id': id,
  'user_id': 'u$id',
  'page_id': page,
  'name': name,
  'handle': handle,
  'badge': badge,
  'body': body,
  'status': 'shown',
  'images': const [],
  'subject_id': null,
  'likes': 2,
  'replies': 4,
  'reposts': 0,
  'created_at': DateTime.now().subtract(const Duration(hours: 7)).toUtc().toIso8601String(),
  'mine': false,
  'liked': true,
  'reposted': false,
  'bookmarked': false,
  'following': false,
};

Future<void> _shot(WidgetTester t, Widget w, String name, {double width = 360, List overrides = const []}) async {
  t.view.physicalSize = Size(width * 3, 1500 * 3);
  t.view.devicePixelRatio = 3;
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        subjectsProvider.overrideWith((_) async => const []),
        communityMeProvider.overrideWith((_) async => {'name': 'Tolu', 'handle': 'tolu'}),
        ...overrides.cast(),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.dark),
        home: Scaffold(body: SafeArea(child: w)),
      ),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 6));
}

void main() {
  setUpAll(() async {
    await _font('LilitaOne', ['assets/fonts/LilitaOne-Regular.ttf']);
    await _font('PlusJakartaSans', ['assets/fonts/PlusJakartaSans-Medium.ttf', 'assets/fonts/PlusJakartaSans-Bold.ttf']);
    await _font('PhosphorRegular', ['assets/fonts/Phosphor-Regular.ttf']);
    await _font('PhosphorFill', ['assets/fonts/Phosphor-Fill.ttf']);
    await _font('MaterialIcons', ['/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  final posts = ListView(
    children: [
      PostCell(post: _post('1', 'Emmanuel Akinbola', 'emmanuel25', badge: 'staff')),
      PostCell(
        post: _post('2', 'SolutionTee', 'solutiontee', badge: 'official', page: 'pg', body: 'Just testing\n\nHello, everyone'),
      ),
      PostCell(
        post: _post('3', 'Emmanuel Oluwanifemi Akinbola', 'emmanuel', badge: 'staff', body: 'Hello, I am new here.'),
      ),
      PostCell(post: _post('4', 'Chidinma Okonkwo-Adebayo Oluwaseun', 'chidinma_okonkwo', body: 'A very long name.')),
      PostCell(post: _post('5', 'Ada Obi', 'ada', body: 'Short name.')),
    ],
  );

  testWidgets('posts 360', (t) async => _shot(t, posts, 'w_posts_360'));
  testWidgets('posts 411', (t) async => _shot(t, posts, 'w_posts_411', width: 411));

  testWidgets('countdown card', (t) async {
    final cd = ExamCountdown(code: 'JAMB', label: 'UTME', date: DateTime.now().add(const Duration(days: 122)));
    await _shot(
      t,
      const Padding(
        padding: EdgeInsets.all(20),
        child: Column(children: [CountdownChip()]),
      ),
      'w_countdown',
      overrides: [examCountdownProvider.overrideWithValue(cd)],
    );
  });

  testWidgets('play and connect', (t) async {
    await _shot(t, const SingleChildScrollView(padding: EdgeInsets.all(20), child: PlayConnectSection()), 'w_play_connect');
  });

  Widget opener(Future<void> Function(BuildContext, WidgetRef) open) => Consumer(
    builder: (context, ref, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => open(context, ref));
      return const SizedBox.expand();
    },
  );

  testWidgets('rating sheet', (t) async {
    await _shot(t, opener((c, r) => showRatingSheet(c, r)), 'w_rating');
  });

  testWidgets('nudge games', (t) async {
    await _shot(t, opener((c, r) => showNudgeSheet(c, 'games')), 'w_nudge_games');
  });

  for (final k in ['games', 'community', 'tutor']) {
    testWidgets('onboarding $k', (t) async {
      await _shot(
        t,
        Center(
          child: SizedBox(width: 340, height: 340, child: SlideArt(kind: k, current: true)),
        ),
        'w_onb_$k',
      );
    });
  }

  // Store image (Play listing): the Community feed at phone size (390 × 844 at 3×).
  testWidgets('store community', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    final feed = [
      {
        ..._post('a', 'Kemi Adebayo', 'kemi', body: 'How do I find the gradient of a line through (1, 2) and (4, 8)? @solutiontee'),
        'ai_answer': 'Use **rise ÷ run**: (8 − 2) ÷ (4 − 1) = 6 ÷ 3 = **2**. The line goes up 2 for every 1 step to the right. You go pass!',
        'replies': 6,
        'likes': 24,
      },
      {
        ..._post(
          'b',
          'Tobi Adeyemi',
          'tobi',
          body: 'Just won 3 games of Comprehension Clash in a row. Read the passage fast, then answer 5 questions. Who wants a rematch tonight?',
        ),
        'likes': 132,
        'replies': 41,
      },
      {
        ..._post(
          'c',
          'Musa Ibrahim',
          'musa_i',
          body: 'Finished my first full JAMB mock today: 268! My target is 300 by March. Who wants to practise Physics together? #JAMB2027',
        ),
        'likes': 57,
        'replies': 12,
      },
      {
        ..._post(
          'd',
          'Chioma Okafor',
          'chioma',
          body: 'Tip: do one comprehension passage every morning against a timer. My English score went up by 15 marks.',
        ),
        'likes': 88,
      },
    ];
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          subjectsProvider.overrideWith((_) async => const []),
          communityMeProvider.overrideWith((_) async => {'name': 'Tolu', 'handle': 'tolu'}),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.dark),
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 52),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back_ios_new, size: 20),
                      const Spacer(),
                      Text(
                        'Community',
                        style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      const CircleAvatar(radius: 16, child: Text('T')),
                    ],
                  ),
                ),
                Row(
                  children: [
                    for (final (i, x) in ['For you', 'Following'].indexed)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              x,
                              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 16, fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Container(height: 3, width: 70, color: i == 0 ? const Color(0xFFF2B233) : Colors.transparent),
                          ],
                        ),
                      ),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [for (final p in feed) PostCell(post: p)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/store_community.png'));
  });
}
