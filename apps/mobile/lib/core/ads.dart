import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../data/db.dart';

import 'house_ads.dart';
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
  List<String> _l(String k) => [for (final x in (j[k] as List? ?? const [])) '$x'];
  int get nativeEvery => format('native') ? _i('native_every') : 0;
  int get homeCards => format('native') ? _i('home_cards') : 0;
  bool get newsCard => format('native') && j['news_card'] == true;
  int get interstitialGapS => _i('interstitial_gap_s');
  int get interstitialPerDay => format('interstitial') ? _i('interstitial_per_day') : 0;
  int get interEveryTests => _i('inter_every_tests');
  int get aiEvery => _i('ai_every');
  List<String> get interSpots => _l('inter_spots');
  int get appOpenAfterMin => format('app_open') ? _i('app_open_after_min') : 0;
  List<String> get earnSpots => format('rewarded_interstitial') ? _l('rint_spots') : const [];
  int get rewardedLeft => format('rewarded') ? _i('rewarded_left') : 0;
  int get xpLeft => _i('xp_left');
  int get xpProgress => _i('xp_progress');
  bool get afterVideo => j['after_video'] == true;

  /// Sticky banner: stays at the top/bottom of the screen while scrolling ('off', 'top', 'bottom' or 'both').
  String get sticky => format('banner') ? '${j['banner_sticky'] ?? 'off'}' : 'off';
  int get randomBreakPct => _i('random_break_pct');
  int get noteCardsEvery => format('native') ? _i('note_cards_every') : 0;
  bool bannerOn(String screen) => format('banner') && _l('banner_screens').contains(screen);
  int reward(String k) => ((j['rewards'] as Map?)?[k] as num?)?.toInt() ?? 0;

  /// Google's sample units are used in test mode or when the admin left a unit empty.
  String unit(String f) {
    final real = '${(j['units'] as Map?)?[f] ?? ''}'.trim();
    if (!test && real.isNotEmpty) return real;
    return switch (f) {
      'banner' => 'ca-app-pub-3940256099942544/6300978111',
      'native' => 'ca-app-pub-3940256099942544/2247696110',
      'interstitial' => 'ca-app-pub-3940256099942544/1033173712',
      'app_open' => 'ca-app-pub-3940256099942544/9257395921',
      'rewarded_interstitial' => 'ca-app-pub-3940256099942544/5354046379',
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
    Ads.instance._db = ref.read(dbProvider);
    if (c.on) await Ads.instance._init(c);
    return c;
  } catch (_) {
    return AdsConfig.off;
  }
});

/// Screens where no ad may ever show (running exam, CBT, checkout). Each such screen calls [enter] / [leave].
class AdsGate {
  static final notifier = ValueNotifier<int>(0);
  static void enter() => notifier.value++;
  static void leave() => notifier.value = (notifier.value - 1).clamp(0, 1 << 20);
  static bool get blocked => notifier.value > 0;
}

class Ads {
  Ads._();
  static final instance = Ads._();
  bool _started = false;
  AdsConfig _c = AdsConfig.off;
  AppDb? _db;
  final _rand = math.Random();
  InterstitialAd? _inter;
  bool _loadingInter = false;
  AppOpenAd? _open;
  bool _loadingOpen = false;
  DateTime? _lastFull, _pausedAt;
  int _interToday = 0;
  String _interDay = '';
  int _tests = 0, _ai = 0;
  final _pending = <String, Map<String, int>>{};
  Timer? _flush;

  Future<void> _init(AdsConfig c) async {
    _c = c;
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
    // Have a break ad ready before the first break (otherwise the first break only starts loading one).
    unawaited(_loadInter());
  }

  /// Load results for the admin report and for finding problems: "news#ok", or "news#e3" (Google's error code; 3 = no
  /// ad to show, 0 = internal, 1 = bad request, 2 = network).
  void result(String format, String placement, {int? error}) => log(format, '$placement#${error == null ? 'ok' : 'e$error'}');

