import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/db.dart';
import 'api.dart';

final dbProvider = Provider<AppDb>((ref) {
  final db = AppDb();
  ref.onDispose(db.close);
  return db;
});

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
final apiProvider = Provider<WebApi>((ref) => WebApi());

/// Current session (null when signed out). Rebuilds on sign-in, sign-out and token refresh.
final sessionProvider = StreamProvider<Session?>((ref) async* {
  final auth = ref.watch(supabaseProvider).auth;
  yield auth.currentSession;
  await for (final e in auth.onAuthStateChange) {
    yield e.session;
  }
});

// ---------------------------------------------------------------- settings (per device)
class AppSettings {
  const AppSettings({this.theme = ThemeMode.system, this.reduceMotion = false, this.dataSaver = false, this.onboarded = false, this.toured = false});
  final ThemeMode theme;
  final bool reduceMotion;
  final bool dataSaver;
  final bool onboarded;
  final bool toured;

  AppSettings copyWith({ThemeMode? theme, bool? reduceMotion, bool? dataSaver, bool? onboarded, bool? toured}) => AppSettings(
    theme: theme ?? this.theme,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    dataSaver: dataSaver ?? this.dataSaver,
    onboarded: onboarded ?? this.onboarded,
    toured: toured ?? this.toured,
  );
  Map<String, Object> toJson() => {'theme': theme.name, 'rm': reduceMotion, 'ds': dataSaver, 'ob': onboarded, 'tour': toured};
  static AppSettings fromJson(Map<String, dynamic> j) => AppSettings(
    theme: ThemeMode.values.firstWhere((m) => m.name == j['theme'], orElse: () => ThemeMode.system),
    reduceMotion: j['rm'] == true,
    dataSaver: j['ds'] == true,
    onboarded: j['ob'] == true,
    toured: j['tour'] == true,
  );
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  Future<void> update(AppSettings Function(AppSettings) f) async {
    state = f(state);
    await ref.read(dbProvider).kvSet('settings', jsonEncode(state.toJson()));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// Settings read from SQLite before the first frame ([loadSettings]); main.dart overrides this.
final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

Future<AppSettings> loadSettings(AppDb db) async {
  final raw = await db.kvGet('settings');
  return raw == null ? const AppSettings() : AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

// ---------------------------------------------------------------- cached server data
/// Fetches from Supabase, caches in SQLite, and falls back to the cache when offline.
Future<T> cached<T>(Ref ref, String key, Future<Object?> Function(SupabaseClient s) fetch, T Function(Object? json) parse) async {
  final db = ref.read(dbProvider);
  try {
    final fresh = await fetch(ref.read(supabaseProvider)).timeout(const Duration(seconds: 15));
    await db.kvSet(key, jsonEncode(fresh));
    return parse(fresh);
  } catch (e) {
    final old = await db.kvGet(key);
    if (old != null) return parse(jsonDecode(old));
    rethrow;
  }
}

List<Map<String, dynamic>> rows(Object? j) => [for (final r in (j as List? ?? const [])) Map<String, dynamic>.from(r as Map)];

/// Admin switches read once per app start from public settings (set in app.dart):
/// cash prizes and cash referral rewards (off until the regulator approves, D-110) and the exam bodies' own logos
/// (off until JAMB, WAEC and NECO give written permission: typographic badges are shown instead, D-111).
bool cashPrizesOn = false;
bool examLogosOn = false;

/// The student turned on personalised ads in Settings (adults only; set in app.dart from the profile).
bool adsConsent = false;

final appSettingsProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => cached(ref, 'app_settings', (s) => s.from('app_settings').select('key, value'), (j) => {for (final r in rows(j)) r['key'] as String: r['value']}),
);

final onboardingProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => cached(
    ref,
    'onboarding',
    (s) => s.from('onboarding_slides').select('title, body, animation, sort').eq('enabled', true).order('sort', ascending: true),
    rows,
  ),
);

final tabsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => cached(
    ref,
    'tabs',
    (s) => s.from('app_tabs').select('key, title, icon, type, sort, premium_only, config').eq('enabled', true).order('sort', ascending: true),
    rows,
  ),
);

