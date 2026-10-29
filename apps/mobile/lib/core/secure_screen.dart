import 'package:flutter/services.dart';

/// Blocks screenshots and screen recording (Android FLAG_SECURE) while a test is open.
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
}
