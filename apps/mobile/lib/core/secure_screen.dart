import 'dart:async';

import 'package:flutter/services.dart';

/// Screenshots and screen recording (Android FLAG_SECURE), as the admin decides (D-080, Admin → Flags & settings):
/// "whole app" and "tests, challenges and Premium videos". Screens that need it call [on] / [off]; [policy] comes
/// from the server settings. Implemented in android/app/src/main/kotlin/.../MainActivity.kt.
abstract final class SecureScreen {
  static const _ch = MethodChannel('solutiontee/secure');
  static bool _whole = false, _exams = true;
  static int _screens = 0;

  /// Is the screen blocked right now (so a screenshot attempt really failed)?
  static bool get protecting => _whole || (_exams && _screens > 0);

  /// A test, challenge, challenge review or Premium video is open.
  static Future<void> on() {
    _screens++;
    return _apply();
  }

  static Future<void> off() {
    if (_screens > 0) _screens--;
    return _apply();
  }

  /// The admin's switches (app_settings.screen_protection).
  static Future<void> policy({required bool wholeApp, required bool exams}) {
    _whole = wholeApp;
    _exams = exams;
    return _apply();
  }

  static Future<void> _apply() async {
    try {
      await _ch.invokeMethod<void>('set', protecting);
    } catch (_) {
      // Not available (tests, other platforms): nothing to do.
    }
  }

  /// Calls [onScreenshot] when the student tries a screenshot (Android 14+) and [onRecording] when screen recording
  /// starts (Android 15+). Older phones still block the picture, they just do not tell us (D-075).
  static StreamSubscription<MethodCall> watch({void Function()? onScreenshot, void Function()? onRecording}) => DeviceEvents.stream.listen((c) {
    if (c.method == 'screenshot') onScreenshot?.call();
    if (c.method == 'recording' && c.arguments == true) onRecording?.call();
  });
}

/// Messages from Android on `solutiontee/device`: focus, multiWindow, screenshot, recording. One handler, many listeners.
abstract final class DeviceEvents {
  /// Screens that show their own screenshot message (the app-wide one stays quiet there).
  static bool ownMessage(String path) => path.startsWith('/cbt/') || path.endsWith('/play') || path.endsWith('/review');

  static const ch = MethodChannel('solutiontee/device');
  static final _c = StreamController<MethodCall>.broadcast();
  static bool _hooked = false;

  static Stream<MethodCall> get stream {
    if (!_hooked) {
      _hooked = true;
      ch.setMethodCallHandler((call) async => _c.add(call));
    }
    return _c.stream;
  }

  /// For tests: pretend Android sent [method].
  static void debugSend(String method, [Object? args]) => _c.add(MethodCall(method, args));
}
