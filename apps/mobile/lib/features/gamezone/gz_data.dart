import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../community/community_data.dart' show Json, asJson, asList;
import '../tutor/tutor_chat.dart' show broadcastPayload;
import '../tutor/tutor_live.dart';

// Game Zone v2 data (D-157). The server runs every match (gz_* functions); the app shows it, timed by the server clock.
// Live updates come on private Realtime topics (gz:<match> for players, gzu:<user> for "match found" and rematch
// invites), with timed refreshes as a backup so a dropped connection never freezes a game.

SupabaseClient get _db => Supabase.instance.client;

Future<Object?> gzRpc(String fn, [Map<String, dynamic>? params]) => _db.rpc(fn, params: params).timeout(const Duration(seconds: 15));

String? gzUid() {
  try {
    return _db.auth.currentUser?.id;
  } catch (_) {
    return null;
  }
}

/// Friendly words for server errors.
String gzErrorText(Object? e) {
  final m = e is PostgrestException ? e.message : '$e';
  if (m.contains('too_many')) return 'You have played a lot of games today. Come back tomorrow for more.';
  if (m.contains('no_questions')) return 'There are not enough questions for this subject yet. Try another subject.';
  if (m.contains('no_content')) return 'This game is getting ready. Please try another game for now.';
  if (m.contains('off')) return 'This game is paused for now. Please try another one.';
  if (m.contains('subject')) return 'Pick one of your JAMB subjects to play.';
  if (m.contains('not allowed')) return 'You cannot play this game right now.';
  if (e is TimeoutException || m.contains('SocketException') || m.contains('Failed host lookup') || m.contains('ClientException')) {
    return 'Could not reach SolutionTee. Check your internet and try again.';
  }
  return 'Something went wrong. Please try again.';
}

// ---------------------------------------------------------------- server clock

/// The difference between the server's clock and the phone's (kept from the quickest round trip).
abstract final class GzClock {
  static int _offset = 0;
  static int _bestRtt = 1 << 30;
  static DateTime _seen = DateTime.fromMillisecondsSinceEpoch(0);

  static int now() => DateTime.now().millisecondsSinceEpoch + _offset;

  static void sample(int serverNow, int sentAt, int gotAt) {
    final rtt = gotAt - sentAt;
    // A fresher sample wins after 30 s, so a phone clock change is picked up.
    final stale = DateTime.now().difference(_seen).inSeconds > 30;
    if (rtt <= _bestRtt || stale) {
      _bestRtt = rtt;
      _seen = DateTime.now();
      _offset = serverNow - (sentAt + rtt ~/ 2);
    }
  }

  @visibleForTesting
  static void set(int offset) => _offset = offset;
}

