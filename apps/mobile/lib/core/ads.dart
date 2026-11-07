import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../data/db.dart';

import 'providers.dart';

/// Google AdMob (big update 2, step B, D-101). The admin sets a level (Off … Ultra) and the server answers with what
/// this student may see (`ads_config`): Premium and "Off" mean no ads. Rules kept here:
/// - never during a running exam, on the CBT question screen or at checkout ([AdsGate]);
/// - banners at the top of lists, card (native) ads between list items, break (interstitial) ads only at breaks with
///   gaps and a daily cap, rewarded "watch to unlock" always the student's choice and granted by the server;
/// - personalised ads only for 18+, non-personalised under 18, child-directed under 13 (birth year asked once).
class AdsConfig {
  AdsConfig(this.j);
  final Map<String, dynamic> j;
  static final off = AdsConfig(const {'on': false});

  bool get on => j['on'] == true;
  bool get test => j['test'] != false;
  bool get askBirthYear => j['ask_birth_year'] == true;
  String get ageGroup => '${j['age_group'] ?? 'unknown'}';
  bool get personalised => j['personalised'] == true;
  bool format(String f) => on && (j['formats'] as Map?)?[f] != false;
  int _i(String k) => (j[k] as num?)?.toInt() ?? 0;
  int get nativeEvery => format('native') ? _i('native_every') : 0;
  int get interstitialGapS => _i('interstitial_gap_s');
  int get interstitialPerDay => format('interstitial') ? _i('interstitial_per_day') : 0;
  int get rewardedLeft => format('rewarded') ? _i('rewarded_left') : 0;
  bool get afterVideo => j['after_video'] == true;
  bool bannerOn(String screen) => format('banner') && ((j['banner_screens'] as List?) ?? const []).contains(screen);
  int reward(String k) => ((j['rewards'] as Map?)?[k] as num?)?.toInt() ?? 0;

  /// Google's sample units are used in test mode or when the admin left a unit empty.
  String unit(String f) {
    final real = '${(j['units'] as Map?)?[f] ?? ''}'.trim();
    if (!test && real.isNotEmpty) return real;
    return switch (f) {
      'banner' => 'ca-app-pub-3940256099942544/6300978111',
      'native' => 'ca-app-pub-3940256099942544/2247696110',
      'interstitial' => 'ca-app-pub-3940256099942544/1033173712',
      _ => 'ca-app-pub-3940256099942544/5224354917',
    };
  }

  AdRequest get request => AdRequest(nonPersonalizedAds: !personalised);
}

