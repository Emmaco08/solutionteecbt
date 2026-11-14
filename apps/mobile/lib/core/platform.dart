import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Desktop build (Windows; Linux and macOS behave the same) — D-166. Uses [defaultTargetPlatform] so widget tests stay
/// on the phone layout unless a test sets `debugDefaultTargetPlatformOverride`.
bool get isDesktop => !kIsWeb && const {TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS}.contains(defaultTargetPlatform);
bool get isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// Build number of a desktop build (minutes since 1970, set by GitHub like the Android versionCode). 0 = developer build.
const desktopBuild = int.fromEnvironment('APP_BUILD');

/// The computer's own id, hashed before it leaves the app (one account per device and bans, D-078, on desktop).
abstract final class DesktopMachine {
  static String? _raw;

  static Future<String?> rawId() async {
    if (_raw != null) return _raw;
    try {
      if (Platform.isWindows) {
        final r = await Process.run('reg', ['query', r'HKLM\SOFTWARE\Microsoft\Cryptography', '/v', 'MachineGuid']).timeout(const Duration(seconds: 5));
        final m = RegExp(r'MachineGuid\s+REG_SZ\s+([0-9A-Fa-f-]{20,})').firstMatch('${r.stdout}');
        _raw = m?.group(1)?.toLowerCase();
      } else if (Platform.isLinux) {
        _raw = (await File('/etc/machine-id').readAsString()).trim();
      }
    } catch (_) {}
    return _raw;
  }

  static Future<String?> hashed(String salt) async {
    final r = await rawId();
    return r == null || r.isEmpty ? null : sha256.convert(utf8.encode('$salt$r')).toString();
  }
}
