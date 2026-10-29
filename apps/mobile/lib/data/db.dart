import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'db.g.dart';

/// Questions downloaded for a test (only Free/opened questions the server allowed). Kept for offline use and review.
class CachedQuestions extends Table {
  TextColumn get id => text()();
  IntColumn get examId => integer()();
  IntColumn get subjectId => integer()();
  IntColumn get year => integer()();
  IntColumn get number => integer().nullable()();
  TextColumn get body => text()();
  TextColumn get optionsJson => text()(); // {"A": "...", ...}
  TextColumn get answer => text()();
  TextColumn get explanation => text().nullable()();
  TextColumn get topic => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get passageId => text().nullable()();
  TextColumn get passageTitle => text().nullable()();
  TextColumn get passageBody => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

/// One test. Saved as soon as it starts, so it survives the app being killed or the phone restarting.
class LocalAttempts extends Table {
  TextColumn get id => text()(); // UUID v4, also the server id
  IntColumn get examId => integer()();
  TextColumn get examCode => text()();
  TextColumn get mode => text()(); // full | subject | year | quick | topic
  TextColumn get configJson => text()(); // subjects, years, timed, title
  TextColumn get questionIdsJson => text()(); // order shown to the student
  IntColumn get limitSeconds => integer()(); // 0 = untimed
  IntColumn get usedMs => integer().withDefault(const Constant(0))();
  IntColumn get currentIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get submittedAt => dateTime().nullable()();
  TextColumn get clientScoreJson => text().nullable()();
  TextColumn get serverScoreJson => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class LocalAnswers extends Table {
  TextColumn get attemptId => text().references(LocalAttempts, #id, onDelete: KeyAction.cascade)();
  TextColumn get questionId => text()();
  TextColumn get choice => text().nullable()();
  BoolColumn get flagged => boolean().withDefault(const Constant(false))();
  IntColumn get timeMs => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {attemptId, questionId};
}

/// Small key/value cache for server-driven config (tabs, onboarding, settings) so the app opens offline.
class KvCache extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [CachedQuestions, LocalAttempts, LocalAnswers, KvCache])
class AppDb extends _$AppDb {
  AppDb([QueryExecutor? e]) : super(e ?? driftDatabase(name: 'solutiontee'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (d) async => customStatement('PRAGMA foreign_keys = ON'),
      );

  // ---- key/value
  Future<String?> kvGet(String key) async => (await (select(kvCache)..where((t) => t.key.equals(key))).getSingleOrNull())?.value;
  Future<void> kvSet(String key, String value) =>
      into(kvCache).insertOnConflictUpdate(KvCacheCompanion.insert(key: key, value: value, updatedAt: Value(DateTime.now())));

  // ---- attempts
  Future<LocalAttempt?> unfinishedAttempt() => (select(localAttempts)
        ..where((a) => a.submittedAt.isNull())
        ..orderBy([(a) => OrderingTerm.desc(a.startedAt)])
        ..limit(1))
      .getSingleOrNull();

  Future<List<LocalAttempt>> finishedAttempts() =>
      (select(localAttempts)..where((a) => a.submittedAt.isNotNull())..orderBy([(a) => OrderingTerm.desc(a.submittedAt)])).get();

  Future<List<LocalAttempt>> unsyncedAttempts() =>
      (select(localAttempts)..where((a) => a.submittedAt.isNotNull() & a.synced.equals(false))).get();

  Future<List<LocalAnswer>> answersFor(String attemptId) => (select(localAnswers)..where((a) => a.attemptId.equals(attemptId))).get();

  Future<void> saveAnswer(String attemptId, String questionId, {String? choice, bool? flagged, int addMs = 0}) async {
    final existing = await (select(localAnswers)..where((a) => a.attemptId.equals(attemptId) & a.questionId.equals(questionId))).getSingleOrNull();
    await into(localAnswers).insertOnConflictUpdate(LocalAnswersCompanion.insert(
      attemptId: attemptId,
      questionId: questionId,
      choice: Value(choice ?? existing?.choice),
      flagged: Value(flagged ?? existing?.flagged ?? false),
      timeMs: Value((existing?.timeMs ?? 0) + addMs),
    ));
  }

  Future<void> clearChoice(String attemptId, String questionId) => (update(localAnswers)
        ..where((a) => a.attemptId.equals(attemptId) & a.questionId.equals(questionId)))
      .write(const LocalAnswersCompanion(choice: Value(null)));

  Future<void> saveProgress(String attemptId, {required int usedMs, required int index}) =>
      (update(localAttempts)..where((a) => a.id.equals(attemptId))).write(LocalAttemptsCompanion(usedMs: Value(usedMs), currentIndex: Value(index)));

  Future<List<CachedQuestion>> questionsByIds(List<String> ids) async {
    final rows = await (select(cachedQuestions)..where((q) => q.id.isIn(ids))).get();
    final byId = {for (final r in rows) r.id: r};
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  /// Removes everything for a signed-out or deleted account.
  Future<void> wipe() => transaction(() async {
        await delete(localAnswers).go();
        await delete(localAttempts).go();
        await delete(cachedQuestions).go();
        await delete(kvCache).go();
      });
}