  /// Counts sent to the server in small batches (admin report).
  void log(String format, String placement, {bool click = false}) {
    final k = '$format|$placement';
    final m = _pending.putIfAbsent(k, () => {'impressions': 0, 'clicks': 0});
    if (click) {
      m['clicks'] = m['clicks']! + 1;
    } else {
      m['impressions'] = m['impressions']! + 1;
    }
    _flush ??= Timer(const Duration(seconds: 8), _send);
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
      _interToday = int.tryParse(await db.kvGet('ads:inter:$_interDay') ?? '') ?? 0;
      _tests = int.tryParse(await db.kvGet('ads:tests') ?? '') ?? 0;
    } catch (_) {
      _interToday = 0;
    }
  }

  Future<void> _loadInter() async {
    final c = _c;
    if (c.interstitialPerDay == 0 || _inter != null || _loadingInter) return;
    _loadingInter = true;
    await InterstitialAd.load(
      adUnitId: c.unit('interstitial'),
      request: c.request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _inter = ad;
          _loadingInter = false;
          result('interstitial', 'break');
        },
        onAdFailedToLoad: (e) {
          _loadingInter = false;
          result('interstitial', 'break', error: e.code);
        },
      ),
    );
  }

  /// Gets a break ad ready (call when a break is near, e.g. when results open).
  Future<void> prepareBreak(WidgetRef ref) async {
    _c = ref.read(adsConfigProvider).value ?? _c;
    await _loadInter();
  }

  /// No full-screen ad within 30 s of another (AdMob: no ad right before/after another full-screen ad).
  bool get _recentFull => _lastFull != null && DateTime.now().difference(_lastFull!).inSeconds < 30;

  /// Is this break one where the level shows a break ad? test = after every Nth test; ai = every Nth AI answer.
  Future<bool> _spotAllowed(String spot) async {
    final c = _c;
    final db = _db;
    switch (spot) {
      case 'test':
        if (c.interEveryTests <= 0) return false;
        _tests++;
        try {
          await db?.kvSet('ads:tests', '$_tests');
        } catch (_) {}
        return _tests % c.interEveryTests == 0;
      case 'challenge':
        return c.interEveryTests > 0;
      case 'ai':
        // At the next break after every N AI answers (never on top of an answer the student is reading).
        if (c.aiEvery <= 0 || _ai < c.aiEvery) return false;
        _ai = 0;
        return true;
      case 'video_end':
        return c.interSpots.contains('video_end') || c.afterVideo;
      case 'random':
        return c.randomBreakPct > 0 && _rand.nextInt(100) < c.randomBreakPct;
      default:
        return c.interSpots.contains(spot);
    }
  }

  /// A natural break (after a test, around a video, after a note or quiz, an AI answer, a section change): shows a
  /// full-screen (mostly video) ad when the level allows this spot, the gap and the daily cap. Returns true when shown.
  Future<bool> breakPoint(WidgetRef ref, String spot) async {
    _c = ref.read(adsConfigProvider).value ?? _c;
    if (!breaksOn) return false;
    _db ??= ref.read(dbProvider);
    return breakAt(spot);
  }

  /// The level shows break ads at all (and the red line is not up).
  bool get breaksOn => _c.interstitialPerDay > 0 && !AdsGate.blocked;

  /// One more AI tutor answer finished (counts toward the "ai" break).
  void aiAnswered() => _ai++;

  /// The same, from outside a widget (the route observer for Ultra's random breaks).
  Future<bool> breakAt(String spot) async {
    final c = _c;
    if (AdsGate.blocked || c.interstitialPerDay == 0 || _recentFull) return false;
    final db = _db;
    if (db != null) await _loadDayCount(db);
    if (!await _spotAllowed(spot)) return false;
    if (_interToday >= c.interstitialPerDay) return false;
    if (_lastFull != null && DateTime.now().difference(_lastFull!).inSeconds < c.interstitialGapS) return false;
    // A brand campaign may take this break (its share); it counts toward the same gap and daily cap.
    final house = House.pick('break');
    if (house != null) {
      _lastFull = DateTime.now();
      _interToday++;
      try {
        await db?.kvSet('ads:inter:$_interDay', '$_interToday');
      } catch (_) {}
      final shown = await House.breakNow(house);
      _lastFull = DateTime.now();
      if (shown) return true;
    }
    final ad = _inter;
    if (ad == null) {
      unawaited(_loadInter());
      return false;
    }
    _inter = null;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => log('interstitial', spot),
      onAdClicked: (_) => log('interstitial', spot, click: true),
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _lastFull = DateTime.now();
        if (!closed.isCompleted) closed.complete();
        unawaited(_loadInter());
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        if (!closed.isCompleted) closed.complete();
        unawaited(_loadInter());
      },
    );
    _lastFull = DateTime.now();
    _interToday++;
    try {
      await db?.kvSet('ads:inter:$_interDay', '$_interToday');
    } catch (_) {}
    await ad.show();
    // Callers that wait (e.g. before a video) carry on when the ad is closed.
    await closed.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    return true;
  }

  /// The app went to the background: remember when, and get an app-open ad ready.
  void paused() {
    _pausedAt = DateTime.now();
    final c = _c;
    if (c.appOpenAfterMin <= 0 || _open != null || _loadingOpen) return;
    _loadingOpen = true;
    AppOpenAd.load(
      adUnitId: c.unit('app_open'),
      request: c.request,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _open = ad;
          _loadingOpen = false;
          result('app_open', 'resume');
        },
        onAdFailedToLoad: (e) {
          _loadingOpen = false;
          result('app_open', 'resume', error: e.code);
        },
      ),
    );
  }

  /// The student came back: an app-open ad when they were away at least the level's minutes (never over an exam,
  /// checkout or right after another full-screen ad).
  void resumed() {
    final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
    _pausedAt = null;
    final c = _c;
    final ad = _open;
    if (ad == null || c.appOpenAfterMin <= 0 || away.inMinutes < c.appOpenAfterMin || AdsGate.blocked || _recentFull) return;
    _open = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => log('app_open', 'resume'),
      onAdClicked: (_) => log('app_open', 'resume', click: true),
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _lastFull = DateTime.now();
      },
      onAdFailedToShowFullScreenContent: (a, _) => a.dispose(),
    );
    _lastFull = DateTime.now();
    ad.show();
  }
}

