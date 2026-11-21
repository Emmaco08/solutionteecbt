// ignore_for_file: invalid_use_of_visible_for_testing_member
// App tutorial videos (D-187): the REAL app screens at Android phone size (390 × 844, ×3 = 1170 × 2532), driven the
// way a student uses them: open a screen, tap a real widget, type into a real field. Every step is saved as a picture
// and the exact rectangle of each tap / typed field goes into steps.json, so the video's finger lands where the
// student must tap. A small fake backend on this computer answers the app's server calls with sample rows (nothing
// reaches the live server). Pictures: test_shots/shots/tutorial/<name>/NN.png + steps.json.
// Not part of `flutter test`. Run: TUT=signup,custom flutter test test_shots/tutorial_test.dart --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
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
import 'package:solutiontee_cbt/features/auth/auth_screens.dart';
import 'package:solutiontee_cbt/features/onboarding/onboarding_screens.dart';
import 'package:solutiontee_cbt/features/setup/setup_screen.dart';
import 'package:solutiontee_cbt/router.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:solutiontee_cbt/widgets/phosphor.g.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tutorial_fixtures.dart';

const _k = 3.0; // device pixel ratio: logical → picture pixels
const _phone = Size(390, 844);

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    if (File(f).existsSync()) l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

Future<void> _katex() async {
  final cfg = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync()) as Map<String, dynamic>;
  final pkg = (cfg['packages'] as List).cast<Map<String, dynamic>>().firstWhere((p) => p['name'] == 'flutter_math_fork');
  final dir = Directory('${Uri.parse(pkg['rootUri'] as String).toFilePath()}/lib/katex_fonts/fonts');
  final byFamily = <String, List<String>>{};
  for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
    byFamily.putIfAbsent(f.uri.pathSegments.last.split('-').first, () => []).add(f.path);
  }
  for (final e in byFamily.entries) {
    await _font('packages/flutter_math_fork/${e.key}', e.value);
  }
}

class _SignedIn extends LocalStorage {
  const _SignedIn();
  static String get session {
    String b64(Map<String, Object> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    final exp = DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/ 1000;
    final jwt = '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': tutUid, 'exp': exp, 'role': 'authenticated', 'aud': 'authenticated'})}.sig';
    return jsonEncode({
      'access_token': jwt,
      'token_type': 'bearer',
      'expires_in': 31536000,
      'expires_at': exp,
      'refresh_token': 'r',
      'user': {
        'id': tutUid,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'tolu@example.com',
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

  /// Builds the test from the questions stored on this phone, with the subjects and counts the student picked
  /// (the live app asks the server for the paper first).
  @override
  Future<String> start(TestRequest r, {required int Function(int subjectId) countFor, required double minutesPerQuestion}) async {
    final ids = <String>[];
    for (final sid in r.subjectIds) {
      final qs = await (db.select(db.cachedQuestions)..where((q) => q.subjectId.equals(sid))).get();
      ids.addAll(qs.take(countFor(sid)).map((q) => q.id));
    }
    const id = 'tut-attempt';
    await db
        .into(db.localAttempts)
        .insertOnConflictUpdate(
          LocalAttemptsCompanion.insert(
            id: id,
            examId: r.examId,
            examCode: r.examCode,
            mode: r.mode.name,
            configJson: jsonEncode({'title': r.title ?? 'Practice'}),
            questionIdsJson: jsonEncode(ids),
            limitSeconds: !r.timed ? 0 : (r.limitMinutes != null ? r.limitMinutes! * 60 : (ids.length * minutesPerQuestion * 60).round()),
            startedAt: DateTime.now(),
          ),
        );
    return id;
  }
}

// ------------------------------------------------------------------ the fake backend

/// Answers the app's Supabase calls from [tutTables] / [tutRpc] (tutorial_fixtures.dart): reads get sample rows,
/// writes succeed, sign-up and code checks succeed.
Future<HttpServer> _fakeBackend() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final body = await utf8.decoder.bind(req).join();
    final path = req.uri.path;
    Object? out;
    var status = 200;
    if (path.startsWith('/auth/v1/')) {
      out = path.endsWith('/user') ? jsonDecode(_SignedIn.session)['user'] : (path.contains('verify') || path.contains('token') ? jsonDecode(_SignedIn.session) : <String, dynamic>{});
    } else if (path.startsWith('/rest/v1/rpc/')) {
      final fn = path.substring('/rest/v1/rpc/'.length);
      final args = body.isEmpty ? null : jsonDecode(body);
      tutRemember(fn, args is Map ? Map<String, dynamic>.from(args) : const {});
      out = tutRpc.containsKey(fn) ? tutRpc[fn] : null;
    } else if (path.startsWith('/rest/v1/')) {
      final table = path.substring('/rest/v1/'.length);
      if (req.method == 'GET' || req.method == 'HEAD') {
        out = tutTables[table] ?? const [];
      } else {
        status = req.method == 'POST' ? 201 : 200;
        out = body.isEmpty ? const [] : (jsonDecode(body) is List ? jsonDecode(body) : [jsonDecode(body)]);
      }
      final single = (req.headers.value('accept') ?? '').contains('vnd.pgrst.object');
      if (single && out is List) out = out.isEmpty ? <String, dynamic>{} : out.first;
    } else if (path.startsWith('/functions/v1/')) {
      out = tutFunctions[path.substring('/functions/v1/'.length)] ?? <String, dynamic>{};
    } else {
      status = 404;
      out = <String, dynamic>{};
    }
    if (Platform.environment['TUT_LOG'] != null) stdout.writeln('API ${req.method} $path ${req.uri.query} -> $status ${jsonEncode(out).length}b');
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..headers.set('content-range', '0-0/*')
      ..write(jsonEncode(out));
    await req.response.close();
  });
  return server;
}

