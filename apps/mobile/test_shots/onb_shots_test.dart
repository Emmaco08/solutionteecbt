// Frames of the Game Zone, Community and Request a tutor onboarding films (owner, 14 Nov 2026). Not part of
// `flutter test`. Run: flutter test test_shots/onb_shots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/onboarding/onboarding_art.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

void main() {
  setUpAll(() async {
    await _font('LilitaOne', ['assets/fonts/LilitaOne-Regular.ttf']);
    await _font('PlusJakartaSans', ['assets/fonts/PlusJakartaSans-Medium.ttf', 'assets/fonts/PlusJakartaSans-Bold.ttf']);
    await _font('PhosphorRegular', ['assets/fonts/Phosphor-Regular.ttf']);
    await _font('PhosphorFill', ['assets/fonts/Phosphor-Fill.ttf']);
    await _font('MaterialIcons', ['/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });
  for (final k in ['games', 'community', 'tutor']) {
    for (final m in Brightness.values) {
      testWidgets('onb $k ${m.name}', (t) async {
        t.view.physicalSize = const Size(360 * 2, 360 * 2);
        t.view.devicePixelRatio = 2;
        await t.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(m),
            home: Scaffold(
              body: Center(
                child: SizedBox(width: 340, height: 340, child: SlideArt(kind: k, current: true)),
              ),
            ),
          ),
        );
        final n = m == Brightness.dark ? 40 : 1;
        final step = {'games': 5600, 'community': 6400, 'tutor': 6800}[k]! ~/ 40;
        for (var f = 0; f < n; f++) {
          await t.pump(Duration(milliseconds: m == Brightness.dark ? step : (step * 34)));
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/onb/${k}_${m.name}_${f.toString().padLeft(2, '0')}.png'));
        }
      });
    }
  }
}
