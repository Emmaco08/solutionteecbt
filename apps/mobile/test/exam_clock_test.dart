import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/cbt/exam_clock.dart';

void main() {
  late DateTime now;
  DateTime clock() => now;
  setUp(() => now = DateTime(2026, 10, 27, 9));

  test('counts down while running', () {
    final c = ExamClock(limit: const Duration(minutes: 120), now: clock)..start();
    now = now.add(const Duration(minutes: 30));
    expect(c.left, const Duration(minutes: 90));
    expect(c.warning, 0);
  });

  test('resume after the app is killed: time while closed does not count', () {
    final c = ExamClock(limit: const Duration(minutes: 120), now: clock)..start();
    now = now.add(const Duration(minutes: 40));
    final saved = c.snapshot(); // saved with the last answer
    // App killed. Phone restarts. 3 hours later the student reopens the test.
    now = now.add(const Duration(hours: 3));
    final resumed = ExamClock(limit: const Duration(minutes: 120), used: saved, now: clock)..start();
    expect(resumed.left, const Duration(minutes: 80));
    now = now.add(const Duration(minutes: 5));
    expect(resumed.left, const Duration(minutes: 75));
  });

  test('pause and start again keep the used time', () {
    final c = ExamClock(limit: const Duration(minutes: 10), now: clock)..start();
    now = now.add(const Duration(minutes: 4));
    expect(c.pause(), const Duration(minutes: 4));
    now = now.add(const Duration(minutes: 30)); // paused: not counted
    c.start();
    now = now.add(const Duration(minutes: 1));
    expect(c.used, const Duration(minutes: 5));
  });

  test('warning colours at 10 and 5 minutes, expiry at zero (auto-submit)', () {
    final c = ExamClock(limit: const Duration(minutes: 20), now: clock)..start();
    now = now.add(const Duration(minutes: 10));
    expect(c.warning, 1);
    now = now.add(const Duration(minutes: 5));
    expect(c.warning, 2);
    expect(c.expired, isFalse);
    now = now.add(const Duration(minutes: 6));
    expect(c.left, Duration.zero);
    expect(c.expired, isTrue);
  });

  test('untimed tests never expire', () {
    final c = ExamClock(limit: Duration.zero, now: clock)..start();
    now = now.add(const Duration(hours: 5));
    expect(c.timed, isFalse);
    expect(c.expired, isFalse);
    expect(c.used, const Duration(hours: 5));
  });

  test('format', () {
    expect(ExamClock.format(const Duration(minutes: 119, seconds: 5)), '1:59:05');
    expect(ExamClock.format(const Duration(minutes: 4, seconds: 9)), '04:09');
  });
}
