import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/tutor/tutor.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

// Request a tutor (C12, D-149).
Widget _app(Map<String, dynamic> data) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    tutorProvider.overrideWith((_) async => data),
    subjectsProvider.overrideWith(
      (_) async => [
        {'id': 3, 'code': 'PHY', 'name': 'Physics', 'sort': 1},
      ],
    ),
  ],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: const TutorScreen()),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

Map<String, dynamic> _req(String status) => {
  'id': 'r1',
  'subject_id': 3,
  'level': 'jamb',
  'goals': 'Help with graphs',
  'times': 'Evenings',
  'status': status,
  'created_at': '2026-11-11T10:00:00Z',
};

const _plan = {'id': 'p1', 'name': 'Monthly', 'description': '8 lessons on WhatsApp', 'price_kobo': 1500000, 'days': 30, 'sessions': 8};

void main() {
  test('WhatsApp links turn 0801… into 234801…', () {
    expect(whatsappUri('08012345678').toString(), 'https://wa.me/2348012345678');
    expect(whatsappUri('+234 801 234 5678').toString(), 'https://wa.me/2348012345678');
    expect(tutorOpen(null), isFalse);
    expect(tutorOpen(_req('closed')), isFalse);
    expect(tutorOpen(_req('replied')), isTrue);
  });

  testWidgets('no request yet shows the request form', (t) async {
    t.view.physicalSize = const Size(1200, 3600);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app({'request': null, 'messages': [], 'plans': [], 'subscription': null, 'tutor': null}));
    await _settle(t);
    expect(find.text('Get help from a real teacher'), findsOneWidget);
    expect(find.text('Send request'), findsOneWidget);
    expect(find.text('JAMB'), findsOneWidget);
  });

  testWidgets('an open request shows the chat and the plans; no tutor contacts without a plan', (t) async {
    t.view.physicalSize = const Size(1200, 3600);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _app({
        'request': _req('replied'),
        'messages': [
          {'id': 1, 'from_staff': true, 'body': 'Thanks! We got your request.', 'at': '2026-11-11T10:00:00Z'},
          {'id': 2, 'from_staff': false, 'body': 'When can we start?', 'at': '2026-11-11T10:05:00Z'},
        ],
        'plans': [_plan],
        'subscription': null,
        'tutor': null,
      }),
    );
    await _settle(t);
    expect(find.text('JAMB · Physics'), findsOneWidget);
    expect(find.text('Thanks! We got your request.'), findsOneWidget);
    expect(find.text('When can we start?'), findsOneWidget);
    expect(find.text('Tutor plans'), findsOneWidget);
    expect(find.text('₦15,000'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
  });

  testWidgets('with a plan on, the tutor contacts show and the plans hide', (t) async {
    t.view.physicalSize = const Size(1200, 3600);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _app({
        'request': _req('matched'),
        'messages': [],
        'plans': [_plan],
        'subscription': {'plan': 'Monthly', 'ends_at': '2026-12-11T10:00:00Z'},
        'tutor': {'name': 'Mrs Bello', 'subjects': 'Physics', 'bio': null, 'whatsapp': '+2348012345678', 'phone': '08012345678'},
      }),
    );
    await _settle(t);
    expect(find.text('Your tutor: Mrs Bello'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Tutor plans'), findsNothing);
    expect(find.textContaining('plan is on until 11 Dec 2026'), findsOneWidget);
  });
}
