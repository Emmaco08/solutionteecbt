import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show InsertMode, Value, BooleanExpressionOperators;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/api.dart';
import '../core/providers.dart';
import '../features/cbt/scoring.dart';
import 'db.dart';

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
}

final testsRepoProvider = Provider<TestsRepo>((ref) => TestsRepo(ref));

class TestsRepo {
  TestsRepo(this.ref);
  final Ref ref;
  AppDb get _db => ref.read(dbProvider);
  SupabaseClient get _sb => ref.read(supabaseProvider);
  final _rnd = Random();

  /// Fetches one paper (exam + subject + year) through the server's plan check and caches it.
  /// Falls back to the cache when offline. Throws a friendly [ApiError] when locked.
  Future<List<CachedQuestion>> paper(int examId, int subjectId, int year) async {
    try {
      final all = <Map<String, dynamic>>[];
      for (var offset = 0; offset < 500; offset += 100) {
        final page =
            await _sb
                    .rpc(
                      'fetch_questions',
                      params: {'p_exam': examId, 'p_subject': subjectId, 'p_year': year, 'p_mode': 'cbt', 'p_limit': 100, 'p_offset': offset},
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

  /// Builds a test, saves it on the phone (so it can be resumed) and returns its id.
  Future<String> start(TestRequest r, {required int Function(int subjectId) countFor, required double minutesPerQuestion}) async {
    final picked = <CachedQuestion>[];
    for (final sid in r.subjectIds) {
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
          // Mixed: an even share from each subject, from a random open year.
          final y = years[_rnd.nextInt(years.length)];
          pool = (await paper(r.examId, sid, y))..shuffle(_rnd);
          pool = pool.take((r.count / r.subjectIds.length).ceil()).toList();
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
    if (r.mode == TestMode.quick) {
      picked.shuffle(_rnd);
      if (picked.length > r.count) picked.removeRange(r.count, picked.length);
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
            configJson: jsonEncode({'subjects': r.subjectIds, 'year': r.year, 'topics': r.topics, 'timed': r.timed, 'title': r.title}),
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