/// What the server says this student sees. Read when the app opens (and after sign-in / Premium changes).
final adsConfigProvider = FutureProvider<AdsConfig>((ref) async {
  final s = currentSession(ref);
  if (s == null || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return AdsConfig.off;
  try {
    final j = await ref.read(supabaseProvider).rpc('ads_config').timeout(const Duration(seconds: 12));
    final c = AdsConfig(Map<String, dynamic>.from((j as Map?) ?? const {}));
    if (c.on) await Ads.instance._init(c);
    return c;
  } catch (_) {
    return AdsConfig.off;
  }
});

/// Screens where no ad may ever show (running exam, CBT, checkout). Each such screen calls [enter] / [leave].
class AdsGate {
  static int _blocked = 0;
  static void enter() => _blocked++;
  static void leave() => _blocked = (_blocked - 1).clamp(0, 1 << 20);
  static bool get blocked => _blocked > 0;
}

class Ads {
  Ads._();
  static final instance = Ads._();
  bool _started = false;
  InterstitialAd? _inter;
  bool _loadingInter = false;
  DateTime? _lastInter;
  int _interToday = 0;
  String _interDay = '';
  final _pending = <String, Map<String, int>>{};
  Timer? _flush;

  Future<void> _init(AdsConfig c) async {
    if (_started) return;
    _started = true;
    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        // Under 13: child treatment; 13-17 or unknown: teen treatment (never personalised); 18+: no restriction.
        ageRestrictedTreatment: c.ageGroup == 'child'
            ? AgeRestrictedTreatment.child
            : c.ageGroup == 'adult'
            ? AgeRestrictedTreatment.unspecified
            : AgeRestrictedTreatment.teen,
        maxAdContentRating: c.ageGroup == 'adult' ? MaxAdContentRating.t : MaxAdContentRating.g,
      ),
    );
  }

  /// Counts sent to the server in small batches (admin report).
  void log(String format, String placement, {bool click = false}) {
    final k = '$format|$placement';
    final m = _pending.putIfAbsent(k, () => {'impressions': 0, 'clicks': 0});
    if (click) {
      m['clicks'] = m['clicks']! + 1;
    } else {
      m['impressions'] = m['impressions']! + 1;
    }
    _flush ??= Timer(const Duration(seconds: 20), _send);
  }

  Future<void> _send() async {
    _flush = null;
    if (_pending.isEmpty) return;
    final events = [
      for (final e in _pending.entries) {'format': e.key.split('|')[0], 'placement': e.key.split('|')[1], ...e.value},
    ];
    _pending.clear();
    try {
      await Supabase.instance.client.rpc('ads_log', params: {'p_events': events});
    } catch (_) {}
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _loadDayCount(AppDb db) async {
    if (_interDay == _today()) return;
    _interDay = _today();
    try {
      final v = await db.kvGet('ads:inter:$_interDay');
      _interToday = int.tryParse(v ?? '') ?? 0;
    } catch (_) {
      _interToday = 0;
    }
  }

  /// Gets a break ad ready (call when a break is near, e.g. when results open).
  Future<void> prepareBreak(WidgetRef ref) async {
    final c = ref.read(adsConfigProvider).value ?? AdsConfig.off;
    if (c.interstitialPerDay == 0 || _inter != null || _loadingInter) return;
    _loadingInter = true;
    await InterstitialAd.load(
      adUnitId: c.unit('interstitial'),
      request: c.request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _inter = ad;
          _loadingInter = false;
        },
        onAdFailedToLoad: (_) => _loadingInter = false,
      ),
    );
  }

  /// A break (after results, a challenge or a video): shows a full-screen ad if the level, gap and daily cap allow.
  Future<void> breakPoint(WidgetRef ref, String placement) async {
    final c = ref.read(adsConfigProvider).value ?? AdsConfig.off;
    if (AdsGate.blocked || c.interstitialPerDay == 0) return;
    if (placement == 'video' && !c.afterVideo) return;
    await _loadDayCount(ref.read(dbProvider));
    if (_interToday >= c.interstitialPerDay) return;
    if (_lastInter != null && DateTime.now().difference(_lastInter!).inSeconds < c.interstitialGapS) return;
    final ad = _inter;
    if (ad == null) {
      unawaited(prepareBreak(ref));
      return;
    }
    _inter = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => log('interstitial', placement),
      onAdClicked: (_) => log('interstitial', placement, click: true),
      onAdDismissedFullScreenContent: (a) => a.dispose(),
      onAdFailedToShowFullScreenContent: (a, _) => a.dispose(),
    );
    _lastInter = DateTime.now();
    _interToday++;
    try {
      await ref.read(dbProvider).kvSet('ads:inter:$_interDay', '$_interToday');
    } catch (_) {}
    await ad.show();
  }
}

/// "Watch to unlock" (rewarded). The server makes a nonce, AdMob tells the server the ad was watched (server-side
/// verification), and only then is the reward given. Returns true when the reward arrived.
Future<bool> watchToUnlock(BuildContext context, WidgetRef ref, {required String kind, String? itemRef, String placement = ''}) async {
  final c = ref.read(adsConfigProvider).value ?? AdsConfig.off;
  if (AdsGate.blocked || !c.format('rewarded')) return false;
  final sb = ref.read(supabaseProvider);
  final uid = sb.auth.currentUser?.id;
  if (uid == null) return false;
  Map<String, dynamic> start;
  try {
    start = Map<String, dynamic>.from(await sb.rpc('ad_reward_start', params: {'p_kind': kind, 'p_ref': itemRef}) as Map);
  } catch (_) {
    return false;
  }
  if (start['ok'] != true) {
    if (context.mounted) {
      final why = start['why'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            why == 'cap'
                ? 'You have used all your free unlocks for today. Go Premium for no limits and no ads.'
                : why == 'full'
                ? 'You already have the most streak freezes you can hold.'
                : 'Watching for a reward is not available right now.',
          ),
        ),
      );
    }
    return false;
  }
  final nonce = '${start['nonce']}';
  final test = start['test'] == true;
  final done = Completer<bool>();
  var earned = false;
  await RewardedAd.load(
    adUnitId: c.unit('rewarded'),
    request: c.request,
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) async {
        await ad.setServerSideOptions(ServerSideVerificationOptions(userId: uid, customData: nonce));
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (_) => Ads.instance.log('rewarded', placement),
          onAdDismissedFullScreenContent: (a) {
            a.dispose();
            if (!done.isCompleted) done.complete(earned);
          },
          onAdFailedToShowFullScreenContent: (a, _) {
            a.dispose();
            if (!done.isCompleted) done.complete(false);
          },
        );
        await ad.show(onUserEarnedReward: (_, _) => earned = true);
      },
      onAdFailedToLoad: (_) {
        if (!done.isCompleted) done.complete(false);
      },
    ),
  );
  if (!await done.future) return false;
  // The server gives the reward when AdMob's signed callback arrives (usually a few seconds).
  for (var i = 0; i < 12; i++) {
    try {
      final st = await sb.rpc('ad_reward_status', params: {'p_nonce': nonce, 'p_test_claim': test});
      if ((st as Map)['status'] == 'granted') {
        ref.invalidate(adsConfigProvider);
        return true;
      }
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  }
  return false;
}