/// The result of watching a rewarded video: [granted] = the reward is given; [counted] = one more video counted toward a
/// reward that needs several ([count] of [need]).
class AdReward {
  const AdReward({this.granted = false, this.counted = false, this.count = 0, this.need = 0});
  final bool granted, counted;
  final int count, need;
  static const none = AdReward();
}

/// "Watch to earn" (rewarded video, or a skippable "earn" video at a break when [interstitial] is true). The server
/// makes a nonce, AdMob tells the server the video was watched (server-side verification), and only then is the reward
/// given or counted.
Future<AdReward> watchForReward(
  BuildContext context,
  WidgetRef ref, {
  required String kind,
  String? itemRef,
  String placement = '',
  bool interstitial = false,
}) async {
  final c = ref.read(adsConfigProvider).value ?? AdsConfig.off;
  if (AdsGate.blocked || !c.format(interstitial ? 'rewarded_interstitial' : 'rewarded')) return AdReward.none;
  final sb = ref.read(supabaseProvider);
  final uid = sb.auth.currentUser?.id;
  if (uid == null) return AdReward.none;
  Map<String, dynamic> start;
  try {
    start = Map<String, dynamic>.from(await sb.rpc('ad_reward_start', params: {'p_kind': kind, 'p_ref': itemRef}) as Map);
  } catch (_) {
    return AdReward.none;
  }
  if (start['ok'] != true) {
    if (context.mounted) {
      final why = start['why'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            why == 'cap'
                ? 'You have watched all your reward videos for today. Go Premium for no limits and no ads.'
                : why == 'xp_cap'
                ? 'You have earned all your XP from videos for today. Come back tomorrow.'
                : why == 'full'
                ? 'You already have the most streak freezes you can hold.'
                : 'Watching for a reward is not available right now.',
          ),
        ),
      );
    }
    return AdReward.none;
  }
  final nonce = '${start['nonce']}';
  final test = start['test'] == true;
  final done = Completer<bool>();
  var earned = false;
  final ssv = ServerSideVerificationOptions(userId: uid, customData: nonce);
  FullScreenContentCallback<T> callbacks<T extends AdWithoutView>() => FullScreenContentCallback<T>(
    onAdShowedFullScreenContent: (_) => Ads.instance.log(interstitial ? 'rewarded' : 'rewarded', placement),
    onAdClicked: (_) => Ads.instance.log('rewarded', placement, click: true),
    onAdDismissedFullScreenContent: (a) {
      a.dispose();
      Ads.instance._lastFull = DateTime.now();
      if (!done.isCompleted) done.complete(earned);
    },
    onAdFailedToShowFullScreenContent: (a, _) {
      a.dispose();
      if (!done.isCompleted) done.complete(false);
    },
  );
  void failed(LoadAdError e) {
    Ads.instance.result('rewarded', placement, error: e.code);
    if (!done.isCompleted) done.complete(false);
  }

  if (interstitial) {
    await RewardedInterstitialAd.load(
      adUnitId: c.unit('rewarded_interstitial'),
      request: c.request,
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) async {
          await ad.setServerSideOptions(ssv);
          ad.fullScreenContentCallback = callbacks<RewardedInterstitialAd>();
          await ad.show(onUserEarnedReward: (_, _) => earned = true);
        },
        onAdFailedToLoad: failed,
      ),
    );
  } else {
    await RewardedAd.load(
      adUnitId: c.unit('rewarded'),
      request: c.request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) async {
          await ad.setServerSideOptions(ssv);
          ad.fullScreenContentCallback = callbacks<RewardedAd>();
          await ad.show(onUserEarnedReward: (_, _) => earned = true);
        },
        onAdFailedToLoad: failed,
      ),
    );
  }
  if (!await done.future) return AdReward.none;
  // The server gives (or counts) the reward when AdMob's signed callback arrives (usually a few seconds).
  for (var i = 0; i < 12; i++) {
    try {
      final st = Map<String, dynamic>.from(await sb.rpc('ad_reward_status', params: {'p_nonce': nonce, 'p_test_claim': test}) as Map);
      final s = st['status'];
      if (s == 'granted' || s == 'counted') {
        ref.invalidate(adsConfigProvider);
        return AdReward(granted: s == 'granted', counted: s == 'counted', count: (st['count'] as num?)?.toInt() ?? 0, need: (st['need'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  }
  return AdReward.none;
}

/// Older callers: true when the reward was given.
Future<bool> watchToUnlock(BuildContext context, WidgetRef ref, {required String kind, String? itemRef, String placement = ''}) async =>
    (await watchForReward(context, ref, kind: kind, itemRef: itemRef, placement: placement)).granted;

/// A skippable "earn XP" video offered at a break (rewarded interstitial; AdMob requires an intro the student can skip).
/// Only when the level offers it at [spot] and XP videos are left today.
Future<void> offerEarnVideo(BuildContext context, WidgetRef ref, String spot) async {
  final c = ref.read(adsConfigProvider).value ?? AdsConfig.off;
  if (AdsGate.blocked || !c.earnSpots.contains(spot) || c.xpLeft <= 0 || c.rewardedLeft <= 0 || Ads.instance._recentFull) return;
  final xp = c.reward('xp_amount') > 0 ? c.reward('xp_amount') : 5;
  final need = c.reward('xp_ads') > 1 ? c.reward('xp_ads') : 1;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => _EarnCountdown(xp: xp, need: need, progress: c.xpProgress),
  );
  if (go != true || !context.mounted) return;
  final r = await watchForReward(context, ref, kind: 'xp', placement: 'earn_$spot', interstitial: true);
  if (!context.mounted) return;
  if (r.granted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('+$xp XP added to your wallet.')));
  } else if (r.counted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r.count} of ${r.need} videos watched. ${r.need - r.count} more for +$xp XP.')));
  }
}

