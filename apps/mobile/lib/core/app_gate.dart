import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/theme.dart';
import '../theme/tokens.g.dart';
import '../ui/kit.dart';
import '../widgets/phosphor.g.dart';
import 'config.dart';
import 'connectivity.dart';
import 'providers.dart';
import 'updater.dart';

// Updates, maintenance and no-internet mode (owner, 14 Nov 2026).
//  • Maintenance (Admin → Settings): a calm full screen with the admin's message and "back by" time; it lifts by itself
//    when the admin switches it off. Staff (not tutors) keep using the app so they can test.
//  • Play Store app: when Google Play has a newer version, a pop-up offers it and opens the Play Store. The admin can make
//    it a must ("force"), or set a minimum build that every app (Play or website) must reach.
//  • No internet: a small banner at the top while offline and a green "Back online" when it returns.

const _playId = 'com.solutiontee.cbt';

/// The server's rules for this app: maintenance, update rules and whether this person is staff. Offline (or an old
/// server) → no rules, so students can keep using downloaded tests.
final appGateProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final j = await ref.read(supabaseProvider).rpc('app_gate').timeout(const Duration(seconds: 8));
    return Map<String, dynamic>.from(j as Map);
  } catch (_) {
    return const {};
  }
});

/// This app's build number (versionCode: minutes since 1970, set when GitHub builds it). 0 if unknown.
final myBuildProvider = FutureProvider<int>((ref) => Updater.myCode());

/// Google Play has a newer version of this (Play Store) app. null: none, not a Play install, or Play not reachable.
final playUpdateProvider = FutureProvider<AppUpdateInfo?>((ref) async {
  if (appFlavor != 'play' || !Platform.isAndroid) return null;
  try {
    final info = await InAppUpdate.checkForUpdate().timeout(const Duration(seconds: 10));
    return info.updateAvailability == UpdateAvailability.updateAvailable ? info : null;
  } catch (_) {
    return null;
  }
});

Map<String, dynamic> _map(Object? o) => o is Map ? Map<String, dynamic>.from(o) : const {};

/// Opens this app's page on Google Play (the Play Store app, else the website).
Future<void> openPlayStore() async {
  final ok = await launchUrl(Uri.parse('market://details?id=$_playId'), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok) await launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=$_playId'), mode: LaunchMode.externalApplication);
}

/// Wraps the whole app (inside MaterialApp): maintenance and forced updates replace every screen; the update pop-up and
/// the offline banner sit on top.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> with WidgetsBindingObserver {
  Timer? _poll;
  int? _shownFor; // the Play version the pop-up was shown for in this session
  bool _popup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Every few minutes so maintenance (or a forced update) reaches people already in the app.
    _poll = Timer.periodic(const Duration(minutes: 5), (_) => ref.invalidate(appGateProvider));
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      ref.invalidate(appGateProvider);
      ref.invalidate(playUpdateProvider);
    }
  }

  Future<void> _maybePopup(AppUpdateInfo info) async {
    final v = info.availableVersionCode ?? 0;
    if (_shownFor == v) return;
    _shownFor = v;
    if (await _Snooze.recently(v)) return;
    if (mounted) setState(() => _popup = true);
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(appGateProvider).value ?? const {};
    final build = ref.watch(myBuildProvider).value ?? 0;
    final play = ref.watch(playUpdateProvider).value;
    // Back online: fetch the rules again.
    ref.listen(onlineProvider, (prev, next) {
      if (prev?.value == false && next.value == true) ref.invalidate(appGateProvider);
    });

    final m = _map(g['maintenance']);
    final staffPass = g['staff'] == true && m['staff_bypass'] != false;
    if (m['enabled'] == true && !staffPass) {
      return MaintenanceScreen(
        message: m['message'] as String?,
        until: DateTime.tryParse('${m['until'] ?? ''}')?.toLocal(),
        onRetry: () => ref.invalidate(appGateProvider),
      );
    }

    final pu = _map(g['play_update']);
    final minBuild = (g['min_build'] as num?)?.toInt() ?? 0;
    final isPlay = appFlavor == 'play';
    // A developer build (versionCode 1) is never blocked.
    final tooOld = build >= 1000000 && minBuild > build;
    if (isPlay && (tooOld || (play != null && pu['force'] == true))) {
      return PlayUpdateScreen(notes: '${pu['notes'] ?? ''}');
    }
    if (isPlay && play != null && pu['prompt'] != false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePopup(play));
    }

    return Stack(
      children: [
        widget.child,
        const _OfflineBanner(),
        if (_popup && play != null)
          Positioned.fill(
            child: UpdatePopup(
              notes: '${pu['notes'] ?? ''}',
              onUpdate: () {
                setState(() => _popup = false);
                openPlayStore();
              },
              onLater: () {
                setState(() => _popup = false);
                _Snooze.save(play.availableVersionCode ?? 0);
              },
            ),
          ),
      ],
    );
  }
}

