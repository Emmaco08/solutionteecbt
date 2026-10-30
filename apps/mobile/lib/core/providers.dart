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

final examsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => cached(
    ref,
    'exams',
    (s) => s.from('exam_bodies').select('id, code, name, sort, exam_configs(*)').eq('is_active', true).order('sort', ascending: true),
    rows,
  ),
);

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
        .select('id, title, summary, body, category, link_type, link_target, is_pinned, publish_at')
        .eq('status', 'published')
        .lte('publish_at', DateTime.now().toUtc().toIso8601String())
        .order('is_pinned', ascending: false)
        .order('publish_at', ascending: false)
        .limit(10),
    rows,
  );
});

/// Published years with lock status for this student (server decides).
final openYearsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(sessionProvider);
  return cached(ref, 'open_years', (s) => s.rpc('my_open_years'), rows);
});

final myPlanProvider = FutureProvider<Map<String, dynamic>>((ref) {
  ref.watch(sessionProvider);
  return cached(ref, 'my_plan', (s) => s.rpc('my_plan'), (j) => Map<String, dynamic>.from(j as Map));
});

final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return null;
  return cached(
    ref,
    'profile',
    (s) => s.from('profiles').select().eq('id', session.user.id).maybeSingle(),
    (j) => j == null ? null : Map<String, dynamic>.from(j as Map),
  );
});