class _EarnCountdown extends StatefulWidget {
  const _EarnCountdown({required this.xp, required this.need, required this.progress});
  final int xp, need, progress;
  @override
  State<_EarnCountdown> createState() => _EarnCountdownState();
}

class _EarnCountdownState extends State<_EarnCountdown> {
  int _left = 5;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 1) {
        t.cancel();
        Navigator.of(context).pop(true);
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Earn +${widget.xp} XP'),
    content: Text(
      widget.need > 1
          ? 'Watch a short video (${widget.progress + 1} of ${widget.need}) to earn ${widget.xp} XP. It starts in $_left s.'
          : 'Watch a short video to earn ${widget.xp} XP. It starts in $_left s.',
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No thanks')),
      FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Watch now')),
    ],
  );
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
          Ads.instance.result('banner', widget.screen);
          if (mounted) setState(() => _ready = true);
        },
        onAdImpression: (_) => Ads.instance.log('banner', widget.screen),
        onAdClicked: (_) => Ads.instance.log('banner', widget.screen, click: true),
        onAdFailedToLoad: (ad, e) {
          Ads.instance.result('banner', widget.screen, error: e.code);
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  HouseAd? _house;
  bool _decided = false;

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(adsConfigProvider).value ?? AdsConfig.off;
    if (!c.bannerOn(widget.screen) || AdsGate.blocked) return const SizedBox.shrink();
    // Our own brand campaigns take their share of this slot (decided once per banner).
    final houses = ref.watch(houseAdsProvider);
    if (!_decided && !houses.isLoading) {
      _decided = true;
      _house = House.pick('banner', list: houses.value ?? const []);
    }
    if (!_decided) return const SizedBox.shrink();
    if (_house != null) return HouseBanner(ad: _house!);
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
  HouseAd? _house;
  bool _decided = false;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(adsConfigProvider).value ?? AdsConfig.off;
    if (!c.format('native') || AdsGate.blocked) return const SizedBox.shrink();
    final houses = ref.watch(houseAdsProvider);
    if (!_decided && !houses.isLoading) {
      _decided = true;
      _house = House.pick('card', list: houses.value ?? const []);
    }
    if (!_decided) return const SizedBox.shrink();
    if (_house != null) return HouseCard(ad: _house!);
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
          Ads.instance.result('native', widget.placement);
          if (mounted) setState(() => _ready = true);
        },
        onAdImpression: (_) => Ads.instance.log('native', widget.placement),
        onAdClicked: (_) => Ads.instance.log('native', widget.placement, click: true),
        onAdFailedToLoad: (ad, e) {
          Ads.instance.result('native', widget.placement, error: e.code);
          ad.dispose();
        },
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