int? gzMs(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

// ---------------------------------------------------------------- hub data

final gzHomeProvider = FutureProvider.autoDispose<Json>((ref) async => asJson(await gzRpc('gz_home')));

final gzLeadersProvider = FutureProvider.autoDispose.family<Json, String?>((ref, game) async => asJson(await gzRpc('gz_leaders', {'p_game': game})));

// ---------------------------------------------------------------- the player's own live feed (gzu:<uid>)

/// One channel for "match found" and rematch invites, shared by every Game Zone screen.
class GzUserFeed {
  GzUserFeed._();
  static final instance = GzUserFeed._();

  final _events = StreamController<(String, Json)>.broadcast();
  Stream<(String, Json)> get events => _events.stream;

  LiveChannel? _ch;
  ResumeWatcher? _resume;
  int _users = 0;

  void hold() {
    _users++;
    if (_ch != null) return;
    final uid = gzUid();
    if (uid == null) return;
    _ch = LiveChannel('gzu:$uid', private: true, (ch) {
      for (final e in const ['matched', 'rematch']) {
        ch.onBroadcast(event: e, callback: (p) => _events.add((e, broadcastPayload(p))));
      }
    })..open();
    _resume = ResumeWatcher(() => _ch?.restart());
  }

  void release() {
    _users = math.max(0, _users - 1);
    if (_users > 0) return;
    _ch?.close();
    _ch = null;
    _resume?.dispose();
    _resume = null;
  }
}

// ---------------------------------------------------------------- matchmaking

enum FindStage { idle, searching, found, failed }

/// Quick Match / Ranked: waits in the queue (the server pairs students of a similar level), and a SolutionTee Bot
/// joins after the wait. Practice and friend games come straight back.
class GzFinder extends ChangeNotifier {
  GzFinder({required this.game, required this.mode, this.subject, this.level = 'medium'});
  final String game;
  final String mode;
  final int? subject;
  final String level;

  FindStage stage = FindStage.idle;
  String? matchId;
  bool bot = false;
  int waited = 0;
  int wait = 15;
  int searching = 0;
  String? error;

  Timer? _poll;
  StreamSubscription<(String, Json)>? _sub;
  bool _disposed = false;
  bool _busy = false;
  final _started = Stopwatch();

  Future<void> start() async {
    stage = FindStage.searching;
    error = null;
    _started
      ..reset()
      ..start();
    _notify();
    GzUserFeed.instance.hold();
    _sub = GzUserFeed.instance.events.listen((e) {
      if (e.$1 == 'matched' && e.$2['match'] != null) _found('${e.$2['match']}');
    });
    try {
      final r = asJson(await gzRpc('gz_find', {'p_game': game, 'p_mode': mode, 'p_subject': subject, 'p_level': level}));
      _take(r);
      if (stage == FindStage.searching) {
        _poll = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
      }
    } catch (e) {
      error = gzErrorText(e);
      stage = FindStage.failed;
      _notify();
    }
  }

  void _take(Json r) {
    final s = '${r['status']}';
    if ((s == 'matched' || s == 'lobby') && r['match'] != null) {
      bot = r['bot'] == true;
      _found('${r['match']}');
    } else if (s == 'waiting') {
      waited = gzMs(r['waited']) ?? _started.elapsed.inSeconds;
      wait = gzMs(r['wait']) ?? wait;
      searching = gzMs(r['searching']) ?? searching;
      _notify();
    } else if (s == 'none' && stage == FindStage.searching) {
      // The queue entry is gone (for example after a long pause): ask again.
      start();
    }
  }

  Future<void> _tick() async {
    if (_busy || stage != FindStage.searching) return;
    _busy = true;
    try {
      _take(asJson(await gzRpc('gz_poll')));
    } catch (_) {
      // Keep waiting; the next tick tries again.
    } finally {
      _busy = false;
    }
  }

  void _found(String id) {
    if (stage == FindStage.found) return;
    matchId = id;
    stage = FindStage.found;
    _stop();
    _notify();
  }

  Future<void> cancel() async {
    _stop();
    stage = FindStage.idle;
    try {
      await gzRpc('gz_cancel');
    } catch (_) {}
  }

  void _stop() {
    _poll?.cancel();
    _poll = null;
    _sub?.cancel();
    _sub = null;
    GzUserFeed.instance.release();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_poll != null || _sub != null) _stop();
    super.dispose();
  }
}

// ---------------------------------------------------------------- a live match

enum GzPhase { loading, lobby, intro, play, done, cancelled, error }

/// One match: its state from gz_state, live events, and the student's answers.
class GzMatch extends ChangeNotifier {
  GzMatch(this.id);
  final String id;

  Json? s;
  String? error;

  /// The option the student just tapped (shown at once, before the server answers).
  ({int idx, String choice})? picked;

  /// The server's reply to the latest answer: correct, key, points, combo, next…
  Json? result;

  /// Race: the item on screen and the student's own position (updated from each answer, no waiting for a refresh).
  Json? raceItem;
  int racePos = 0;
  int raceCorrect = 0;
  int raceScore = 0;
  int raceCombo = 0;
  int penaltyUntil = 0;
  bool sending = false;

  /// Bumps on every right answer (drives the bursts and pops).
  int hits = 0;
  int misses = 0;

  LiveChannel? _ch;
  ResumeWatcher? _resume;
  Timer? _next;
  Timer? _backup;
  Timer? _debounce;
  Timer? _show;
  bool _loading = false;
  bool _again = false;
  bool _disposed = false;

  int Function() get now => GzClock.now;

  String get game => '${s?['game'] ?? ''}';
  String get status => '${s?['status'] ?? ''}';
  Json get me => asJson(s?['me']);
  List<Json> get players => asList(s?['players']);
  Json? get round => s?['round'] == null ? null : asJson(s?['round']);
  Json? get last => s?['last'] == null ? null : asJson(s?['last']);
  int get startsAt => gzMs(s?['starts_at']) ?? 0;
  int get endsAt => gzMs(s?['ends_at']) ?? 0;
  int get seconds => gzMs(s?['seconds']) ?? 15;
  int get rounds => gzMs(s?['rounds']) ?? 10;
  int get target => gzMs(s?['target']) ?? 10;

