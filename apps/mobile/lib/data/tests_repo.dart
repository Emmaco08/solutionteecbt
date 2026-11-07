import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:drift/drift.dart' show InsertMode, Value, BooleanExpressionOperators;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/api.dart';
import '../core/providers.dart';
import '../features/cbt/scoring.dart';
import 'db.dart';
import 'paper_sections.dart';

enum TestMode { full, subject, year, quick, topic }

/// What the student chose on the Test setup screen.
class TestRequest {
  const TestRequest({
    required this.mode,
    required this.examId,
    required this.examCode,
    required this.subjectIds,
    this.year,
    this.topics = const [],
    this.count = 20,
    this.limitMinutes,
    this.timed = true,
    this.title = '',
    this.ids = const [],
    this.years = const [],
  });
  final TestMode mode;
  final int examId;
  final String examCode;
  final List<int> subjectIds; // full JAMB: English + 3; quick: the student's subjects (mixed)
  final int? year; // null = pick an open year for each subject
  final List<String> topics; // topic drill
  final int count; // topic drill / quick test size
  final int? limitMinutes; // fixed time (quick, topic); otherwise minutes per question
  final bool timed;
  final String title;

  /// Exact questions picked by the AI tutor (server order). When set, the test is built from these only.
  final List<String> ids;

  /// The years the AI tutor's [ids] come from.
  final List<int> years;
}

final testsRepoProvider = Provider<TestsRepo>((ref) => TestsRepo(ref));

class TestsRepo {
  TestsRepo(this.ref);
  final Ref ref;
  AppDb get _db => ref.read(dbProvider);
  SupabaseClient get _sb => ref.read(supabaseProvider);
  final _rnd = Random();

