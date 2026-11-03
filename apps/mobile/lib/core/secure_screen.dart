import 'dart:async';

import 'package:flutter/services.dart';

/// Screenshots and screen recording are blocked in the whole app (Android FLAG_SECURE, set when the app opens; owner,
/// D-076). `on`/`off` are kept for the screens that need it most, but Android never turns it off.
/// Implemented in android/app/src/main/kotlin/.../MainActivity.kt.
abstract final class SecureScreen {
  static const _ch = MethodChannel('solutiontee/secure');
  static Future<void> on() => _call(true);
  static Future<void> off() => _call(false);
  static Future<void> _call(bool on) async {
    try {
      await _ch.invokeMethod<void>('set', on);
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
