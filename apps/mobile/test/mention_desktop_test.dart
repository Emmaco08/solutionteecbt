// @mention suggestions can be clicked with a mouse on Windows (owner, 16 Nov 2026, D-178). With a mouse, pressing
// outside a text box takes its focus away; the list used to vanish on the press, so the click never landed.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/community/community_widgets.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('typing @so and clicking SolutionTee finishes the handle (${platform.name})', (t) async {
      debugDefaultTargetPlatformOverride = platform;
      seedMentionSuggestions('so', [
        {'handle': 'solutiontee', 'name': 'SolutionTee', 'badge': 'official'},
        {'handle': 'sola_ade', 'name': 'Sola Ade'},
      ]);
      final text = TextEditingController();
      final focus = FocusNode();
      await t.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextField(controller: text, focusNode: focus),
                    MentionSuggestions(controller: text, focus: focus),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.byType(TextField));
      await t.enterText(find.byType(TextField), 'Thanks @so');
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 60)); // the list slides open
      }
      expect(find.text('@solutiontee'), findsOneWidget);
      await t.tap(find.text('@solutiontee'), kind: platform == TargetPlatform.windows ? PointerDeviceKind.mouse : PointerDeviceKind.touch);
      await t.pump(const Duration(milliseconds: 400));
      expect(text.text, 'Thanks @solutiontee ');
      expect(focus.hasFocus, isTrue, reason: 'the cursor stays in the text box, so the student keeps typing');
      expect(find.text('@sola_ade'), findsNothing, reason: 'the list closes after a pick');
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
