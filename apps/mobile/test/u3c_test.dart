import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solutiontee_cbt/core/api.dart';
import 'package:solutiontee_cbt/core/providers.dart';
import 'package:solutiontee_cbt/data/db.dart';
import 'package:solutiontee_cbt/data/paper_sections.dart';
import 'package:solutiontee_cbt/data/tests_repo.dart';
import 'package:solutiontee_cbt/features/cbt/cbt_screen.dart';

import 'widgets_test.dart' show OfflineRepo, app;

Map<String, dynamic> row(String id, {int year = 2020, String? answer}) => {
  'id': id,
  'number': 1,
  'body': 'Body $id',
  'options': {'A': 'a', 'B': 'b'},
  'answer': answer ?? 'A',
  'year': year,
};

/// Plays back server answers instead of calling Supabase.
class FakePaperRepo extends TestsRepo {
  FakePaperRepo(super.ref);
  Map<String, dynamic> Function(Map<String, dynamic> params)? answer;
  final paperCalls = <Map<String, dynamic>>[];
  final fetched = <List<String>>[];
  @override
  Future<Map<String, dynamic>> rpcPaper(Map<String, dynamic> params) async {
    paperCalls.add(params);
    return answer!(params);
  }

  @override
  Future<List<Map<String, dynamic>>> rpcByIds(List<String> ids) async {
    fetched.add(ids);
    return [for (final id in ids) row(id)];
  }

  @override
  Future<int> syncPending() async => 0;
}