/// "Later" hides the pop-up for that Play version for a day.
abstract final class _Snooze {
  static Future<File> _file() async => File('${(await getApplicationSupportDirectory()).path}/update_snooze.json');

  static Future<bool> recently(int version) async {
    try {
      final j = jsonDecode(await (await _file()).readAsString()) as Map;
      final at = DateTime.tryParse('${j['at']}');
      return j['v'] == version && at != null && DateTime.now().difference(at) < const Duration(hours: 24);
    } catch (_) {
      return false;
    }
  }

  static Future<void> save(int version) async {
    try {
      await (await _file()).writeAsString(jsonEncode({'v': version, 'at': DateTime.now().toIso8601String()}));
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------------------------------- pieces

/// The deep navy-to-blue stage behind the full screens, with two soft glows that drift slowly.
class _Stage extends StatelessWidget {
  const _Stage({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    Widget glow(Color c, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [c.withValues(alpha: .35), c.withValues(alpha: 0)]),
      ),
    );
    Widget drift(Widget w, double dx, double dy, int ms) =>
        rm ? w : w.animate(onPlay: (a) => a.repeat(reverse: true)).move(begin: Offset.zero, end: Offset(dx, dy), duration: ms.ms, curve: Curves.easeInOut);
    return Scaffold(
      backgroundColor: Palette.navy900,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.navy950, Palette.navy900, Color(0xFF13306A)]),
              ),
            ),
          ),
          Positioned(top: -80, right: -60, child: drift(glow(Palette.blue500, 280), -30, 30, 5200)),
          Positioned(bottom: -100, left: -80, child: drift(glow(Palette.gold400, 300), 30, -24, 6400)),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

