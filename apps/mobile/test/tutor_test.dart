import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/features/tutor/tutor.dart';
import 'package:solutiontee_cbt/features/tutor/tutor_chat.dart';
import 'package:solutiontee_cbt/features/tutor/tutor_live.dart';
import 'package:solutiontee_cbt/theme/theme.dart';

// Request a tutor v2/v3 (D-152, D-153).
Widget _app(Map<String, dynamic> data, {Widget home = const TutorScreen()}) => ProviderScope(
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
        {'id': 4, 'code': 'CHE', 'name': 'Chemistry', 'sort': 2},
      ],
    ),
  ],
  child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 30; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(1200, 5200);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

Map<String, dynamic> _req(String status, {int? custom, String? assignedAt}) => {
  'id': 'r1',
  'subject_id': 3,
  'subjects': 'Physics, Chemistry',
  'level': 'jamb',
  'goals': 'Help with graphs',
  'times': 'Evenings',
  'status': status,
  'custom_price_kobo': custom,
  'custom_days': custom == null ? null : 60,
  'custom_note': custom == null ? null : 'Weekend classes',
  'assigned_at': assignedAt,
};

const _plans = [
  {'id': 'p1', 'name': 'Starter', 'description': '4 lessons', 'price_kobo': 1000000, 'days': 30, 'sessions': 4},
  {'id': 'p2', 'name': 'Monthly', 'description': 'Two video classes a week\nChat any day', 'price_kobo': 1800000, 'days': 30, 'sessions': 8},
  {'id': 'p3', 'name': 'Intensive', 'description': '20 lessons', 'price_kobo': 4000000, 'days': 90, 'sessions': 20},
];

