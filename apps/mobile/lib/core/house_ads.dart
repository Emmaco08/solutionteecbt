import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../widgets/r2_image.dart';
import 'ads.dart';
import 'providers.dart';

/// Our own ads (house ads / brand campaigns, D-105). A brand campaign takes a share of the ad slots the ads level
/// already has (it never adds slots): banners, cards, breaks, and video ads before / in the middle of / after our own
/// video lessons (AdMob cannot play inside our player). The server says which campaigns run for this student (never
/// Premium, never under 13) and counts views against the daily cap per student.
class HouseAd {
  HouseAd(this.j) : left = (j['left'] as num?)?.toInt() ?? 0;
  final Map<String, dynamic> j;
  int left;

  String get id => '${j['id']}';
  String get brand => '${j['brand'] ?? ''}';
  List<String> get placements => [for (final p in (j['placements'] as List? ?? const [])) '$p'];
  int get share => (j['share'] as num?)?.toInt() ?? 0;
  int get weight => math.max(1, (j['weight'] as num?)?.toInt() ?? 1);
  String? get link => _s('link');
  String get cta => _s('cta') ?? 'Learn more';
  String? get banner => _s('banner');
  String? get card => _s('card');
  String? get cardTitle => _s('card_title');
  String? get cardBody => _s('card_body');
  bool get breakVideo => j['break_kind'] == 'video';
  String? get breakFile => _s('break');
  String? get video => _s('video');
  int get skipAfter => (j['skip_after'] as num?)?.toInt() ?? 5;
  String? _s(String k) {
    final v = j[k];
    return v == null || '$v'.trim().isEmpty ? null : '$v';
  }

  /// The file this campaign shows in [placement] (null = it cannot show there).
  String? fileFor(String placement) => switch (placement) {
    'banner' => banner,
    'card' => card == null || cardTitle == null ? null : card,
    'break' => breakFile,
    _ => video,
  };
}

/// Running campaigns for this student (empty when ads are off, for Premium and under 13).
final houseAdsProvider = FutureProvider<List<HouseAd>>((ref) async {
  final c = await ref.watch(adsConfigProvider.future);
  if (!c.on) {
    House.remember(const []);
    return const [];
  }
  try {
    final j = await ref.read(supabaseProvider).rpc('house_ads').timeout(const Duration(seconds: 12));
    final list = [for (final x in (j as List? ?? const [])) HouseAd(Map<String, dynamic>.from(x as Map))];
    House.remember(list);
    return list;
  } catch (_) {
    House.remember(const []);
    return const [];
  }
});

/// The root navigator (full-screen house breaks open on it).
final rootNavKey = GlobalKey<NavigatorState>();

class House {
  static final _rand = math.Random();
  static List<HouseAd> _list = const [];

  /// Keeps the latest list for code without a WidgetRef (breaks from the router observer).
  static void remember(List<HouseAd> list) => _list = list;

  /// Picks a campaign for this slot: one that shows here, has views left today and has the file; then its share decides
  /// whether this slot is ours or AdMob's. Weighted when several brands run.
  static HouseAd? pick(String placement, {List<HouseAd>? list}) {
    final all = [
      for (final a in list ?? _list)
        if (a.placements.contains(placement) && a.left > 0 && a.fileFor(placement) != null) a,
    ];
    if (all.isEmpty) return null;
    final total = all.fold<int>(0, (t, a) => t + a.weight);
    var r = _rand.nextInt(total);
    HouseAd chosen = all.first;
    for (final a in all) {
      if (r < a.weight) {
        chosen = a;
        break;
      }
      r -= a.weight;
    }
    return _rand.nextInt(100) < chosen.share ? chosen : null;
  }

  static void view(HouseAd a, String placement) {
    a.left = math.max(0, a.left - 1);
    _log(a, placement, false);
  }

  static Future<void> click(HouseAd a, String placement) async {
    _log(a, placement, true);
    final l = a.link;
    if (l != null) await launchUrl(Uri.parse(l), mode: LaunchMode.externalApplication);
  }

  static void _log(HouseAd a, String placement, bool click) {
    Supabase.instance.client.rpc('house_ad_log', params: {'p_campaign': a.id, 'p_placement': placement, 'p_click': click}).ignore();
  }

