/// CBT marking on the phone, so results show instantly (even offline).
/// Mirrors `public.submit_attempt` on the server exactly; the server score is the one that counts
/// (it re-marks from its own answer key when the attempt syncs).
library;

class QuestionKey {
  const QuestionKey({required this.id, required this.subjectId, required this.answer, this.topic});
  final String id;
  final int subjectId;
  final String answer; // 'A'..'E'
  final String? topic;
}

class SubjectScore {
  const SubjectScore({required this.subjectId, required this.total, required this.correct, required this.answered});
  final int subjectId;
  final int total;
  final int correct;
  final int answered;

  /// Score out of 100 for this subject: round(100 * correct / questions). Unanswered counts as wrong.
  int get score => total == 0 ? 0 : (100 * correct / total).round();

  Map<String, Object> toJson() => {'subject_id': subjectId, 'total': total, 'correct': correct, 'answered': answered, 'score': score};
}

class AttemptScore {
  const AttemptScore(this.subjects);
  final List<SubjectScore> subjects;

  int get questions => subjects.fold(0, (t, s) => t + s.total);
  int get answered => subjects.fold(0, (t, s) => t + s.answered);
  int get correct => subjects.fold(0, (t, s) => t + s.correct);

  /// Sum of subject scores. JAMB (4 subjects) gives a score out of 400.
  int get total => subjects.fold(0, (t, s) => t + s.score);
  int get max => subjects.length * 100;

  /// Accuracy over all questions, 0–100.
  int get accuracy => questions == 0 ? 0 : (100 * correct / questions).round();

  Map<String, Object> toJson() => {
    'questions': questions,
    'answered': answered,
    'correct': correct,
    'total': total,
    'max': max,
    'subjects': [for (final s in subjects) s.toJson()],
  };
}

/// Marks a test. [answers] maps question id to the chosen letter (missing = not answered).
AttemptScore scoreAttempt(List<QuestionKey> questions, Map<String, String> answers) {
  final bySubject = <int, List<QuestionKey>>{};
  for (final q in questions) {
    bySubject.putIfAbsent(q.subjectId, () => []).add(q);
  }
  final ids = bySubject.keys.toList()..sort();
  return AttemptScore([
    for (final sid in ids)
      SubjectScore(
        subjectId: sid,
        total: bySubject[sid]!.length,
        correct: bySubject[sid]!.where((q) => answers[q.id]?.toUpperCase() == q.answer).length,
        answered: bySubject[sid]!.where((q) => answers[q.id] != null).length,
      ),
  ]);
}

/// Topics with the most wrong answers (for "weak topics" on the results screen).
List<({String topic, int wrong, int total})> weakTopics(List<QuestionKey> questions, Map<String, String> answers, {int top = 3}) {
  final stats = <String, ({int wrong, int total})>{};
  for (final q in questions) {
    final t = q.topic;
    if (t == null || t.isEmpty) continue;
    final s = stats[t] ?? (wrong: 0, total: 0);
    final wrong = answers[q.id]?.toUpperCase() != q.answer;
    stats[t] = (wrong: s.wrong + (wrong ? 1 : 0), total: s.total + 1);
  }
  final list = [
    for (final e in stats.entries)
      if (e.value.wrong > 0) (topic: e.key, wrong: e.value.wrong, total: e.value.total),
  ]..sort((a, b) => (b.wrong / b.total).compareTo(a.wrong / a.total));
  return list.take(top).toList();
}
