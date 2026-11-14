// ignore_for_file: invalid_use_of_visible_for_testing_member
// Desktop (Windows) screenshots, D-166: real screens inside the real desktop frame at laptop sizes. Supabase points at
// a closed local port, so nothing reaches the live server; the main providers get sample data.
// Not part of `flutter test`. Run: flutter test test_shots/desktop_shots_test.dart --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solutiontee_cbt/core/house_ads.dart' show rootNavKey;
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:solutiontee_cbt/data/tests_repo.dart';
import 'package:solutiontee_cbt/desktop/desktop_frame.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'desktop_fixtures.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

late AppDb db;

Future<void> shot(WidgetTester t, String path, String name, {Size size = const Size(1440, 900), bool dark = false, List extra = const []}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  final router = GoRouter(initialLocation: path, navigatorKey: rootNavKey, routes: desktopRoutes());
  await t.runAsync(() async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db), testsRepoProvider.overrideWith((ref) => OfflineRepo(ref)), ...fixtureOverrides(), ...extra.cast()],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          routerConfig: router,
          scrollBehavior: const DesktopScrollBehavior(),
          builder: (context, child) => DesktopFrame(router: router, child: child!),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await t.pump(const Duration(milliseconds: 120));
    }
  });
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/desktop/$name.png'));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 8));
  debugDefaultTargetPlatformOverride = null;
}

void main() {
  setUpAll(() async {
    await _font('LilitaOne', ['assets/fonts/LilitaOne-Regular.ttf']);
    await _font('PlusJakartaSans', ['assets/fonts/PlusJakartaSans-Medium.ttf', 'assets/fonts/PlusJakartaSans-Bold.ttf']);
    await _font('PhosphorRegular', ['assets/fonts/Phosphor-Regular.ttf']);
    await _font('PhosphorFill', ['assets/fonts/Phosphor-Fill.ttf']);
    await _font('MaterialIcons', ['/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage(), autoRefreshToken: false),
    );
  });
  setUp(() async {
    db = AppDb(NativeDatabase.memory());
    await seedCbt(db);
  });
  tearDown(() => db.close());

  final screens = Platform.environment['SHOTS']?.split(',');
  bool want(String n) => screens == null || screens.contains(n);

  for (final (path, name) in desktopScreens) {
    if (!want(name)) continue;
    testWidgets(name, (t) => shot(t, path, name));
  }
  if (want('home_1366')) testWidgets('home_1366', (t) => shot(t, '/home', 'home_1366', size: const Size(1366, 768)));
  if (want('home_dark')) testWidgets('home_dark', (t) => shot(t, '/home', 'home_dark', dark: true));
  if (want('cbt_dark')) testWidgets('cbt_dark', (t) => shot(t, '/cbt/att1', 'cbt_dark', dark: true));
}

/// Seeds one attempt with three questions (like test/widgets_test.dart).
Future<void> seedCbt(AppDb db) async {
  const ids = ['q1', 'q2', 'q3'];
  const bodies = ['If log₁₀ 2 = 0.3010, find log₁₀ 8.', 'Find the roots of x² − 5x + 6 = 0.', 'Simplify (2³ × 2⁴) ÷ 2⁵.'];
  const opts = [
    {'A': '0.6020', 'B': '0.9030', 'C': '2.4080', 'D': '0.0753'},
    {'A': 'x = 2 or 3', 'B': 'x = −2 or −3', 'C': 'x = 1 or 6', 'D': 'x = −1 or 6'},
    {'A': '2', 'B': '4', 'C': '8', 'D': '16'},
  ];
  for (final (i, id) in ids.indexed) {
    await db
        .into(db.cachedQuestions)
        .insert(CachedQuestionsCompanion.insert(id: id, examId: 1, subjectId: 10, year: 2020, body: bodies[i], optionsJson: jsonEncode(opts[i]), answer: 'B'));
  }
  await db
      .into(db.localAttempts)
      .insert(
        LocalAttemptsCompanion.insert(
          id: 'att1',
          examId: 1,
          examCode: 'JAMB',
          mode: 'subject',
          configJson: jsonEncode({'title': 'JAMB Mathematics 2020'}),
          questionIdsJson: jsonEncode(ids),
          limitSeconds: 3600,
          startedAt: DateTime.now(),
          currentIndex: const Value(0),
        ),
      );
}
