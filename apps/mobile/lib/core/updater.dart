import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'config.dart';
import 'platform.dart';
import 'app_gate.dart' show appGateProvider, UpdatePopup, updateMode;
import 'house_ads.dart' show rootNavKey;
import 'update_ui.dart';

export 'update_ui.dart';

/// In-app update of the direct (website) app and the Windows app (owner, D-080, D-166; rebuilt 16 Nov 2026, D-181).
/// The app asks the website for the newest build, compares it with its own build number (minutes since 1970, set by
/// GitHub), downloads it and installs it. One [UpdateController] runs the download for the whole app, so the update
/// screen, the pop-up and the small card all show the same progress, and an optional update can keep downloading
/// while the student goes on practising. When the admin's "must update" switch is on, nothing else can be used until
/// it is installed. The Play Store app is left to Google Play (Play does not allow apps to install themselves).

/// How many update pop-ups are on screen now (other pop-ups wait for them, D-174).
final updatePopupsOpen = ValueNotifier<int>(0);

class AppRelease {
  const AppRelease({required this.version, required this.build, required this.size, required this.builtAt, required this.url});
  final String version, url;
  final int? build;
  final int size;
  final DateTime? builtAt;

  factory AppRelease.fromJson(Map<String, dynamic> j) => AppRelease(
    version: '${j['version'] ?? ''}',
    build: (j['build'] as num?)?.toInt(),
    size: (j['size'] as num?)?.toInt() ?? 0,
    builtAt: DateTime.tryParse('${j['built_at'] ?? ''}'),
    url: '${j['url'] ?? '${Config.apiBase}/download/apk'}',
  );

  /// Newer than the installed build [myCode]? Builds made before D-080 have no build number: use the build time
  /// (a little later than the build number, so allow 30 minutes).
  bool newerThan(int myCode) {
    if (myCode < 1000000) return false; // a developer build (versionCode 1): never nag
    if (build != null) return build! > myCode;
    final at = builtAt;
    return at != null && at.millisecondsSinceEpoch ~/ 60000 > myCode + 30;
  }

  String get sizeText => size <= 0 ? '' : fmtMb(size);

  /// The file name the download is saved under.
  String get fileName => 'solutiontee-${build ?? version}.${isWindows ? 'exe' : 'apk'}';
}

class UpdateInfo {
  const UpdateInfo(this.release, {required this.force, this.popup = false, this.notes = ''});
  final AppRelease release;

  /// Must update: the app is locked until the new build is installed.
  final bool force;

  /// Pop-up with "Update now" and "Later" (Admin → Settings → App updates → Pop-up).
  final bool popup;
  final String notes;
}

// ---------------------------------------------------------------------------------------------------- download pieces

/// One progress report: bytes so far, the full size (0 if not known yet), and whether the download is waiting for
/// the internet (Android's download manager pauses by itself and carries on when the phone is back online).
class DlTick {
  const DlTick(this.got, this.total, {this.waiting = false});
  final int got, total;
  final bool waiting;
}

/// Stops a download that is running.
class CancelToken {
  bool cancelled = false;
  void cancel() => cancelled = true;
}

class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

/// A problem the student can act on, in plain words.
class UpdateError implements Exception {
  const UpdateError(this.message);
  final String message;

  static const internet = UpdateError('The download stopped. Check your internet and tap Try again. It continues from where it stopped.');
  static const space = UpdateError('There is not enough free space. Delete a few photos or videos, then tap Try again.');
  static const stopped = UpdateError('The download was stopped. Tap Try again to start it again.');
  static const installer = UpdateError('The installer did not open. Tap Install update to try again.');

  /// Any error, as words for the student.
  static UpdateError from(Object e) {
    if (e is UpdateError) return e;
    if (e is FileSystemException) {
      final code = e.osError?.errorCode;
      // ENOSPC (28) on Android; ERROR_DISK_FULL (112) / ERROR_HANDLE_DISK_FULL (39) on Windows.
      if (code == 28 || code == 112 || code == 39) return space;
      return const UpdateError('The update could not be saved. Free up some space and tap Try again.');
    }
    return internet;
  }
}