// ------------------------------------------------------------------ the recorder

/// Saves each step's picture and the rectangles the student taps or types into.
class Rec {
  Rec(this.t, this.name);
  final WidgetTester t;
  final String name;
  final steps = <Map<String, Object?>>[];

  Map<String, double> _rect(Finder f) {
    final r = t.getRect(f.first);
    return {'x': r.left * _k, 'y': r.top * _k, 'w': r.width * _k, 'h': r.height * _k};
  }

  /// Lets the app finish: real time for the fake server and timers, frames for animations.
  Future<void> settle([int n = 14]) async {
    await t.runAsync(() async {
      for (var i = 0; i < n; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await t.pump(const Duration(milliseconds: 100));
      }
    });
  }

  Future<void> snap([String? note]) async {
    final i = steps.length;
    final file = '${i.toString().padLeft(2, '0')}.png';
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/tutorial/$name/$file'));
    steps.add({'png': file, 'note': ?note});
  }

  /// Scrolls the screen until [f] is built and visible (long lists build lazily), and saves that picture.
  Future<void> scrollTo(Finder f, {double step = 250}) async {
    await t.scrollUntilVisible(f, step, scrollable: find.byType(Scrollable).first, maxScrolls: 30);
    await settle(4);
    steps.removeLast();
    await snap();
  }

  /// Taps a real widget (scrolling it into view first) and saves the next screen.
  Future<void> tap(Finder f, {String? note, bool scroll = true, int wait = 14}) async {
    if (scroll) {
      await t.ensureVisible(f.first);
      await settle(4);
      // the picture before the tap must show the widget where it is now
      if (steps.isNotEmpty) {
        steps.removeLast();
        await snap(note);
      }
    }
    steps.last['tap'] = _rect(f);
    await t.tap(f.first, warnIfMissed: false);
    await settle(wait);
    await snap();
  }

  /// Types into a real field and saves the screen with the text in it.
  Future<void> type(Finder f, String text, {String? note, Finder? box, int wait = 8}) async {
    await t.ensureVisible(f.first);
    await settle(3);
    steps.last['type'] = {..._rect(box ?? f), 'text': text};
    if (note != null) steps.last['note'] = note;
    await t.enterText(f.first, text);
    await settle(wait);
    await snap();
  }

