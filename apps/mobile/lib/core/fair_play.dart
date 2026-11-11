import 'dart:convert';

import '../data/db.dart';

/// Fair play on tests (B10, D-144): how often the student left the app, for how long, and screenshot attempts,
/// kept on the phone per test and sent with it. The server turns them (with the time on each question) into a risk
/// score; only leaderboard runs can be held for review. Nothing here ever stops a test.
class FairPlay {
  FairPlay(this._db, this.attemptId);
  final AppDb _db;
  final String attemptId;

  static String key(String attemptId) => 'fair:$attemptId';

  DateTime? _leftAt;

  Future<Map<String, dynamic>> _read() async {
    final raw = await _db.kvGet(key(attemptId));
    return raw == null ? {'away': 0, 'away_ms': 0, 'shots': 0} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _add(String k, int n) async {
    final m = await _read();
    m[k] = ((m[k] as num?)?.toInt() ?? 0) + n;
    await _db.kvSet(key(attemptId), jsonEncode(m));
  }

  void left() => _leftAt ??= DateTime.now();

  Future<void> back() async {
    final at = _leftAt;
    if (at == null) return;
    _leftAt = null;
    final ms = DateTime.now().difference(at).inMilliseconds;
    // A glance at a notification shade is not leaving the test.
    if (ms < 1500) return;
    await _add('away', 1);
    await _add('away_ms', ms);
  }

  Future<void> screenshot() => _add('shots', 1);

  /// What to send with the test (null when nothing was recorded).
  static Future<Map<String, dynamic>?> report(AppDb db, String attemptId) async {
    final raw = await db.kvGet(key(attemptId));
    return raw == null ? {'away': 0, 'away_ms': 0, 'shots': 0} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> clear(AppDb db, String attemptId) => db.kvDelete(key(attemptId));
}
