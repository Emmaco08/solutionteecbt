import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'platform.dart';

/// The phone's ids (hashed, never sent raw) and what the phone noticed — fair play and one account per phone
/// (D-070, D-079). Implemented in MainActivity.kt.
abstract final class DeviceCheck {
  static const ch = MethodChannel('solutiontee/device');

  static String _hash(String salt, String raw) => sha256.convert(utf8.encode('$salt$raw')).toString();

  /// The Android ID, hashed (different for each copy of the app; used by challenges).
  static Future<String?> hashedId() async {
    if (isDesktop) return DesktopMachine.hashed('solutiontee:');
    try {
      final raw = await ch.invokeMethod<String>('id');
      if (raw == null || raw.isEmpty) return null;
      return _hash('solutiontee:', raw);
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>> flags() async {
    try {
      return [for (final f in await ch.invokeMethod<List<Object?>>('flags') ?? const []) '$f'];
    } catch (_) {
      return const [];
    }
  }

  /// [phone-wide id (Widevine), Android ID] hashed, and the phone's flags ("clone:…", "emulator", …).
  static Future<DeviceIds> ids() async {
    // Windows (D-166): the computer's hardware id in the phone-wide slot, this Windows installation's id in the
    // Android-id slot, so one account per computer works like one account per phone.
    if (isDesktop) {
      return DeviceIds(await DesktopMachine.hashedHardware('solutiontee:drm:'), await DesktopMachine.hashed('solutiontee:'), DesktopMachine.flags());
    }
    try {
      final m = Map<String, Object?>.from(await ch.invokeMethod<Map<Object?, Object?>>('ids') ?? const {});
      final drm = '${m['drm'] ?? ''}', android = '${m['android'] ?? ''}';
      return DeviceIds(drm.isEmpty ? null : _hash('solutiontee:drm:', drm), android.isEmpty ? null : _hash('solutiontee:', android), [
        for (final f in (m['flags'] as List?) ?? const []) '$f',
      ]);
    } catch (_) {
      return DeviceIds(null, await hashedId(), await flags());
    }
  }
}

class DeviceIds {
  const DeviceIds(this.drm, this.android, this.flags);
  final String? drm, android;
  final List<String> flags;

  /// In the order the server expects: [drm, android].
  List<String?> get list => [drm, android];

  /// This copy of the app runs as a dual app, inside a cloner or as another Android user.
  bool get clone => flags.any((f) => f.startsWith('clone:'));
  bool get any => drm != null || android != null;
}
