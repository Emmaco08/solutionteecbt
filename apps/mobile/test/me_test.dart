import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/profile/me_extras.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

void main() {
  testWidgets('badges: the 8 from the design, with how many are earned', (t) async {
    final badges = [
      for (final (k, title, on) in [
        ('streak7', '7-day streak', true),
        ('first250', 'First 250+', true),
        ('speedster', 'Speedster', false),
        ('correct100', '100 correct', true),
        ('score300', 'Score 300', false),
        ('nightowl', 'Night owl', false),
        ('bookworm', 'Bookworm', false),
        ('fullmock', 'Full mock', true),
      ])
        {'key': k, 'title': title, 'earned': on, 'progress': 'x'},
    ];
    await t.pumpWidget(
      ProviderScope(
        overrides: [myBadgesProvider.overrideWith((_) async => badges)],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(body: SingleChildScrollView(child: BadgesSection())),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Badges'), findsOneWidget);
    expect(find.text('4 of 8'), findsOneWidget);
    for (final b in badges) {
      expect(find.text(b['title'] as String), findsOneWidget);
    }
    // Badges not earned yet are faded.
    expect(t.widgetList<Opacity>(find.byType(Opacity)).where((o) => o.opacity < 1).length, 4);
  });
}
