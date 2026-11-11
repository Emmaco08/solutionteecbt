import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/api.dart';
import '../core/providers.dart';
import 'study_repo.dart';

// Videos and PDFs saved on this phone (A4, D-139). Files live in the app's own private folder (other apps cannot
// read them). The website still decides: a file is only downloaded through the same plan-checked link used to
// stream it, and a saved Premium file is checked again whenever the phone is online. Without internet it opens for
// [offlineGrace] after the last check; when the plan has ended, the file is removed.

/// How long a saved Premium file opens without internet before the app must check the plan again.
const offlineGrace = Duration(days: 30);

class SavedFile {
  const SavedFile({
    required this.id,
    required this.file,
    required this.kind,
    required this.title,
    required this.bytes,
    required this.savedAt,
    required this.checkedAt,
    this.subjectId,
    this.free = false,
  });

  final String id;

  /// '360' or '720' (video) or 'pdf'.
  final String file;

  /// Study kind: video_solution, lesson or doc.
  final String kind;
  final String title;
  final int bytes;
  final DateTime savedAt, checkedAt;
  final int? subjectId;

  /// Free items never need a plan check.
  final bool free;

  bool get isVideo => file != 'pdf';
  String get fileName => '$id-$file.${isVideo ? 'mp4' : 'pdf'}';

  SavedFile copyWith({DateTime? checkedAt}) => SavedFile(
    id: id,
    file: file,
    kind: kind,
    title: title,
    bytes: bytes,
    savedAt: savedAt,
    checkedAt: checkedAt ?? this.checkedAt,
    subjectId: subjectId,
    free: free,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'file': file,
    'kind': kind,
    'title': title,
    'bytes': bytes,
    'saved_at': savedAt.toIso8601String(),
    'checked_at': checkedAt.toIso8601String(),
    'subject_id': subjectId,
    'free': free,
  };

  static SavedFile fromJson(Map<String, dynamic> j) => SavedFile(
    id: '${j['id']}',
    file: '${j['file']}',
    kind: '${j['kind']}',
    title: '${j['title']}',
    bytes: (j['bytes'] as num?)?.toInt() ?? 0,
    savedAt: DateTime.tryParse('${j['saved_at']}') ?? DateTime.now(),
    checkedAt: DateTime.tryParse('${j['checked_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    subjectId: (j['subject_id'] as num?)?.toInt(),
    free: j['free'] == true,
  );
}

/// May a saved file open right now without asking the server? (Free items always; Premium within the grace time.)
bool openableOffline(SavedFile f, DateTime now) => f.free || now.difference(f.checkedAt) < offlineGrace;

/// Downloads in progress: item id → 0..1 (or -1 while the size is not known yet).
final offlineJobsProvider = NotifierProvider<OfflineJobs, Map<String, double>>(OfflineJobs.new);

class OfflineJobs extends Notifier<Map<String, double>> {
  final _cancel = <String>{};
  @override
  Map<String, double> build() => const {};
  void set(String id, double p) => state = {...state, id: p};
  void done(String id) {
    _cancel.remove(id);
    state = {...state}..remove(id);
  }

  void cancel(String id) => _cancel.add(id);
  bool cancelled(String id) => _cancel.contains(id);
}

final offlineFilesProvider = NotifierProvider<OfflineFiles, Map<String, SavedFile>>(OfflineFiles.new);

class _Cancelled implements Exception {}

class OfflineFiles extends Notifier<Map<String, SavedFile>> {
  static const _kvKey = 'offline_files';
  Directory? _folder;

  /// Finishes when the saved list has been read from the phone (open() waits for it after a cold start).
  late Future<void> ready;

  @override
  Map<String, SavedFile> build() {
    ready = _load();
    return const {};
  }

  Future<Directory> _dir() async => _folder ??= await Directory('${(await getApplicationSupportDirectory()).path}/offline').create(recursive: true);
  Future<File> _file(SavedFile s) async => File('${(await _dir()).path}/${s.fileName}');

  Future<void> _load() async {
    try {
      final raw = await ref.read(dbProvider).kvGet(_kvKey);
      if (raw == null) return;
      final list = [for (final j in (jsonDecode(raw) as List)) SavedFile.fromJson(Map<String, dynamic>.from(j as Map))];
      final ok = <String, SavedFile>{};
      for (final s in list) {
        if (await (await _file(s)).exists()) ok[s.id] = s;
      }
      state = {...ok, ...state};
    } catch (_) {}
  }