  /// Drags a slider (or anything) sideways by [dx] logical pixels and saves the screen.
  Future<void> drag(Finder f, double dx, {String? note}) async {
    await t.ensureVisible(f.first);
    await settle(4);
    steps.removeLast();
    await snap(note);
    final r = _rect(f);
    steps.last['drag'] = {...r, 'dx': dx * _k};
    await t.drag(f.first, Offset(dx, 0), warnIfMissed: false);
    await settle(8);
    await snap();
  }

  /// Scrolls the screen by [dy] logical pixels and saves it.
  Future<void> scroll(double dy, {String? note}) async {
    steps.last['scroll'] = dy * _k;
    await t.drag(find.byType(Scrollable).first, Offset(0, -dy), warnIfMissed: false);
    await settle(8);
    await snap(note);
  }

  void save() {
    final dir = Directory('test_shots/shots/tutorial/$name')..createSync(recursive: true);
    File('${dir.path}/steps.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert({'name': name, 'size': [1170, 2532], 'steps': steps}));
  }
}

// ------------------------------------------------------------------ the app at phone size

late AppDb db;

Future<(Rec, GoRouter)> _start(WidgetTester t, String name, {GoRouter? router, String? at}) async {
  HttpOverrides.global = null; // flutter_test answers every request with 400; the fake backend is real
  db = AppDb(NativeDatabase.memory());
  await t.runAsync(() => seedTutorialDb(db));
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  t.view.physicalSize = _phone * _k;
  t.view.devicePixelRatio = _k;
  // Android status bar and gesture bar, so the app keeps clear of them like on a real phone
  t.view.padding = const FakeViewPadding(top: 32 * _k, bottom: 16 * _k);
  t.view.viewPadding = const FakeViewPadding(top: 32 * _k, bottom: 16 * _k);
  final container = ProviderContainer(
    overrides: [
      dbProvider.overrideWithValue(db),
      testsRepoProvider.overrideWith((ref) => _OfflineRepo(ref)),
      initialSettingsProvider.overrideWithValue(const AppSettings(onboarded: true, toured: true, theme: ThemeMode.light)),
      ...tutorialOverrides(),
    ],
  );
  final GoRouter r = router ?? container.read(routerProvider);
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    final s = d.exceptionAsString();
    if (s.contains('SocketException') || s.contains('ClientException') || s.contains('MissingPlugin') || s.contains('WebSocket') || s.contains('RealtimeSubscribe')) return;
    old?.call(d);
  };
  await t.runAsync(() async {
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(debugShowCheckedModeBanner: false, theme: buildTheme(Brightness.light), routerConfig: r),
      ),
    );
  });
  final rec = Rec(t, name);
  if (at != null) r.go(at);
  await rec.settle(20);
  return (rec, r);
}

Future<void> _end(WidgetTester t, Rec rec) async {
  rec.save();
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(minutes: 2));
  await t.runAsync(db.close);
  debugDefaultTargetPlatformOverride = null;
}

/// A router with only the sign-up screens (no "already signed in" redirects), the way a new student sees them.
GoRouter _signUpRouter() => GoRouter(
  navigatorKey: rootNavKey,
  initialLocation: '/welcome',
  routes: [
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: '/signup', builder: (_, _) => const SignUpScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/verify', builder: (_, s) => VerifyCodeScreen(args: s.extra as VerifyArgs? ?? const VerifyArgs(email: 'tolu@example.com', type: OtpType.signup, codeLength: 6))),
    GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
    GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: SizedBox())),
    GoRoute(path: '/welcome-new', builder: (_, _) => const WelcomeNewScreen()),
  ],
);

// ------------------------------------------------------------------ the tutorials

