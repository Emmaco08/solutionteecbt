import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/test/custom_exam.dart';

/// Custom exam (owner, 2026-11-07): the admin's limits.
void main() {
  test('at most 40 questions per subject, 60 for English; admin can change them and keep it for Premium', () {
    final d = CustomExamRules(null);
    expect(d.on, isTrue);
    expect(d.premiumOnly, isFalse);
    expect(d.maxFor({'code': 'mth'}), 40);
    expect(d.maxFor({'code': 'eng'}), 60);
    expect(d.maxMinutes, 180);
    final a = CustomExamRules({'on': true, 'who': 'premium', 'max_questions': 30, 'max_english': 50, 'max_minutes': 90});
    expect(a.premiumOnly, isTrue);
    expect(a.maxFor({'code': 'phy'}), 30);
    expect(a.maxFor({'code': 'eng'}), 50);
    expect(CustomExamRules({'on': false}).on, isFalse);
  });
}