  Future<void> _persist() => ref.read(dbProvider).kvSet(_kvKey, jsonEncode([for (final s in state.values) s.toJson()]));

  /// Saves one file of a study item. Throws [ApiError] with a message for the student.
  Future<void> save(Map<String, dynamic> item, String file) async {
    final id = '${item['id']}';
    final jobs = ref.read(offlineJobsProvider.notifier);
    if (ref.read(offlineJobsProvider).containsKey(id)) return;
    jobs.set(id, -1);
    final s = SavedFile(
      id: id,
      file: file,
      kind: '${item['kind'] ?? (file == 'pdf' ? 'doc' : 'video_solution')}',
      title: '${item['title'] ?? 'Saved file'}',
      bytes: 0,
      savedAt: DateTime.now(),
      checkedAt: DateTime.now(),
      subjectId: (item['subject_id'] as num?)?.toInt(),
      free: item['is_free'] == true,
    );
    final target = await _file(s);
    final part = File('${target.path}.part');
    final client = http.Client();
    try {
      final url = await ref.read(studyRepoProvider).fileUrl(id, file);
      final res = await client.send(http.Request('GET', Uri.parse(url))).timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) throw ApiError('Could not download it. Try again.');
      final total = res.contentLength ?? 0;
      final sink = part.openWrite();
      var got = 0, shown = 0.0;
      try {
        await for (final chunk in res.stream.timeout(const Duration(seconds: 60))) {
          if (jobs.cancelled(id)) throw _Cancelled();
          sink.add(chunk);
          got += chunk.length;
          if (total > 0 && got / total - shown >= .01) jobs.set(id, shown = got / total);
        }
      } finally {
        await sink.close();
      }
      if (total > 0 && got < total) throw ApiError('The download stopped. Check your internet and try again.');
      await part.rename(target.path);
      state = {
        ...state,
        id: SavedFile.fromJson({...s.toJson(), 'bytes': got}),
      };
      await _persist();
    } on _Cancelled {
      if (await part.exists()) await part.delete();
    } on FileSystemException {
      if (await part.exists()) await part.delete();
      throw ApiError('Your phone is out of space. Remove some files and try again.');
    } on ApiError {
      if (await part.exists()) await part.delete();
      rethrow;
    } catch (_) {
      if (await part.exists()) await part.delete();
      throw ApiError('The download stopped. Check your internet and try again.');
    } finally {
      client.close();
      jobs.done(id);
    }
  }

  /// Log out: every saved video and PDF leaves the phone (the next person must not open this account's files).
  Future<void> removeAll() async {
    for (final id in ref.read(offlineJobsProvider).keys) {
      ref.read(offlineJobsProvider.notifier).cancel(id);
    }
    try {
      final d = await _dir();
      if (await d.exists()) await d.delete(recursive: true);
      _folder = null;
    } catch (_) {}
    state = const {};
    await _persist();
  }

  Future<void> remove(String id) async {
    final s = state[id];
    if (s == null) return;
    try {
      final f = await _file(s);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    state = {...state}..remove(id);
    await _persist();
  }

  /// The saved file of [id] if it may open now, or null when nothing is saved. A Premium file is checked with the
  /// website when online (removed if the plan no longer opens it, [ApiError] 402); offline it opens within the grace
  /// time, otherwise [ApiError] asks to connect once.
  Future<File?> open(String id) async {
    await ready;
    final s = state[id];
    if (s == null) return null;
    final f = await _file(s);
    if (!await f.exists()) {
      await remove(id);
      return null;
    }
    if (s.free) return f;
    try {
      await ref.read(studyRepoProvider).fileUrl(id, s.file).timeout(const Duration(seconds: 8));
      state = {...state, id: s.copyWith(checkedAt: DateTime.now())};
      unawaited(_persist());
      return f;
    } on ApiError catch (e) {
      if (e.status == 402 || e.status == 404) {
        await remove(id);
        rethrow;
      }
    } catch (_) {}
    if (openableOffline(s, DateTime.now())) return f;
    throw ApiError('Connect to the internet once so we can check your plan, then your saved files open again.');
  }
}

/// "54 MB", "820 KB".
String fileSize(num bytes) =>
    bytes >= 1024 * 1024 ? '${(bytes / 1024 / 1024).toStringAsFixed(bytes >= 10 * 1024 * 1024 ? 0 : 1)} MB' : '${(bytes / 1024).ceil()} KB';
