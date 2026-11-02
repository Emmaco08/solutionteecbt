import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/data/ai_repo.dart';
import 'package:solutiontee_cbt/widgets/note_markdown.dart';

void main() {
  test('SSE parser handles events split across network pieces', () {
    final p = AiSseParser();
    final a = p.add('data: {"t":"start","chat_id":"c1"}\n\ndata: {"t":"d","c":"Hel');
    expect(a.length, 1);
    expect((a.first as AiStart).chatId, 'c1');
    final b = p.add('lo"}\n\ndata: {"t":"think"}\n\ndata: {"t":"done","message_id":"m1","left":2,"model":"x"}\n\n');
    expect(b.map((e) => e.runtimeType).toList(), [AiDelta, AiThinking, AiDone]);
    expect((b[0] as AiDelta).text, 'Hello');
    expect((b[2] as AiDone).left, 2);
  });

  test('SSE parser turns server errors into AiFailed and ignores junk', () {
    final p = AiSseParser();
    final e = p.add(': keep-alive\n\ndata: not json\n\ndata: {"t":"error","code":"busy","message":"Busy"}\n\n');
    expect(e.length, 1);
    expect((e.first as AiFailed).code, 'busy');
    expect((e.first as AiFailed).message, 'Busy');
  });

  test(r'maths written as \( \) and \[ \] is accepted', () {
    expect(NoteDoc.normalizeMath(r'Root \(x = 3\) here'), r'Root $x = 3$ here');
    expect(NoteDoc.normalizeMath('\\[\n\\frac{a}{b}\n\\]'), '\$\$\n\\frac{a}{b}\n\$\$');
    // A LaTeX line break "\\[4pt]" is not a display-maths opener.
    expect(NoteDoc.normalizeMath(r'keep $y$ and \\[4pt]'), r'keep $y$ and \\[4pt]');
  });
}
