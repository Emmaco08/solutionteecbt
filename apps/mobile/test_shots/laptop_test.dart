// ignore_for_file: invalid_use_of_visible_for_testing_member
// Laptop check (owner, 16 Nov 2026: "test all the screens on laptop and be 100% sure"). The REAL app: the real router,
// the real desktop frame and sidebar, signed in, with sample data, opened the way a student opens each page (from the
// sidebar, or pushed from another page), at common laptop sizes. Pictures land in test_shots/shots/laptop/<size>/.
// Not part of `flutter test`. Run: flutter test test_shots/laptop_test.dart --update-goldens  (SHOTS=a,b to pick)
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solutiontee_cbt/app.dart' show appTextScaler;
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:solutiontee_cbt/data/tests_repo.dart';
import 'package:solutiontee_cbt/desktop/desktop_frame.dart';
import 'package:solutiontee_cbt/features/xp/streak_ui.dart';
import 'package:solutiontee_cbt/router.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:solutiontee_cbt/widgets/r2_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'laptop_fixtures.dart';

class _SignedIn extends LocalStorage {
  const _SignedIn();
  static String get session {
    String b64(Map<String, Object> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    final exp = DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/ 1000;
    const uid = '00000000-0000-4000-8000-000000000001';
    final jwt = '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': uid, 'exp': exp, 'role': 'authenticated', 'aud': 'authenticated'})}.sig';
    return jsonEncode({
      'access_token': jwt,
      'token_type': 'bearer',
      'expires_in': 31536000,
      'expires_at': exp,
      'refresh_token': 'r',
      'user': {
        'id': uid,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'student@example.com',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': {'provider': 'email'},
        'user_metadata': {},
      },
    });
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => true;
  @override
  Future<String?> accessToken() async => session;
  @override
  Future<void> removePersistedSession() async {}
  @override
  Future<void> persistSession(String persistSessionString) async {}
}

class _OfflineRepo extends TestsRepo {
  _OfflineRepo(super.ref);
  @override
  Future<int> syncPending() async => 0;
}

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

/// One page opened like a student opens it: [go] from the sidebar, then any [push]es from inside, then [act].
class Flow {
  const Flow(this.name, this.go, {this.push = const [], this.act, this.dark = false});
  final String name, go;
  final List<String> push;
  final Future<void> Function(WidgetTester t)? act;
  final bool dark;
}

const sizes = {'1366x768': Size(1366, 768), '1920x1080': Size(1920, 1080), '1280x720': Size(1280, 720)};

final flows = <Flow>[
  const Flow('home', '/home'),
  const Flow('home_dark', '/home', dark: true),
  const Flow('news', '/news'),
  const Flow('news_article_from_home', '/home', push: ['/news/n1']),
  const Flow('test', '/test'),
  Flow('cbt_from_test', '/test', push: ['/cbt/att1']),
  Flow(
    'cbt_calculator',
    '/test',
    push: ['/cbt/att1'],
    act: (t) async {
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyC);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    },
  ),
  const Flow('study', '/study'),
  const Flow('games_from_sidebar', '/games'),
  const Flow('games_from_home', '/home', push: ['/games']),
  const Flow('community_from_sidebar', '/community'),
  const Flow('community_from_home', '/home', push: ['/community']),
  const Flow('leaderboard', '/leaderboard'),
  const Flow('me', '/me'),
  const Flow('ai', '/ai'),
  const Flow('classes', '/classes'),
  const Flow('settings', '/settings'),
  const Flow('badges', '/badges'),
];

late AppDb db;