/// A round badge with a soft halo that breathes.
class _Halo extends StatelessWidget {
  const _Halo({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    final ring = Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.gold400.withValues(alpha: .10)),
    );
    return SizedBox(
      width: 170,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          rm ? ring : ring.animate(onPlay: (a) => a.repeat(reverse: true)).scaleXY(begin: .88, end: 1.06, duration: 1800.ms, curve: Curves.easeInOut),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .08),
              border: Border.all(color: Colors.white.withValues(alpha: .14)),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------- maintenance

/// Maintenance: two gears turning, the admin's message, the "back by" time, and Try again (it also checks by itself).
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key, this.message, this.until, required this.onRetry});
  final String? message;
  final DateTime? until;
  final VoidCallback onRetry;
  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  Timer? _check;

  @override
  void initState() {
    super.initState();
    _check = Timer.periodic(const Duration(seconds: 30), (_) => widget.onRetry());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.reduceMotion ? _spin.stop() : _spin.repeat();
  }

  @override
  void dispose() {
    _check?.cancel();
    _spin.dispose();
    super.dispose();
  }

  String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final today = DateUtils.isSameDay(t, DateTime.now());
    final when = '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
    return today ? when : '$when on ${t.day}/${t.month}';
  }

  @override
  Widget build(BuildContext context) {
    final msg = (widget.message ?? '').trim();
    final until = widget.until;
    return _Stage(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Halo(
                child: AnimatedBuilder(
                  animation: _spin,
                  builder: (_, _) => SizedBox(
                    width: 80,
                    height: 70,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 4,
                          child: Transform.rotate(
                            angle: _spin.value * 2 * math.pi,
                            child: Icon(PhosphorIcons.gearSix(PhosphorIconsStyle.fill), size: 50, color: Palette.gold400),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Transform.rotate(
                            angle: -_spin.value * 2 * math.pi * 1.6,
                            child: Icon(PhosphorIcons.gearSix(PhosphorIconsStyle.fill), size: 34, color: Palette.blue300),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).scaleXY(begin: .9, end: 1, curve: Curves.easeOutBack),
              const Gap(Space.s5),
              Text('We are making SolutionTee better', textAlign: TextAlign.center, style: context.ty.h1.col(Colors.white)),
              const Gap(Space.s3),
              Text(
                msg.isEmpty ? 'We are doing some quick work on the app. Please check back soon.' : msg,
                textAlign: TextAlign.center,
                style: context.ty.body.col(const Color(0xFFC9D6EA)),
              ),
              if (until != null && until.isAfter(DateTime.now())) ...[
                const Gap(Space.s4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(99)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIcons.clock(PhosphorIconsStyle.fill), size: 16, color: Palette.gold300),
                      const SizedBox(width: 6),
                      Text('Back by ${_clock(until)}', style: context.ty.sm.bold.col(Colors.white)),
                    ],
                  ),
                ),
              ],
              const Gap(Space.s6),
              Btn('Try again', kind: BtnKind.accent, leading: PhosphorIcons.arrowClockwise(), onPressed: widget.onRetry),
              const Gap(Space.s3),
              Text('The app opens by itself as soon as we are done.', textAlign: TextAlign.center, style: context.ty.cap.col(const Color(0xFF9FB0CC))),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------- updates

/// The forced update for the Play Store app: the rocket, why, and one button to Google Play.
class PlayUpdateScreen extends StatelessWidget {
  const PlayUpdateScreen({super.key, this.notes = ''});
  final String notes;
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    Widget icon = Icon(PhosphorIcons.arrowCircleUp(PhosphorIconsStyle.fill), size: 64, color: Palette.gold400);
    if (!rm) icon = icon.animate(onPlay: (a) => a.repeat(reverse: true)).moveY(begin: 4, end: -6, duration: 1200.ms, curve: Curves.easeInOut);
    return _Stage(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Halo(child: icon).animate().fadeIn(duration: 400.ms).scaleXY(begin: .9, end: 1, curve: Curves.easeOutBack),
              const Gap(Space.s5),
              Text('Time to update', textAlign: TextAlign.center, style: context.ty.h1.col(Colors.white)),
              const Gap(Space.s3),
              Text(
                'A new version of SolutionTee CBT is on Google Play. Update to keep practising. Your account, progress and saved tests stay.',
                textAlign: TextAlign.center,
                style: context.ty.body.col(const Color(0xFFC9D6EA)),
              ),
              if (notes.trim().isNotEmpty) ...[const Gap(Space.s4), _Notes(notes)],
              const Gap(Space.s6),
              _PlayButton(onTap: openPlayStore),
              const Gap(Space.s3),
              Text('It takes about a minute.', textAlign: TextAlign.center, style: context.ty.cap.col(const Color(0xFF9FB0CC))),
            ],
          ),
        ),
      ),
    );
  }
}

