import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solutiontee_cbt/core/app_gate.dart' show updateMode;
import 'package:solutiontee_cbt/core/house_ads.dart' show rootNavKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/secure_screen.dart';
import 'package:solutiontee_cbt/core/updater.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

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

  testWidgets('update needed: version, size and the update button', (t) async {
    const info = UpdateInfo(AppRelease(version: '0.3.1-202611041200', build: 29371300, size: 28 * 1048576, builtAt: null, url: 'u'), force: true);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const UpdateScreen(info: info),
      ),
    );
    await t.pump();
    expect(find.text('Update needed'), findsOneWidget);
    expect(find.text('Version 0.3.1-202611041200 · 28.0 MB'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
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
  Widget gate(UpdateInfo info) => ProviderScope(
    key: UniqueKey(),
    overrides: [appUpdateProvider.overrideWith((_) async => info)],
    child: MaterialApp(
      navigatorKey: rootNavKey,
      theme: buildTheme(Brightness.light),
      home: const UpdateGate(child: Scaffold(body: Text('HOME'))),
    ),
  );

  testWidgets('pop-up style: the app stays usable, Update now opens the download, Later closes it', (t) async {
    await t.pumpWidget(gate(const UpdateInfo(rel, force: false, popup: true, notes: 'Faster tests')));
    await t.pump();
    // "Later" is remembered in a real file: let the file check finish.
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('Update needed'), findsNothing);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    await t.ensureVisible(find.text('Update now'));
    await t.pump();
    await t.tap(find.text('Update now'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Update available'), findsOneWidget);
    await t.tap(find.text('Later'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('Update available'), findsNothing);
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
    await t.pump();
    expect(find.text('Update needed'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    await t.pumpWidget(gate(const UpdateInfo(rel, force: false)));
    await t.pump();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('Update needed'), findsNothing);
  });
}
