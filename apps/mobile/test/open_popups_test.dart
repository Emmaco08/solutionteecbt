// The pop-ups of one app open never overlap (owner, 16 Nov 2026: "test if the WhatsApp join pop-up is not conflicting
// with the JAMB countdown and the app tour"). D-174.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:solutiontee_cbt/features/home/countdown.dart';
import 'package:solutiontee_cbt/features/home/whatsapp_channel.dart';
import 'package:solutiontee_cbt/features/shell/open_popups.dart';
import 'package:solutiontee_cbt/features/home/home_screen.dart' show PracticeStats, practiceStatsProvider;
import 'package:solutiontee_cbt/features/home/top_card.dart' show motivationProvider;
import 'package:solutiontee_cbt/features/profile/badges.dart' show badgesProvider;
import 'package:solutiontee_cbt/features/xp/streak_ui.dart' show myStreakProvider;
import 'package:solutiontee_cbt/theme/theme.dart';

String _in(int days) {
  final d = DateTime.now().add(Duration(days: days));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

void main() {
  late AppDb db;
  setUp(() {
    db = AppDb(NativeDatabase.memory());
    newAppOpen();
  });
  tearDown(() => db.close());

  final settings = {
    'exam_countdown': {
      'on': true,
      'daily': true,
      'dates': {'JAMB': _in(100)},
    },
    'whatsapp_channel': {'enabled': true, 'popup': true, 'url': 'https://whatsapp.com/channel/0029VaTEST'},
    'engagement': {
      'rating': {'on': false},
      'nudges': {'on': false},
    },
  };

  Future<void> open(WidgetTester t, {required bool toured, bool joined = false}) async {
    await t.pumpWidget(const SizedBox()); // a fresh app each time
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          initialSettingsProvider.overrideWithValue(AppSettings(onboarded: true, toured: toured)),
          appSettingsProvider.overrideWith((ref) async => settings),
          profileProvider.overrideWith(
            (ref) async => {
              'target_exams': ['JAMB'],
            },
          ),
          myStreakProvider.overrideWith((ref) async => const <String, dynamic>{}),
          badgesProvider.overrideWith((ref) async => const <String, dynamic>{'won': []}),
          waJoinedProvider.overrideWith((ref) async => joined),
          practiceStatsProvider.overrideWith((ref) async => const PracticeStats(today: 0, streak: 0, week: {})),
          motivationProvider.overrideWith((ref) async => const <String, dynamic>{}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(onPressed: () => runOpenPopups(context, ref), child: const Text('open app')),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.tap(find.text('open app'));
    await settle(t);
  }

  testWidgets('countdown first; the WhatsApp pop-up only after the countdown is closed', (t) async {
    await open(t, toured: true);
    expect(find.byType(ExamCountdownScreen), findsOneWidget);
    expect(find.byType(WhatsAppPopup), findsNothing, reason: 'never on top of the countdown');
    await t.tap(find.byTooltip('Close'));
    await settle(t, seconds: 2);
    expect(find.byType(ExamCountdownScreen), findsNothing);
    expect(find.byType(WhatsAppPopup), findsOneWidget);
    // Maybe later closes it.
    await t.ensureVisible(find.text('Maybe later'));
    await t.pump();
    await t.tap(find.text('Maybe later'));
    await settle(t);
    expect(find.byType(WhatsAppPopup), findsNothing);
  });

  testWidgets('a new student (app tour not done yet): no countdown and no WhatsApp pop-up on this open', (t) async {
    await open(t, toured: false);
    expect(find.byType(ExamCountdownScreen), findsNothing);
    expect(find.byType(WhatsAppPopup), findsNothing);
  });

  testWidgets('second open the same day: no countdown, the WhatsApp pop-up straight away; none after joining', (t) async {
    final now = DateTime.now();
    await t.runAsync(() => db.kvSet('countdown_day', '${now.year}-${now.month}-${now.day}'));
    await open(t, toured: true);
    expect(find.byType(ExamCountdownScreen), findsNothing);
    expect(find.byType(WhatsAppPopup), findsOneWidget);
    await t.ensureVisible(find.text('Maybe later'));
    await t.pump();
    await t.tap(find.text('Maybe later'));
    await settle(t);
    newAppOpen();
    await open(t, toured: true, joined: true);
    expect(find.byType(WhatsAppPopup), findsNothing);
  });
}

Future<void> settle(WidgetTester t, {int seconds = 1}) async {
  for (var i = 0; i < 10 * seconds; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 100));
  }
}
