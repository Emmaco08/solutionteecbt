// Every screen on Windows (D-166): walks every route in lib/router.dart and opens it inside the real app router and
// desktop frame, signed in, at a 1366 x 768 laptop size. Fails on any exception or layout overflow. The server is a
// closed local port, so screens show their loading, error or offline states; the point is that each one opens.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:solutiontee_cbt/data/tests_repo.dart';
import 'package:solutiontee_cbt/desktop/desktop_frame.dart';
import 'package:solutiontee_cbt/router.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A stored session that is valid for a year, so the app starts signed in without the network.
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

/// Real marking on this computer, no network sync.
class _OfflineRepo extends TestsRepo {
  _OfflineRepo(super.ref);
  @override
  Future<int> syncPending() async => 0;
}

/// Every concrete path in the router; `:params` become `1`. Redirect-only routes are left out.
List<String> allPaths(List<RouteBase> routes, [String parent = '']) {
  final out = <String>[];
  for (final r in routes) {
    if (r is GoRoute) {
      final p = r.path.startsWith('/') ? r.path : '${parent == '/' ? '' : parent}/${r.path}';
      if (r.builder != null || r.pageBuilder != null) out.add(p.replaceAll(RegExp(r':[A-Za-z_]+'), '1'));
      out.addAll(allPaths(r.routes, p));
    } else if (r is ShellRouteBase) {
      out.addAll(allPaths(r.routes, parent));
    }
  }
  return out;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(localStorage: _SignedIn(), autoRefreshToken: false),
    );
  });

  test('the app starts signed in for this test', () {
    expect(Supabase.instance.client.auth.currentSession, isNotNull);
  });

  testWidgets('every route opens on Windows at 1366 x 768 without errors or overflow', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    t.view.physicalSize = const Size(1366, 768);
    t.view.devicePixelRatio = 1;
    final db = AppDb(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [dbProvider.overrideWithValue(db), testsRepoProvider.overrideWith((ref) => _OfflineRepo(ref))]);
    final router = container.read(routerProvider);
    final only = const String.fromEnvironment('ROUTES').split(',').where((e) => e.isNotEmpty).toSet();
    final paths = allPaths(router.configuration.routes).toSet().where((p) => only.isEmpty || only.contains(p)).toList();
    final problems = <String, String>{};
    String current = '';

    final oldOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      final text = d.exceptionAsString();
      // Network failures are expected here (no server); everything else is a real problem.
      if (text.contains('SocketException') || text.contains('ClientException') || text.contains('Connection refused')) return;
      if (only.isNotEmpty) debugPrint('---- $current\n${d.toString()}');
      problems.putIfAbsent(current, () => text.split('\n').first);
    };

    await t.runAsync(() async {
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: buildTheme(Brightness.light),
            routerConfig: router,
            scrollBehavior: const DesktopScrollBehavior(),
            builder: (context, child) => DesktopFrame(router: router, child: child!),
          ),
        ),
      );
      for (final p in paths) {
        current = p;
        router.go(p);
        for (var i = 0; i < 6; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          await t.pump(const Duration(milliseconds: 100));
        }
        final e = t.takeException();
        if (e != null && only.isNotEmpty) debugPrint('---- $p (thrown)\n$e\n${e is Error ? e.stackTrace : ''}');
        if (e != null) problems.putIfAbsent(p, () => '$e'.split('\n').first);
      }
    });

    FlutterError.onError = oldOnError;
    debugPrint('Opened ${paths.length} routes on Windows: ${paths.join(', ')}');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(minutes: 2));
    container.dispose();
    await db.close();
    debugDefaultTargetPlatformOverride = null;
    expect(problems, isEmpty, reason: problems.entries.map((e) => '${e.key}: ${e.value}').join('\n'));
    if (only.isEmpty) expect(paths.length, greaterThan(90));
  });
}
