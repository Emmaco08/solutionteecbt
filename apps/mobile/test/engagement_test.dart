// App rating card rules (owner, 16 Nov 2026: "test if app rating really works"). D-160 timing: after 3 days and 6 opens
// (admin can change), then every N days; "Not now" waits 14 days.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/engagement.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

void main() {
  late AppDb db;
  setUp(() => db = AppDb(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<bool?> run(WidgetTester t, {Map<String, dynamic> settings = const {}}) async {
    bool? shown;
    await t.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db), appSettingsProvider.overrideWith((ref) async => settings)],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    await ref.read(appSettingsProvider.future);
                    if (!context.mounted) return;
                    shown = await Engagement.maybeShowOne(context, ref);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.tap(find.text('open'));
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await t.pump(const Duration(milliseconds: 100));
    }
    return shown;
  }

  testWidgets('a new install sees no rating card', (t) async {
    await t.runAsync(() async {
      await db.kvSet('eng_first', DateTime.now().toIso8601String());
      await db.kvSet('eng_opens', '2');
      // Nudges off so nothing else shows.
    });
    await run(
      t,
      settings: {
        'engagement': {
          'nudges': {'on': false},
        },
      },
    );
    expect(find.text('Tap a star'), findsNothing);
  });

  testWidgets('after 3 days and 6 opens the rating card shows; Not now waits 14 days', (t) async {
    await t.runAsync(() async {
      await db.kvSet('eng_first', DateTime.now().subtract(const Duration(days: 4)).toIso8601String());
      await db.kvSet('eng_opens', '6');
    });
    await run(t);
    expect(find.text('Tap a star'), findsOneWidget);
    await t.tap(find.text('Not now'));
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Tap a star'), findsNothing);
    final next = DateTime.parse((await t.runAsync<String?>(() => db.kvGet('eng_rating_next')))!);
    expect(next.difference(DateTime.now()).inDays, inInclusiveRange(13, 14));
  });

  testWidgets('the admin can switch the rating card off', (t) async {
    await t.runAsync(() async {
      await db.kvSet('eng_first', DateTime.now().subtract(const Duration(days: 30)).toIso8601String());
      await db.kvSet('eng_opens', '60');
    });
    await run(
      t,
      settings: {
        'engagement': {
          'rating': {'on': false},
          'nudges': {'on': false},
        },
      },
    );
    expect(find.text('Tap a star'), findsNothing);
  });
}
