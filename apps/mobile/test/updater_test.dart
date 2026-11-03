import 'package:flutter/material.dart';
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
}
