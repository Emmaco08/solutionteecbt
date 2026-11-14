import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef _FindC = IntPtr Function(Pointer<Utf16>, Pointer<Utf16>);
typedef _FindD = int Function(Pointer<Utf16>, Pointer<Utf16>);
typedef _AffC = Int32 Function(IntPtr, Uint32);
typedef _AffD = int Function(int, int);

/// Windows "exclude from capture" for the app window (screenshots, screen recording and sharing show it black), the
/// desktop version of Android's FLAG_SECURE (D-080, D-166). Windows 10 2004+; older Windows ignores it.
abstract final class WinCapture {
  static const _wdaNone = 0x0, _wdaExclude = 0x11;

  static bool set(bool exclude) {
    try {
      final u = DynamicLibrary.open('user32.dll');
      final find = u.lookupFunction<_FindC, _FindD>('FindWindowW');
      final aff = u.lookupFunction<_AffC, _AffD>('SetWindowDisplayAffinity');
      final cls = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
      final title = 'SolutionTee CBT'.toNativeUtf16();
      final h = find(cls, title);
      calloc.free(cls);
      calloc.free(title);
      if (h == 0) return false;
      return aff(h, exclude ? _wdaExclude : _wdaNone) != 0;
    } catch (_) {
      return false;
    }
  }
}