  GzPhase get phase {
    if (s == null) return error != null ? GzPhase.error : GzPhase.loading;
    return switch (status) {
      'lobby' => GzPhase.lobby,
      'cancelled' => GzPhase.cancelled,
      'done' => GzPhase.done,
      _ => now() < startsAt ? GzPhase.intro : GzPhase.play,
    };
  }

  void open() {
    _ch = LiveChannel('gz:$id', private: true, (ch) {
      for (final e in const ['start', 'ans', 'round', 'step', 'done', 'joined', 'left', 'cancelled']) {
        ch.onBroadcast(event: e, callback: (_) => _soon(e == 'step' ? 250 : 60));
      }
    }, onUp: (_) => _soon(0))..open();
    _resume = ResumeWatcher(() {
      _ch?.restart();
      _soon(0);
    });
    load();
  }

  void _soon(int ms) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: ms), load);
  }

  Future<void> load() async {
    if (_disposed) return;
    if (_loading) {
      _again = true;
      return;
    }
    _loading = true;
    try {
      final sent = DateTime.now().millisecondsSinceEpoch;
      final r = asJson(await gzRpc('gz_state', {'p_match': id}));
      GzClock.sample(gzMs(r['now']) ?? sent, sent, DateTime.now().millisecondsSinceEpoch);
      _apply(r);
      error = null;
    } catch (e) {
      error = gzErrorText(e);
    } finally {
      _loading = false;
    }
    if (_disposed) return;
    _plan();
    notifyListeners();
    if (_again) {
      _again = false;
      load();
    }
  }

  void _apply(Json r) {
    final oldRound = gzMs(round?['idx']);
    s = r;
    final nr = round;
    if (nr != null && gzMs(nr['idx']) != oldRound) {
      picked = null;
      result = null;
    }
    if (nr?['mine'] != null && result == null) result = asJson(nr!['mine']);
    final m = me;
    final isRace = game == 'rush' || game == 'blitz' || game == 'reading';
    if (isRace && m.isNotEmpty) {
      final pos = gzMs(m['pos']) ?? 0;
      if (pos >= racePos || raceItem == null) {
        racePos = pos;
        raceCorrect = gzMs(m['correct']) ?? raceCorrect;
        raceScore = gzMs(m['score']) ?? raceScore;
        raceCombo = gzMs(m['combo']) ?? raceCombo;
        if (r['item'] != null) raceItem = asJson(r['item']);
      }
      penaltyUntil = math.max(penaltyUntil, gzMs(m['penalty_until']) ?? 0);
    }
  }

  /// Plans the next refresh at the next moment that matters, plus a slow backup.
  void _plan() {
    _next?.cancel();
    _backup?.cancel();
    if (s == null || status == 'done' || status == 'cancelled') return;
    final t = now();
    int? at;
    if (status == 'lobby') {
      final until = gzMs(s?['lobby_until']);
      if (until != null && until - t < 20000) at = until + 300;
    } else if (t < startsAt) {
      at = startsAt + 60;
    } else if (round != null) {
      final r = round!;
      final open = gzMs(r['open_at']) ?? 0;
      if (r['item'] == null && t < open) {
        at = math.max(t + 40, open - 1300); // the server sends the question 1.5 s early
      } else if (t < open) {
        _show?.cancel();
        _show = Timer(Duration(milliseconds: open - t), () {
          if (!_disposed) notifyListeners();
        });
        at = (gzMs(r['close_at']) ?? open) + 450;
      } else {
        at = (gzMs(r['close_at']) ?? t) + 450;
      }
    } else if (game == 'reading' && t < (gzMs(s?['answer_at']) ?? 0)) {
      // Comprehension Clash: fetch the first question just before the passage closes.
      at = (gzMs(s?['answer_at']) ?? t) - 1200;
      if (at <= t) at = t + 300;
    } else if (game == 'rush' || game == 'blitz' || game == 'reading') {
      at = t + 1500;
      if (endsAt > 0 && endsAt < at) at = endsAt + 400;
    } else if (game == 'memory') {
      at = t + 3000;
    }
    if (at != null) _next = Timer(Duration(milliseconds: math.max(40, at - t)), load);
    _backup = Timer(Duration(seconds: status == 'lobby' ? 3 : 5), load);
  }

  // ---------------------------------------------------------------- actions

  /// Answer the round now on screen (Duel, Word War, Survival, Relay).
  Future<void> answerRound(int idx, String choice) async {
    if (picked != null || sending) return;
    picked = (idx: idx, choice: choice);
    sending = true;
    notifyListeners();
    try {
      final r = asJson(await gzRpc('gz_answer', {'p_match': id, 'p_idx': idx, 'p_choice': choice}));
      if (r['ok'] == true) {
        result = r;
        r['correct'] == true ? hits++ : misses++;
      } else if (r['error'] == 'closed') {
        result = {'late': true};
      }
    } catch (e) {
      error = gzErrorText(e);
      picked = null;
    } finally {
      sending = false;
    }
    if (_disposed) return;
    notifyListeners();
    _soon(80);
  }

  /// One step in a race (Speed Rush, Maths Blitz): the next item comes straight back.
  Future<Json?> answerRace(String choice) async {
    if (sending || now() < penaltyUntil) return null;
    final idx = racePos;
    sending = true;
    picked = (idx: idx, choice: choice);
    notifyListeners();
    Json? r;
    try {
      r = asJson(await gzRpc('gz_answer', {'p_match': id, 'p_idx': idx, 'p_choice': choice}));
      if (r['ok'] == true) {
        result = r;
        r['correct'] == true ? hits++ : misses++;
        racePos = gzMs(r['pos']) ?? racePos + 1;
        raceScore = gzMs(r['score']) ?? raceScore;
        raceCombo = gzMs(r['combo']) ?? 0;
        if (r['correct'] == true) raceCorrect++;
        final pen = gzMs(r['penalty_ms']) ?? 0;
        if (pen > 0) penaltyUntil = now() + pen;
        if (r['next'] != null) raceItem = asJson(r['next']);
        if (r['finished'] == true) _soon(200);
      } else if (r['error'] == 'wait') {
        // Still spun out: nothing to do.
      } else {
        _soon(0);
      }
    } catch (e) {
      error = gzErrorText(e);
    } finally {
      sending = false;
      picked = null;
    }
    if (!_disposed) notifyListeners();
    return r;
  }

  /// Memory Flash: a level cleared.
  Future<Json?> memoryLevel(int level, int moves, int ms) async {
    try {
      final r = asJson(await gzRpc('gz_memory', {'p_match': id, 'p_level': level, 'p_moves': moves, 'p_ms': ms}));
      if (r['finished'] == true) _soon(150);
      return r;
    } catch (e) {
      error = gzErrorText(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> startNow() async {
    try {
      final r = asJson(await gzRpc('gz_start_now', {'p_match': id}));
      _soon(0);
      return r['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> leave() async {
    try {
      await gzRpc('gz_leave', {'p_match': id});
    } catch (_) {}
  }

  static Future<Json> rematch(String id) async => asJson(await gzRpc('gz_rematch', {'p_match': id}));

  @override
  void dispose() {
    _disposed = true;
    _next?.cancel();
    _backup?.cancel();
    _debounce?.cancel();
    _show?.cancel();
    _ch?.close();
    _resume?.dispose();
    super.dispose();
  }
}

/// Join a friend's game with their 6-letter code. Returns the match id, or an error message.
Future<(String?, String?)> gzJoin(String code) async {
  try {
    final r = asJson(await gzRpc('gz_join', {'p_code': code.trim().toUpperCase()}));
    return switch ('${r['status']}') {
      'matched' || 'lobby' => ('${r['match']}', null),
      'full' => (null, 'That game is full. Ask your friend for a new code.'),
      'subject' => (null, 'That game uses a subject that is not in your JAMB subjects.'),
      _ => (null, 'We could not find a game with that code. Check the letters and try again.'),
    };
  } catch (e) {
    return (null, gzErrorText(e));
  }
}

Future<Json?> gzSaveAvatar(Map<String, dynamic> look) async {
  try {
    return asJson(await gzRpc('gz_avatar_save', {'p': look}));
  } catch (_) {
    return null;
  }
}
