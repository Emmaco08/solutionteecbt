import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/data/ai_repo.dart';
import 'package:solutiontee_cbt/features/ai/ai_cards.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:solutiontee_cbt/widgets/math_text.dart';
import 'package:solutiontee_cbt/widgets/note_markdown.dart';

import 'u3b_test.dart' show FakeAi, chat, end, sendFromComposer, settle;

/// Big update 2, step A: reminders, the photo read card, steps that run one after another, and text fixes.
class _Reminders extends FakeAi {
  final cancelled = <String>[];
  @override
  Future<bool> cancelReminder(String id) async {
    cancelled.add(id);
    return true;
  }
}

Widget _host(Widget child, {AiRepo? repo}) => ProviderScope(
  overrides: [if (repo != null) aiRepoProvider.overrideWithValue(repo)],
  child: MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 800, child: child)),
    ),
  ),
);

void main() {
  testWidgets('reminders card lists reminders and cancels one', (t) async {
    final repo = _Reminders();
    await t.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      _host(
        const RemindersCard(
          card: {
            'type': 'reminders',
            'items': [
              {'id': 'r1', 'title': 'Study Physics', 'when': 'today at 6:00 pm'},
              {'id': 'r2', 'title': 'Read the novel', 'when': 'tomorrow at 7:00 am'},
            ],
          },
        ),
        repo: repo,
      ),
    );
    expect(find.text('Study Physics'), findsOneWidget);
    expect(find.text('today at 6:00 pm'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Cancel this reminder').first);
    await t.pump();
    await t.pump();
    expect(repo.cancelled, ['r1']);
    expect(find.text('Study Physics'), findsNothing);
    expect(find.text('Read the novel'), findsOneWidget);
  });

  testWidgets('photo read card: edit, then Solve it sends the corrected text', (t) async {
    String? sent;
    await t.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      _host(
        PhotoTextCard(card: const {'type': 'photo_text', 'text': 'Solve 2x + 3 = 11'}, send: ({text, tool, args, questionId, explain = false}) => sent = text),
      ),
    );
    expect(find.text('What I read from your photo'), findsOneWidget);
    await t.tap(find.text('Edit'));
    await t.pump();
    await t.enterText(find.byType(TextField), 'Solve 2x + 5 = 11');
    await t.tap(find.text('Solve it'));
    await t.pump();
    expect(sent, contains('Solve 2x + 5 = 11'));
    expect(find.text('Sent — solving it'), findsOneWidget);
  });

  testWidgets('a request with several steps sends the next step by itself', (t) async {
    final ai = FakeAi()
      ..script = (i) => i == 0
          ? [
              AiStart('c1'),
              AiDelta('Your weakest topic is Motion.'),
              AiDone(
                messageId: 'm1',
                next: const [
                  {'tool': 'study_plan', 'args': {}, 'label': 'Make my study plan'},
                  {'tool': 'mock_exam', 'args': {}, 'label': 'Start a JAMB mock'},
                ],
              ),
            ]
          : [AiStart('c1'), AiDelta('Done.'), AiDone(messageId: 'm${i + 1}')];
    await chat(t, ai);
    await sendFromComposer(t, 'Check my weak topics, then make a plan, then a mock');
    await settle(t, 2500);
    expect(ai.asked.length, greaterThanOrEqualTo(2));
    expect(ai.asked[1]['tool'], 'study_plan');
    expect(find.text('Make my study plan'), findsWidgets);
    await end(t);
  });

  test('odd dashes and <br> are tidied', () {
    expect(MathText.tidy('step‑by‑step'), 'step-by-step');
    expect(NoteDoc.tidy('| a<br>• b |'), '| a · b |');
    expect(NoteDoc.tidy('line one<br>line two'), 'line one\nline two');
  });

  testWidgets('an underlined word is plain underlined text, not maths', (t) async {
    await t.pumpWidget(_host(const MathText(r'one is a $\underline{\text{freelance}}$ journalist')));
    final rich = t.widget<Text>(find.byType(Text).first);
    final spans = (rich.textSpan! as TextSpan).children!.whereType<TextSpan>().toList();
    expect(spans.any((s) => s.text == 'freelance' && s.style?.decoration == TextDecoration.underline), isTrue);
  });

  test('AiSseParser reads next steps and skips keep-alive lines', () {
    final p = AiSseParser();
    final e = p.add(': keep-alive\n\ndata: {"t":"done","message_id":"m","next":[{"tool":"quiz","label":"Quiz me"}]}\n\n');
    expect(e.single, isA<AiDone>());
    expect((e.single as AiDone).next.single['tool'], 'quiz');
  });
}
