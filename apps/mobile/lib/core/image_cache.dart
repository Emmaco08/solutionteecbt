import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Question pictures saved on the phone (big update 2, A12). The CBT downloads every picture of a test before the
/// clock starts, so nothing loads during the exam. Files older than 30 days are removed.
class QuestionImageCache {
  QuestionImageCache._();
  static Directory? _dir;
  static final _mem = <String, File>{};

  static Future<Directory> _folder() async => _dir ??= await Directory('${(await getApplicationSupportDirectory()).path}/qimg').create(recursive: true);
  static String _name(String key) => sha1.convert(utf8.encode(key)).toString();

  /// The saved picture for [key], if there is one.
  static Future<File?> file(String key) async {
    final hit = _mem[key];
    if (hit != null) return hit;
    try {
      final f = File('${(await _folder()).path}/${_name(key)}');
      if (await f.exists() && await f.length() > 0) return _mem[key] = f;
    } catch (_) {}
    return null;
  }

  /// Downloads one picture: [sign] turns the key into a short-lived link (the server checks access first).
  static Future<bool> fetch(String key, Future<String> Function(String key) sign, {int tries = 3}) async {
    if (await file(key) != null) return true;
    for (var n = 0; n < tries; n++) {
      try {
        final url = await sign(key);
        final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
          final dir = await _folder();
          final tmp = File('${dir.path}/${_name(key)}.part');
          await tmp.writeAsBytes(r.bodyBytes, flush: true);
          _mem[key] = await tmp.rename('${dir.path}/${_name(key)}');
          return true;
        }
      } catch (_) {}
      await Future<void>.delayed(Duration(milliseconds: 600 * (n + 1)));
    }
    return false;
  }

  /// Downloads all [keys], three at a time. [onProgress] gets (done, total). Returns the keys that failed.
  static Future<List<String>> fetchAll(List<String> keys, Future<String> Function(String key) sign, {void Function(int done, int total)? onProgress}) async {
    final todo = [
      ...{...keys},
    ];
    final failed = <String>[];
    var done = 0;
    var next = 0;
    Future<void> worker() async {
      while (next < todo.length) {
        final k = todo[next++];
        if (!await fetch(k, sign)) failed.add(k);
        done++;
        onProgress?.call(done, todo.length);
      }
    }

    await Future.wait([for (var i = 0; i < 3; i++) worker()]);
    unawaited(_prune());
    return failed;
  }

  static Future<void> _prune() async {
    try {
      final old = DateTime.now().subtract(const Duration(days: 30));
      await for (final e in (await _folder()).list()) {
        if (e is File && (await e.lastModified()).isBefore(old)) await e.delete();
      }
    } catch (_) {}
  }
}