void main() {
  late AppDb db;
  late ProviderContainer container;
  late FakePaperRepo repo;
  final provider = Provider<FakePaperRepo>((ref) => FakePaperRepo(ref));

  setUp(() {
    db = AppDb(NativeDatabase.memory());
    container = ProviderContainer(overrides: [dbProvider.overrideWithValue(db), openYearsProvider.overrideWith((_) async => <Map<String, dynamic>>[])]);
    repo = container.read(provider);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  TestRequest req(TestMode mode, {List<int> subjects = const [1], int? year}) =>
      TestRequest(mode: mode, examId: 1, examCode: 'JAMB', subjectIds: subjects, year: year, count: 20);

  Future<Map<String, dynamic>> config(String id) async =>
      jsonDecode((await (db.select(db.localAttempts)..where((x) => x.id.equals(id))).getSingle()).configJson) as Map<String, dynamic>;

  test('server paper: keeps server order, stores sections relative to the whole attempt, downloads only missing ids', () async {
    // Cache one of the ids already.
    await db
        .into(db.cachedQuestions)
        .insert(CachedQuestionsCompanion.insert(id: 'e2', examId: 1, subjectId: 1, year: 2019, body: 'Body e2', optionsJson: '{"A":"a"}', answer: 'A'));
    repo.answer = (p) => p['p_subject'] == 1
        ? {
            'ok': true,
            'ids': ['e3', 'e1', 'e2'],
            'sections': [
              {'key': 'antonyms', 'label': 'Antonyms', 'instruction': 'Opposite.', 'start': 0, 'count': 2},
              {'key': 'more', 'label': 'More', 'instruction': '', 'start': 2, 'count': 1},
            ],
          }
        : {
            'ok': true,
            'ids': ['m1'],
            'sections': [],
          };
    final id = await repo.start(req(TestMode.full, subjects: [1, 2]), countFor: (s) => s == 1 ? 3 : 1, minutesPerQuestion: 1);
    final a = await (db.select(db.localAttempts)..where((x) => x.id.equals(id))).getSingle();
    expect(jsonDecode(a.questionIdsJson), ['e3', 'e1', 'e2', 'm1']);
    expect(repo.paperCalls.first, {'p_exam': 1, 'p_subject': 1, 'p_year': null, 'p_count': 3});
    expect(repo.fetched.first, unorderedEquals(['e3', 'e1']));
    final cfg = await config(id);
    final secs = PaperSections.fromConfig(cfg);
    expect(secs.all.length, 2); // only the English subject has sections
    expect(secs.at(0)!.label, 'Antonyms');
    expect(secs.at(1)!.label, 'Antonyms');
    expect(secs.at(2)!.key, 'more');
    expect(secs.at(3), isNull);
    expect(secs.position(secs.at(0)!), 'Section 1 of 1');
  });

  test('sections of a second subject are shifted by the questions before them', () async {
    repo.answer = (p) => {
      'ok': true,
      'ids': p['p_subject'] == 1 ? ['a1', 'a2'] : ['b1', 'b2', 'b3'],
      'sections': [
        {'key': 'grammar', 'label': 'Grammar', 'instruction': 'Fill.', 'start': 1, 'count': 1},
      ],
    };
    final id = await repo.start(req(TestMode.quick, subjects: [1, 2]), countFor: (_) => 2, minutesPerQuestion: 1);
    final secs = PaperSections.fromConfig(await config(id));
    expect(secs.all.map((s) => (s.subjectId, s.start)), [(1, 1), (2, 3)]);
    expect(repo.paperCalls.map((c) => c['p_count']), [10, 10]); // quick: the subject's share
  });

  test('year mode passes the year and no count', () async {
    repo.answer = (p) => {
      'ok': true,
      'ids': ['y1'],
      'sections': [],
    };
    final id = await repo.start(req(TestMode.year, year: 2018), countFor: (_) => 40, minutesPerQuestion: 1);
    expect(repo.paperCalls.single, {'p_exam': 1, 'p_subject': 1, 'p_year': 2018, 'p_count': null});
    expect((await config(id)).containsKey('sections'), isFalse);
  });

  test('locked paper throws the friendly premium error', () async {
    repo.answer = (_) => {'ok': false, 'why': 'locked'};
    await expectLater(
      repo.start(req(TestMode.subject, year: 2010), countFor: (_) => 40, minutesPerQuestion: 1),
      throwsA(isA<ApiError>().having((e) => e.message, 'message', 'This year is part of Premium.')),
    );
  });

  test('falls back to the local logic when the server cannot be reached', () async {
    await db
        .into(db.cachedQuestions)
        .insert(
          CachedQuestionsCompanion.insert(
            id: 'c1',
            examId: 1,
            subjectId: 1,
            year: 2018,
            number: const Value(1),
            body: 'Cached',
            optionsJson: '{"A":"a"}',
            answer: 'A',
          ),
        );
    repo.answer = (_) => throw Exception('offline');
    final id = await repo.start(req(TestMode.subject, year: 2018), countFor: (_) => 40, minutesPerQuestion: 1);
    final a = await (db.select(db.localAttempts)..where((x) => x.id.equals(id))).getSingle();
    expect(jsonDecode(a.questionIdsJson), ['c1']);
    expect((await config(id)).containsKey('sections'), isFalse);
  });

  group('section header in the CBT screen', () {
    setUp(() async {
      const ids = ['q1', 'q2', 'q3', 'q4'];
      for (final id in ids) {
        await db
            .into(db.cachedQuestions)
            .insert(
              CachedQuestionsCompanion.insert(
                id: id,
                examId: 1,
                subjectId: 10,
                year: 2020,
                body: 'Text $id',
                optionsJson: '{"A":"Alpha","B":"Bravo"}',
                answer: 'B',
              ),
            );
      }
      await db
          .into(db.localAttempts)
          .insert(
            LocalAttemptsCompanion.insert(
              id: 'att1',
              examId: 1,
              examCode: 'JAMB',
              mode: 'subject',
              configJson: jsonEncode({
                'title': 'JAMB English',
                'sections': {
                  '10': [
                    {'key': 'antonyms', 'label': 'Antonyms', 'instruction': 'Choose the option opposite in meaning.', 'start': 0, 'count': 2},
                    {'key': 'synonyms', 'label': 'Synonyms', 'instruction': 'Choose the option nearest in meaning.', 'start': 2, 'count': 1},
                    {'key': 'more', 'label': 'More', 'instruction': '', 'start': 3, 'count': 1},
                  ],
                },
              }),
              questionIdsJson: jsonEncode(ids),
              limitSeconds: 600,
              startedAt: DateTime.now(),
            ),
          );
    });

    testWidgets('shows the instruction above the first question of each section and none for "more"', (t) async {
      await t.runAsync(() async {
        await t.pumpWidget(
          app(
            const CbtScreen(attemptId: 'att1'),
            overrides: [
              dbProvider.overrideWithValue(db),
              subjectsProvider.overrideWith(
                (_) async => [
                  {'id': 10, 'code': 'eng', 'name': 'Use of English'},
                ],
              ),
              testsRepoProvider.overrideWith((ref) => OfflineRepo(ref)),
              profileProvider.overrideWith((_) async => {'full_name': 'Ada Obi'}),
            ],
          ),
        );
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await t.pump();
        }
      });
      await t.pump(const Duration(milliseconds: 500));
      Future<void> next() async {
        await t.tap(find.text('Next'));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await t.pump(const Duration(milliseconds: 400));
      }

      expect(find.text('Section 1 of 2 · Antonyms'), findsOneWidget);
      expect(find.text('Choose the option opposite in meaning.'), findsOneWidget);
      await next(); // q2: same section, no repeat of the card
      expect(find.text('Text q2'), findsOneWidget);
      expect(find.byType(SectionCard), findsNothing);
      await next(); // q3: new section
      expect(find.text('Section 2 of 2 · Synonyms'), findsOneWidget);
      expect(find.text('Choose the option nearest in meaning.'), findsOneWidget);
      await next(); // q4: "more", no instruction
      expect(find.text('Text q4'), findsOneWidget);
      expect(find.byType(SectionCard), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    });
  });
}