  /// A full-screen house break (picture or video) or a video-lesson ad. Returns when it is closed.
  static Future<void> showFull(BuildContext context, HouseAd a, String placement) async {
    final video = placement != 'break' || a.breakVideo;
    view(a, placement);
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (_, _, _) => _HouseFull(ad: a, placement: placement, video: video, fileKey: a.fileFor(placement)!),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  /// A house break from code without a context (Ads.breakAt): opens on the root navigator.
  static Future<bool> breakNow(HouseAd a) async {
    final ctx = rootNavKey.currentContext;
    if (ctx == null) return false;
    await showFull(ctx, a, 'break');
    return true;
  }
}

/// A brand's banner (in place of an AdMob banner in this slot).
class HouseBanner extends ConsumerStatefulWidget {
  const HouseBanner({super.key, required this.ad});
  final HouseAd ad;
  @override
  ConsumerState<HouseBanner> createState() => _HouseBannerState();
}

class _HouseBannerState extends ConsumerState<HouseBanner> {
  @override
  void initState() {
    super.initState();
    House.view(widget.ad, 'banner');
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Semantics(
      button: true,
      label: 'Ad from ${widget.ad.brand}',
      child: GestureDetector(
        onTap: () => House.click(widget.ad, 'banner'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 6.4,
                child: R2Image(imageKey: widget.ad.banner!, fit: BoxFit.cover),
              ),
              const Positioned(top: 3, left: 3, child: _AdTag()),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A brand's card (in place of an AdMob card in this slot).
class HouseCard extends ConsumerStatefulWidget {
  const HouseCard({super.key, required this.ad});
  final HouseAd ad;
  @override
  ConsumerState<HouseCard> createState() => _HouseCardState();
}

class _HouseCardState extends ConsumerState<HouseCard> {
  @override
  void initState() {
    super.initState();
    House.view(widget.ad, 'card');
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.ad;
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => House.click(a, 'card'),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.dividerColor),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(width: 72, height: 72, child: R2Image(imageKey: a.card!, decodeWidth: 240)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _AdTag(),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(a.brand, style: t.textTheme.labelSmall, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(a.cardTitle ?? '', style: t.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (a.cardBody != null) Text(a.cardBody!, style: t.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (a.link != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF2B233), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      a.cta,
                      style: const TextStyle(color: Color(0xFF0B1F44), fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdTag extends StatelessWidget {
  const _AdTag();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(color: const Color(0xFFF2B233), borderRadius: BorderRadius.circular(4)),
    child: const Text(
      'Ad',
      style: TextStyle(color: Color(0xFF0B1F44), fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

/// Full-screen house ad: a picture or a short video, with "Skip in N" and the brand's button.
class _HouseFull extends ConsumerStatefulWidget {
  const _HouseFull({required this.ad, required this.placement, required this.video, required this.fileKey});
  final HouseAd ad;
  final String placement, fileKey;
  final bool video;
  @override
  ConsumerState<_HouseFull> createState() => _HouseFullState();
}

class _HouseFullState extends ConsumerState<_HouseFull> {
  VideoPlayerController? _v;
  Timer? _t;
  late int _left = widget.video ? widget.ad.skipAfter : math.max(3, widget.ad.skipAfter);
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 0) {
        t.cancel();
      } else {
        setState(() => _left--);
      }
    });
    if (widget.video) _startVideo();
  }

  Future<void> _startVideo() async {
    try {
      final url = await ref.read(apiProvider).signImage(widget.fileKey);
      final v = VideoPlayerController.networkUrl(Uri.parse(url));
      await v.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) {
        v.dispose();
        return;
      }
      v.addListener(() {
        final val = v.value;
        if (val.isInitialized && !val.isPlaying && val.duration > Duration.zero && val.position >= val.duration - const Duration(milliseconds: 300)) {
          _close();
        }
      });
      setState(() => _v = v);
      await v.play();
    } catch (_) {
      // No internet or the file is gone: never trap the student behind a broken ad.
      if (mounted) setState(() => _failed = true);
      _close();
    }
  }

  bool _closed = false;
  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _t?.cancel();
    _v?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.ad;
    final v = _v;
    final pad = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: _left <= 0 || _failed,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: widget.video
                  ? (v == null
                        ? const Center(child: CircularProgressIndicator())
                        : Center(
                            child: AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v)),
                          ))
                  : R2Image(imageKey: widget.fileKey, fit: BoxFit.contain, decodeWidth: 1080),
            ),
            Positioned(
              top: pad.top + 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  'Ad · ${a.brand}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Positioned(
              top: pad.top + 8,
              right: 8,
              child: _left > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: Text(widget.video ? 'Skip in $_left' : 'Close in $_left', style: const TextStyle(color: Colors.white)),
                    )
                  : TextButton.icon(
                      style: TextButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white, minimumSize: const Size(48, 48)),
                      onPressed: _close,
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(widget.video ? 'Skip' : 'Close'),
                    ),
            ),
            if (a.link != null)
              Positioned(
                left: 24,
                right: 24,
                bottom: pad.bottom + 24,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF2B233),
                    foregroundColor: const Color(0xFF0B1F44),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () {
                    _v?.pause();
                    House.click(a, widget.placement);
                  },
                  child: Text(a.cta, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