/// Students who joined before we asked: the birth year is asked once and must be answered to go on (personalised ads
/// only for 18+, non-personalised 13-17, child treatment under 13). New students give it during profile setup.
bool _askingBirthYear = false;
Future<void> askBirthYearOnce(BuildContext context, WidgetRef ref) async {
  final c = ref.read(adsConfigProvider).value ?? AdsConfig.off;
  if (!c.askBirthYear || _askingBirthYear) return;
  _askingBirthYear = true;
  try {
    final now = DateTime.now().year;
    int? picked;
    var saving = false;
    String? err;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (ctx, set) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('What year were you born?', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  const Text('We ask once, so what you see suits your age. Students under 18 never get ads based on what they do.'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: picked,
                    menuMaxHeight: 360,
                    decoration: const InputDecoration(labelText: 'Birth year'),
                    items: [for (var y = now - 8; y >= now - 60; y--) DropdownMenuItem(value: y, child: Text('$y'))],
                    onChanged: (v) => set(() => picked = v),
                  ),
                  if (err != null) ...[const SizedBox(height: 8), Text(err!, style: TextStyle(color: Theme.of(ctx).colorScheme.error))],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: picked == null || saving
                        ? null
                        : () async {
                            set(() {
                              saving = true;
                              err = null;
                            });
                            try {
                              await ref.read(supabaseProvider).rpc('set_birth_year', params: {'p_year': picked});
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (_) {
                              set(() {
                                saving = false;
                                err = 'Could not save. Check your internet and try again.';
                              });
                            }
                          },
                    child: Text(saving ? 'Saving…' : 'Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    ref.invalidate(adsConfigProvider);
  } finally {
    _askingBirthYear = false;
  }
}

/// For logs: the pending counts (tests).
@visibleForTesting
String debugPendingAds() => jsonEncode(Ads.instance._pending);

/// Ultra's random break pop-ups: sometimes a break ad when the student moves to another screen (never inside a task;
/// the red-line screens block it). Added to the router's observers.
class AdsRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && previousRoute != null) {
      Future<void>.delayed(const Duration(milliseconds: 600), () => Ads.instance.breakAt('random'));
    }
  }
}