/// A banner at the top of a list, under the header, when the level shows banners on [screen].
class AdBanner extends ConsumerStatefulWidget {
  const AdBanner({super.key, required this.screen});
  final String screen;
  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  BannerAd? _ad;
  bool _ready = false;

  void _load(AdsConfig c) {
    if (_ad != null || !c.bannerOn(widget.screen)) return;
    _ad = BannerAd(
      adUnitId: c.unit('banner'),
      size: AdSize.banner,
      request: c.request,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _ready = true);
        },
        onAdImpression: (_) => Ads.instance.log('banner', widget.screen),
        onAdClicked: (_) => Ads.instance.log('banner', widget.screen, click: true),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(adsConfigProvider).value ?? AdsConfig.off;
    if (!c.bannerOn(widget.screen) || AdsGate.blocked) return const SizedBox.shrink();
    _load(c);
    if (!_ready || _ad == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: SizedBox(
          width: _ad!.size.width.toDouble(),
          height: _ad!.size.height.toDouble(),
          child: AdWidget(ad: _ad!),
        ),
      ),
    );
  }
}

/// A card ad between list items (Google's native template, styled like our cards).
class AdNativeCard extends ConsumerStatefulWidget {
  const AdNativeCard({super.key, required this.placement});
  final String placement;
  @override
  ConsumerState<AdNativeCard> createState() => _AdNativeCardState();
}

class _AdNativeCardState extends ConsumerState<AdNativeCard> {
  NativeAd? _ad;
  bool _ready = false;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(adsConfigProvider).value ?? AdsConfig.off;
    if (c.nativeEvery == 0 || AdsGate.blocked) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    _ad ??= NativeAd(
      adUnitId: c.unit('native'),
      request: c.request,
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        cornerRadius: 16,
        mainBackgroundColor: dark ? const Color(0xFF13233F) : Colors.white,
        callToActionTextStyle: NativeTemplateTextStyle(textColor: const Color(0xFF0B1F44), backgroundColor: const Color(0xFFF2B233), size: 14),
        primaryTextStyle: NativeTemplateTextStyle(textColor: dark ? Colors.white : const Color(0xFF0B1F44), size: 15),
        secondaryTextStyle: NativeTemplateTextStyle(textColor: dark ? const Color(0xFFC9D5EA) : const Color(0xFF5B6B84), size: 13),
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _ready = true);
        },
        onAdImpression: (_) => Ads.instance.log('native', widget.placement),
        onAdClicked: (_) => Ads.instance.log('native', widget.placement, click: true),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
    if (!_ready) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 90, maxHeight: 120),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AdWidget(ad: _ad!),
        ),
      ),
    );
  }
}

/// Inserts a card ad after every N items of a list, as the level says. [build] makes item i.
List<Widget> withNativeAds(WidgetRef ref, int count, Widget Function(int i) build, {required String placement}) {
  final every = (ref.watch(adsConfigProvider).value ?? AdsConfig.off).nativeEvery;
  return [
    for (var i = 0; i < count; i++) ...[
      build(i),
      if (every > 0 && (i + 1) % every == 0 && i + 1 < count) AdNativeCard(key: ValueKey('ad-$placement-$i'), placement: placement),
    ],
  ];
}

/// Ask once for the birth year (personalised ads only for 18+). Returns quietly if the student skips.
Future<void> askBirthYearOnce(BuildContext context, WidgetRef ref) async {
  final c = ref.read(adsConfigProvider).value ?? AdsConfig.off;
  if (!c.on || !c.askBirthYear) return;
  final db = ref.read(dbProvider);
  final asked = await db.kvGet('ads:asked_birth_year');
  if (asked != null && DateTime.now().difference(DateTime.tryParse(asked) ?? DateTime(2000)).inDays < 14) return;
  await db.kvSet('ads:asked_birth_year', DateTime.now().toIso8601String());
  if (!context.mounted) return;
  final now = DateTime.now().year;
  int? picked;
  final year = await showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('What year were you born?', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('We ask once, so the ads you see suit your age. Students under 18 never get ads based on what they do.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: picked,
                decoration: const InputDecoration(labelText: 'Birth year'),
                items: [for (var y = now - 8; y >= now - 60; y--) DropdownMenuItem(value: y, child: Text('$y'))],
                onChanged: (v) => set(() => picked = v),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: picked == null ? null : () => Navigator.pop(ctx, picked), child: const Text('Save')),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not now')),
            ],
          ),
        ),
      ),
    ),
  );
  if (year == null) return;
  try {
    await ref.read(supabaseProvider).rpc('set_birth_year', params: {'p_year': year});
    ref.invalidate(adsConfigProvider);
  } catch (_) {}
}

/// For logs: the pending counts (tests).
@visibleForTesting
String debugPendingAds() => jsonEncode(Ads.instance._pending);
