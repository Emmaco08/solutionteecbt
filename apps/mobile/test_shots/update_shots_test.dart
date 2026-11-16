// The update screens of the website app and the Windows app (D-181). Not part of `flutter test`.
// Run: flutter test test_shots/update_shots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/updater.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

/// Shows one moment of the update, without downloading anything.
class _Fixed extends UpdateController {
  _Fixed(this.s);
  final UpdState s;
  @override
  UpdState build() => s;
  @override
  Future<void> restore(AppRelease r) async {}
  @override
  Future<void> start(AppRelease r, {bool install = true}) async {}
}

const _mb = 1048576;
const _rel = AppRelease(version: '0.3.1-202611161107', build: 29400000, size: 28 * _mb, builtAt: null, url: 'u');
const _notes = 'Faster tests and smoother scrolling\nNew Game Zone sounds\nFixes for the calculator';

Future<void> _shot(WidgetTester t, String name, Widget home, UpdState s, {Size size = const Size(390, 844), bool windows = false}) async {
  if (windows) debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        updateCtlProvider.overrideWith(() => _Fixed(s)),
        myVersionNameProvider.overrideWith((ref) async => '0.3.0-202611021530'),
        appUpdateProvider.overrideWith((ref) async => const UpdateInfo(_rel, force: false, notes: _notes)),
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(Brightness.light), home: home),
    ),
  );
  for (var i = 0; i < 16; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/update/$name.png'));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 3));
  debugDefaultTargetPlatformOverride = null;
}

void main() {
  setUpAll(() async {
    await _font('PlusJakartaSans', ['assets/fonts/PlusJakartaSans-Medium.ttf', 'assets/fonts/PlusJakartaSans-Bold.ttf']);
    await _font('PhosphorRegular', ['assets/fonts/Phosphor-Regular.ttf']);
    await _font('PhosphorFill', ['assets/fonts/Phosphor-Fill.ttf']);
    await _font('MaterialIcons', ['/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  const optional = UpdateScreen(info: UpdateInfo(_rel, force: false, notes: _notes), optional: true);
  const force = UpdateScreen(info: UpdateInfo(_rel, force: true, notes: _notes));
  final states = <String, UpdState>{
    '1_ready_to_download': const UpdState(),
    '2_downloading': const UpdState(phase: UpdPhase.downloading, got: 11 * _mb + 300000, total: 28 * _mb, speed: 1.4 * _mb),
    '3_waiting_internet': const UpdState(phase: UpdPhase.waiting, got: 19 * _mb, total: 28 * _mb),
    '4_ready_to_install': const UpdState(phase: UpdPhase.ready, got: 28 * _mb, total: 28 * _mb),
    '5_permission': const UpdState(phase: UpdPhase.permission, got: 28 * _mb, total: 28 * _mb),
    '6_failed': UpdState(phase: UpdPhase.failed, got: 9 * _mb, total: 28 * _mb, error: UpdateError.internet.message),
  };
  for (final e in states.entries) {
    testWidgets('phone ${e.key}', (t) => _shot(t, 'phone_${e.key}', optional, e.value));
  }
  testWidgets('phone must update', (t) => _shot(t, 'phone_0_must_update', force, const UpdState()));
  testWidgets('phone small card while downloading', (t) {
    return _shot(
      t,
      'phone_7_card_downloading',
      const Scaffold(
        backgroundColor: Color(0xFFF4F6FA),
        body: UpdateGate(child: Center(child: Text('Home'))),
      ),
      const UpdState(phase: UpdPhase.downloading, got: 15 * _mb, total: 28 * _mb, speed: 1.2 * _mb),
    );
  });
  testWidgets('phone small card ready', (t) {
    return _shot(
      t,
      'phone_8_card_ready',
      const Scaffold(
        backgroundColor: Color(0xFFF4F6FA),
        body: UpdateGate(child: Center(child: Text('Home'))),
      ),
      const UpdState(phase: UpdPhase.ready, got: 28 * _mb, total: 28 * _mb),
    );
  });
  testWidgets('laptop downloading', (t) {
    return _shot(
      t,
      'laptop_downloading',
      optional,
      const UpdState(phase: UpdPhase.downloading, got: 11 * _mb, total: 28 * _mb, speed: 2.1 * _mb),
      size: const Size(1366, 768),
      windows: true,
    );
  });
  testWidgets('laptop ready', (t) {
    return _shot(
      t,
      'laptop_ready',
      optional,
      const UpdState(phase: UpdPhase.ready, got: 28 * _mb, total: 28 * _mb),
      size: const Size(1366, 768),
      windows: true,
    );
  });
}
