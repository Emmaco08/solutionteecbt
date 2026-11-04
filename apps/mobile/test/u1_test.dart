import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/auth/auth_screens.dart';
import 'package:solutiontee_cbt/features/home/tour.dart';
import 'package:solutiontee_cbt/features/xp/streak_ui.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

void main() {
  testWidgets('OTP boxes: tapping opens the keyboard and typed digits fill the boxes', (t) async {
    final code = TextEditingController();
    final focus = FocusNode();
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CodeBoxes(controller: code, focus: focus, length: 8),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    // Lose focus (like closing the keyboard), then tap the boxes again.
    focus.unfocus();
    await t.pump();
    expect(focus.hasFocus, isFalse);
    await t.tap(find.byType(CodeBoxes));
    await t.pump();
    expect(focus.hasFocus, isTrue);
    expect(t.testTextInput.isVisible, isTrue);

    // The phone's back button closes the keyboard but the field keeps focus: a tap must open it again.
    t.testTextInput.hide();
    expect(t.testTextInput.isVisible, isFalse);
    expect(focus.hasFocus, isTrue);
    await t.tap(find.byType(CodeBoxes));
    await t.pump();
    expect(t.testTextInput.isVisible, isTrue);

    await t.enterText(find.byKey(const ValueKey('code-field')), '1234a5678');
    await t.pump(const Duration(milliseconds: 300));
    expect(code.text, '12345678'); // letters are dropped
    for (final d in ['1', '4', '5', '8']) {
      expect(find.text(d), findsOneWidget);
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    code.dispose();
    focus.dispose();
  });

  testWidgets('tour: a step whose target is far below the screen scrolls to it, and Done closes the tour', (t) async {
    var done = false;
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: _TourHarness(onDone: () => done = true),
      ),
    );
    await t.tap(find.byType(FloatingActionButton));
    await _settle(t);
    for (final title in ['First', 'Second', 'Third', 'Fourth']) {
      expect(find.text(title), findsOneWidget);
      await t.tap(find.text('Next'));
      await _settle(t);
    }
    expect(find.text('Fifth'), findsOneWidget);
    expect(find.text('Step 5 of 5'), findsOneWidget);
    // The tip card is on screen and tappable.
    final done0 = t.getRect(find.text('Done'));
    expect(done0.top, greaterThan(0));
    expect(done0.bottom, lessThan(t.view.physicalSize.height / t.view.devicePixelRatio));
    await t.tap(find.text('Done'));
    await _settle(t);
    expect(done, isTrue);
    expect(find.text('Fifth'), findsNothing);
  });

  testWidgets('tour: Back returns to the previous step', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: _TourHarness(onDone: () {}),
      ),
    );
    await t.tap(find.byType(FloatingActionButton));
    await _settle(t);
    await t.tap(find.text('Next'));
    await _settle(t);
    expect(find.text('Second'), findsOneWidget);
    await t.tap(find.text('Back'));
    await _settle(t);
    expect(find.text('First'), findsOneWidget);
  });

  test('streak week: past days without practice are "missed", frozen days keep their ice, future days stay empty', () {
    final w = [
      {'done': true},
      {'done': false},
      {'done': false, 'saved': 'freeze'},
      {'done': true, 'today': true},
      {'done': false},
      {'done': false},
      {'done': false},
    ];
    expect([for (var k = 0; k < 7; k++) StreakWeek.stateOf(w, k)], ['done', 'missed', 'frozen', 'today_done', 'future', 'future', 'future']);
    w[3] = {'done': false, 'today': true};
    expect(StreakWeek.stateOf(w, 3), 'today');
  });

  testWidgets('streak week shows a missed-day icon and the labels', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: const Scaffold(
          body: StreakWeek(
            week: [
              {'done': true},
              {'done': false},
              {'done': false, 'today': true},
            ],
            onDark: true,
          ),
        ),
      ),
    );
    await _settle(t);
    expect(find.bySemanticsLabel('missed'), findsOneWidget);
    expect(find.bySemanticsLabel('today, not yet'), findsOneWidget);
    expect(find.bySemanticsLabel('practised'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });

  for (final (name, setting, shown) in [
    ('off', {'enabled': false, 'web_client_id': '123-abc.apps.googleusercontent.com'}, false),
    ('on without a client ID', {'enabled': true, 'web_client_id': ''}, false),
    ('on with a client ID', {'enabled': true, 'web_client_id': '123-abc.apps.googleusercontent.com'}, true),
  ]) {
    testWidgets('Continue with Google on log-in and sign-up: $name', (t) async {
      for (final screen in const [LoginScreen(), SignUpScreen()]) {
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              appSettingsProvider.overrideWith((ref) async => {'google_auth': setting}),
            ],
            child: MaterialApp(theme: buildTheme(Brightness.light), home: screen),
          ),
        );
        await _settle(t);
        expect(find.text('Continue with Google'), shown ? findsOneWidget : findsNothing);
        if (screen is SignUpScreen) expect(find.textContaining('By continuing with Google'), shown ? findsOneWidget : findsNothing);
      }
    });
  }
}

/// A long page with a target far below the screen, like Home's Upgrade card.
class _TourHarness extends StatefulWidget {
  const _TourHarness({required this.onDone});
  final VoidCallback onDone;
  @override
  State<_TourHarness> createState() => _TourHarnessState();
}

class _TourHarnessState extends State<_TourHarness> {
  final top = GlobalKey(), bottom = GlobalKey();
  OverlayEntry? e;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      children: [
        Container(key: top, height: 120, color: Colors.blue),
        for (var i = 0; i < 20; i++) SizedBox(height: 150, child: Text('row $i')),
        Container(key: bottom, height: 100, color: Colors.amber),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () {
        e = OverlayEntry(
          builder: (_) => TourOverlay(
            steps: [
              TourStep(key: top, icon: Icons.star, title: 'First', text: 'a'),
              const TourStep(icon: Icons.star, title: 'Second', text: 'b'),
              const TourStep(icon: Icons.star, title: 'Third', text: 'c'),
              TourStep(rect: () => const Rect.fromLTWH(0, 5000, 10, 10), icon: Icons.star, title: 'Fourth', text: 'd'),
              TourStep(key: bottom, icon: Icons.star, title: 'Fifth', text: 'e'),
            ],
            onDone: () {
              e?.remove();
              widget.onDone();
            },
          ),
        );
        Overlay.of(context).insert(e!);
      },
    ),
  );
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}
