import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import '../../core/win_registry.dart';

// Game Zone sound (D-157): effects and two music loops, all made by design/scripts/gz_sounds.py (ours, no licences).
// Effects play from small low-latency pools; music loops, fades between tracks, pauses when the app goes to the
// background, and mixes with other apps. Both are switched in the hub (speaker button) and remembered.

enum GzSfx { tap, correct, wrong, tick, count, go, whoosh, flip, pair, coin, found, combo, pop, spin, win, lose, level }

/// Sound files: OGG on phones; MP3 on Windows, which plays OGG only with an optional Microsoft add-on (D-166).
String get _ext => Platform.isWindows ? 'mp3' : 'ogg';

/// A Windows PC with no speakers or headphones cannot play anything: sounds stay off there instead of erroring (D-167).
bool get _canPlay => !Platform.isWindows || WinAudio.hasOutput;

class GzSound with WidgetsBindingObserver {
  GzSound._();
  static final instance = GzSound._();

  bool sounds = true;
  bool music = true;

  /// Off in tests (no audio plugin there).
  static bool enabled = !Platform.environment.containsKey('FLUTTER_TEST');

  final Map<GzSfx, AudioPool> _pools = {};
  final Map<GzSfx, Future<AudioPool>> _loading = {};
  AudioPlayer? _player;
  String? _track;
  final List<String?> _wanted = [];
  bool _started = false;
  bool _paused = false;
  Timer? _fade;

  static const _musicVolume = 0.42;

  /// Effects and music share the speaker: no player asks Android for audio focus. (With the default "gain" focus each
  /// effect took focus from our own music player, which then stopped for good — owner report, 12 Nov 2026.)
  static final AudioContext _mix = AudioContext(
    android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none, usageType: AndroidUsageType.game, contentType: AndroidContentType.sonification),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient, options: const {AVAudioSessionOptions.mixWithOthers}),
  );

  void _start() {
    if (_started || !enabled || !_canPlay) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    AudioPlayer.global.setAudioContext(_mix).catchError((_) {});
    for (final s in const [GzSfx.tap, GzSfx.correct, GzSfx.wrong, GzSfx.tick, GzSfx.count, GzSfx.go, GzSfx.flip, GzSfx.pair, GzSfx.pop]) {
      unawaited(_pool(s).then((_) {}, onError: (_) => _loading.remove(s)));
    }
  }

  Future<AudioPool> _pool(GzSfx s) {
    final ready = _pools[s];
    if (ready != null) return Future.value(ready);
    return _loading[s] ??=
        AudioPool.create(source: AssetSource('sounds/${s.name}.$_ext'), maxPlayers: s == GzSfx.tap || s == GzSfx.flip ? 4 : 2, audioContext: _mix).then((p) {
          _pools[s] = p;
          return p;
        });
  }

  /// Plays an effect at once (it is ignored when effects are off).
  void play(GzSfx s, {double volume = 1}) {
    if (!sounds || !enabled || !_canPlay) return;
    _start();
    final p = _pools[s];
    if (p != null) {
      unawaited(p.start(volume: volume).then((_) {}, onError: (_) {}));
    } else {
      unawaited(_pool(s).then((p) => p.start(volume: volume)).then((_) {}, onError: (_) => _loading.remove(s)));
    }
  }

  /// A screen asks for a music track ('hub', 'battle' or null for silence); the newest screen wins.
  void push(String? track) {
    _wanted.add(track);
    _apply();
  }

  void pop() {
    if (_wanted.isNotEmpty) _wanted.removeLast();
    _apply();
  }

  /// The screen on top changes its track (lobby → game → results).
  void replace(String? track) {
    if (_wanted.isEmpty) return push(track);
    if (_wanted.last == track) return;
    _wanted[_wanted.length - 1] = track;
    _apply();
  }

  void setMusic(bool on) {
    music = on;
    _apply();
  }

  void _apply() {
    if (!enabled) return;
    final want = music && !_paused && _wanted.isNotEmpty ? _wanted.last : null;
    if (want == _track) return;
    _track = want;
    _start();
    _switchTo(want);
  }

  Future<void> _switchTo(String? track) async {
    if (!_canPlay) return;
    final fresh = _player == null;
    final p = _player ??= AudioPlayer(playerId: 'gz_music');
    _fade?.cancel();
    try {
      if (fresh) await p.setAudioContext(_mix);
      if (track == null) {
        await _fadeTo(p, 0);
        await p.pause();
        return;
      }
      await p.setReleaseMode(ReleaseMode.loop);
      await _fadeTo(p, 0, ms: 250);
      await p.stop();
      await p.setVolume(0);
      await p.play(AssetSource('sounds/music_$track.$_ext'), volume: 0, ctx: _mix);
      await _fadeTo(p, _musicVolume, ms: 700);
    } catch (_) {}
  }

  Future<void> _fadeTo(AudioPlayer p, double to, {int ms = 400}) async {
    final from = p.volume;
    const steps = 10;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(Duration(milliseconds: ms ~/ steps));
      try {
        await p.setVolume(from + (to - from) * i / steps);
      } catch (_) {
        return;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final away = state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.detached;
    if (away == _paused) return;
    _paused = away;
    if (away) {
      _track = null;
      _player?.pause();
    } else {
      _apply();
    }
  }
}

/// Keeps a music track playing while this screen is open.
class GzMusic extends StatefulWidget {
  const GzMusic({super.key, required this.track, required this.child});
  final String? track;
  final Widget child;
  @override
  State<GzMusic> createState() => _GzMusicState();
}

class _GzMusicState extends State<GzMusic> {
  @override
  void initState() {
    super.initState();
    GzSound.instance.push(widget.track);
  }

  @override
  void didUpdateWidget(GzMusic old) {
    super.didUpdateWidget(old);
    if (old.track != widget.track) GzSound.instance.replace(widget.track);
  }

  @override
  void dispose() {
    GzSound.instance.pop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