  /// Fetches one paper (exam + subject + year) through the server's plan check and caches it.
  /// [mode] is 'cbt' (tests) or 'pq' (Study: past questions with answers); each has its own year rule.
  /// Falls back to the cache when offline. Throws a friendly [ApiError] when locked.
  Future<List<CachedQuestion>> paper(int examId, int subjectId, int year, {String mode = 'cbt'}) async {
    try {
      final all = <Map<String, dynamic>>[];
      for (var offset = 0; offset < 500; offset += 100) {
        final page =
            await _sb
                    .rpc(
                      'fetch_questions',
                      params: {'p_exam': examId, 'p_subject': subjectId, 'p_year': year, 'p_mode': mode, 'p_limit': 100, 'p_offset': offset},
                    )
                    .timeout(const Duration(seconds: 20))
                as List;
        all.addAll(page.map((e) => Map<String, dynamic>.from(e as Map)));
        if (page.length < 100) break;
      }
      await _db.batch((b) {
        for (final q in all) {
          b.insert(
            _db.cachedQuestions,
            CachedQuestionsCompanion.insert(
              id: q['id'] as String,
              examId: examId,
              subjectId: subjectId,
              year: year,
              number: Value((q['number'] as num?)?.toInt()),
              body: q['body'] as String,
              optionsJson: jsonEncode(q['options']),
              answer: q['answer'] as String,
              explanation: Value(q['explanation'] as String?),
              topic: Value(q['topic'] as String?),
              imagePath: Value(q['image_path'] as String?),
              passageId: Value(q['passage_id'] as String?),
              passageTitle: Value(q['passage_title'] as String?),
              passageBody: Value(q['passage_body'] as String?),
              fetchedAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
      return [for (final q in all) _fromMap(q, examId, subjectId, year)];
    } on PostgrestException catch (e) {
      if (e.message == 'locked') throw ApiError('This year is part of Premium.', status: 402);
      if (e.message == 'rate_limited') throw ApiError('You have opened many questions in the last hour. Please try again a bit later.');
      if (e.message == 'banned') throw ApiError('This account has been suspended. Contact support.');
      if (e.message == 'not_found') throw ApiError('These questions are not available yet.');
      throw ApiError('Could not load the questions. Try again.');
    } catch (e) {
      if (e is ApiError) rethrow;
      // Offline: use what we downloaded before.
      final cachedRows = await (_db.select(
        _db.cachedQuestions,
      )..where((q) => q.examId.equals(examId) & q.subjectId.equals(subjectId) & q.year.equals(year))).get();
      if (cachedRows.isNotEmpty) return cachedRows;
      throw ApiError('You are offline and this paper is not on your phone yet. Connect once to download it.');
    }
  }

  CachedQuestion _fromMap(Map<String, dynamic> q, int examId, int subjectId, int year) => CachedQuestion(
    id: q['id'] as String,
    examId: examId,
    subjectId: subjectId,
    year: year,
    number: (q['number'] as num?)?.toInt(),
    body: q['body'] as String,
    optionsJson: jsonEncode(q['options']),
    answer: q['answer'] as String,
    explanation: q['explanation'] as String?,
    topic: q['topic'] as String?,
    imagePath: q['image_path'] as String?,
    passageId: q['passage_id'] as String?,
    passageTitle: q['passage_title'] as String?,
    passageBody: q['passage_body'] as String?,
    fetchedAt: DateTime.now(),
  );

  /// Open (published + allowed) years for a subject, newest first.
  Future<List<int>> openYears(int examId, int subjectId) async {
    final years = await ref.read(openYearsProvider.future);
    return [
      for (final y in years)
        if (y['exam_id'] == examId && y['subject_id'] == subjectId && y['cbt_open'] == true) (y['year'] as num).toInt(),
    ]..sort((a, b) => b.compareTo(a));
  }

  /// Keeps questions that share a passage next to each other (in the order the passage first appears).
  static List<CachedQuestion> groupPassages(List<CachedQuestion> qs) {
    final out = <CachedQuestion>[];
    final seen = <String>{};
    for (final q in qs) {
      final p = q.passageId;
      if (p == null) {
        out.add(q);
      } else if (seen.add(p)) {
        out.addAll(qs.where((x) => x.passageId == p));
      }
    }
    return out;
  }

  /// Keeps only the questions whose id is in [ids], in the server's order (first copy of each id), with passage groups together.
  static List<CachedQuestion> pickByIds(Iterable<CachedQuestion> pool, List<String> ids) {
    final order = {for (final (i, id) in ids.indexed) id: i};
    final seen = <String>{};
    final kept = [
      for (final q in pool)
        if (order.containsKey(q.id) && seen.add(q.id)) q,
    ]..sort((a, b) => order[a.id]!.compareTo(order[b.id]!));
    return groupPassages(kept);
  }

  /// Server call: the ordered question ids of one complete JAMB paper. Overridable in tests.
  @visibleForTesting
  Future<Map<String, dynamic>> rpcPaper(Map<String, dynamic> params) async {
    final res = await _sb.rpc('cbt_paper', params: params).timeout(const Duration(seconds: 20));
    return Map<String, dynamic>.from(res as Map);
  }

  /// Server call: exactly these questions (max 200). Overridable in tests.
  @visibleForTesting
  Future<List<Map<String, dynamic>>> rpcByIds(List<String> ids) async {
    final res = await _sb.rpc('fetch_questions_by_ids', params: {'p_ids': ids}).timeout(const Duration(seconds: 20)) as List;
    return [for (final e in res) Map<String, dynamic>.from(e as Map)];
  }

  /// Builds one subject's part of a JAMB test on the server (complete paper, English sections).
  /// Returns null when the server cannot be reached, so the caller can use the local logic.
  /// [offset] is where this subject's questions start in the whole attempt.
  Future<({List<CachedQuestion> questions, List<PaperSection> sections})?> _serverPaper(
    TestRequest r,
    int sid, {
    required int? year,
    required int? count,
    required int offset,
  }) async {
    final Map<String, dynamic> res;
    try {
      res = await rpcPaper({'p_exam': r.examId, 'p_subject': sid, 'p_year': year, 'p_count': count});
    } on PostgrestException catch (e) {
      if (e.message == 'locked') throw ApiError('This year is part of Premium.', status: 402);
      if (e.message == 'banned') throw ApiError('This account has been suspended. Contact support.');
      return null;
    } catch (_) {
      return null;
    }
    if (res['ok'] != true) {
      switch (res['why']) {
        case 'locked':
          throw ApiError('This year is part of Premium.', status: 402);
        case 'no_open_years':
          throw ApiError('No open years for this subject yet.');
        case 'login':
          throw ApiError('Please log in again to start this test.');
        default:
          return null;
      }
    }
    final ids = [for (final x in (res['ids'] as List? ?? const [])) '$x'];
    if (ids.isEmpty) return null;

    // Download only what is not on the phone yet.
    final cached = {for (final q in await _db.questionsByIds(ids)) q.id: q};
    final missing = [
      for (final id in ids)
        if (!cached.containsKey(id)) id,
    ];
    try {
      for (var i = 0; i < missing.length; i += 200) {
        final rows = await rpcByIds(missing.sublist(i, min(i + 200, missing.length)));
        final fresh = [for (final q in rows) _fromMap(q, r.examId, sid, (q['year'] as num?)?.toInt() ?? 0)];
        await _db.batch((b) {
          for (final q in fresh) {
            b.insert(
              _db.cachedQuestions,
              CachedQuestionsCompanion.insert(
                id: q.id,
                examId: q.examId,
                subjectId: q.subjectId,
                year: q.year,
                number: Value(q.number),
                body: q.body,
                optionsJson: q.optionsJson,
                answer: q.answer,
                explanation: Value(q.explanation),
                topic: Value(q.topic),
                imagePath: Value(q.imagePath),
                passageId: Value(q.passageId),
                passageTitle: Value(q.passageTitle),
                passageBody: Value(q.passageBody),
                fetchedAt: Value(DateTime.now()),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        });
        for (final q in fresh) {
          cached[q.id] = q;
        }
      }
    } on PostgrestException catch (e) {
      if (e.message == 'locked') throw ApiError('This year is part of Premium.', status: 402);
      return null;
    } catch (_) {
      return null;
    }
    final questions = [
      for (final id in ids)
        if (cached[id] != null) cached[id]!,
    ];
    if (questions.length != ids.length) return null; // incomplete download: use the local logic
    final sections = [
      for (final s in (res['sections'] as List? ?? const []))
        if (s is Map)
          PaperSection(
            subjectId: sid,
            key: '${s['key'] ?? ''}',
            label: '${s['label'] ?? ''}',
            instruction: '${s['instruction'] ?? ''}',
            start: ((s['start'] as num?)?.toInt() ?? 0) + offset,
            count: (s['count'] as num?)?.toInt() ?? 0,
          ),
    ];
    return (questions: questions, sections: sections);
  }

  /// Builds a test, saves it on the phone (so it can be resumed) and returns its id.
  Future<String> start(TestRequest r, {required int Function(int subjectId) countFor, required double minutesPerQuestion}) async {
    final picked = <CachedQuestion>[];
    final sectionsBySubject = <String, List<Map<String, dynamic>>>{};
    for (final (si, sid) in r.subjectIds.indexed) {
      if (r.ids.isNotEmpty) {
        // AI tutor test: fetch each year's paper through the plan check and keep only the questions the tutor picked.
        final pool = <CachedQuestion>[];
        for (final y in r.years.isNotEmpty ? r.years : await openYears(r.examId, sid)) {
          pool.addAll(await paper(r.examId, sid, y));
        }
        picked.addAll(pickByIds(pool, r.ids));
        continue;
      }
      if (r.examCode == 'JAMB' && const [TestMode.full, TestMode.subject, TestMode.year, TestMode.quick].contains(r.mode)) {
        // Complete paper built on the server (English follows the JAMB sections). Null = offline: use the local logic below.
        final share = r.count ~/ r.subjectIds.length + (si < r.count % r.subjectIds.length ? 1 : 0);
        final srv = await _serverPaper(
          r,
          sid,
          year: r.mode == TestMode.quick ? null : r.year,
          count: switch (r.mode) {
            TestMode.year => null,
            TestMode.quick => share,
            _ => countFor(sid),
          },
          offset: picked.length,
        );
        if (srv != null) {
          picked.addAll(srv.questions);
          if (srv.sections.isNotEmpty) sectionsBySubject['$sid'] = [for (final s in srv.sections) s.toJson()];
          continue;
        }
      }
      final years = r.year != null ? [r.year!] : await openYears(r.examId, sid);
      if (years.isEmpty) throw ApiError('No open years for this subject yet.');
      List<CachedQuestion> pool;
      switch (r.mode) {
        case TestMode.full:
        case TestMode.subject:
        case TestMode.year:
          // A real past paper: one year per subject (random open year unless chosen).
          final y = r.year ?? years[_rnd.nextInt(years.length)];
          pool = await paper(r.examId, sid, y);
          pool.sort((a, b) => (a.number ?? 999).compareTo(b.number ?? 999));
          if (r.mode != TestMode.year) pool = pool.take(countFor(sid)).toList();
        case TestMode.quick:
          // An even share from each subject (the first subjects take any remainder), from a random open year.
          // Subjects stay in order, like a real exam: finish one subject, then the next.
          final y = years[_rnd.nextInt(years.length)];
          final share = r.count ~/ r.subjectIds.length + (si < r.count % r.subjectIds.length ? 1 : 0);
          pool = groupPassages((await paper(r.examId, sid, y))..shuffle(_rnd)).take(share).toList();
        case TestMode.topic:
          pool = [];
          for (final y in r.year != null ? [r.year!] : years) {
            pool.addAll((await paper(r.examId, sid, y)).where((q) => r.topics.contains(q.topic)));
            if (pool.length >= r.count * 2) break;
          }
          pool = (pool..shuffle(_rnd)).take(r.count).toList();
      }
      picked.addAll(pool);
    }
    if (picked.isEmpty) {
      throw ApiError(r.mode == TestMode.topic ? 'No questions for these topics yet. Try other topics.' : 'No questions found for this choice yet.');
    }

    // Keep passage groups together in the order shown.
    final ids = [for (final q in picked) q.id];
    final limit = !r.timed ? 0 : (r.limitMinutes != null ? r.limitMinutes! * 60 : (picked.length * minutesPerQuestion * 60).round());
    final id = const Uuid().v4();
    await _db
        .into(_db.localAttempts)
        .insert(
          LocalAttemptsCompanion.insert(
            id: id,
            examId: r.examId,
            examCode: r.examCode,
            mode: r.mode.name,
            configJson: jsonEncode({
              'subjects': r.subjectIds,
              'year': r.year,
              'topics': r.topics,
              'timed': r.timed,
              'title': r.title,
              if (sectionsBySubject.isNotEmpty) 'sections': sectionsBySubject,
            }),
            questionIdsJson: jsonEncode(ids),
            limitSeconds: limit,
            startedAt: DateTime.now(),
          ),
        );
    // Only one unfinished test at a time: the old one is submitted as it is, so its score still counts
    // (prototype test-setup). One with no answers is simply removed.
    final others = await (_db.select(_db.localAttempts)..where((a) => a.submittedAt.isNull() & a.id.equals(id).not())).get();
    for (final o in others) {
      final answered = (await _db.answersFor(o.id)).any((x) => x.choice != null);
      if (answered) {
        await submit(o.id, usedMs: o.usedMs);
      } else {
        await (_db.delete(_db.localAttempts)..where((a) => a.id.equals(o.id))).go();
      }
    }
    return id;
  }

  /// Marks the test on the phone (instant), saves it, then tries to sync so the server re-marks it.
  Future<AttemptScore> submit(String attemptId, {required int usedMs}) async {
    final a = await (_db.select(_db.localAttempts)..where((x) => x.id.equals(attemptId))).getSingle();
    final ids = (jsonDecode(a.questionIdsJson) as List).cast<String>();
    final qs = await _db.questionsByIds(ids);
    final answers = {
      for (final x in await _db.answersFor(attemptId))
        if (x.choice != null) x.questionId: x.choice!,
    };
    final score = scoreAttempt([for (final q in qs) QuestionKey(id: q.id, subjectId: q.subjectId, answer: q.answer, topic: q.topic)], answers);
    await (_db.update(_db.localAttempts)..where((x) => x.id.equals(attemptId))).write(
      LocalAttemptsCompanion(submittedAt: Value(DateTime.now()), usedMs: Value(usedMs), clientScoreJson: Value(jsonEncode(score.toJson()))),
    );
    await syncPending();
    return score;
  }

  /// Sends finished tests to the server (re-marked there). Safe to call any time; repeats are idempotent.
  Future<int> syncPending() async {
    var done = 0;
    for (final a in await _db.unsyncedAttempts()) {
      final answers = await _db.answersFor(a.id);
      try {
        final server = await _sb
            .rpc(
              'submit_attempt',
              params: {
                'p': {
                  'id': a.id,
                  'exam_id': a.examId,
                  'mode': a.mode,
                  'config': jsonDecode(a.configJson),
                  'question_ids': jsonDecode(a.questionIdsJson),
                  'started_at': a.startedAt.toUtc().toIso8601String(),
                  'submitted_at': a.submittedAt!.toUtc().toIso8601String(),
                  'time_used_s': (a.usedMs / 1000).round(),
                  'client_score': a.clientScoreJson == null ? null : jsonDecode(a.clientScoreJson!),
                  'answers': [
                    for (final x in answers) {'q': x.questionId, 'c': x.choice, 'f': x.flagged, 't': x.timeMs},
                  ],
                },
              },
            )
            .timeout(const Duration(seconds: 20));
        await (_db.update(
          _db.localAttempts,
        )..where((x) => x.id.equals(a.id))).write(LocalAttemptsCompanion(synced: const Value(true), serverScoreJson: Value(jsonEncode(server))));
        done++;
      } catch (_) {
        // Offline or temporarily failing: try again later.
      }
    }
    return done;
  }
}