/// Uploaded logos of exams the admin added (code → private storage key, D-138). JAMB, WAEC and NECO use the files
/// bundled with the app. Filled each time the exam list loads.
final examLogoKeys = <String, String>{};

final examsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => cached(
    ref,
    'exams',
    (s) => s.from('exam_bodies').select('id, code, name, subtitle, logo_path, sort, exam_configs(*)').eq('is_active', true).order('sort', ascending: true),
    (j) {
      final list = rows(j);
      for (final e in list) {
        final key = '${e['logo_path'] ?? ''}';
        if (key.startsWith('public/exams/')) examLogoKeys['${e['code']}'.toUpperCase()] = key;
      }
      return list;
    },
  ),
);

/// Exams other than JAMB, in the admin's order (WAEC, NECO and any the admin added).
List<Map<String, dynamic>> otherExams(List<Map<String, dynamic>> exams) => [
  for (final e in exams)
    if (e['code'] != 'JAMB') e,
];

final subjectsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => cached(ref, 'subjects', (s) => s.from('subjects').select('id, code, name, sort').order('sort', ascending: true), rows),
);

final examSubjectsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => cached(ref, 'exam_subjects', (s) => s.from('exam_subjects').select('exam_id, subject_id, compulsory, question_count, minutes'), rows),
);

/// Syllabus topics per subject (for topic drills).
final topicsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => cached(ref, 'topics', (s) => s.from('topics').select('id, subject_id, name, sort').order('sort', ascending: true), rows),
);

final newsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(sessionProvider);
  return cached(
    ref,
    'news',
    (s) => s
        .from('news_posts')
        .select('id, title, summary, body, category, link_type, link_target, image_path, is_pinned, publish_at')
        .eq('status', 'published')
        .lte('publish_at', DateTime.now().toUtc().toIso8601String())
        .order('is_pinned', ascending: false)
        .order('publish_at', ascending: false)
        .limit(10),
    rows,
  );
});

/// Published years with lock status for this student (server decides).
/// The signed-in session. The stream's first value arrives a moment after start-up, so fall back to the
/// session Supabase already restored from secure storage (otherwise start-up thinks nobody is logged in).
Session? currentSession(Ref ref) => ref.watch(sessionProvider).value ?? Supabase.instance.client.auth.currentSession;

/// Per-account cache key, so one account's cached data never shows for another on a shared phone.
String _mine(Ref ref, String key) => '$key:${currentSession(ref)?.user.id ?? 'anon'}';

/// Today's Lagos date as YYYY-MM-DD (Nigeria is UTC+1 all year).
String lagosToday() => DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String().substring(0, 10);

/// Questions answered today in tests saved on the server from any phone (the Home daily goal), or null when
/// logged out or unknown (offline with no answer from today). The app adds its own tests not synced yet.
Future<int?> serverPracticeToday(Ref ref) async {
  try {
    if (currentSession(ref) == null) return null;
    final m = await cached(ref, _mine(ref, 'practice_today'), (s) => s.rpc('my_practice_today'), (j) => Map<String, dynamic>.from(j as Map));
    if (m['day'] != lagosToday()) return null; // a cached answer from another day
    return (m['answered'] as num?)?.toInt();
  } catch (_) {
    return null;
  }
}

final openYearsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return cached(ref, _mine(ref, 'open_years'), (s) => s.rpc('my_open_years'), rows);
});

final myPlanProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return cached(ref, _mine(ref, 'my_plan'), (s) => s.rpc('my_plan'), (j) => Map<String, dynamic>.from(j as Map));
});

final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final session = currentSession(ref);
  if (session == null) return null;
  return cached(
    ref,
    'profile:${session.user.id}',
    (s) => s.from('profiles').select().eq('id', session.user.id).maybeSingle(),
    (j) => j == null ? null : Map<String, dynamic>.from(j as Map),
  );
});
