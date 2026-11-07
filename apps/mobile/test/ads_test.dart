import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/ads.dart';
import 'package:solutiontee_cbt/features/study/note_screens.dart' show NoteView;
import 'package:solutiontee_cbt/widgets/note_markdown.dart' show NoteDoc;

/// Big update 2, step B: what the server's ads config means in the app.
void main() {
  test('off and Premium: nothing shows', () {
    final c = AdsConfig.off;
    expect(c.on, isFalse);
    expect(c.bannerOn('study'), isFalse);
    expect(c.nativeEvery, 0);
    expect(c.interstitialPerDay, 0);
    expect(c.rewardedLeft, 0);
  });

  test('a level: banners only on its screens, formats can be switched off, test units in test mode', () {
    final c = AdsConfig({
      'on': true,
      'test': true,
      'formats': {'banner': true, 'native': false, 'interstitial': true, 'rewarded': true},
      'units': {'banner': 'ca-app-pub-1111111111111111/2222222222'},
      'banner_screens': ['study', 'news'],
      'native_every': 6,
      'interstitial_gap_s': 240,
      'interstitial_per_day': 6,
      'rewarded_left': 4,
      'personalised': false,
      'age_group': 'teen',
      'rewards': {'ai_prompts': 2},
    });
    expect(c.bannerOn('study'), isTrue);
    expect(c.bannerOn('me'), isFalse);
    expect(c.nativeEvery, 0, reason: 'card ads switched off by the admin');
    expect(c.interstitialPerDay, 6);
    expect(c.rewardedLeft, 4);
    expect(c.reward('ai_prompts'), 2);
    expect(c.unit('banner'), 'ca-app-pub-3940256099942544/6300978111', reason: 'test mode always uses Google test ads');
    expect(c.request.nonPersonalizedAds, isTrue, reason: 'under 18: never personalised');
  });

  test('live mode uses the real unit; adults may get personalised ads', () {
    final c = AdsConfig({
      'on': true,
      'test': false,
      'units': {'rewarded': 'ca-app-pub-1111111111111111/3333333333'},
      'personalised': true,
    });
    expect(c.unit('rewarded'), 'ca-app-pub-1111111111111111/3333333333');
    expect(c.unit('banner'), startsWith('ca-app-pub-3940256099942544/'), reason: 'an empty unit falls back to a test unit');
    expect(c.request.nonPersonalizedAds, isFalse);
  });

  test('the red line blocks ads while an exam or checkout is open', () {
    expect(AdsGate.blocked, isFalse);
    AdsGate.enter();
    expect(AdsGate.blocked, isTrue);
    AdsGate.leave();
    expect(AdsGate.blocked, isFalse);
    AdsGate.leave();
    expect(AdsGate.blocked, isFalse, reason: 'never below zero');
  });

  testWidgets('a banner takes no space when ads are off', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [adsConfigProvider.overrideWith((_) async => AdsConfig.off)],
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AdBanner(screen: 'study'),
                Text('content'),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.text('content'), findsOneWidget);
    expect(t.getSize(find.byType(AdBanner)).height, 0);
  });

  test('ads v2 extras: sticky banners, random breaks and cards inside notes follow the formats', () {
    final c = AdsConfig({
      'on': true,
      'formats': {'banner': true, 'native': true},
      'banner_sticky': 'both',
      'random_break_pct': 15,
      'note_cards_every': 3,
      'home_cards': 4,
      'inter_spots': ['video_start', 'note'],
      'rint_spots': ['test'],
      'xp_left': 7,
    });
    expect(c.sticky, 'both');
    expect(c.randomBreakPct, 15);
    expect(c.noteCardsEvery, 3);
    expect(c.homeCards, 4);
    expect(c.interSpots, contains('note'));
    expect(c.earnSpots, ['test']);
    expect(c.xpLeft, 7);
    final noBanner = AdsConfig({
      'on': true,
      'formats': {'banner': false, 'native': false},
      'banner_sticky': 'top',
      'note_cards_every': 3,
    });
    expect(noBanner.sticky, 'off', reason: 'banners switched off: no sticky banner');
    expect(noBanner.noteCardsEvery, 0);
    expect(AdsConfig.off.sticky, 'off');
  });

  test('cards inside a note go before a heading, never first or last', () {
    final doc = NoteDoc.parse(
      ['# Title', 'p1', 'p2', 'p3', '## Part two', 'p4', 'p5', '## Part three', 'p6', 'p7', 'p8', 'p9', 'p10', 'p11', 'p12'].join('\n\n'),
    );
    expect(NoteView.adSpots(doc, 0), isEmpty);
    final spots = NoteView.adSpots(doc, 3);
    expect(spots, contains(4), reason: 'before "Part two" after 4 blocks');
    expect(spots.contains(0), isFalse);
    expect(spots.contains(doc.blocks.length - 1), isFalse);
    for (final i in spots) {
      expect(i, greaterThan(0));
    }
  });

  testWidgets('sticky banners add nothing when the level has none', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [adsConfigProvider.overrideWith((_) async => AdsConfig.off)],
        child: const MaterialApp(home: StickyAds(child: Text('app'))),
      ),
    );
    await t.pump();
    expect(find.text('app'), findsOneWidget);
    expect(find.byType(Column), findsNothing);
  });
}
