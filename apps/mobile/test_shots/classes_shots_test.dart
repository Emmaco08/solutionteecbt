// Screenshots of online classes v2 (owner, 14 Nov 2026): programme cards, the programme screen (not in yet / in and
// live), a session screen with its countdown and the Home card. Not part of `flutter test`.
// Run: flutter test test_shots/classes_shots_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/features/classes/classes.dart';
import 'package:solutiontee_cbt/theme/theme.dart';
import 'package:solutiontee_cbt/widgets/r2_image.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

String _at(Duration d) => DateTime.now().add(d).toUtc().toIso8601String();

Map<String, dynamic> _prog({bool enrolled = false, bool live = false, String id = 'p1'}) => {
  'id': id,
  'slug': 'jamb-marathon',
  'title': 'JAMB Marathon Class',
  'tagline': 'Cover the whole JAMB syllabus in 8 weeks, live with top teachers',
  'flyer_path': 'public/classes/flyer.png',
  'exam': 'JAMB',
  'subjects': 'English, Maths, Physics, Chemistry',
  'teacher': 'Mr Adebayo',
  'teacher_bio': 'Physics teacher for 12 years. Thousands of students passed JAMB with him.',
  'schedule_note': 'Mon, Wed, Fri · 6–8 pm',
  'access': 'paid',
  'price_kobo': 1500000,
  'compare_kobo': 2500000,
  'seats_left': 18,
  'enrolled': enrolled,
  'allowed': enrolled,
  'buyable': true,
  'sessions_left': 21,
  'sessions_done': 3,
  'next': {
    'id': 's4',
    'title': 'Session 4: Motion and forces',
    'starts_at': live ? _at(const Duration(minutes: -20)) : _at(const Duration(days: 1, hours: 3, minutes: 12)),
    'minutes': 120,
    'live': live,
  },
  'highlights': ['Every JAMB topic, step by step', 'Weekly mock tests and reviews', 'Recordings of every session', 'Ask the teacher questions live'],
  'about': 'An 8-week live class for JAMB candidates. Each session takes one big topic, explains it simply, then works through past questions together.',
  'faq': [
    {'q': 'What if I miss a session?', 'a': 'Watch the recording in the app any time.'},
  ],
  'sessions': [
    {'id': 's1', 'title': 'Session 1: Introduction', 'starts_at': _at(const Duration(days: -6)), 'minutes': 120, 'status': 'published', 'has_recording': true},
    {'id': 's2', 'title': 'Session 2: Algebra', 'starts_at': _at(const Duration(days: -4)), 'minutes': 120, 'status': 'published', 'has_recording': true},
    {
      'id': 's4',
      'title': 'Session 4: Motion and forces',
      'starts_at': live ? _at(const Duration(minutes: -20)) : _at(const Duration(days: 1, hours: 3)),
      'minutes': 120,
      'status': 'published',
    },
    {'id': 's5', 'title': 'Session 5: Organic chemistry', 'starts_at': _at(const Duration(days: 3)), 'minutes': 120, 'status': 'published'},
  ],
};

Map<String, dynamic> _session({bool live = false}) => {
  'id': 's4',
  'title': 'Session 4: Motion and forces',
  'teacher': 'Mr Adebayo',
  'starts_at': live ? _at(const Duration(minutes: -20)) : _at(const Duration(hours: 5, minutes: 42)),
  'minutes': 120,
  'access': 'paid',
  'status': 'published',
  'registered': false,
  'allowed': true,
  'has_recording': false,
  'taken': 30,
  'seats': null,
  'program_id': 'p1',
  'program_title': 'JAMB Marathon Class',
};

void main() {
  late List<int> flyer;
  setUpAll(() async {
    await _font('PlusJakartaSans', ['assets/fonts/PlusJakartaSans-Medium.ttf', 'assets/fonts/PlusJakartaSans-Bold.ttf']);
    await _font('PhosphorRegular', ['assets/fonts/Phosphor-Regular.ttf']);
    await _font('PhosphorFill', ['assets/fonts/Phosphor-Fill.ttf']);
    await _font('MaterialIcons', ['/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    flyer = File('/tmp/claude-0/-home-user-solutionteecbt/9af2e74a-900a-5793-af73-b76bbcef40ba/scratchpad/flyer.png').readAsBytesSync();
  });

  Future<void> shot(
    WidgetTester t,
    Widget w,
    String name, {
    List<Map<String, dynamic>> sessions = const [],
    List<Map<String, dynamic>> programs = const [],
    Map<String, dynamic>? program,
    double h = 844,
  }) async {
    t.view.physicalSize = Size(390 * 3, h * 3);
    t.view.devicePixelRatio = 3;
    await t.runAsync(() async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            classesProvider.overrideWith((_) async => sessions),
            programsProvider.overrideWith((_) async => programs),
            programProvider.overrideWith((ref, id) async => program),
            r2BytesProvider.overrideWith((ref, a) async => Uint8List.fromList(flyer)),
          ],
          child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(Brightness.dark), home: w),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await t.pump(const Duration(milliseconds: 200));
      }
    });
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/classes/$name.png'));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  }

  testWidgets(
    'list',
    (t) => shot(
      t,
      const ClassesScreen(),
      'list',
      programs: [
        _prog(),
        _prog(id: 'p2', enrolled: true, live: true),
      ],
      sessions: [_session(live: true), _session()],
    ),
  );
  testWidgets('program buy', (t) => shot(t, const ProgramScreen(id: 'p1'), 'program_buy', program: _prog(), h: 1700));
  testWidgets('program live', (t) => shot(t, const ProgramScreen(id: 'p1'), 'program_live', program: _prog(enrolled: true, live: true)));
  testWidgets('session upcoming', (t) => shot(t, const ClassScreen(id: 's4'), 'session_upcoming', sessions: [_session()]));
  testWidgets('session live', (t) => shot(t, const ClassScreen(id: 's4'), 'session_live', sessions: [_session(live: true)]));
  testWidgets(
    'home card',
    (t) => shot(
      t,
      const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: [NextClassCard()]),
          ),
        ),
      ),
      'home_card',
      sessions: [_session()],
      h: 300,
    ),
  );
}
