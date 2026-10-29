/// Exam timer that survives the app being killed or the phone restarting.
///
/// The time left is never kept only in memory: we save the total allowed time and the time already used,
/// plus when the current run started. On resume we add the time that passed while the app was open.
/// Time the app is closed does NOT count (like pausing a paper exam), so a phone crash doesn't cost a student
/// their test. Each answer save also saves the clock, so at most a few seconds can be lost.
library;

class ExamClock {
  ExamClock({required this.limit, Duration used = Duration.zero, DateTime Function()? now})
    // ignore: prefer_initializing_formals
    : _used = used,
      _now = now ?? DateTime.now;

  /// Total time allowed (Duration.zero = untimed).
  final Duration limit;
  final DateTime Function() _now;
  Duration _used;
  DateTime? _runningSince;

  bool get timed => limit > Duration.zero;
  bool get running => _runningSince != null;

  /// Time used so far, including the current run.
  Duration get used => _used + (running ? _now().difference(_runningSince!) : Duration.zero);

  /// Time left (never below zero). Untimed tests always report the full limit (zero).
  Duration get left {
    if (!timed) return Duration.zero;
    final l = limit - used;
    return l.isNegative ? Duration.zero : l;
  }

  bool get expired => timed && left == Duration.zero;

  /// Warning level for the header colour: 0 normal, 1 at 10 minutes left, 2 at 5 minutes left.
  int get warning => !timed
      ? 0
      : left <= const Duration(minutes: 5)
      ? 2
      : left <= const Duration(minutes: 10)
      ? 1
      : 0;

  void start() => _runningSince ??= _now();

  /// Stops counting (app paused/closed) and returns the total used, to save.
  Duration pause() {
    if (running) {
      _used += _now().difference(_runningSince!);
      _runningSince = null;
    }
    return _used;
  }

  /// Snapshot to store with every answer.
  Duration snapshot() => used;

  static String format(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