/// "What's new" lines from the admin, each with a tick.
class _Notes extends StatelessWidget {
  const _Notes(this.text, {this.dark = true});
  final String text;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final lines = text.split(RegExp(r'\n+')).map((l) => l.replaceFirst(RegExp(r'^[\-•*]\s*'), '').trim()).where((l) => l.isNotEmpty).take(5).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(color: dark ? Colors.white.withValues(alpha: .07) : context.c.surfaceSunken, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("What's new", style: context.ty.cap.bold.col(dark ? Palette.gold300 : Palette.gold600)),
          const SizedBox(height: 6),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), size: 16, color: dark ? Palette.green300 : context.c.success),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l, style: context.ty.sm.col(dark ? Colors.white : context.c.text))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The gold "Update on Google Play" button with the Play logo and a soft shine.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    Widget b = Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: Palette.gold400,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Palette.gold400.withValues(alpha: .35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.googlePlayLogo(PhosphorIconsStyle.fill), size: 22, color: Palette.navy900),
          const SizedBox(width: 10),
          Text('Update on Google Play', style: context.ty.label.bold.col(Palette.navy900)),
        ],
      ),
    );
    if (!context.reduceMotion) {
      b = b.animate(onPlay: (a) => a.repeat()).shimmer(delay: 2200.ms, duration: 900.ms, color: Colors.white.withValues(alpha: .5));
    }
    return Semantics(
      button: true,
      label: 'Update on Google Play',
      child: GestureDetector(onTap: onTap, child: b),
    );
  }
}

/// The newest Play Store version name ("1.4.0"), from our website, for the pop-up. null if not known.
final playVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final r = await http.get(Uri.parse('${Config.apiBase}/api/app/latest?channel=play')).timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) return null;
    final v = '${(jsonDecode(r.body) as Map)['version'] ?? ''}'.split('-').first.trim();
    return v.isEmpty ? null : v;
  } catch (_) {
    return null;
  }
});

/// The "new version" pop-up (owner, 14 Nov 2026, after an example he liked): a big "Discover a new version" title with
/// the version in gold, a rocket taking off on the right, a short friendly note, and Ignore / Update now side by side.
/// Update now → Google Play; Ignore → hidden for a day.
class UpdatePopup extends ConsumerWidget {
  const UpdatePopup({super.key, required this.onUpdate, required this.onLater, this.notes = '', this.version});
  final VoidCallback onUpdate, onLater;
  final String notes;

