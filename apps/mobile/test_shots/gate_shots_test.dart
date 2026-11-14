// Screenshots of the update pop-up, forced update, maintenance and offline screens (owner, 14 Nov 2026). Not part of
// `flutter test`. Run: flutter test test_shots/gate_shots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/app_gate.dart';
import 'package:solutiontee_cbt/core/connectivity.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:solutiontee_cbt/widgets/states.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

Future<void> _shot(WidgetTester t, Widget w, String name, {Brightness mode = Brightness.dark}) async {
  t.view.physicalSize = const Size(390 * 3, 844 * 3);
  t.view.devicePixelRatio = 3;
  await t.pumpWidget(
    ProviderScope(
      overrides: [onlineProvider.overrideWith((ref) => Stream.value(false))],
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(mode), home: w),
    ),
  );
  for (var i = 0; i < 14; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 6));
}

void main() {
  setUpAll(() async {
    await _font('PlusJakartaSans', ['assets/fonts/PlusJakartaSans-Medium.ttf', 'assets/fonts/PlusJakartaSans-Bold.ttf']);
    await _font('PhosphorRegular', ['assets/fonts/Phosphor-Regular.ttf']);
    await _font('PhosphorFill', ['assets/fonts/Phosphor-Fill.ttf']);
    await _font('MaterialIcons', ['/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });
  const notes = 'New Game Zone games\nCleaner challenge cards\nFaster question bank';
  for (final m in Brightness.values) {
    testWidgets('popup ${m.name}', (t) async {
      await _shot(
        t,
        Scaffold(
          body: Stack(
            children: [
              const Center(child: Text('Home screen')),
              Positioned.fill(
                child: UpdatePopup(version: '1.4.0', onUpdate: () {}, onLater: () {}),
              ),
            ],
          ),
        ),
        'gate_popup_${m.name}',
        mode: m,
      );
    });
  }
  testWidgets('force', (t) => _shot(t, const PlayUpdateScreen(notes: notes), 'gate_force'));
  testWidgets('maintenance', (t) async {
    await _shot(
      t,
      MaintenanceScreen(message: 'We are adding new features. Back in 30 minutes.', until: DateTime.now().add(const Duration(minutes: 30)), onRetry: () {}),
      'gate_maintenance',
    );
  });
  testWidgets(
    'offline',
    (t) => _shot(
      t,
      Scaffold(
        body: SafeArea(child: OfflineView(onRetry: () {})),
      ),
      'gate_offline',
    ),
  );
}
