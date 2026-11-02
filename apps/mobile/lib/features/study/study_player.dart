import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/api.dart';
import '../../data/study_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';

/// Plays one study video (D-057). Owns the controller so the normal and fullscreen views share it.
/// - Quality: 360p on mobile data or with data saver, 720p (when uploaded) on Wi-Fi. Drops to 360p by itself
///   after repeated stalls, and remembers the spot when switching.
/// - A dropped connection shows "Tap to retry", which asks for a fresh signed link and carries on from the spot.
/// - The screen stays awake while playing.
class StudyPlayer extends ChangeNotifier {
  StudyPlayer({required this.itemId, required this.repo, required this.hasHd, required this.dataSaver});
  final String itemId;
  final StudyRepo repo;
  final bool hasHd, dataSaver;

  VideoPlayerController? ctl;
  String quality = '360';
  double speed = 1;
  bool loading = true, disposed = false;
  String? error;

  /// One-off messages for the screen to show as a toast (e.g. "Switched to 360p").
  final message = ValueNotifier<String?>(null);

  final _stalls = <DateTime>[];
  DateTime? _stallStart;
  bool _wasPlaying = false;

  Future<void> start({Duration? at}) async {
    var q = '360';
    if (hasHd && !dataSaver) {
      final net = await Connectivity().checkConnectivity();
      if (net.contains(ConnectivityResult.wifi) || net.contains(ConnectivityResult.ethernet)) q = '720';
    }
    await open(q, at: at);
  }

  Future<void> open(String q, {Duration? at}) async {
    loading = true;
    error = null;
    notifyListeners();
    final old = ctl;
    final keep = at ?? old?.value.position;
    final playAfter = old == null || old.value.isPlaying || _wasPlaying;
    try {
      final url = await repo.fileUrl(itemId, q);
      final c = VideoPlayerController.networkUrl(Uri.parse(url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false));
      await c.initialize().timeout(const Duration(seconds: 40));
      if (disposed) {
        await c.dispose();
        return;
      }
      if (keep != null && keep > Duration.zero && keep < c.value.duration - const Duration(seconds: 3)) await c.seekTo(keep);
      await c.setPlaybackSpeed(speed);
      old?.removeListener(_watch);
      ctl = c;
      quality = q;
      loading = false;
      _stalls.clear();
      c.addListener(_watch);
      notifyListeners();
      await old?.dispose();
      if (playAfter) await c.play();
    } catch (e) {
      loading = false;
      error = e is ApiError ? e.message : 'The video could not load. Check your internet and tap to retry.';
      notifyListeners();
    }
  }

  void _watch() {
    final c = ctl;
    if (c == null) return;
    final v = c.value;
    if (v.hasError && error == null) {
      error = 'Connection lost. Tap to retry from ${clock(v.position.inSeconds)}.';
      WakelockPlus.disable();
      notifyListeners();
      return;
    }
    if (v.isPlaying != _wasPlaying) {
      _wasPlaying = v.isPlaying;
      v.isPlaying ? WakelockPlus.enable() : WakelockPlus.disable();
    }
    // Bad network: two stalls of 2.5 s+ within 45 s on HD → switch to 360p at the same spot.
    if (v.isBuffering && v.isPlaying) {
      _stallStart ??= DateTime.now();
    } else if (_stallStart != null) {
      final long = DateTime.now().difference(_stallStart!) > const Duration(milliseconds: 2500);
      _stallStart = null;
      if (long && quality == '720') {
        final now = DateTime.now();
        _stalls
          ..add(now)
          ..removeWhere((t) => now.difference(t) > const Duration(seconds: 45));
        if (_stalls.length >= 2) {
          message.value = 'Your network is slow, so we switched to 360p.';
          open('360');
        }
      }
    }
  }

  Future<void> retry() => open(quality);

  Future<void> setSpeed(double s) async {
    speed = s;
    await ctl?.setPlaybackSpeed(s);
    notifyListeners();
  }

  Future<void> seekBy(Duration d) async {
    final c = ctl;
    if (c == null) return;
    final to = c.value.position + d;
    await c.seekTo(to < Duration.zero ? Duration.zero : (to > c.value.duration ? c.value.duration : to));
  }

