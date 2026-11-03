import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../theme/theme.dart';
import '../theme/tokens.g.dart';
import '../ui/kit.dart';
import '../widgets/phosphor.g.dart';
import 'config.dart';
import 'providers.dart';

/// In-app update of the direct (website) app (owner, D-080). The app asks the website for the newest build, compares
/// it with its own versionCode (minutes since 1970, set by GitHub), downloads it inside the app and opens Android's
/// installer. When the admin's "must update" switch is on, nothing else can be used until it is installed.
/// The Play Store app is left to Google Play (Play does not allow apps to install themselves).

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

  String get sizeText => size <= 0 ? '' : '${(size / 1048576).toStringAsFixed(1)} MB';
}

class UpdateInfo {
  const UpdateInfo(this.release, {required this.force});
  final AppRelease release;
  final bool force;
}

abstract final class Updater {
  static const _ch = MethodChannel('solutiontee/update');

  /// This app's versionCode (0 if unknown).
  static Future<int> myCode() async {
    try {
      final m = await _ch.invokeMapMethod<String, Object?>('version');
      return (m?['code'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> canInstall() async {
    try {
      return await _ch.invokeMethod<bool>('canInstall') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> allowInstall() async {
    try {
      await _ch.invokeMethod<bool>('allowInstall');
    } catch (_) {}
  }

  static Future<void> install(File apk) => _ch.invokeMethod<bool>('install', apk.path);

  /// Downloads the APK into the app's cache (reused if already complete), reporting 0..1.
  static Future<File> download(AppRelease r, void Function(double) onProgress) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    await dir.create(recursive: true);
    final name = 'solutiontee-${r.build ?? r.version}.apk';
    final file = File('${dir.path}/$name');
    if (await file.exists() && r.size > 0 && await file.length() == r.size) {
      onProgress(1);
      return file;
    }
    for (final old in dir.listSync()) {
      if (old is File && !old.path.endsWith(name)) await old.delete().catchError((_) => old);
    }
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(r.url))).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw HttpException('download ${res.statusCode}');
      final total = res.contentLength ?? r.size;
      final sink = file.openWrite();
      var got = 0;
      await for (final chunk in res.stream.timeout(const Duration(seconds: 60))) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress((got / total).clamp(0, 1));
      }
      await sink.close();
      if (r.size > 0 && await file.length() != r.size) throw const HttpException('incomplete');
      return file;
    } finally {
      client.close();
    }
  }
}

/// Is a newer direct app ready? null = up to date, Play build, offline or not known.
final appUpdateProvider = FutureProvider<UpdateInfo?>((ref) async {
  if (appFlavor == 'play' || !Platform.isAndroid) return null;
  final mine = await Updater.myCode();
  final r = await http.get(Uri.parse('${Config.apiBase}/api/app/latest'), headers: {'cache-control': 'no-cache'}).timeout(const Duration(seconds: 10));
  if (r.statusCode != 200) return null;
  final rel = AppRelease.fromJson(Map<String, dynamic>.from(jsonDecode(r.body) as Map));
  if (!rel.newerThan(mine)) return null;
  var force = true;
  try {
    final s = await ref.read(appSettingsProvider.future);
    final u = s['app_update'];
    if (u is Map && u['force'] == false) force = false;
  } catch (_) {}
  return UpdateInfo(rel, force: force);
});

/// Wraps the whole app: a forced update replaces every screen; an optional one shows a small card.
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> with WidgetsBindingObserver {
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) ref.invalidate(appUpdateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(appUpdateProvider).value;
    if (u == null) return widget.child;
    if (u.force) return UpdateScreen(info: u);
    if (_dismissed) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: Space.s4,
          right: Space.s4,
          bottom: Space.s4 + MediaQuery.of(context).padding.bottom + 64,
          child: Material(
            color: Colors.transparent,
            child: UpdateCard(info: u, onClose: () => setState(() => _dismissed = true)),
          ),
        ),
      ],
    );
  }
}

/// Download → install, with progress and the "install unknown apps" step.
class _UpdateFlow {
  _UpdateFlow(this.onChange);
  final VoidCallback onChange;
  double? progress;
  String? error;
  bool busy = false, needsPermission = false;