/// Sticky banners: wrap the whole app; a banner stays at the top and/or bottom while the student scrolls. Hidden on
/// red-line screens (exam, CBT, challenge, checkout), for Premium and when the level has no sticky banner.
class StickyAds extends ConsumerWidget {
  const StickyAds({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(adsConfigProvider).value ?? AdsConfig.off;
    final where = c.sticky;
    if (where == 'off') return child;
    return ValueListenableBuilder<int>(
      valueListenable: AdsGate.notifier,
      builder: (context, blocked, _) {
        if (blocked > 0) return child;
        final top = where == 'top' || where == 'both', bottom = where == 'bottom' || where == 'both';
        final pad = MediaQuery.paddingOf(context);
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              // A small gap keeps the banner away from the app's own buttons (AdMob: no ads right next to buttons).
              if (top)
                Padding(
                  padding: EdgeInsets.only(top: pad.top, bottom: 6),
                  child: const _StickyBanner(slot: 'sticky_top'),
                ),
              Expanded(
                child: MediaQuery.removePadding(context: context, removeTop: top, removeBottom: bottom, child: child),
              ),
              if (bottom)
                Padding(
                  padding: EdgeInsets.only(top: 6, bottom: pad.bottom),
                  child: const _StickyBanner(slot: 'sticky_bottom'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StickyBanner extends ConsumerStatefulWidget {
  const _StickyBanner({required this.slot});
  final String slot;
  @override
  ConsumerState<_StickyBanner> createState() => _StickyBannerState();
}

class _StickyBannerState extends ConsumerState<_StickyBanner> {
  BannerAd? _ad;
  bool _ready = false;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(adsConfigProvider).value ?? AdsConfig.off;
    _ad ??= BannerAd(
      adUnitId: c.unit('banner'),
      size: AdSize.banner,
      request: c.request,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          Ads.instance.result('banner', widget.slot);
          if (mounted) setState(() => _ready = true);
        },
        onAdImpression: (_) => Ads.instance.log('banner', widget.slot),
        onAdClicked: (_) => Ads.instance.log('banner', widget.slot, click: true),
        onAdFailedToLoad: (ad, e) {
          Ads.instance.result('banner', widget.slot, error: e.code);
          ad.dispose();
        },
      ),
    )..load();
    if (!_ready) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      height: _ad!.size.height.toDouble(),
      child: Center(
        child: SizedBox(
          width: _ad!.size.width.toDouble(),
          child: AdWidget(ad: _ad!),
        ),
      ),
    );
  }
}