  @override
  void dispose() {
    disposed = true;
    ctl?.removeListener(_watch);
    ctl?.dispose();
    message.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}

/// The video with its controls: tap to show/hide, double-tap left/right to go back/forward 10 s (more taps add up),
/// hold for 2× speed, seek bar with the downloaded part shaded, speed, quality and fullscreen.
class StudyPlayerView extends StatefulWidget {
  const StudyPlayerView({super.key, required this.player, required this.title, this.fullscreen = false, this.placeholder});
  final StudyPlayer player;
  final String title;
  final bool fullscreen;

  /// Shown until the first frame (the thumbnail).
  final Widget? placeholder;

  @override
  State<StudyPlayerView> createState() => _StudyPlayerViewState();
}

class _StudyPlayerViewState extends State<StudyPlayerView> {
  bool _controls = true;
  Timer? _hide;
  int _skip = 0; // accumulated seconds for the double-tap bubble (negative = back)
  Timer? _skipReset;
  bool _boost = false;
  double? _scrub;

  StudyPlayer get p => widget.player;

  @override
  void initState() {
    super.initState();
    _autoHide();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _skipReset?.cancel();
    super.dispose();
  }

  void _autoHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && (p.ctl?.value.isPlaying ?? false)) setState(() => _controls = false);
    });
  }

  void _show() {
    setState(() => _controls = true);
    _autoHide();
  }

  void _toggle() {
    if (_controls) {
      _hide?.cancel();
      setState(() => _controls = false);
    } else {
      _show();
    }
  }

  void _doubleTap(TapDownDetails d, double width) {
    final forward = d.localPosition.dx > width / 2;
    final step = forward ? 10 : -10;
    setState(() => _skip = (_skip.sign == step.sign ? _skip : 0) + step);
    p.seekBy(Duration(seconds: step));
    HapticFeedback.selectionClick();
    _skipReset?.cancel();
    _skipReset = Timer(const Duration(milliseconds: 800), () => mounted ? setState(() => _skip = 0) : null);
  }

  Future<void> _playPause() async {
    final c = p.ctl;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
      _hide?.cancel();
      setState(() => _controls = true);
    } else {
      if (c.value.position >= c.value.duration - const Duration(milliseconds: 300)) await c.seekTo(Duration.zero);
      await c.play();
      _autoHide();
    }
  }

  Future<void> _speedSheet() async {
    _hide?.cancel();
    await showSheet<void>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Playback speed', style: ctx.ty.h3),
          const Gap(Space.s3),
          Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: [
              for (final s in const [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
                AppChip(
                  s == 1 ? 'Normal' : '$s×',
                  on: p.speed == s,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    p.setSpeed(s);
                  },
                ),
            ],
          ),
          const Gap(Space.s3),
          Text('Tip: hold the video to play at 2× until you let go.', style: ctx.ty.cap.col(ctx.c.textMuted)),
        ],
      ),
    );
    _autoHide();
  }

  Future<void> _qualitySheet() async {
    _hide?.cancel();
    await showSheet<void>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Video quality', style: ctx.ty.h3),
          const Gap(Space.s3),
          ListCard(
            children: [
              for (final (q, t, c) in [
                ('360', '360p · data saver', 'Smooth on slow networks, uses less data'),
                if (p.hasHd) ('720', '720p · HD', 'Sharper, best on Wi-Fi'),
              ])
                ListRow(
                  icon: q == '720' ? PhosphorIcons.highDefinition(PhosphorIconsStyle.fill) : PhosphorIcons.cellSignalLow(PhosphorIconsStyle.fill),
                  tone: p.quality == q ? Tone.blue : Tone.neutral,
                  title: t,
                  caption: c,
                  trailing: p.quality == q ? Icon(PhosphorIcons.check(PhosphorIconsStyle.fill), color: ctx.c.secondary) : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (q != p.quality) p.open(q);
                  },
                ),
            ],
          ),
        ],
      ),
    );
    _autoHide();
  }

  Future<void> _fullscreen() async {
    if (widget.fullscreen) {
      Navigator.of(context).maybePop();
      return;
    }
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => _FullscreenPlayer(player: p, title: widget.title),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
    if (mounted) _show();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: p,
    builder: (context, _) {
      final c = p.ctl;
      final ready = c != null && c.value.isInitialized;
      return Container(
        color: Colors.black,
        child: ready
            ? ValueListenableBuilder<VideoPlayerValue>(valueListenable: c, builder: (context, v, _) => _live(context, c, v))
            : Stack(
                alignment: Alignment.center,
                children: [
                  ?widget.placeholder,
                  if (p.loading) const _Spinner(),
                  if (p.error != null) _ErrorBox(text: p.error!, onRetry: p.retry),
                ],
              ),
      );
    },
  );

  Widget _live(BuildContext context, VideoPlayerController c, VideoPlayerValue v) {
    final total = v.duration.inMilliseconds;
    final pos = _scrub ?? (total == 0 ? 0.0 : v.position.inMilliseconds / total);
    final buffered = total == 0 || v.buffered.isEmpty ? 0.0 : v.buffered.map((r) => r.end.inMilliseconds).reduce((a, b) => a > b ? a : b) / total;
    final ended = total > 0 && v.position.inMilliseconds >= total - 300 && !v.isPlaying;
    final white = context.ty.cap.bold.col(Colors.white);
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        onDoubleTapDown: (d) => _doubleTap(d, box.maxWidth),
        onDoubleTap: () {},
        onLongPressStart: (_) {
          if (!v.isPlaying) return;
          setState(() => _boost = true);
          c.setPlaybackSpeed(2);
          HapticFeedback.mediumImpact();
        },
        onLongPressEnd: (_) {
          if (!_boost) return;
          setState(() => _boost = false);
          c.setPlaybackSpeed(p.speed);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(c)),
            ),
            if (p.error != null) _ErrorBox(text: p.error!, onRetry: p.retry),
            if (p.error == null && (v.isBuffering || p.loading) && !ended) const IgnorePointer(child: Center(child: _Spinner())),
            // Double-tap bubbles.
            if (_skip != 0)
              Align(
                alignment: _skip > 0 ? Alignment.centerRight : Alignment.centerLeft,
                child: IgnorePointer(
                  child: Container(
                    width: box.maxWidth * .38,
                    height: box.maxHeight,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.horizontal(
                        left: _skip > 0 ? Radius.circular(box.maxHeight) : Radius.zero,
                        right: _skip < 0 ? Radius.circular(box.maxHeight) : Radius.zero,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _skip > 0 ? PhosphorIcons.fastForward(PhosphorIconsStyle.fill) : PhosphorIcons.rewind(PhosphorIconsStyle.fill),
                          color: Colors.white,
                          size: 26,
                        ),
                        const SizedBox(height: 4),
                        Text('${_skip.abs()} seconds', style: white),
                      ],
                    ),
                  ),
                ),
              ),
            if (_boost)
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(99)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIcons.fastForward(PhosphorIconsStyle.fill), color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text('2× speed', style: white),
                    ],
                  ),
                ),
              ),
            // Controls.
            IgnorePointer(
              ignoring: !_controls && !ended,
              child: AnimatedOpacity(
                opacity: _controls || ended ? 1 : 0,
                duration: Motion.fast,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xB3000000)],
                      stops: [0, .25, .6, 1],
                    ),
                  ),
                  child: SafeArea(
                    top: widget.fullscreen,
                    bottom: widget.fullscreen,
                    child: Column(
                      children: [
                        if (widget.fullscreen)
                          Row(
                            children: [
                              IconBtn(PhosphorIcons.arrowLeft(), label: 'Exit full screen', color: Colors.white, onPressed: _fullscreen),
                              Expanded(
                                child: Text(widget.title, style: context.ty.body.bold.col(Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _RoundBtn(
                              icon: PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.bold),
                              label: 'Back 10 seconds',
                              onTap: () => p.seekBy(const Duration(seconds: -10)),
                              size: 44,
                            ),
                            const SizedBox(width: 28),
                            _RoundBtn(
                              icon: ended
                                  ? PhosphorIcons.arrowClockwise(PhosphorIconsStyle.bold)
                                  : v.isPlaying
                                  ? PhosphorIcons.pause(PhosphorIconsStyle.fill)
                                  : PhosphorIcons.play(PhosphorIconsStyle.fill),
                              label: ended ? 'Watch again' : (v.isPlaying ? 'Pause' : 'Play'),
                              onTap: _playPause,
                              size: 60,
                              filled: true,
                            ),
                            const SizedBox(width: 28),
                            _RoundBtn(
                              icon: PhosphorIcons.arrowClockwise(PhosphorIconsStyle.bold),
                              label: 'Forward 10 seconds',
                              onTap: () => p.seekBy(const Duration(seconds: 10)),
                              size: 44,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 4, 2),
                          child: Row(
                            children: [
                              Text(
                                '${clock(((_scrub ?? pos) * total / 1000).round())} / ${clock(v.duration.inSeconds)}',
                                style: white.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                              ),
                              const Spacer(),
                              _Chip(text: p.speed == 1 ? '1×' : '${p.speed}×', label: 'Playback speed', onTap: _speedSheet),
                              _Chip(text: p.quality == '720' ? 'HD' : '360p', label: 'Video quality', onTap: _qualitySheet),
                              IconBtn(
                                widget.fullscreen ? PhosphorIcons.cornersIn(PhosphorIconsStyle.bold) : PhosphorIcons.cornersOut(PhosphorIconsStyle.bold),
                                label: widget.fullscreen ? 'Exit full screen' : 'Full screen',
                                color: Colors.white,
                                onPressed: _fullscreen,
                              ),
                            ],
                          ),
                        ),
                        _SeekBar(
                          value: pos.clamp(0, 1).toDouble(),
                          buffered: buffered.clamp(0, 1).toDouble(),
                          onChanged: (x) {
                            _hide?.cancel();
                            setState(() => _scrub = x);
                          },
                          onEnd: (x) {
                            setState(() => _scrub = null);
                            c.seekTo(Duration(milliseconds: (x * total).round()));
                            _autoHide();
                          },
                        ),
                        SizedBox(height: widget.fullscreen ? 8 : 2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenPlayer extends StatefulWidget {
  const _FullscreenPlayer({required this.player, required this.title});
  final StudyPlayer player;
  final String title;
  @override
  State<_FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<_FullscreenPlayer> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: StudyPlayerView(player: widget.player, title: widget.title, fullscreen: true),
  );
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3));
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill), color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: context.ty.sm.bold.col(Colors.white)),
          const SizedBox(height: 12),
          Btn('Try again', kind: BtnKind.accent, sm: true, leading: PhosphorIcons.arrowClockwise(), onPressed: onRetry),
        ],
      ),
    ),
  );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.label, required this.onTap, this.size = 44, this.filled = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final bool filled;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Pressable(
      onTap: onTap,
      scale: .9,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: filled ? Colors.white.withValues(alpha: .92) : const Color(0x66000000), shape: BoxShape.circle),
        child: Icon(icon, size: size * .45, color: filled ? Palette.navy900 : Colors.white),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.label, required this.onTap});
  final String text, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(text, style: context.ty.cap.bold.col(Colors.white)),
          ),
        ),
      ),
    ),
  );
}

/// Seek bar: played part in gold, downloaded part lighter, a thumb that grows while dragging.
class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.value, required this.buffered, required this.onChanged, required this.onEnd});
  final double value, buffered;
  final ValueChanged<double> onChanged, onEnd;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(color: Colors.white24),
                  FractionallySizedBox(
                    widthFactor: buffered,
                    child: Container(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: Palette.gold400,
            inactiveTrackColor: Colors.transparent,
            thumbColor: Palette.gold400,
            overlayColor: Palette.gold400.withValues(alpha: .25),
          ),
          child: Slider(value: value, onChanged: onChanged, onChangeEnd: onEnd, semanticFormatterCallback: (v) => '${(v * 100).round()}%'),
        ),
      ],
    ),
  );
}