  /// Shown after the app name; when null the newest Play version is looked up.
  final String? version;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rm = context.reduceMotion;
    final c = context.c;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final v = version ?? ref.watch(playVersionProvider).value;
    final body = context.ty.body.col(c.textMuted);
    final card = Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(horizontal: Space.s5),
      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s5, Space.s5, Space.s5),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF141C2E) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: dark ? Colors.white.withValues(alpha: .06) : c.border),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 16))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('Discover a\nnew version', style: context.ty.h1.copyWith(height: 1.15)),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'SolutionTee CBT ', style: context.ty.label.bold),
                            TextSpan(text: v ?? 'New', style: context.ty.label.bold.col(dark ? Palette.gold400 : Palette.blue600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const _RocketArt(size: 130),
              ],
            ),
            const SizedBox(height: Space.s4),
            Text('Dear student,', style: context.ty.body.col(c.text)),
            const SizedBox(height: 10),
            Text('This is an important update. Update now to get the newest features, faster tests and a smoother experience.', style: body),
            if (notes.trim().isNotEmpty) ...[const SizedBox(height: Space.s3), _Notes(notes, dark: false)],
            const SizedBox(height: 10),
            Text('Tap Update now to get it from Google Play.', style: body),
            const SizedBox(height: Space.s5),
            Row(
              children: [
                Expanded(
                  child: _PopupButton(
                    'Ignore',
                    bg: dark ? Palette.blue600.withValues(alpha: .22) : Palette.blue50,
                    fg: dark ? Palette.blue300 : Palette.blue700,
                    onTap: onLater,
                  ),
                ),
                const SizedBox(width: Space.s3),
                Expanded(
                  child: _PopupButton('Update now', bg: Palette.gold400, fg: Palette.navy900, onTap: onUpdate, shine: !rm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final barrier = GestureDetector(
      onTap: onLater,
      child: const ColoredBox(color: Color(0xA6000000), child: SizedBox.expand()),
    );
    return Stack(
      children: [
        rm ? barrier : barrier.animate().fadeIn(duration: 260.ms),
        Center(
          child: rm
              ? card
              : card
                    .animate()
                    .fadeIn(duration: 260.ms)
                    .slideY(begin: .12, end: 0, duration: 460.ms, curve: Curves.easeOutCubic)
                    .scaleXY(begin: .94, end: 1, duration: 460.ms, curve: Curves.easeOutBack),
        ),
      ],
    );
  }
}

class _PopupButton extends StatelessWidget {
  const _PopupButton(this.text, {required this.bg, required this.fg, required this.onTap, this.shine = false});
  final String text;
  final Color bg, fg;
  final VoidCallback onTap;
  final bool shine;
  @override
  Widget build(BuildContext context) {
    Widget b = Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
      child: Text(text, style: context.ty.label.bold.copyWith(fontSize: 17).col(fg)),
    );
    if (shine) b = b.animate(onPlay: (a) => a.repeat()).shimmer(delay: 2400.ms, duration: 900.ms, color: Colors.white.withValues(alpha: .5));
    return Semantics(
      button: true,
      label: text,
      child: GestureDetector(onTap: onTap, child: b),
    );
  }
}

/// A rocket lifting off from a soft blob, with small rings, a triangle and a squiggle drifting around it.
class _RocketArt extends StatelessWidget {
  const _RocketArt({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final line = dark ? const Color(0xFFC9D6EA) : Palette.navy400;
    Widget ring(double d) => Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: line, width: 2),
      ),
    );
    Widget float(Widget w, {double dy = 4, int ms = 1600, int delay = 0}) =>
        rm ? w : w.animate(onPlay: (a) => a.repeat(reverse: true), delay: delay.ms).moveY(begin: -dy, end: dy, duration: ms.ms, curve: Curves.easeInOut);
    Widget rocket = Transform.rotate(
      angle: .62,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.rocket(PhosphorIconsStyle.fill), size: size * .52, color: Palette.gold400),
          // Flame.
          Transform.translate(
            offset: Offset(0, -size * .06),
            child: Container(
              width: size * .1,
              height: size * .14,
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF8A3D), Color(0x00FF8A3D)]),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(99)),
              ),
            ),
          ),
        ],
      ),
    );
    if (!rm) {
      rocket = rocket
          .animate(onPlay: (a) => a.repeat(reverse: true))
          .move(begin: const Offset(-3, 4), end: const Offset(3, -5), duration: 1300.ms, curve: Curves.easeInOut);
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _Blob(dark ? const Color(0xFF26314A) : Palette.blue50, dark ? const Color(0xFF1D2740) : Palette.blue100)),
          ),
          Positioned(left: size * .16, top: size * .02, child: float(ring(size * .1), delay: 200)),
          Positioned(right: -4, top: size * .3, child: float(ring(size * .14), dy: 5, ms: 1900)),
          Positioned(left: 0, bottom: size * .02, child: float(ring(size * .09), ms: 1400, delay: 500)),
          Positioned(
            left: size * .02,
            top: size * .3,
            child: float(CustomPaint(size: Size(size * .14, size * .08), painter: _Shape(line, triangle: false)), dy: 3, ms: 1700),
          ),
          Positioned(
            left: size * .18,
            top: size * .5,
            child: float(CustomPaint(size: Size.square(size * .13), painter: _Shape(line, triangle: true)), dy: 3, ms: 2100, delay: 300),
          ),
          Positioned(left: size * .26, top: size * .04, child: rocket),
        ],
      ),
    );
  }
}

