import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solutiontee_cbt/core/app_gate.dart' show PlayOffer, UpdatePopup, updateMode;
import 'package:solutiontee_cbt/core/house_ads.dart' show rootNavKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/secure_screen.dart';
import 'package:solutiontee_cbt/core/updater.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

/// The phone or computer, faked: the test decides how the download goes.
class FakeBackend extends UpdateBackend {
  Completer<File>? dl;
  void Function(DlTick)? tick;
  bool can = true;
  int allows = 0, installs = 0, cancels = 0, downloads = 0;
  (int, bool, File?) resumeWith = (0, false, null);

  @override
  Future<File> download(AppRelease r, void Function(DlTick) onTick, CancelToken token) {
    downloads++;
    tick = onTick;
    return (dl = Completer<File>()).future;
  }

  @override
  Future<(int, bool, File?)> resume(AppRelease r) async => resumeWith;
  @override
  Future<bool> canInstall() async => can;
  @override
  Future<void> allowInstall() async => allows++;
  @override
  Future<void> install(File f) async => installs++;
  @override
  Future<void> cancel(AppRelease r) async => cancels++;
  @override
  Future<void> cleanup() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an update exists only when the published build is newer than this one', () {
    const mine = 29371234; // minutes since 1970, as GitHub builds it
    AppRelease rel({int? build, DateTime? at}) => AppRelease(version: '0.3.0-x', build: build, size: 1, builtAt: at, url: 'u');
    expect(rel(build: mine + 5).newerThan(mine), isTrue);
    expect(rel(build: mine).newerThan(mine), isFalse);
    expect(rel(build: mine - 100).newerThan(mine), isFalse);
    // builds published before the build number was sent: the build time decides, with 30 minutes of slack
    final same = DateTime.fromMillisecondsSinceEpoch((mine + 3) * 60000);
    expect(rel(at: same).newerThan(mine), isFalse);
    expect(rel(at: DateTime.fromMillisecondsSinceEpoch((mine + 90) * 60000)).newerThan(mine), isTrue);
    // a developer build (versionCode 1) is never asked to update
    expect(rel(build: mine).newerThan(1), isFalse);
  });

  test('screenshots are blocked only where the admin switches say', () async {
    await SecureScreen.policy(wholeApp: false, exams: true);
    expect(SecureScreen.protecting, isFalse);
    await SecureScreen.on(); // a test or challenge opens
    expect(SecureScreen.protecting, isTrue);
    await SecureScreen.off();
    expect(SecureScreen.protecting, isFalse);
    await SecureScreen.policy(wholeApp: false, exams: false);
    await SecureScreen.on();
    expect(SecureScreen.protecting, isFalse, reason: 'admin turned tests off too');
    await SecureScreen.off();
    await SecureScreen.policy(wholeApp: true, exams: false);
    expect(SecureScreen.protecting, isTrue, reason: 'whole app');
    await SecureScreen.policy(wholeApp: false, exams: true);
  });

  testWidgets('update needed: versions, size and the update button', (t) async {
    const info = UpdateInfo(AppRelease(version: '0.3.1-202611041200', build: 29371300, size: 28 * 1048576, builtAt: null, url: 'u'), force: true);
    await t.pumpWidget(
      ProviderScope(
        overrides: [updateBackendProvider.overrideWithValue(FakeBackend()), myVersionNameProvider.overrideWith((_) async => '0.3.0-202610201015')],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const UpdateScreen(info: info),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Update needed'), findsOneWidget);
    expect(find.text('0.3.1 · 4 Nov'), findsOneWidget, reason: 'new version, with its date');
    expect(find.text('0.3.0 · 20 Oct'), findsOneWidget, reason: 'the version on this phone');
    expect(find.text('28 MB'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.text('Later'), findsNothing, reason: 'a must-update has no way back');
  });

  test('update styles from Admin → Settings → App updates (and settings saved before styles)', () {
    expect(updateMode({'mode': 'popup', 'force': false}, legacyPopup: false), 'popup');
    expect(updateMode({'mode': 'quiet'}, legacyPopup: true), 'quiet');
    expect(updateMode({'mode': 'force'}, legacyPopup: false), 'force');
    // Older saves: force switch; the Play pop-up was on unless switched off.
    expect(updateMode({'force': true}, legacyPopup: false), 'force');
    expect(updateMode({'force': false}, legacyPopup: false), 'quiet');
    expect(updateMode({'force': false}, legacyPopup: true), 'popup');
    expect(updateMode({'force': false, 'prompt': false}, legacyPopup: true), 'quiet');
  });

  const rel = AppRelease(version: '0.3.1-202611041200', build: 29371300, size: 28 * 1048576, builtAt: null, url: 'u');
  Widget gate(UpdateInfo info, {FakeBackend? backend}) => ProviderScope(
    key: UniqueKey(),
    overrides: [
      appUpdateProvider.overrideWith((_) async => info),
      updateBackendProvider.overrideWithValue(backend ?? FakeBackend()),
      myVersionNameProvider.overrideWith((_) async => '0.3.0-202610201015'),
    ],
    child: MaterialApp(
      navigatorKey: rootNavKey,
      theme: buildTheme(Brightness.light),
      home: const UpdateGate(child: Scaffold(body: Text('HOME'))),
    ),
  );

  testWidgets('pop-up style: Update now starts the download; the student can keep using the app while it runs', (t) async {
    final b = FakeBackend();
    await t.pumpWidget(gate(const UpdateInfo(rel, force: false, popup: true, notes: 'Faster tests'), backend: b));
    await t.pump();
    // "Later" is remembered in a real file: let the file check finish.
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    await t.ensureVisible(find.text('Update now'));
    await t.pump();
    await t.tap(find.text('Update now'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(b.downloads, 1, reason: 'one tap on the pop-up starts the download');
    b.tick!(const DlTick(7 * 1048576, 28 * 1048576));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Downloading update'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    await t.tap(find.text('Keep using the app'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(milliseconds: 400)); // the card comes back the frame after the screen closes
    expect(find.text('HOME'), findsOneWidget);
    // The small card follows the same download.
    expect(find.text('Downloading update'), findsOneWidget);
    b.dl!.complete(File('x.apk'));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Update downloaded'), findsOneWidget);
    expect(b.installs, 0, reason: 'never opens the installer in the middle of what the student is doing');
    await t.tap(find.text('Install'));
    await t.pump(const Duration(milliseconds: 300));
    expect(b.installs, 1);
  });

  testWidgets('pop-up style: Later closes the pop-up and the app is used as normal', (t) async {
    await t.pumpWidget(gate(const UpdateInfo(rel, force: false, popup: true)));
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Discover a\nnew version'), findsOneWidget);
    await t.ensureVisible(find.text('Later'));
    await t.pump();
    await t.tap(find.text('Later'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Discover a\nnew version'), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('must-update style locks the app; quiet style only shows the small card', (t) async {
    await t.pumpWidget(gate(const UpdateInfo(rel, force: true)));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Update needed'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    await t.pumpWidget(gate(const UpdateInfo(rel, force: false)));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('Update needed'), findsNothing);
    expect(find.text('New version ready'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  group('one download for the whole app', () {
    const r = AppRelease(version: '0.3.1-202611041200', build: 29371300, size: 1000, builtAt: null, url: 'u');
    (ProviderContainer, FakeBackend) make() {
      final b = FakeBackend();
      final c = ProviderContainer(overrides: [updateBackendProvider.overrideWithValue(b)]);
      addTearDown(c.dispose);
      return (c, b);
    }

    test('downloading, waiting for internet, then install; Android permission continues by itself', () async {
      final (c, b) = make();
      final ctl = c.read(updateCtlProvider.notifier);
      final run = ctl.start(r);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(updateCtlProvider).phase, UpdPhase.starting);
      b.tick!(const DlTick(400, 1000));
      expect(c.read(updateCtlProvider).phase, UpdPhase.downloading);
      expect(c.read(updateCtlProvider).progress, .4);
      b.tick!(const DlTick(400, 1000, waiting: true));
      expect(c.read(updateCtlProvider).phase, UpdPhase.waiting, reason: 'no internet is a wait, not an error');
      b.can = false;
      b.dl!.complete(File('x.apk'));
      await run;
      expect(c.read(updateCtlProvider).phase, UpdPhase.permission);
      expect(b.allows, 1, reason: 'opens "Allow from this source"');
      await ctl.onResume();
      expect(b.installs, 0, reason: 'still not allowed');
      b.can = true;
      await ctl.onResume(); // back from Settings
      expect(b.installs, 1, reason: 'the install carries on without another tap');
      expect(c.read(updateCtlProvider).installAsked, isTrue);
    });

    test('errors in plain words; Try again starts once more', () async {
      final (c, b) = make();
      final ctl = c.read(updateCtlProvider.notifier);
      var run = ctl.start(r);
      await Future<void>.delayed(Duration.zero);
      b.dl!.completeError(const SocketException('no route'));
      await run;
      expect(c.read(updateCtlProvider).phase, UpdPhase.failed);
      expect(c.read(updateCtlProvider).error, UpdateError.internet.message);
      run = ctl.start(r);
      await Future<void>.delayed(Duration.zero);
      expect(b.downloads, 2);
      b.dl!.completeError(const FileSystemException('write', 'x', OSError('No space left on device', 28)));
      await run;
      expect(c.read(updateCtlProvider).error, UpdateError.space.message);
    });

    test('cancel stops it and removes the file; a late finish changes nothing', () async {
      final (c, b) = make();
      final ctl = c.read(updateCtlProvider.notifier);
      final run = ctl.start(r);
      await Future<void>.delayed(Duration.zero);
      b.tick!(const DlTick(300, 1000));
      await ctl.cancel();
      expect(b.cancels, 1);
      expect(c.read(updateCtlProvider).phase, UpdPhase.idle);
      b.dl!.complete(File('x.apk'));
      await run;
      expect(c.read(updateCtlProvider).phase, UpdPhase.idle);
      expect(b.installs, 0);
    });

    test('coming back: a finished download is ready, a running one is followed, a half one can continue', () async {
      var (c, b) = make();
      b.resumeWith = (1000, false, File('x.apk'));
      await c.read(updateCtlProvider.notifier).restore(r);
      expect(c.read(updateCtlProvider).phase, UpdPhase.ready);

      (c, b) = make();
      b.resumeWith = (300, true, null);
      await c.read(updateCtlProvider.notifier).restore(r);
      await Future<void>.delayed(Duration.zero);
      expect(b.downloads, 1, reason: 'follows the download that is still running');
      expect(c.read(updateCtlProvider.notifier).autoInstall, isFalse, reason: 'and does not jump into the installer');

      (c, b) = make();
      b.resumeWith = (300, false, null);
      await c.read(updateCtlProvider.notifier).restore(r);
      expect(c.read(updateCtlProvider).phase, UpdPhase.idle);
      expect(c.read(updateCtlProvider).progress, .3);
    });
  });

  group('Windows download continues from where it stopped', () {
    final data = List<int>.generate(1000, (i) => i % 251);
    const r = AppRelease(version: '0.3.1', build: 1, size: 1000, builtAt: null, url: 'https://cbt.solutiontee.com/download/windows');

    test('cut short, then continued with a range request; the website link is asked again each time', () async {
      final dir = Directory.systemTemp.createTempSync('upd');
      addTearDown(() => dir.deleteSync(recursive: true));
      final target = File('${dir.path}/solutiontee-1.exe');
      final ranges = <String?>[];
      var first = true;
      final client = MockClient((req) async {
        if (req.url.host == 'cbt.solutiontee.com') {
          expect(req.followRedirects, isFalse);
          return http.Response('', 307, headers: {'location': 'https://files.example/app.exe?sig=${ranges.length}'});
        }
        ranges.add(req.headers['range']);
        if (first) {
          first = false;
          return http.Response.bytes(data.sublist(0, 600), 200); // the connection dropped at 600
        }
        final from = int.parse(req.headers['range']!.split('=')[1].split('-')[0]);
        return http.Response.bytes(data.sublist(from), 206);
      });
      final ticks = <int>[];
      await expectLater(Updater.downloadTo(target, r, (t) => ticks.add(t.got), CancelToken(), client: client), throwsA(isA<UpdateError>()));
      expect(File('${target.path}.part').lengthSync(), 600);
      final f = await Updater.downloadTo(target, r, (t) => ticks.add(t.got), CancelToken(), client: client);
      expect(ranges, [null, 'bytes=600-']);
      expect(f.readAsBytesSync(), data);
      expect(File('${target.path}.part').existsSync(), isFalse);
      expect(ticks.last, 1000);
    });

    test('a server that ignores the range sends the whole file again: the part starts over', () async {
      final dir = Directory.systemTemp.createTempSync('upd');
      addTearDown(() => dir.deleteSync(recursive: true));
      final target = File('${dir.path}/solutiontee-1.exe');
      File('${target.path}.part').writeAsBytesSync(List.filled(400, 9));
      final client = MockClient((req) async {
        if (req.url.host == 'cbt.solutiontee.com') return http.Response('', 307, headers: {'location': 'https://files.example/app.exe'});
        return http.Response.bytes(data, 200);
      });
      final f = await Updater.downloadTo(target, r, (_) {}, CancelToken(), client: client);
      expect(f.readAsBytesSync(), data);
    });

    test('versions read like people say them', () {
      expect(prettyVersion('0.3.0-202611161107'), '0.3.0 · 16 Nov');
      expect(prettyVersion('0.3.0'), '0.3.0');
      expect(fmtMb(28 * 1048576), '28 MB');
      expect(fmtMb(3 * 1048576 + 400000), '3.4 MB');
      expect(fmtLeft(const Duration(seconds: 12)), 'about 15 s left');
      expect(fmtLeft(const Duration(seconds: 130)), 'about 3 min left');
    });
  });

  testWidgets('Play test copy from the website: the pop-up says it downloads from the website (D-173)', (t) async {
    Widget pop({required bool web}) => ProviderScope(
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: UpdatePopup(version: '0.3.0', fromWebsite: web, onUpdate: () {}, onLater: () {}),
        ),
      ),
    );
    await t.pumpWidget(pop(web: true));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Tap Update now to download it, then open the file to install.'), findsOneWidget);
    await t.pumpWidget(pop(web: false));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Tap Update now. It downloads and installs inside the app.'), findsOneWidget);
    // An install from Google Play has no website link: Update now opens Google Play.
    expect(const PlayOffer(5).url, isNull);
    expect(PlayOffer(5, url: Uri.parse('https://cbt.solutiontee.com/download/apk?channel=play')).url?.query, 'channel=play');
  });
}