final tutorials = <String, Future<void> Function(WidgetTester)>{
  'signup': (t) async {
    final (rec, router) = await _start(t, 'signup', router: _signUpRouter());
    await rec.snap('welcome');
    await rec.tap(find.text('Get started'), note: 'get started');
    if (find.text('Create account').evaluate().isEmpty) {
      router.go('/signup');
      await rec.settle();
      rec.steps.removeLast();
      await rec.snap();
    }
    await rec.type(find.byType(TextField).at(0), 'tolu@example.com', note: 'email');
    await rec.type(find.byType(TextField).at(1), 'MySecret2027', note: 'password');
    await rec.tap(find.byType(Checkbox), note: 'agree');
    await rec.tap(find.text('Create account'), note: 'create account', wait: 20);
    if (find.byType(VerifyCodeScreen).evaluate().isEmpty) {
      router.push('/verify', extra: const VerifyArgs(email: 'tolu@example.com', type: OtpType.signup, codeLength: 6));
      await rec.settle();
      rec.steps.removeLast();
      await rec.snap('code screen');
    }
    final codeField = find.descendant(of: find.byType(CodeBoxes), matching: find.byType(TextField));
    await rec.type(codeField, '482913', note: 'code', box: find.byType(CodeBoxes), wait: 2);
    router.go('/setup');
    await rec.settle(30);
    await rec.snap('setup about');
    await rec.type(find.byType(TextField).at(0), 'Tolu Adeyemi', note: 'name');
    await rec.tap(find.text('Choose your state'), note: 'state');
    await rec.tap(find.text('Oyo').last, note: 'oyo');
    await rec.tap(find.text('Choose the year'), note: 'year');
    await rec.tap(find.text('2007').last, note: '2007');
    await rec.tap(find.text('Continue'), note: 'continue', scroll: false, wait: 24);
    await rec.tap(find.text('WAEC WASSCE'), note: 'waec too');
    await rec.tap(find.text('Continue'), note: 'continue', scroll: false, wait: 24);
    for (final s in ['Mathematics', 'Physics', 'Chemistry']) {
      await rec.tap(find.text(s).last, note: s);
    }
    await rec.tap(find.text('Finish setup'), note: 'finish', scroll: false, wait: 24);
    if (find.byType(WelcomeNewScreen).evaluate().isEmpty) {
      router.go('/welcome-new');
      await rec.settle(30);
      rec.steps.removeLast();
      await rec.snap('welcome new');
    }
    await _end(t, rec);
  },
  'custom': (t) async {
    final (rec, _) = await _start(t, 'custom', at: '/test');
    await rec.snap('test tab');
    await rec.tap(find.text('Custom exam'), note: 'custom exam', wait: 20);
    await rec.tap(find.text('Use of English').first, note: 'remove english');
    await rec.tap(find.text('Biology').first, note: 'add biology');
    await rec.drag(find.byType(Slider).first, -150, note: 'fewer questions');
    await rec.tap(find.text('Quadratic equations').first, note: 'topic');
    await rec.tap(find.text('2023').first, note: 'year');
    await rec.drag(find.byType(Slider).last, -120, note: 'time');
    await rec.tap(find.textContaining('Start').last, note: 'start', scroll: false, wait: 30);
    await _end(t, rec);
  },
  'community': (t) async {
    final (rec, router) = await _start(t, 'community', at: '/study');
    await rec.snap('study');
    await rec.scrollTo(find.text('Community'));
    await rec.tap(find.text('Community').first, note: 'open community', wait: 24);
    await rec.tap(find.textContaining('Find the roots').first, note: 'open post', wait: 24, scroll: false);
    await rec.tap(find.text('Follow').first, note: 'follow', scroll: false);
    final reply = find.byType(TextField).last;
    await rec.tap(reply, note: 'reply box', scroll: false);
    await rec.type(reply, '@dav', note: 'mention');
    await rec.settle(14);
    rec.steps.removeLast();
    await rec.snap('suggestions');
    await rec.tap(find.text('David Okon').last, note: 'pick mention', scroll: false);
    await rec.type(reply, '@davidokon thank you! It makes sense now.', note: 'reply text');
    await rec.tap(find.text('Reply').last, note: 'send reply', scroll: false, wait: 24);
    await rec.tap(find.byIcon(PhosphorIcons.arrowLeft()).first, note: 'back', scroll: false, wait: 20);
    await rec.tap(find.byIcon(PhosphorIcons.plus()).first, note: 'new post', scroll: false, wait: 20);
    final box = find.byType(TextField).first;
    await rec.type(box, 'Who has a simple trick for remembering the quadratic formula? Please share!', note: 'write');
    await rec.tap(find.text('Add a subject').first, note: 'subject', scroll: false);
    await rec.tap(find.text('Mathematics').last, note: 'maths', scroll: false);
    await rec.tap(find.text('Post').last, note: 'post', scroll: false, wait: 24);
    await _end(t, rec);
  },
  'mock': (t) async {
    final (rec, router) = await _start(t, 'mock', at: '/test');
    await rec.snap('test tab');
    await rec.tap(find.text('Start full exam').first, note: 'full exam', scroll: false, wait: 20);
    await rec.tap(find.text('Start full exam').last, note: 'start', scroll: false, wait: 70);
    await rec.tap(find.bySemanticsLabel(RegExp(r'^Option B')).first, note: 'answer', scroll: false);
    await rec.tap(find.text('Next').last, note: 'next', scroll: false, wait: 8);
    await rec.tap(find.bySemanticsLabel(RegExp(r'^Option A')).first, note: 'answer 2', scroll: false);
    await rec.tap(find.byTooltip('Flag question').first, note: 'flag', scroll: false);
    await rec.tap(find.textContaining('Math').first, note: 'subject tab', scroll: false, wait: 8);
    await rec.tap(find.byTooltip('Calculator').first, note: 'calculator', scroll: false, wait: 10);
    for (final k in ['1', '2', '×', '8', '=']) {
      await rec.tap(find.text(k).last, note: 'key $k', scroll: false, wait: 2);
    }
    await rec.tap(find.byIcon(PhosphorIcons.x()).last, note: 'close calc', scroll: false, wait: 8);
    await rec.tap(find.byTooltip('Question palette').first, note: 'palette', scroll: false, wait: 10);
    await rec.tap(find.bySemanticsLabel(RegExp(r'^Question 5\b')).first, note: 'jump', scroll: false, wait: 10);
    await rec.tap(find.bySemanticsLabel(RegExp(r'^Option A')).first, note: 'answer 3', scroll: false);
    // later: the student has worked through most of the paper (the app reopens it where they stopped)
    router.go('/test');
    await rec.settle(10);
    await t.runAsync(() => finishMostOfPaper(db, 'tut-attempt'));
    router.go('/cbt/tut-attempt');
    await rec.settle(40);
    await rec.snap('later');
    await rec.tap(find.text('Submit').first, note: 'submit', scroll: false, wait: 10);
    await rec.tap(find.text('Submit now').last, note: 'submit now', scroll: false, wait: 40);
    await rec.scroll(380, note: 'result details');
    await rec.tap(find.text('Review answers').first, note: 'review', scroll: false, wait: 24);
    await _end(t, rec);
  },
};

