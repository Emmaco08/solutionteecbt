import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/tutor/tutor.dart';
import 'package:solutiontee_cbt/features/tutor/tutor_chat.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

// Request a tutor v2 (D-152).
Widget _app(Map<String, dynamic> data) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    tutorProvider.overrideWith((_) async => data),
    profileProvider.overrideWith(
      (_) async => {
        'jamb_subjects': ['PHY'],
      },
    ),
    subjectsProvider.overrideWith(
      (_) async => [
        {'id': 3, 'code': 'PHY', 'name': 'Physics', 'sort': 1},
      ],
    ),
  ],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: const TutorScreen()),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 14; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

Map<String, dynamic> _req(String status, {int? custom}) => {
  'id': 'r1',
  'subject_id': 3,
  'level': 'jamb',
  'goals': 'Help with graphs',
  'status': status,
  'custom_price_kobo': custom,
  'custom_days': custom == null ? null : 60,
  'custom_note': custom == null ? null : 'Weekend classes',
};

const _plans = [
  {'id': 'p1', 'name': 'Starter', 'description': '4 lessons', 'price_kobo': 1000000, 'days': 30, 'sessions': 4},
  {'id': 'p2', 'name': 'Monthly', 'description': '8 lessons', 'price_kobo': 1800000, 'days': 30, 'sessions': 8},
  {'id': 'p3', 'name': 'Intensive', 'description': '20 lessons', 'price_kobo': 4000000, 'days': 90, 'sessions': 20},
];

void main() {
  test('stages follow the request status', () {
    expect(tutorStage(null), TutorStage.request);
    expect(tutorStage(_req('closed')), TutorStage.request);
    expect(tutorStage(_req('new')), TutorStage.plans);
    expect(tutorStage(_req('quoted')), TutorStage.plans);
    expect(tutorStage(_req('paid')), TutorStage.waiting);
    expect(tutorStage(_req('matched'), hasTutor: true), TutorStage.chat);
    expect(tutorStage(_req('ended')), TutorStage.ended);
    expect(tutorOpen(_req('paid')), isTrue);
    expect(tutorOpen(_req('ended')), isFalse);
    expect(whatsappUri('08012345678').toString(), 'https://wa.me/2348012345678');
  });

  test('chat day labels and durations', () {
    final now = DateTime(2026, 11, 11, 12);
    expect(chatDay(DateTime(2026, 11, 11, 8), now), 'Today');
    expect(chatDay(DateTime(2026, 11, 10, 8), now), 'Yesterday');
    expect(chatDay(DateTime(2026, 10, 2), now), '2 Oct');
    expect(fmtDur(75), '1:15');
    expect(initialsOf('Ada Obi'), 'AO');
    expect(chatPreview(ChatMsg(id: 1, role: 'tutor', kind: 'voice', body: '', at: now)), '🎤 Voice note');
  });

  testWidgets('no request: the hero and the request form', (t) async {
    t.view.physicalSize = const Size(1200, 4200);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app({'request': null, 'messages': [], 'plans': _plans}));
    await _settle(t);
    expect(find.text('Learn with a real teacher'), findsOneWidget);
    expect(find.text('See tutor plans'), findsOneWidget);
  });

  testWidgets('a new request shows the plans, a custom price and the custom plan box', (t) async {
    t.view.physicalSize = const Size(1200, 5200);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app({'request': _req('quoted', custom: 2500000), 'messages': [], 'plans': _plans}));
    await _settle(t);
    expect(find.text('Choose your tutor plan'), findsOneWidget);
    expect(find.text('Your custom plan'), findsOneWidget);
    expect(find.text('₦25,000'), findsOneWidget);
    expect(find.text('₦18,000'), findsOneWidget);
    expect(find.text('Most popular'), findsOneWidget);
    expect(find.text('Custom plan'), findsOneWidget);
  });

  testWidgets('paid: the waiting screen with the next steps', (t) async {
    t.view.physicalSize = const Size(1200, 4200);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _app({
        'request': _req('paid'),
        'messages': [],
        'plans': _plans,
        'subscription': {'plan': 'Monthly', 'ends_at': '2026-12-11T10:00:00Z'},
      }),
    );
    await _settle(t);
    expect(find.text('Finding your tutor'), findsOneWidget);
    expect(find.text('Payment received'), findsOneWidget);
    expect(find.textContaining('Monthly plan until 11 Dec 2026'), findsOneWidget);
  });

  testWidgets('bubbles: my text with a read tick, the tutor call card and a study link', (t) async {
    final at = DateTime(2026, 11, 11, 9, 5);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: ListView(
            children: [
              ChatBubble(
                m: ChatMsg(id: 1, role: 'student', kind: 'text', body: 'Good morning sir', at: at, readAt: at),
                mine: true,
                first: true,
                who: 'Mr Ade',
              ),
              ChatBubble(
                m: ChatMsg(
                  id: 2,
                  role: 'tutor',
                  kind: 'link',
                  body: 'Physics class now',
                  at: at,
                  meta: const {'url': 'https://meet.google.com/abc', 'type': 'meet'},
                ),
                mine: false,
                first: true,
                who: 'Mr Ade',
              ),
              ChatBubble(
                m: ChatMsg(
                  id: 3,
                  role: 'tutor',
                  kind: 'ref',
                  body: '',
                  at: at,
                  ref: const {'type': 'pq', 'title': 'JAMB Physics 2019 · Q4', 'exam_id': 1, 'subject_id': 3, 'year': 2019},
                ),
                mine: false,
                first: false,
                who: 'Mr Ade',
              ),
              ChatBubble(
                m: ChatMsg(id: 4, role: 'system', kind: 'text', body: 'Mr Ade is your tutor now.', at: at),
                mine: false,
                first: true,
                who: '',
              ),
            ],
          ),
        ),
      ),
    );
    await _settle(t);
    expect(find.text('Good morning sir'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == 'Seen'), findsOneWidget);
    expect(find.text('Physics class now'), findsOneWidget);
    expect(find.text('Join now'), findsOneWidget);
    expect(find.text('JAMB Physics 2019 · Q4'), findsOneWidget);
    expect(find.text('Mr Ade is your tutor now.'), findsOneWidget);
  });
}