void main() {
  setUpAll(() async {
    await _font('LilitaOne', ['assets/fonts/LilitaOne-Regular.ttf']);
    await _font('PlusJakartaSans', ['assets/fonts/PlusJakartaSans-Medium.ttf', 'assets/fonts/PlusJakartaSans-Bold.ttf']);
    await _font('PhosphorRegular', ['assets/fonts/Phosphor-Regular.ttf']);
    await _font('PhosphorFill', ['assets/fonts/Phosphor-Fill.ttf']);
    await _font('MaterialIcons', ['/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    // KaTeX fonts, so $...$ maths draws as it does in the real app (not empty boxes)
    final katex = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/flutter_math_fork-0.7.4/lib/katex_fonts/fonts';
    for (final f in [
      'Main-Regular',
      'Main-Bold',
      'Main-Italic',
      'Math-Italic',
      'AMS-Regular',
      'Size1-Regular',
      'Size2-Regular',
      'Size3-Regular',
      'Size4-Regular',
    ]) {
      final fam = f.split('-').first;
      if (File('$katex/KaTeX_$f.ttf').existsSync()) await _font('packages/flutter_math_fork/KaTeX_$fam', ['$katex/KaTeX_$f.ttf']);
    }
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(localStorage: _SignedIn(), autoRefreshToken: false, detectSessionInUri: false),
    );
  });

  final pick = Platform.environment['SHOTS']?.split(',').where((e) => e.isNotEmpty).toSet();
  final sizePick = Platform.environment['SIZES']?.split(',').where((e) => e.isNotEmpty).toSet();
  for (final MapEntry(key: sizeName, value: size) in sizes.entries) {
    if (sizePick != null && !sizePick.contains(sizeName)) continue;
    for (final f in flows) {
      if (pick != null && !pick.contains(f.name)) continue;
      testWidgets('$sizeName ${f.name}', (t) async {
        db = AppDb(NativeDatabase.memory());
        await t.runAsync(() => seedCbt(db));
        final photos = {
          for (final n in ['wide', 'tall', 'diagram']) n: Uint8List.fromList(File('test_shots/fixtures/$n.jpg').readAsBytesSync()),
        };
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        final container = ProviderContainer(
          overrides: [
            dbProvider.overrideWithValue(db),
            testsRepoProvider.overrideWith((ref) => _OfflineRepo(ref)),
            initialSettingsProvider.overrideWithValue(AppSettings(onboarded: true, toured: true, theme: f.dark ? ThemeMode.dark : ThemeMode.light)),
            r2BytesProvider.overrideWith((ref, a) async => photos[a.key.contains('tall') ? 'tall' : (a.key.contains('diagram') ? 'diagram' : 'wide')]!),
            ...laptopOverrides(),
          ],
        );
        final router = container.read(routerProvider);
        final old = FlutterError.onError;
        FlutterError.onError = (d) {
          final s = d.exceptionAsString();
          if (s.contains('SocketException') || s.contains('ClientException') || s.contains('Connection refused') || s.contains('MissingPlugin')) return;
          old?.call(d);
        };
        await t.runAsync(() async {
          await t.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: buildTheme(Brightness.light),
                darkTheme: buildTheme(Brightness.dark),
                themeMode: f.dark ? ThemeMode.dark : ThemeMode.light,
                routerConfig: router,
                scrollBehavior: const DesktopScrollBehavior(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: appTextScaler(MediaQuery.of(context), desktop: true)),
                  child: DesktopFrame(router: router, child: child!),
                ),
              ),
            ),
          );
          Future<void> settle([int n = 8]) async {
            for (var i = 0; i < n; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 40));
              await t.pump(const Duration(milliseconds: 120));
            }
          }

          router.go(f.go);
          await settle();
          for (final p in f.push) {
            router.push(p);
            await settle();
          }
          if (f.act != null) {
            await f.act!(t);
            await settle();
          }
          await settle(6);
        });
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/laptop/$sizeName/${f.name}.png'));
        FlutterError.onError = old;
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(minutes: 2));
        container.dispose();
        await t.runAsync(db.close);
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}

/// One JAMB Mathematics attempt with three questions, saved on this computer.
Future<void> seedCbt(AppDb db) async {
  const ids = ['q1', 'q2', 'q3'];
  const bodies = [
    r'If $\log_{10} 2 = 0.3010$ and $\log_{10} 3 = 0.4771$, find the value of $\log_{10} 72$ correct to three decimal places.',
    'Find the roots of the equation x² − 5x + 6 = 0.',
    'Simplify (2³ × 2⁴) ÷ 2⁵.',
  ];
  const opts = [
    {'A': '1.857', 'B': '1.875', 'C': '2.857', 'D': '0.857'},
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

// Keeps the import used when flows are trimmed.
// ignore: unused_element
final _streak = myStreakProvider;
