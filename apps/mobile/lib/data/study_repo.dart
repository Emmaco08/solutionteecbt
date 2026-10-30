import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';
import '../core/providers.dart';

/// Study content (D-053). The server decides what is open: `study_catalog` lists items with a lock flag and
/// no content, `study_item` returns the content only when the student's plan allows it, and file links come
/// from the website after the same check. Nothing here unlocks anything on the phone.
final studyRepoProvider = Provider<StudyRepo>((ref) => StudyRepo(ref));

/// Items of one kind (video_solution, lesson, note, novel, doc) for this student, with `locked`.
final studyCatalogProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, kind) {
  ref.watch(myPlanProvider);
  return ref.read(studyRepoProvider).catalog(kind);
});

/// One item's content. Throws [ApiError] with status 402 when it is Premium.
final studyItemProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) => ref.read(studyRepoProvider).item(id));

final bookmarksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const [];
  return cached(
    ref,
    'bookmarks:$uid',
    (s) => s.from('bookmarks').select('kind, ref, label, created_at').order('created_at', ascending: false).limit(500),
    rows,
  );
});

/// Recently opened study items (newest first) for "Continue learning".
final studyProgressProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const [];
  return cached(
    ref,
    'study_progress:$uid',
    (s) => s.from('study_progress').select('item_id, progress, position, updated_at').order('updated_at', ascending: false).limit(20),
    rows,
  );
});

/// The admin's Free vs Premium rules (public), e.g. {'free': {'videos': false, …}, 'premium': {…}}.
final accessRulesProvider = FutureProvider<Map<String, Map<String, dynamic>>>(
  (ref) => cached(
    ref,
    'access_rules',
    (s) => s.from('access_rules').select('tier, rules'),
    (j) => {for (final r in rows(j)) r['tier'] as String: Map<String, dynamic>.from(r['rules'] as Map)},
  ),
);

/// Premium plans with prices (SAMPLE until the owner confirms).
final plansProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => cached(
    ref,
    'plans',
    (s) => s.from('plans').select('id, code, name, description, price_kobo, duration_days, ends_on, sort').eq('is_active', true).order('sort', ascending: true),
    rows,
  ),
);

/// The rules for this student's tier (Free when unknown).
Map<String, dynamic> myRules(WidgetRef ref) {
  final tier = ref.watch(myPlanProvider).value?['tier'] == 'premium' ? 'premium' : 'free';
  return ref.watch(accessRulesProvider).value?[tier] ?? const {};
}

/// Whether a study feature (videos, lessons, notes, novels, syllabus, offline) is on for this student's plan.
/// Only used to draw locks; the server still checks every item.
bool featureOn(WidgetRef ref, String feature) {
  final v = myRules(ref)[feature];
  return v == true || v == 'all' || (v is num && v > 0);
}

const studyFeature = {'video_solution': 'videos', 'lesson': 'lessons', 'note': 'notes', 'novel': 'novels', 'doc': 'syllabus'};

class StudyRepo {
  StudyRepo(this.ref);
  final Ref ref;
  SupabaseClient get _sb => ref.read(supabaseProvider);
  String get _uid => _sb.auth.currentUser?.id ?? 'anon';

  Future<List<Map<String, dynamic>>> catalog(String kind) => cached(ref, 'study:$kind:$_uid', (s) => s.rpc('study_catalog', params: {'p_kind': kind}), rows);

  /// The cache is used only when the server cannot be reached. When the server answers "locked" (for
  /// example after Premium ends) the phone's old copy is deleted, never shown.
  Future<Map<String, dynamic>> item(String id) async {
    final db = ref.read(dbProvider);
    final key = 'study_item:$id:$_uid';
    try {
      final j = await _sb.rpc('study_item', params: {'p_id': id}).timeout(const Duration(seconds: 15));
      await db.kvSet(key, jsonEncode(j));
      return Map<String, dynamic>.from(j as Map);
    } on PostgrestException catch (e) {
      await db.kvDelete(key);
      if (e.message == 'locked') throw ApiError('This is part of Premium.', status: 402);
      if (e.message == 'not_found') throw ApiError('This is no longer available.', status: 404);
      throw ApiError('Could not load this. Try again.');
    } catch (_) {
      final old = await db.kvGet(key);
      if (old != null) return Map<String, dynamic>.from(jsonDecode(old) as Map);
      throw ApiError('You are offline and this is not on your phone yet.');
    }
  }

  /// A signed link for a file of an item (the website checks the plan first).
  Future<String> fileUrl(String id, String file) async {
    try {
      return await ref.read(apiProvider).studyFile(id, file);
    } on ApiError catch (e) {
      if (e.status == 403) throw ApiError('This is part of Premium.', status: 402);
      rethrow;
    }
  }

  // ------------------------------------------------------------ bookmarks
  Future<bool> toggleBookmark({required String kind, required String refId, required String label}) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) throw ApiError('Please log in again.', status: 401);
    final list = await ref.read(bookmarksProvider.future);
    final on = list.any((b) => b['kind'] == kind && b['ref'] == refId);
    try {
      if (on) {
        await _sb.from('bookmarks').delete().match({'user_id': uid, 'kind': kind, 'ref': refId});
      } else {
        await _sb.from('bookmarks').upsert({'user_id': uid, 'kind': kind, 'ref': refId, 'label': label});
      }
    } catch (_) {
      throw ApiError('Could not save the bookmark. Check your internet and try again.');
    }
    ref.invalidate(bookmarksProvider);
    return !on;
  }

  Future<void> removeBookmark(String kind, String refId) async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    await _sb.from('bookmarks').delete().match({'user_id': uid, 'kind': kind, 'ref': refId});
    ref.invalidate(bookmarksProvider);
  }

  // ------------------------------------------------------------ progress
  /// Saves how far the student got (0–1) plus what "Continue learning" needs to show the row.
  /// Best-effort: a failed save never interrupts reading or watching.
  Future<void> saveProgress(Map<String, dynamic> item, double progress, {Map<String, Object?> position = const {}}) async {
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) return;
      await _sb.from('study_progress').upsert({
        'user_id': uid,
        'item_id': item['id'],
        'progress': double.parse(progress.clamp(0, 1).toStringAsFixed(3)),
        'position': {'kind': item['kind'], 'title': item['title'], 'subject_id': item['subject_id'], ...position},
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      ref.invalidate(studyProgressProvider);
    } catch (_) {}
  }
}

/// The first row that matches, or an empty map (safe for any list of rows).
Map<String, dynamic> firstOr(Iterable<Map<String, dynamic>>? rows, bool Function(Map<String, dynamic>) test, {bool fallbackFirst = false}) {
  if (rows == null) return {};
  for (final r in rows) {
    if (test(r)) return r;
  }
  return fallbackFirst && rows.isNotEmpty ? rows.first : {};
}

/// "6:12" from seconds.
String clock(num? s) {
  if (s == null) return '';
  final t = s.round();
  return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
}

/// "18 MB" from bytes.
String megabytes(num? b) => b == null ? '' : '${(b / 1024 / 1024).toStringAsFixed(b > 10 * 1024 * 1024 ? 0 : 1)} MB';