const _tutor = {
  'id': 't1',
  'name': 'Adebayo Okafor',
  'subjects': 'Mathematics, Physics',
  'bio': 'We start with graphs and motion.',
  'years': 7,
  'qualification': 'B.Sc. Physics',
  'students': 12,
  'online': true,
};

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

  test('chat day labels, durations, last seen', () {
    final now = DateTime(2026, 11, 11, 12);
    expect(chatDay(DateTime(2026, 11, 11, 8), now), 'Today');
    expect(chatDay(DateTime(2026, 11, 10, 8), now), 'Yesterday');
    expect(chatDay(DateTime(2026, 10, 2), now), '2 Oct');
    expect(fmtDur(75), '1:15');
    expect(initialsOf('Ada Obi'), 'AO');
    expect(chatPreview(ChatMsg(id: 1, role: 'tutor', kind: 'voice', body: '', at: now)), '🎤 Voice note');
    expect(lastSeen(DateTime(2026, 11, 11, 18, 40).toIso8601String(), DateTime(2026, 11, 11, 20)), 'last seen today at 6:40 pm');
    expect(lastSeen(null), '');
  });

  test('the tutor reveal shows once, until the student says something', () {
    final at = DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String();
    final req = _req('matched', assignedAt: at);
    expect(tutorShowReveal(req, const [], <String>{}), isTrue);
    expect(tutorShowReveal(req, const [], {'r1'}), isFalse);
    expect(
      tutorShowReveal(req, [
        {'role': 'student', 'at': DateTime.now().toIso8601String()},
      ], <String>{}),
      isFalse,
    );
    expect(tutorShowReveal(_req('paid', assignedAt: at), const [], <String>{}), isFalse);
    final old = DateTime.now().subtract(const Duration(days: 5)).toIso8601String();
    expect(tutorShowReveal(_req('matched', assignedAt: old), const [], <String>{}), isFalse);
  });

  test('plan features, emoji-only messages, call types, quotes', () {
    expect(planFeatures('Two classes a week\n- Chat any day\n• Study plan'), ['Two classes a week', 'Chat any day', 'Study plan']);
    expect(planFeatures(''), isEmpty);
    expect(emojiOnly('😂'), isTrue);
    expect(emojiOnly('👍🏽🔥'), isTrue);
    expect(emojiOnly('ok 👍'), isFalse);
    expect(emojiOnly('😂😂😂😂'), isFalse);
    expect(callType(const {'url': 'https://meet.google.com/abc'}), 'meet');
    expect(callType(const {'url': 'https://us02web.zoom.us/j/1'}), 'zoom');
    expect(callType(const {'url': 'https://wa.me/234801'}), 'whatsapp');
    expect(callType(const {'type': 'whatsapp', 'url': 'https://x.com'}), 'whatsapp');
    expect(callType(const {'url': 'https://teams.live.com/x'}), 'video');
    expect(
      quoteText(const {
        'kind': 'voice',
        'meta': {'duration': 42},
      }),
      'Voice note (0:42)',
    );
    expect(quoteText(const {'kind': 'text', 'body': 'x', 'deleted': true}), 'This message was deleted');
  });

  test('a raw Realtime row: deleted, reactions, reply; an update keeps the reply copy and the star', () {
    final row = ChatMsg.from({
      'id': 9,
      'sender_role': 'tutor',
      'kind': 'image',
      'body': '',
      'attachment_path': 't/x/y.jpg',
      'created_at': '2026-11-11T10:00:00Z',
      'reactions': {'student': '👍', 'tutor': ''},
      'reply_to': 4,
      'deleted_at': null,
    });
    expect(row.role, 'tutor');
    expect(row.reactions, {'student': '👍'});
    expect(row.replyTo, 4);
    expect(row.deleted, isFalse);
    final mine = ChatMsg(id: 9, role: 'tutor', kind: 'image', body: '', at: DateTime(2026), reply: const {'id': 4, 'body': 'hi'}, starred: true);
    mine.update(
      ChatMsg.from({'id': 9, 'sender_role': 'tutor', 'kind': 'image', 'body': '', 'created_at': '2026-11-11T10:00:00Z', 'deleted_at': '2026-11-11T11:00:00Z'}),
    );
    expect(mine.deleted, isTrue);
    expect(mine.kind, 'text');
    expect(mine.attachment, isNull);
    expect(mine.reply?['body'], 'hi');
    expect(mine.starred, isTrue);
  });

  test('live channels join again with a growing wait, up to 30 s', () {
    expect([for (var i = 0; i < 8; i++) LiveChannel.backoff(i)], [1, 2, 4, 8, 16, 30, 30, 30]);
  });

  testWidgets('no request: the hero, subjects from the combination and the request form', (t) async {
    _tall(t);
    await t.pumpWidget(_app({'request': null, 'messages': [], 'plans': _plans}));
    await _settle(t);
    expect(find.text('Learn with a real teacher'), findsOneWidget);
    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('Another subject'), findsOneWidget);
    expect(find.text('Evenings'), findsOneWidget);
    expect(find.text('See tutor plans'), findsOneWidget);
  });

  testWidgets('a quoted request: plans with the custom price first and selected, Pay button follows the choice', (t) async {
    _tall(t);
    await t.pumpWidget(_app({'request': _req('quoted', custom: 2500000), 'messages': [], 'plans': _plans}));
    await _settle(t);
    expect(find.text('Choose your plan'), findsOneWidget);
    expect(find.text('Your custom plan'), findsOneWidget);
    expect(find.text('FOR YOU'), findsOneWidget);
    expect(find.text('Pay ₦25,000'), findsOneWidget);
    await t.tap(find.text('Monthly'));
    await _settle(t);
    expect(find.text('Pay ₦18,000'), findsOneWidget);
    expect(find.text('Two video classes a week'), findsOneWidget);
  });

  testWidgets('a new request: Most popular is picked; the custom plan row', (t) async {
    _tall(t);
    await t.pumpWidget(_app({'request': _req('new'), 'messages': [], 'plans': _plans}));
    await _settle(t);
    expect(find.text('MOST POPULAR'), findsOneWidget);
    expect(find.text('Pay ₦18,000'), findsOneWidget);
    expect(find.text('Custom plan'), findsOneWidget);
    expect(find.textContaining('Physics, Chemistry'), findsOneWidget);
  });

  testWidgets('paid: finding your tutor, with the live steps', (t) async {
    _tall(t);
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
    expect(find.text('Matching a Physics, Chemistry tutor'), findsOneWidget);
  });

  testWidgets('just assigned: the tutor reveal with Say hello', (t) async {
    _tall(t);
    await t.pumpWidget(
      _app({
        'request': _req('matched', assignedAt: DateTime.now().toIso8601String()),
        'messages': [],
        'plans': _plans,
        'tutor': _tutor,
        'subscription': {'plan': 'Monthly', 'ends_at': '2026-12-11T10:00:00Z', 'sessions': 8},
      }),
    );
    await _settle(t);
    expect(find.text('TUTOR ASSIGNED'), findsOneWidget);
    expect(find.text('Meet Adebayo Okafor'), findsOneWidget);
    expect(find.text('7 years teaching'), findsOneWidget);
    expect(find.text('B.Sc. Physics'), findsOneWidget);
    expect(find.text('Say hello'), findsOneWidget);
  });

  testWidgets('the tutor payment screen never says Premium', (t) async {
    _tall(t);
    await t.pumpWidget(
      _app({
        'request': _req('paid'),
        'messages': [],
        'plans': _plans,
        'subscription': {'plan': 'Monthly', 'ends_at': '2026-12-11T10:00:00Z', 'sessions': 8, 'reference': 'st_0123456789abcdef0123', 'amount_kobo': 1800000},
      }, home: const TutorPaidScreen()),
    );
    await _settle(t);
    expect(find.text('Your tutor plan is on!'), findsOneWidget);
    expect(find.text('Payment received · ₦18,000'), findsOneWidget);
    expect(find.text('Monthly · 8 lessons'), findsOneWidget);
    expect(find.textContaining('Premium'), findsNothing);
  });

  testWidgets('bubbles: read ticks, a reply quote, a reaction, the Meet card with its logo, a study link, a deleted message', (t) async {
    final at = DateTime(2026, 11, 11, 9, 5);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: ListView(
            children: [
              ChatBubble(
                m: ChatMsg(
                  id: 1,
                  role: 'student',
                  kind: 'text',
                  body: 'Good morning sir',
                  at: at,
                  readAt: at,
                  reply: const {'id': 0, 'role': 'tutor', 'kind': 'text', 'body': 'Send me the question'},
                  reactions: const {'tutor': '❤️'},
                ),
                mine: true,
                first: true,
                who: 'Mr Ade',
                peer: 'Mr Ade',
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
                m: ChatMsg(id: 5, role: 'tutor', kind: 'text', body: '', at: at, deleted: true),
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
    expect(find.text('Send me the question'), findsOneWidget);
    expect(find.text('❤️'), findsOneWidget);
    expect(find.text('Physics class now'), findsOneWidget);
    expect(find.text('Join with Google Meet'), findsOneWidget);
    expect(find.bySemanticsLabel('Google Meet'), findsWidgets);
    expect(find.text('JAMB PHYSICS 2019 · Q4'), findsOneWidget);
    expect(find.text('This message was deleted'), findsOneWidget);
    expect(find.text('Mr Ade is your tutor now.'), findsOneWidget);
  });
}
