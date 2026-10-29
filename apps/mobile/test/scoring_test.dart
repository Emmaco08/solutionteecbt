import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/cbt/scoring.dart';

List<QuestionKey> jambFull() => [
  for (var i = 0; i < 60; i++) QuestionKey(id: 'e$i', subjectId: 1, answer: 'A', topic: i < 10 ? 'Concord' : 'Comprehension'),
  for (final s in [2, 3, 4])
    for (var i = 0; i < 40; i++) QuestionKey(id: 's$s-$i', subjectId: s, answer: 'B', topic: 'T$s'),
];

void main() {
  test('perfect JAMB paper scores 400 (60 English + 3 x 40)', () {
    final qs = jambFull();
    final all = {for (final q in qs) q.id: q.answer};
    final s = scoreAttempt(qs, all);
    expect(s.questions, 180);
    expect(s.total, 400);
    expect(s.max, 400);
    expect(s.accuracy, 100);
  });

  test('each subject is scaled to 100 on its own (English 60 Qs, others 40)', () {
    final qs = jambFull();
    final answers = <String, String>{
      for (var i = 0; i < 30; i++) 'e$i': 'A', // 30/60 English -> 50
      for (var i = 0; i < 20; i++) 's2-$i': 'B', // 20/40 -> 50
      for (var i = 0; i < 40; i++) 's3-$i': 'B', // 40/40 -> 100
      // subject 4: nothing answered -> 0
    };
    final s = scoreAttempt(qs, answers);
    expect([for (final x in s.subjects) x.score], [50, 50, 100, 0]);
    expect(s.total, 200);
    expect(s.answered, 90);
  });

  test('unanswered counts as wrong, answers are case-insensitive, rounding matches the server', () {
    final qs = [for (var i = 0; i < 3; i++) QuestionKey(id: 'q$i', subjectId: 7, answer: 'C')];
    final s = scoreAttempt(qs, {'q0': 'c', 'q1': 'D'});
    expect(s.subjects.single.correct, 1);
    expect(s.subjects.single.score, 33); // round(100 * 1 / 3)
    final two = scoreAttempt(qs, {'q0': 'C', 'q1': 'C'});
    expect(two.subjects.single.score, 67); // round(66.67)
  });

  test('same numbers as the server test (English 1/2, Maths 2/3 -> 117)', () {
    final qs = [
      const QuestionKey(id: 'e1', subjectId: 1, answer: 'A'),
      const QuestionKey(id: 'e2', subjectId: 1, answer: 'B'),
      const QuestionKey(id: 'm1', subjectId: 2, answer: 'C'),
      const QuestionKey(id: 'm2', subjectId: 2, answer: 'D'),
      const QuestionKey(id: 'm3', subjectId: 2, answer: 'A'),
    ];
    final s = scoreAttempt(qs, {'e1': 'A', 'e2': 'C', 'm1': 'c', 'm2': 'D'});
    expect(s.total, 117);
    expect(s.correct, 3);
    expect(s.max, 200);
  });

  test('weak topics: most-missed first, only topics with mistakes', () {
    final qs = jambFull();
    final answers = {for (final q in qs) q.id: q.answer}
      ..['e0'] = 'B'
      ..['e1'] =
          'B' // Concord: 2 wrong of 10
      ..['s2-0'] = 'A'; // T2: 1 wrong of 40
    final weak = weakTopics(qs, answers);
    expect(weak.first.topic, 'Concord');
    expect(weak.map((w) => w.topic), isNot(contains('T3')));
  });
}