void main() {
  late HttpServer server;
  setUpAll(() async {
    await _font('LilitaOne', ['assets/fonts/LilitaOne-Regular.ttf']);
    await _font('PlusJakartaSans', ['assets/fonts/PlusJakartaSans-Medium.ttf', 'assets/fonts/PlusJakartaSans-Bold.ttf']);
    await _font('PhosphorRegular', ['assets/fonts/Phosphor-Regular.ttf']);
    await _font('PhosphorFill', ['assets/fonts/Phosphor-Fill.ttf']);
    await _font('MaterialIcons', ['/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await _katex();
    // Emoji, as on an Android phone (Noto Color Emoji is Android's own emoji font): registered under the fallback names
    for (final fam in ['FlutterTest', 'Roboto', 'NotoColorEmoji']) {
      await _font(fam, ['/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf']);
    }
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    server = await _fakeBackend();
    await Supabase.initialize(
      url: 'http://127.0.0.1:${server.port}',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(localStorage: _SignedIn(), autoRefreshToken: false, detectSessionInUri: false),
    );
  });
  tearDownAll(() => server.close(force: true));

  final pick = Platform.environment['TUT']?.split(',').where((e) => e.isNotEmpty).toSet();
  for (final e in tutorials.entries) {
    if (pick != null && !pick.contains(e.key)) continue;
    testWidgets(e.key, (t) => e.value(t));
  }
}