  Future<void> run(AppRelease r) async {
    busy = true;
    error = null;
    needsPermission = false;
    onChange();
    try {
      final file = await Updater.download(r, (p) {
        progress = p;
        onChange();
      });
      if (!await Updater.canInstall()) {
        needsPermission = true;
        busy = false;
        onChange();
        await Updater.allowInstall();
        return; // the student comes back from Settings and taps again
      }
      await Updater.install(file);
    } catch (_) {
      error = 'The download stopped. Check your internet and try again.';
    } finally {
      busy = false;
      onChange();
    }
  }
}

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key, required this.info});
  final UpdateInfo info;
  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  late final _flow = _UpdateFlow(() => mounted ? setState(() {}) : null);

  @override
  Widget build(BuildContext context) {
    final c = context.c, r = widget.info.release, f = _flow;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.s5),
          children: [
            const Gap(Space.s8),
            Center(child: IconTile(PhosphorIcons.arrowCircleUp(PhosphorIconsStyle.fill), tone: Tone.gold, size: 72, radius: 36, iconSize: 40)),
            const Gap(Space.s4),
            Text('Update needed', style: context.ty.h1, textAlign: TextAlign.center),
            const Gap(Space.s2),
            Text(
              'A new version of SolutionTee CBT is ready with fixes and new features. Update to keep using the app. Your account and saved tests stay.',
              style: context.ty.body.col(c.textMuted),
              textAlign: TextAlign.center,
            ),
            const Gap(Space.s2),
            Text(
              'Version ${r.version}${r.sizeText.isEmpty ? '' : ' · ${r.sizeText}'}',
              style: context.ty.cap.tnum.col(c.textSubtle),
              textAlign: TextAlign.center,
            ),
            const Gap(Space.s6),
            if (f.progress != null && f.busy) ...[
              ProgressBar(f.progress!),
              const Gap(Space.s2),
              Text('Downloading ${(f.progress! * 100).round()}%', style: context.ty.cap.tnum.col(c.textMuted), textAlign: TextAlign.center),
              const Gap(Space.s4),
            ],
            if (f.needsPermission)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s3),
                child: InfoBanner(
                  icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                  child: const Text('Turn on "Allow from this source" for SolutionTee CBT, come back, then tap Install update.'),
                ),
              ),
            if (f.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s3),
                child: Text(f.error!, style: context.ty.sm.col(c.error), textAlign: TextAlign.center),
              ),
            Btn(
              f.progress == 1 || f.needsPermission ? 'Install update' : 'Update now',
              block: true,
              loading: f.busy,
              leading: PhosphorIcons.downloadSimple(PhosphorIconsStyle.fill),
              onPressed: f.busy ? null : () => f.run(r),
            ),
            const Gap(Space.s3),
            Text('Android will ask you to confirm the update. It only takes a minute.', style: context.ty.cap.col(c.textSubtle), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// The small "update ready" card when updating is optional.
class UpdateCard extends StatefulWidget {
  const UpdateCard({super.key, required this.info, required this.onClose});
  final UpdateInfo info;
  final VoidCallback onClose;
  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> {
  late final _flow = _UpdateFlow(() => mounted ? setState(() {}) : null);

  @override
  Widget build(BuildContext context) {
    final c = context.c, f = _flow;
    return Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(
        color: Palette.navy900,
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.arrowCircleUp(PhosphorIconsStyle.fill), color: Palette.gold500),
          const Gap(Space.s3),
          Expanded(
            child: Text(
              f.busy && f.progress != null ? 'Downloading ${(f.progress! * 100).round()}%' : (f.error ?? 'A new version is ready'),
              style: context.ty.sm.bold.col(Colors.white),
            ),
          ),
          Btn('Update', kind: BtnKind.accent, sm: true, loading: f.busy, onPressed: f.busy ? null : () => f.run(widget.info.release)),
          IconBtn(PhosphorIcons.x(), label: 'Later', color: c.textSubtle, onPressed: widget.onClose),
        ],
      ),
    );
  }
}
