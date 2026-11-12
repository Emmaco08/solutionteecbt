import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/tutor/tutor.dart';
import 'package:solutiontee_cbt/features/tutor/tutor_chat.dart';
import 'package:solutiontee_cbt/features/tutor/tutor_quiz.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

// Tutor quizzes and instant messages (D-154).
void main() {
  test('due labels, score words, clock, pending', () {
    final now = DateTime(2026, 11, 12, 10);
    expect(quizDue(DateTime(2026, 11, 12, 18).toIso8601String(), now), 'Due today');
    expect(quizDue(DateTime(2026, 11, 13, 9).toIso8601String(), now), 'Due tomorrow');
    expect(quizDue(DateTime(2026, 11, 20, 9).toIso8601String(), now), 'Due 20 Nov');
    expect(quizDue(DateTime(2026, 11, 11, 9).toIso8601String(), now), 'Overdue');
    expect(quizDue(null, now), '');
    expect(quizCheer(10, 10), startsWith('Excellent'));
    expect(quizCheer(3, 10), startsWith('Keep going'));
    expect(fmtClock(605), '10:05');
    expect(quizPending({'state': 'new'}), isTrue);
    expect(quizPending({'state': 'done'}), isFalse);
  });

  test('broadcasts are unwrapped (supabase_flutter hands over {type, event, payload})', () {
    expect(
      broadcastPayload({
        'type': 'broadcast',
        'event': 'msg',
        'payload': {'id': 3, 'role': 'tutor'},
      }),
      {'id': 3, 'role': 'tutor'},
    );
    expect(broadcastPayload({'role': 'student'}), {'role': 'student'});
    final m = ChatMsg.from(
      broadcastPayload({
        'payload': {'id': 9, 'role': 'tutor', 'kind': 'text', 'body': '😀', 'at': '2026-11-12T09:00:00Z', 'reactions': {}, 'deleted': false},
      }),
    );
    expect(m.body, '😀');
    expect(emojiOnly(m.body), isTrue);
  });

  Widget app(List<Map<String, dynamic>> quizzes, Widget home) => ProviderScope(
    key: UniqueKey(),
    overrides: [
      tutorProvider.overrideWith(
        (_) async => {
          'request': {'id': 'r1', 'status': 'matched'},
        },
      ),
      tutorQuizzesProvider.overrideWith((_) async => quizzes),
    ],
    child: MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: home),
    ),
  );

  testWidgets('Home shows quizzes to do from the tutor, and nothing without them', (t) async {
    await t.pumpWidget(
      app([
        {'id': 'q1', 'title': 'Waves practice', 'tutor': 'Adebayo Okafor', 'count': 10, 'minutes': 15, 'state': 'new'},
        {'id': 'q2', 'title': 'Old one', 'tutor': 'Adebayo Okafor', 'count': 5, 'state': 'done', 'score': 4, 'total': 5},
      ], const TutorQuizHomeCard()),
    );
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('From your tutor'), findsOneWidget);
    expect(find.text('Waves practice'), findsOneWidget);
    expect(find.text('NEW QUIZ'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Old one'), findsNothing);

    await t.pumpWidget(app(const [], const TutorQuizHomeCard()));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('From your tutor'), findsNothing);
  });

  testWidgets('a quiz in the chat shows as a quiz card', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: ChatBubble(
            m: ChatMsg(
              id: 1,
              role: 'tutor',
              kind: 'ref',
              body: 'Waves practice',
              at: DateTime(2026, 11, 12, 9),
              ref: const {'type': 'quiz', 'id': 'q1', 'title': 'Waves practice', 'count': 10, 'minutes': 15},
            ),
            mine: false,
            first: true,
            who: 'Mr Ade',
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('QUIZ FROM YOUR TUTOR'), findsOneWidget);
    expect(find.text('10 questions · 15 min'), findsOneWidget);
    expect(find.text('Open quiz'), findsOneWidget);
  });
}
