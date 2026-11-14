import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Reads a text value from HKEY_LOCAL_MACHINE on Windows (D-166) through advapi32 RegGetValueW: no `reg.exe`
/// process (which could flash a console window) and no plugin. Returns null when missing or on other platforms.
abstract final class WinRegistry {
  // HKEY_LOCAL_MACHINE is (HKEY)(LONG)0x80000002, sign-extended on 64-bit Windows.
  static const _hklm = 0xFFFFFFFF80000002;
  static const _rrfRtRegSz = 0x00000002;
  static const _rrfSubkeyWow6464 = 0x00010000;

  static String? localMachine(String subKey, String value) {
    try {
      final lib = DynamicLibrary.open('advapi32.dll');
      final get = lib
          .lookupFunction<
            Int32 Function(IntPtr, Pointer<Utf16>, Pointer<Utf16>, Uint32, Pointer<Uint32>, Pointer<Void>, Pointer<Uint32>),
            int Function(int, Pointer<Utf16>, Pointer<Utf16>, int, Pointer<Uint32>, Pointer<Void>, Pointer<Uint32>)
          >('RegGetValueW');
      return using((arena) {
        final key = subKey.toNativeUtf16(allocator: arena), name = value.toNativeUtf16(allocator: arena);
        final size = arena<Uint32>()..value = 1024;
        final buf = arena<Uint8>(1024);
        final r = get(_hklm, key, name, _rrfRtRegSz | _rrfSubkeyWow6464, nullptr, buf.cast(), size);
        if (r != 0) return null;
        final s = buf.cast<Utf16>().toDartString();
        return s.isEmpty ? null : s;
      });
    } catch (_) {
      return null;
    }
  }
}