abstract final class Updater {
  static const _ch = MethodChannel('solutiontee/update');

  /// The app that installed this one: "com.android.vending" for Google Play, "" when unknown or not Android (D-173).
  static Future<String> installer() async {
    if (!Platform.isAndroid) return '';
    try {
      return await _ch.invokeMethod<String>('installer') ?? '';
    } catch (_) {
      return '';
    }
  }

  /// The installed version name, e.g. "0.3.0-202611070721".
  static Future<String> myName() async {
    if (isDesktop) return desktopBuild > 0 ? '${Config.appVersion}-${_stamp(desktopBuild)}' : Config.appVersion;
    try {
      final m = await _ch.invokeMapMethod<String, Object?>('version');
      return '${m?['name'] ?? ''}';
    } catch (_) {
      return '';
    }
  }

  /// A build number (minutes since 1970) as the yyyyMMddHHmm stamp the Android version names use.
  static String _stamp(int minutes) {
    final d = DateTime.fromMillisecondsSinceEpoch(minutes * 60000, isUtc: true);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}${two(d.hour)}${two(d.minute)}';
  }

  /// This app's versionCode (0 if unknown).
  static Future<int> myCode() async {
    if (isDesktop) return desktopBuild;
    try {
      final m = await _ch.invokeMapMethod<String, Object?>('version');
      return (m?['code'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> canInstall() async {
    if (isDesktop) return true;
    try {
      return await _ch.invokeMethod<bool>('canInstall') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> allowInstall() async {
    if (isDesktop) return;
    try {
      await _ch.invokeMethod<bool>('allowInstall');
    } catch (_) {}
  }

  static Future<void> install(File file) async {
    if (isWindows) {
      // The Inno Setup installer updates in place and opens the app again (D-166). The app ends first so its files
      // can be replaced; it ends through the runner (no plugin shutdown), never with exit(), which crashed (D-177).
      await Process.start(file.path, const ['/SILENT', '/SP-', '/NOCANCEL', '/NORESTART', '/CLOSEAPPLICATIONS'], mode: ProcessStartMode.detached);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      try {
        await const MethodChannel('solutiontee/desktop').invokeMethod<void>('quit');
      } catch (_) {}
      exit(0);
    }
    try {
      await _ch.invokeMethod<bool>('install', file.path);
    } on PlatformException {
      throw UpdateError.installer;
    }
  }

  /// Downloads the update, reporting progress. On Android, the phone's download manager does the work (owner,
  /// 2026-11-07): it keeps going when the app is minimised or closed and shows its own notification; the same download
  /// is picked up again when the student comes back. Windows (and a phone without a download manager) downloads inside
  /// the app into a ".part" file that continues from where it stopped.
  static Future<File> download(AppRelease r, void Function(DlTick) onTick, CancelToken token) async {
    if (isDesktop) return downloadTo(await _inAppTarget(r), r, onTick, token);
    try {
      return await _bgDownload(r, onTick, token);
    } on _NoDownloadManager {
      return downloadTo(await _inAppTarget(r), r, onTick, token);
    }
  }

  static Future<Directory> _inAppDir() async => Directory('${(await getTemporaryDirectory()).path}/updates');

  static Future<File> _inAppTarget(AppRelease r) async {
    final dir = await _inAppDir();
    await dir.create(recursive: true);
    // Only this release's files stay (an older half-download is useless now).
    for (final old in dir.listSync()) {
      final n = old.uri.pathSegments.last;
      if (old is File && n != r.fileName && n != '${r.fileName}.part') await old.delete().catchError((_) => old);
    }
    return File('${dir.path}/${r.fileName}');
  }

  /// Downloads [r] into [target] (through "[target].part"), continuing a part already there with an HTTP range request.
  /// The website link is a redirect to a short-lived signed link, so it is asked again for each try.
  @visibleForTesting
  static Future<File> downloadTo(File target, AppRelease r, void Function(DlTick) onTick, CancelToken token, {http.Client? client}) async {
    if (await target.exists() && (r.size <= 0 || await target.length() == r.size)) {
      onTick(DlTick(r.size, r.size));
      return target;
    }
    final part = File('${target.path}.part');
    var have = await part.exists() ? await part.length() : 0;
    if (r.size > 0 && have > r.size) {
      await part.delete();
      have = 0;
    }
    final c = client ?? http.Client();
    try {
      if (r.size > 0 && have == r.size) return await _finish(part, target, r, onTick);
      final url = await _resolve(c, Uri.parse(r.url));
      final req = http.Request('GET', url);
      if (have > 0) req.headers['range'] = 'bytes=$have-';
      final res = await c.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        have = 0; // the server sent the whole file: start the part again
      } else if (res.statusCode == 416 && have > 0) {
        await res.stream.listen(null).cancel();
        await part.delete();
        throw UpdateError.internet; // the part did not match: the next try starts clean
      } else if (res.statusCode != 206) {
        await res.stream.listen(null).cancel();
        throw HttpException('download ${res.statusCode}');
      }
      final total = r.size > 0 ? r.size : (res.contentLength == null ? 0 : have + res.contentLength!);
      onTick(DlTick(have, total));
      final sink = part.openWrite(mode: have > 0 ? FileMode.append : FileMode.write);
      var got = have;
      try {
        await for (final chunk in res.stream.timeout(const Duration(seconds: 60))) {
          if (token.cancelled) throw const UpdateCancelled();
          sink.add(chunk);
          got += chunk.length;
          onTick(DlTick(got, total));
        }
      } finally {
        await sink.close();
      }
      return await _finish(part, target, r, onTick);
    } finally {
      if (client == null) c.close();
    }
  }

  static Future<File> _finish(File part, File target, AppRelease r, void Function(DlTick) onTick) async {
    final len = await part.length();
    if (r.size > 0 && len != r.size) throw UpdateError.internet; // cut short: the next try continues it
    if (await target.exists()) await target.delete();
    final done = await part.rename(target.path);
    onTick(DlTick(len, len));
    return done;
  }

  /// Where the website's download link leads (a 10-minute signed link), without downloading through it twice.
  static Future<Uri> _resolve(http.Client c, Uri url) async {
    final req = http.Request('GET', url)..followRedirects = false;
    final res = await c.send(req).timeout(const Duration(seconds: 20));
    await res.stream.listen(null).cancel();
    final loc = res.headers['location'];
    if (res.statusCode >= 300 && res.statusCode < 400 && loc != null) return url.resolve(loc);
    if (res.statusCode == 200) return url;
    throw HttpException('download ${res.statusCode}');
  }

  static Future<File> _idFile() async => File('${(await getApplicationSupportDirectory()).path}/update_download.json');

  static Future<Map<String, dynamic>> _status(int id) async => Map<String, dynamic>.from(await _ch.invokeMethod('bgStatus', id) as Map);

  /// Where an earlier download of [r] stands (the app was closed or restarted meanwhile): bytes so far, whether it is
  /// still running in the background, and the finished file.
  static Future<(int got, bool running, File? done)> resume(AppRelease r) async {
    try {
      if (isDesktop || !Platform.isAndroid) {
        final target = File('${(await _inAppDir()).path}/${r.fileName}');
        if (await target.exists() && (r.size <= 0 || await target.length() == r.size)) return (r.size, false, target);
        final part = File('${target.path}.part');
        return (await part.exists() ? await part.length() : 0, false, null);
      }
      final f = await _idFile();
      if (!await f.exists()) return (0, false, null);
      final j = jsonDecode(await f.readAsString()) as Map;
      if (j['name'] != r.fileName) return (0, false, null);
      final st = await _status((j['id'] as num).toInt());
      final status = (st['status'] as num?)?.toInt() ?? 0, got = (st['got'] as num?)?.toInt() ?? 0;
      if (status == 8) {
        final file = File('${st['path']}');
        if (await file.exists() && (r.size <= 0 || await file.length() == r.size)) return (r.size, false, file);
      }
      if (status == 1 || status == 2 || status == 4) return (got, true, null);
    } catch (_) {}
    return (0, false, null);
  }

  static Future<File> _bgDownload(AppRelease r, void Function(DlTick) onTick, CancelToken token) async {
    int? id;
    try {
      final f = await _idFile();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map;
        if (j['name'] == r.fileName) {
          final st = await _status((j['id'] as num).toInt());
          final s = (st['status'] as num?)?.toInt() ?? 0;
          if (s == 1 || s == 2 || s == 4 || s == 8) id = (j['id'] as num).toInt(); // follow it again, never from zero
        }
      }
    } on MissingPluginException {
      throw _NoDownloadManager();
    } catch (_) {}
    if (id == null) {
      try {
        id = (await _ch.invokeMethod<num>('bgDownload', {'url': r.url, 'name': r.fileName, 'title': 'SolutionTee CBT update'}))?.toInt();
      } on MissingPluginException {
        throw _NoDownloadManager();
      } on PlatformException {
        throw _NoDownloadManager();
      }
      if (id == null) throw _NoDownloadManager();
      await (await _idFile()).writeAsString(jsonEncode({'id': id, 'name': r.fileName}));
    }
    // Follow it while the app is open (it carries on by itself when the app is not). A pause (no internet) is shown as
    // waiting, not as an error: the download manager continues when the phone is back online.
    while (true) {
      if (token.cancelled) throw const UpdateCancelled();
      final st = await _status(id);
      final status = (st['status'] as num?)?.toInt() ?? 0;
      final got = (st['got'] as num?)?.toInt() ?? 0, total = (st['total'] as num?)?.toInt() ?? 0;
      onTick(DlTick(got, total > 0 ? total : r.size, waiting: status == 4));
      if (status == 8) {
        final file = File('${st['path']}');
        if (r.size > 0 && await file.length() != r.size) {
          await _forget();
          throw UpdateError.stopped;
        }
        return file;
      }
      if (status == 16 || status == 0) {
        await _forget();
        // DownloadManager.ERROR_INSUFFICIENT_SPACE
        throw (st['reason'] as num?)?.toInt() == 1006 ? UpdateError.space : (status == 0 ? UpdateError.stopped : UpdateError.internet);
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
  }

  static Future<void> _forget() async {
    try {
      await (await _idFile()).delete();
    } catch (_) {}
  }

  /// Stops and removes a download (the "Cancel download" button).
  static Future<void> cancel(AppRelease r) async {
    try {
      if (Platform.isAndroid && !isDesktop) {
        final f = await _idFile();
        if (await f.exists()) {
          final j = jsonDecode(await f.readAsString()) as Map;
          await _ch.invokeMethod('bgCancel', (j['id'] as num).toInt());
        }
        await _forget();
      }
      final dir = await _inAppDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// The app is up to date: old update files are deleted so they do not fill the phone (about 28 MB each).
  static Future<void> cleanup() async {
    try {
      if (Platform.isAndroid && !isDesktop) {
        await _ch.invokeMethod('cleanup');
        await _forget();
      }
      final dir = await _inAppDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}

class _NoDownloadManager implements Exception {}

// ---------------------------------------------------------------------------------------------------- the controller

enum UpdPhase {
  /// Nothing running (an earlier part may be there: [UpdState.got] > 0).
  idle,

  /// Asking the server for the file.
  starting,
  downloading,

  /// No internet: carries on by itself.
  waiting,

  /// Downloaded; the install has not finished.
  ready,

  /// Android needs "Allow from this source" for SolutionTee.
  permission,

  /// Windows: the installer runs and the app closes.
  installing,
  failed,
}

@immutable
class UpdState {
  const UpdState({this.phase = UpdPhase.idle, this.got = 0, this.total = 0, this.speed = 0, this.error, this.build, this.installAsked = false});
  final UpdPhase phase;
  final int got, total;

  /// Bytes a second, over the last few seconds (0 when not known).
  final double speed;
  final String? error;

  /// The build this state is about.
  final int? build;

  /// Android's install screen was opened at least once.
  final bool installAsked;

  double? get progress => total > 0 ? (got / total).clamp(0.0, 1.0) : null;
  bool get active => phase == UpdPhase.starting || phase == UpdPhase.downloading || phase == UpdPhase.waiting;

  /// Time left, when the speed is known.
  Duration? get left => speed > 1000 && total > got ? Duration(seconds: ((total - got) / speed).ceil()) : null;

  UpdState copyWith({UpdPhase? phase, int? got, int? total, double? speed, String? error, bool clearError = false, bool? installAsked}) => UpdState(
    phase: phase ?? this.phase,
    got: got ?? this.got,
    total: total ?? this.total,
    speed: speed ?? this.speed,
    error: clearError ? null : (error ?? this.error),
    build: build,
    installAsked: installAsked ?? this.installAsked,
  );
}

/// What the controller needs from the phone or computer (a fake one in tests).
class UpdateBackend {
  const UpdateBackend();
  Future<File> download(AppRelease r, void Function(DlTick) onTick, CancelToken token) => Updater.download(r, onTick, token);
  Future<(int, bool, File?)> resume(AppRelease r) => Updater.resume(r);
  Future<bool> canInstall() => Updater.canInstall();
  Future<void> allowInstall() => Updater.allowInstall();
  Future<void> install(File f) => Updater.install(f);
  Future<void> cancel(AppRelease r) => Updater.cancel(r);
  Future<void> cleanup() => Updater.cleanup();
}

final updateBackendProvider = Provider<UpdateBackend>((ref) => const UpdateBackend());

/// The one download for the whole app.
class UpdateController extends Notifier<UpdState> {
  CancelToken? _token;
  File? _file;
  AppRelease? _rel;
  final _samples = <(int ms, int got)>[];

  /// The student is on the update screen, waiting: install as soon as the download is done. When they go back to the
  /// app it finishes in the background and the small card offers the install (never in the middle of a test).
  bool autoInstall = false;

  UpdateBackend get _b => ref.read(updateBackendProvider);

  @override
  UpdState build() => const UpdState();

  /// Picks up an earlier download of [r] (the app was closed or restarted): finished, still running, or half done.
  Future<void> restore(AppRelease r) async {
    if (state.active || (_rel?.build == r.build && state.phase != UpdPhase.idle)) return;
    _rel = r;
    final (got, running, done) = await _b.resume(r);
    if (state.active || state.phase != UpdPhase.idle) return;
    if (done != null) {
      _file = done;
      state = UpdState(phase: UpdPhase.ready, got: r.size, total: r.size, build: r.build);
    } else if (running) {
      unawaited(start(r, install: false));
    } else if (got > 0) {
      state = UpdState(got: got, total: r.size, build: r.build);
    }
  }

  /// Downloads [r] (or follows the download already running) and, when [install], installs it as soon as it is done.
  Future<void> start(AppRelease r, {bool install = true}) async {
    if (install) autoInstall = true;
    if (state.active) return;
    if (state.phase == UpdPhase.ready && _file != null && _rel?.build == r.build) {
      if (install) await this.install();
      return;
    }
    _rel = r;
    autoInstall = install;
    final token = _token = CancelToken();
    _samples.clear();
    state = UpdState(phase: UpdPhase.starting, got: state.build == r.build ? state.got : 0, total: r.size, build: r.build);
    try {
      final f = await _b.download(r, (t) => token.cancelled ? null : _tick(t), token);
      if (token.cancelled) return;
      _file = f;
      state = state.copyWith(phase: UpdPhase.ready, got: state.total > 0 ? state.total : state.got, speed: 0);
      if (autoInstall) await this.install();
    } on UpdateCancelled {
      return;
    } catch (e) {
      if (token.cancelled) return;
      state = state.copyWith(phase: UpdPhase.failed, error: UpdateError.from(e).message, speed: 0);
    }
  }

  void _tick(DlTick t) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _samples.add((now, t.got));
    _samples.removeWhere((s) => now - s.$1 > 4000);
    var speed = 0.0;
    if (_samples.length > 1) {
      final dt = (now - _samples.first.$1) / 1000;
      if (dt >= .8) speed = (t.got - _samples.first.$2) / dt;
    }
    state = state.copyWith(
      phase: t.waiting ? UpdPhase.waiting : (t.got > 0 ? UpdPhase.downloading : UpdPhase.starting),
      got: t.got,
      total: t.total > 0 ? t.total : state.total,
      speed: t.waiting ? 0 : speed,
      clearError: true,
    );
  }

  /// Opens the installer (Android asks the student to confirm; Windows installs and opens the app again).
  Future<void> install() async {
    final f = _file;
    final r = _rel;
    if (f == null) {
      if (r != null) await start(r);
      return;
    }
    if (!await _b.canInstall()) {
      // Android: "Allow from this source". When the student comes back ([onResume]) the install carries on by itself.
      state = state.copyWith(phase: UpdPhase.permission, clearError: true);
      await _b.allowInstall();
      return;
    }
    state = state.copyWith(phase: UpdPhase.installing, clearError: true);
    try {
      await _b.install(f);
      // Android shows its own install screen; if the student backs out, Install update opens it again.
      state = state.copyWith(phase: UpdPhase.ready, installAsked: true);
    } catch (e) {
      state = state.copyWith(phase: UpdPhase.ready, error: (e is UpdateError ? e : UpdateError.installer).message);
    }
  }

  /// The app came back to the front: after "Allow from this source", the install continues.
  Future<void> onResume() async {
    if (state.phase == UpdPhase.permission && await _b.canInstall()) await install();
  }

  /// Opens the phone's setting again (the "Open settings" button).
  Future<void> askPermission() => _b.allowInstall();

  /// Stops the download and removes what was saved.
  Future<void> cancel() async {
    _token?.cancel();
    autoInstall = false;
    final r = _rel;
    _file = null;
    state = UpdState(build: r?.build);
    if (r != null) await _b.cancel(r);
  }

  /// The app is up to date: nothing to show, and old update files go.
  Future<void> upToDate() async {
    if (state.active) return;
    _file = null;
    state = const UpdState();
    await _b.cleanup();
  }
}

final updateCtlProvider = NotifierProvider<UpdateController, UpdState>(UpdateController.new);

/// The installed version name ("0.3.0-202611070721").
final myVersionNameProvider = FutureProvider<String>((ref) => Updater.myName());

/// Is a newer direct app ready? null = up to date, Play build, offline or not known.
final appUpdateProvider = FutureProvider<UpdateInfo?>((ref) async {
  if (appFlavor == 'play' || !(Platform.isAndroid || isWindows)) return null;
  final mine = await Updater.myCode();
  final r = await http
      .get(Uri.parse('${Config.apiBase}/api/app/latest${isWindows ? '?channel=windows' : ''}'), headers: {'cache-control': 'no-cache'})
      .timeout(const Duration(seconds: 10));
  if (r.statusCode != 200) return null;
  final rel = AppRelease.fromJson(Map<String, dynamic>.from(jsonDecode(r.body) as Map));
  if (!rel.newerThan(mine)) {
    unawaited(ref.read(updateCtlProvider.notifier).upToDate());
    return null;
  }
  // Admin → Settings → App updates (owner, 15 Nov 2026): "quiet" = the small card, "popup" = Update now / Later,
  // "force" = locked until updated. The admin's minimum build also locks any older app.
  var mode = 'quiet', notes = '';
  try {
    final g = await ref.read(appGateProvider.future);
    final u = g['app_update'];
    if (u is Map) {
      mode = updateMode(Map<String, dynamic>.from(u), legacyPopup: false);
      notes = '${u['notes'] ?? ''}';
    }
    if (((g['min_build'] as num?)?.toInt() ?? 0) > mine) mode = 'force';
  } catch (_) {}
  return UpdateInfo(rel, force: mode == 'force', popup: mode == 'popup', notes: notes);
});

/// How many update screens are open (the small card hides while one is).
final updateScreensOpen = ValueNotifier<int>(0);

// ---------------------------------------------------------------------------------------------------- the gate

/// Wraps the whole app: a forced update replaces every screen; an optional one shows the pop-up or the small card, and
/// a download running in the background shows its progress in the small card.
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> with WidgetsBindingObserver {
  bool _dismissed = false;
  int? _asked, _popupFor, _restored;
  DateTime _checked = DateTime.now();

  Future<void> _askPopup(UpdateInfo u) async {
    final b = u.release.build ?? 0;
    if (_asked == b) return;
    _asked = b;
    if (await _UpdateSnooze.recently(b)) return;
    if (mounted) setState(() => _popupFor = b);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    updateScreensOpen.addListener(_rebuild);
  }

  // A screen opens or closes while Flutter is building: rebuild just after the frame.
  void _rebuild() => WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() {}) : null);

  @override
  void dispose() {
    updateScreensOpen.removeListener(_rebuild);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) return;
    ref.read(updateCtlProvider.notifier).onResume();
    // Check the website again when the student comes back, at most every 15 minutes (on Windows this fires each time
    // the window comes to the front).
    if (DateTime.now().difference(_checked) > const Duration(minutes: 15)) {
      _checked = DateTime.now();
      ref.invalidate(appUpdateProvider);
    }
  }

  void _open(UpdateInfo u, {bool start = false}) {
    rootNavKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => UpdateScreen(info: u, optional: true, startNow: start),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(appUpdateProvider).value;
    final st = ref.watch(updateCtlProvider);
    if (u == null) return widget.child;
    if (_restored != u.release.build) {
      _restored = u.release.build;
      Future.microtask(() => ref.read(updateCtlProvider.notifier).restore(u.release));
    }
    if (u.force) return UpdateScreen(info: u);
    if (u.popup) _askPopup(u);
    final busy = st.phase != UpdPhase.idle || st.got > 0;
    final showCard = updateScreensOpen.value == 0 && _popupFor != u.release.build && (busy || (!u.popup && !_dismissed));
    return Stack(
      children: [
        widget.child,
        if (showCard) UpdateFloatCard(info: u, onOpen: () => _open(u), onClose: busy ? null : () => setState(() => _dismissed = true)),
        if (u.popup && _popupFor == u.release.build)
          Positioned.fill(
            child: UpdatePopup(
              version: u.release.version.split('-').first,
              notes: u.notes,
              onUpdate: () {
                setState(() => _popupFor = null);
                _open(u, start: true);
              },
              onLater: () {
                setState(() => _popupFor = null);
                _UpdateSnooze.save(u.release.build ?? 0);
              },
            ),
          ),
      ],
    );
  }
}

/// "Later" on the update pop-up hides it for that build for a day.
abstract final class _UpdateSnooze {
  static Future<File> _file() async => File('${(await getApplicationSupportDirectory()).path}/app_update_snooze.json');

  static Future<bool> recently(int build) async {
    try {
      final j = jsonDecode(await (await _file()).readAsString()) as Map;
      final at = DateTime.tryParse('${j['at']}');
      return j['b'] == build && at != null && DateTime.now().difference(at) < const Duration(hours: 24);
    } catch (_) {
      return false;
    }
  }

  static Future<void> save(int build) async {
    try {
      await (await _file()).writeAsString(jsonEncode({'b': build, 'at': DateTime.now().toIso8601String()}));
    } catch (_) {}
  }
}
