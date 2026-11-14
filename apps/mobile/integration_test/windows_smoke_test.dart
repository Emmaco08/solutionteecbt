// Windows check (D-166), run by GitHub on a real Windows machine for every Windows build:
//   flutter test integration_test/windows_smoke_test.dart -d windows --dart-define=FIXTURES=<abs path to fixtures>
// Runs inside the real Windows app binary (with every plugin and our C++ runner) and uses each thing an Android
// feature needs: device ids for one account per computer, the local database, secure storage, files, game sounds,
// PDFs, notifications, screenshot blocking, the microphone, speech, links, keep-awake and connectivity.
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:record/record.dart';
import 'package:solutiontee_cbt/core/device.dart';
import 'package:solutiontee_cbt/core/platform.dart';
import 'package:solutiontee_cbt/core/win_capture.dart';
import 'package:solutiontee_cbt/core/win_registry.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const fixtures = String.fromEnvironment('FIXTURES');
final hex64 = RegExp(r'^[0-9a-f]{64}$');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('runs on Windows', () {
    expect(Platform.isWindows, isTrue);
    expect(isDesktop, isTrue);
  });

  test('one account per computer: Windows id and hardware id are read and hashed', () async {
    final guid = WinRegistry.localMachine(r'SOFTWARE\Microsoft\Cryptography', 'MachineGuid');
    expect(guid, isNotNull, reason: 'MachineGuid');
    final ids = await DeviceCheck.ids();
    expect(ids.android, matches(hex64));
    expect(ids.any, isTrue);
    expect(ids.clone, isFalse);
    final hw = await DesktopMachine.hardwareId();
    // ignore: avoid_print
    print('hardware id: ${hw == null ? 'none (placeholder or missing)' : 'found'}; flags: ${ids.flags}; drm slot: ${ids.drm != null}');
    if (hw != null) expect(ids.drm, matches(hex64));
    // The same computer always gives the same ids.
    final again = await DeviceCheck.ids();
    expect(again.list, ids.list);
  });

  test('local database (offline question packs, attempts, bookmarks)', () async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}smoke_${DateTime.now().millisecondsSinceEpoch}.sqlite');
    final db = AppDb(NativeDatabase(file));
    await db.kvSet('smoke', 'ok');
    expect(await db.kvGet('smoke'), 'ok');
    await db.close();
    await file.delete();
  });

  test('secure storage (sign-in tokens)', () async {
    const s = FlutterSecureStorage();
    await s.write(key: 'smoke', value: 'secret');
    expect(await s.read(key: 'smoke'), 'secret');
    await s.delete(key: 'smoke');
    expect(await s.read(key: 'smoke'), isNull);
  });

  test('folders for downloads (offline videos and PDFs)', () async {
    for (final d in [await getApplicationSupportDirectory(), await getApplicationDocumentsDirectory(), await getTemporaryDirectory()]) {
      expect(await d.exists(), isTrue, reason: d.path);
    }
  });

  test('game sounds and music play (MP3 on Windows)', () async {
    final names = ['tap', 'correct', 'wrong', 'win', 'music_hub', 'music_battle'];
    for (final name in names) {
      expect((await rootBundle.load('assets/sounds/$name.mp3')).lengthInBytes, greaterThan(1000), reason: '$name.mp3 is in the app');
    }
    if (!WinAudio.hasOutput) {
      // GitHub's Windows machines have no sound card; the app keeps sounds off on such a PC instead of erroring.
      // ignore: avoid_print
      print('no audio output on this machine: sounds checked as files only');
      return;
    }
    for (final name in names) {
      final p = AudioPlayer();
      await p.setSource(AssetSource('sounds/$name.mp3')).timeout(const Duration(seconds: 15));
      final d = await p.getDuration();
      expect(d, isNotNull, reason: name);
      expect(d!.inMilliseconds, greaterThan(0), reason: name);
      await p.dispose();
    }
  });

  test('PDF documents open and render', () async {
    final doc = await PdfDocument.openFile('$fixtures${Platform.pathSeparator}page.pdf');
    expect(doc.pagesCount, 1);
    final page = await doc.getPage(1);
    final img = await page.render(width: 200, height: 200, format: PdfPageImageFormat.png);
    expect(img?.bytes.isNotEmpty, isTrue);
    await page.close();
    await doc.close();
  });

  test('live notifications: the Windows channel answers', () async {
    const ch = MethodChannel('solutiontee/desktop');
    final r = await ch.invokeMethod<bool>('notify', {'id': 'smoke', 'title': 'SolutionTee CBT', 'body': 'Windows check'});
    expect(r, isA<bool>());
  });

  test('screenshot blocking on (tests and challenges) and off', () {
    expect(WinCapture.set(true), isTrue);
    expect(WinCapture.set(false), isTrue);
  });

  test('microphone and speech (voice notes, voice questions) start without errors', () async {
    final rec = AudioRecorder();
    final allowed = await rec.hasPermission().timeout(const Duration(seconds: 15));
    // ignore: avoid_print
    print('microphone allowed here: $allowed');
    await rec.dispose();
    final speech = SpeechToText();
    final ok = await speech.initialize().timeout(const Duration(seconds: 20), onTimeout: () => false);
    // ignore: avoid_print
    print('speech available here: $ok');
  });

  test('links open in the browser, keep-awake for videos, internet status', () async {
    expect(await canLaunchUrl(Uri.parse('https://cbt.solutiontee.com')), isTrue);
    await WakelockPlus.enable();
    expect(await WakelockPlus.enabled, isTrue);
    await WakelockPlus.disable();
    expect(await Connectivity().checkConnectivity(), isNotEmpty);
  });
}
