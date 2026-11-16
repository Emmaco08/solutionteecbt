import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:video_player/video_player.dart';

import '../features/gamezone/gz_sound.dart';

/// Video players that are open now, so closing the Windows app can stop them first (D-177).
abstract final class LiveVideos {
  static final _all = <VideoPlayerController>{};

  static VideoPlayerController track(VideoPlayerController c) {
    _all.add(c);
    return c;
  }

  static void forget(VideoPlayerController? c) {
    if (c != null) _all.remove(c);
  }

  static Future<void> stopAll() async {
    final list = [..._all];
    _all.clear();
    for (final c in list) {
      try {
        await c.pause(); // the screen that owns it still disposes it
      } catch (_) {}
    }
  }
}

/// The Windows window is closing (owner, 16 Nov 2026: an "Application Error" box appeared after closing the app).
/// Stop the game music and effects and every video first, so no audio or video thread is still running while
/// Windows shuts the app down; the runner then ends the process cleanly (windows/runner/main.cpp).
abstract final class DesktopExit {
  static bool _running = false;

  static Future<AppExitResponse> run() async {
    if (_running) return AppExitResponse.exit;
    _running = true;
    try {
      await Future.wait([GzSound.instance.shutdown(), LiveVideos.stopAll()]).timeout(const Duration(seconds: 2));
    } catch (_) {}
    return AppExitResponse.exit;
  }
}