/// A small outlined triangle or squiggle for the rocket picture.
class _Shape extends CustomPainter {
  _Shape(this.color, {required this.triangle});
  final Color color;
  final bool triangle;
  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    if (triangle) {
      canvas.drawPath(
        Path()
          ..moveTo(s.width * .9, s.height * .1)
          ..lineTo(s.width * .1, s.height * .5)
          ..lineTo(s.width * .9, s.height * .9)
          ..close(),
        paint,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(0, s.height * .5)
          ..quadraticBezierTo(s.width * .25, 0, s.width * .5, s.height * .5)
          ..quadraticBezierTo(s.width * .75, s.height, s.width, s.height * .5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Shape old) => old.color != color;
}

/// An organic blob shape behind the rocket.
class _Blob extends CustomPainter {
  _Blob(this.a, this.b);
  final Color a, b;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(s.width * .52, s.height * .06)
      ..cubicTo(s.width * .82, s.height * .02, s.width * 1.0, s.height * .28, s.width * .95, s.height * .55)
      ..cubicTo(s.width * .9, s.height * .85, s.width * .62, s.height * 1.0, s.width * .4, s.height * .92)
      ..cubicTo(s.width * .18, s.height * .84, s.width * .12, s.height * .6, s.width * .2, s.height * .38)
      ..cubicTo(s.width * .27, s.height * .18, s.width * .36, s.height * .09, s.width * .52, s.height * .06)
      ..close();
    canvas.drawPath(p, Paint()..shader = LinearGradient(colors: [a, b], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(Offset.zero & s));
  }

  @override
  bool shouldRepaint(covariant _Blob old) => old.a != a || old.b != b;
}

// ---------------------------------------------------------------------------------------------------- offline

/// A small pill at the top while offline ("No internet · downloaded tests still work"), and a green "Back online" for a
/// moment when the connection returns.
class _OfflineBanner extends ConsumerStatefulWidget {
  const _OfflineBanner();
  @override
  ConsumerState<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<_OfflineBanner> {
  bool _back = false;
  bool _small = false;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(onlineProvider, (prev, next) {
      _t?.cancel();
      if (next.value == true && prev?.value == false) {
        setState(() => _back = true);
        _t = Timer(const Duration(milliseconds: 2500), () => mounted ? setState(() => _back = false) : null);
      } else if (next.value == false) {
        // After a few seconds the banner shrinks to a small "Offline" chip so it does not cover the screen.
        setState(() => _small = false);
        _t = Timer(const Duration(seconds: 5), () => mounted ? setState(() => _small = true) : null);
      }
    });
    final offline = ref.watch(onlineProvider).value == false;
    final show = offline || _back;
    final top = MediaQuery.paddingOf(context).top + 6;
    final pill = !show
        ? const SizedBox.shrink(key: ValueKey('none'))
        : Container(
            key: ValueKey(offline ? 'off$_small' : 'back'),
            padding: EdgeInsets.symmetric(horizontal: _small && offline ? 10 : 14, vertical: 7),
            decoration: BoxDecoration(
              color: offline ? Palette.navy800 : Palette.green600,
              borderRadius: BorderRadius.circular(99),
              boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  offline ? PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill) : PhosphorIcons.wifiHigh(PhosphorIconsStyle.fill),
                  size: 16,
                  color: offline ? Palette.gold300 : Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  offline ? (_small ? 'Offline' : 'No internet · downloaded tests still work') : 'Back online',
                  style: context.ty.cap.bold.col(Colors.white),
                ),
              ],
            ),
          );
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      // Material gives the text its normal style: above the app's screens there is none, and Flutter then draws its
      // "missing style" double yellow underline (owner, 14 Nov 2026).
      child: IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: AnimatedSwitcher(
              duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, -.8), end: Offset.zero).animate(a),
                  child: child,
                ),
              ),
              child: pill,
            ),
          ),
        ),
      ),
    );
  }
}
