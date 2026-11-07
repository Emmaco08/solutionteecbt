import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:solutiontee_cbt/features/home/home_screen.dart';
import 'package:solutiontee_cbt/features/home/top_card.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

LocalAttempt _attempt() => LocalAttempt(
  id: 'a1',
  examId: 1,
  examCode: 'JAMB',
  mode: 'mock',
  configJson: '{"title":"JAMB UTME Mock","timed":true}',
  questionIdsJson: '[${List.generate(180, (i) => '"q$i"').join(',')}]',
  limitSeconds: 7200,
  usedMs: 600000,
  currentIndex: 3,
  startedAt: DateTime.now().subtract(const Duration(hours: 2)),
  synced: false,
);

Widget _app(Brightness b, {bool reduce = false}) => ProviderScope(
  overrides: [unfinishedAnsweredProvider('a1').overrideWith((_) async => 14)],
  child: MaterialApp.router(
    theme: buildTheme(b),
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(disableAnimations: reduce, textScaler: const TextScaler.linear(1.6)),
      child: child!,
    ),
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(child: ResumeHero(a: _attempt())),
          ),
        ),
        GoRoute(path: '/cbt/:id', builder: (_, s) => Text('cbt ${s.pathParameters['id']}')),
      ],
    ),
  ),
);

void main() {
  for (final b in Brightness.values) {
    testWidgets('ResumeHero shows progress and Continue in ${b.name} mode', (t) async {
      t.view.physicalSize = const Size(360 * 3, 800 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(b));
      await t.pump(const Duration(milliseconds: 1500));
      expect(find.text('14/180'), findsOneWidget);
      expect(find.text('JAMB UTME Mock'), findsOneWidget);
      expect(find.text('14 answered'), findsOneWidget);
      expect(find.text('166 to go'), findsOneWidget);
      expect(find.textContaining('left'), findsOneWidget);
      expect(find.textContaining('Paused'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('ResumeHero is still with reduce motion and Continue opens the test', (t) async {
    t.view.physicalSize = const Size(360 * 3, 800 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(Brightness.light, reduce: true));
    await t.pumpAndSettle();
    expect(find.text('14/180'), findsOneWidget);
    await t.tap(find.text('Continue test'));
    await t.pumpAndSettle();
    expect(find.text('cbt a1'), findsOneWidget);
  });
}
