import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'win_registry.dart';

import 'package:flutter/foundation.dart';

/// Desktop build (Windows; Linux and macOS behave the same) — D-166. Uses [defaultTargetPlatform] so widget tests stay
/// on the phone layout unless a test sets `debugDefaultTargetPlatformOverride`.
bool get isDesktop => !kIsWeb && const {TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS}.contains(defaultTargetPlatform);
bool get isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// Build number of a desktop build (minutes since 1970, set by GitHub like the Android versionCode). 0 = developer build.
const desktopBuild = int.fromEnvironment('APP_BUILD');

/// The computer's own id, hashed before it leaves the app (one account per device and bans, D-078, on desktop).
abstract final class DesktopMachine {
  static String? _raw, _hw;
  static bool _hwRead = false;

  /// This Windows installation's id (MachineGuid). Changes when Windows is reinstalled.
  static Future<String?> rawId() async {
    if (_raw != null) return _raw;
    try {
      if (Platform.isWindows) {
        _raw = WinRegistry.localMachine(r'SOFTWARE\Microsoft\Cryptography', 'MachineGuid')?.trim().toLowerCase();
      } else if (Platform.isLinux) {
        _raw = (await File('/etc/machine-id').readAsString()).trim();
      }
    } catch (_) {}
    return _raw;
  }

  /// The computer's own id (the motherboard's SMBIOS UUID, as Windows records it): stays the same when Windows is
  /// reinstalled, like the phone-wide id on Android (D-166). Placeholder values some makers ship are ignored.
  static Future<String?> hardwareId() async {
    if (_hwRead) return _hw;
    _hwRead = true;
    try {
      if (Platform.isWindows) _hw = cleanHardwareId(WinRegistry.localMachine(r'SYSTEM\HardwareConfig', 'LastConfig'));
    } catch (_) {}
    return _hw;
  }

  /// "{4C4C4544-0042-…}" → "4c4c4544-0042-…"; null for empty or placeholder ids shared by many computers.
  static String? cleanHardwareId(String? raw) {
    final v = (raw ?? '').trim().replaceAll(RegExp(r'[{}]'), '').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(v)) return null;
    final digits = v.replaceAll('-', '');
    if (RegExp(r'^(0+|f+)$').hasMatch(digits)) return null;
    const placeholders = {'03000200-0400-0500-0006-000700080009', '00020003-0004-0005-0006-000700080009', '12345678-1234-5678-90ab-cddeefaabbcc'};
    return placeholders.contains(v) ? null : v;
  }

  /// "vm" when Windows runs inside a virtual machine (a common way to make extra accounts). Any flag lists the account
  /// under "Warning signs" on the admin fraud page, so a normal computer sends none.
  static List<String> flags() {
    if (!Platform.isWindows) return const [];
    final bios = [
      WinRegistry.localMachine(r'HARDWARE\DESCRIPTION\System\BIOS', 'SystemManufacturer'),
      WinRegistry.localMachine(r'HARDWARE\DESCRIPTION\System\BIOS', 'SystemProductName'),
    ].whereType<String>().join(' ');
    return [if (isVirtualMachine(bios)) 'vm'];
  }

  static bool isVirtualMachine(String bios) =>
      RegExp(r'virtualbox|vmware|qemu|kvm|parallels|xen|bochs|innotek|virtual machine', caseSensitive: false).hasMatch(bios);

  static Future<String?> hashed(String salt) async {
    final r = await rawId();
    return r == null || r.isEmpty ? null : sha256.convert(utf8.encode('$salt$r')).toString();
  }

  static Future<String?> hashedHardware(String salt) async {
    final r = await hardwareId();
    return r == null ? null : sha256.convert(utf8.encode('$salt$r')).toString();
  }
}
