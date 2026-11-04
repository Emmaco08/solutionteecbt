import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';

export '../../core/device.dart' show DeviceCheck, DeviceIds;

/// Challenges & events (milestone 4E2, D-028 to D-030, D-070). The server sends one question at a time, marks and
/// times every answer, counts exits and ranks. The phone only shows what it is given.

/// "₦20,000" from whole naira.
String nairaWhole(num n) {
  final s = n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '₦$s';
}

/// "3:12" from milliseconds.
String mmss(num ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// "2h 05m", "3d 4h", "12m" until [t].
String untilShort(DateTime t, {DateTime? now}) {
  final s = t.difference(now ?? DateTime.now()).inSeconds.clamp(0, 1 << 31);
  final d = s ~/ 86400, h = s % 86400 ~/ 3600, m = s % 3600 ~/ 60;
  if (d > 0) return '${d}d ${h}h';
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${m}m';
}

/// Friendly text for a server error.
String challengeError(Object e) {
  if (e is PostgrestException && e.message.isNotEmpty && e.code != '42501') return e.message;
  return 'Something went wrong. Check your internet and try again.';
}

class Challenge {
  Challenge(this.j);
  final Map<String, dynamic> j;
  String get id => '${j['id']}';
  String get title => '${j['title']}';
  String? get subtitle => j['subtitle'] as String?;
  String get kind => '${j['kind']}';
  String get icon => '${j['icon'] ?? 'trophy'}';
  String? get exam => j['exam'] as String?;
  String get status => '${j['status']}';
  DateTime get startsAt => DateTime.parse('${j['starts_at']}').toLocal();
  DateTime get endsAt => DateTime.parse('${j['ends_at']}').toLocal();
  int get questions => (j['questions'] as num?)?.toInt() ?? 0;
  int get seconds => (j['seconds'] as num?)?.toInt() ?? 30;
  List<int> get prizes => [for (final p in (j['prizes'] as List? ?? const [])) (p as num).toInt()];
  String? get reward => j['reward'] as String?;
  int get joined => (j['joined'] as num?)?.toInt() ?? 0;
  int get allowedExits => (j['allowed_exits'] as num?)?.toInt() ?? 0;
  Map<String, dynamic>? get mine => j['mine'] is Map ? Map<String, dynamic>.from(j['mine'] as Map) : null;
  bool get live => status == 'live';
  bool get upcoming => status == 'upcoming';
  bool get ended => status == 'ended';
  List<Map<String, dynamic>> get winners => rows(j['winners']);

  /// 'fixed' (same questions for all), 'mixed' (the student's JAMB subjects) or 'subject' (one subject) — D-073.
  String get mode => '${j['mode'] ?? 'fixed'}';
  String? get subject => j['subject'] as String?;
  bool get eligible => j['eligible'] != false;
  bool get sameQuestions => j['same_questions'] == true;

  /// XP entry fee (0 = free). Cash-prize challenges take earned XP only (D-081, D-083).
  int get xpFee => (j['xp_fee'] as num?)?.toInt() ?? 0;
  bool get xpEarnedOnly => j['xp_earned_only'] == true;

  /// The admin lets students use the calculator in this challenge (D-085).
  bool get calculator => j['calculator'] == true;

  /// "Free to join" or "100 XP to join".
  String get entryText => xpFee > 0 ? '$xpFee XP to join' : 'Free to join';

  /// Questions per subject at each level, easiest first, skipping zeros: [('Easy', 3), ('Hard', 2)].
  List<(String, int)> get perLevel {
    final m = j['per_level'] is Map ? Map<String, dynamic>.from(j['per_level'] as Map) : const <String, dynamic>{};
    return [
      for (final (k, l) in const [('easy', 'Easy'), ('medium', 'Medium'), ('hard', 'Hard'), ('very_hard', 'Very hard')])
        if (((m[k] as num?) ?? 0) > 0) (l, (m[k] as num).toInt()),
    ];
  }

  /// One line on whose questions these are.
  String get modeText => switch (mode) {
    'mixed' =>
      sameQuestions
          ? 'Questions from your 4 JAMB subjects, mixed. Everyone who takes a subject gets the same questions, in a different order.'
          : 'Questions from your 4 JAMB subjects, mixed.',
    'subject' =>
      sameQuestions
          ? 'Only for students who take ${subject ?? 'this subject'}. Everyone gets the same questions, in a different order.'
          : 'Only for students who take ${subject ?? 'this subject'}.',
    _ => 'Everyone answers the same questions, shuffled.',
  };

  /// Why this student cannot take it (null = they can).
  String? get ineligibleText => eligible
      ? null
      : mode == 'subject'
      ? 'This challenge is only for students who take ${subject ?? 'this subject'}. Add it to your JAMB subjects to join.'
      : 'Choose your JAMB subjects first, so we can pick your questions.';

  /// "₦20,000 first prize", the reward text, or practice.
  String get rewardText => prizes.isNotEmpty ? '${nairaWhole(prizes.first)} first prize' : (reward ?? 'No prize, just for practice');
  String get rule => kind == 'practice'
      ? 'No winners. See how you rank against other students.'
      : 'Best score wins. Same score: the fastest time wins. Same score and same time: the student who started earlier wins.';
}

final challengesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const {'on': false};
  return cached(ref, 'challenges:$uid', (s) => s.rpc('challenges_list'), (j) => Map<String, dynamic>.from(j as Map));
});

final challengeProvider = FutureProvider.autoDispose.family<Challenge, String>((ref, id) async {
  final j = await ref.read(supabaseProvider).rpc('challenge_detail', params: {'p_id': id}).timeout(const Duration(seconds: 15));
  return Challenge(Map<String, dynamic>.from(j as Map));
});

final challengeResultProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final j = await ref.read(supabaseProvider).rpc('challenge_result', params: {'p_id': id}).timeout(const Duration(seconds: 15));
  return Map<String, dynamic>.from(j as Map);
});

/// The student's own answers, after the challenge has ended (D-074).
final challengeReviewProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final j = await ref.read(supabaseProvider).rpc('challenge_review', params: {'p_id': id}).timeout(const Duration(seconds: 15));
  return Map<String, dynamic>.from(j as Map);
});

/// "Very hard" from 'very_hard'.
String levelName(String k) => const {'easy': 'Easy', 'medium': 'Medium', 'hard': 'Hard', 'very_hard': 'Very hard'}[k] ?? '';

final winningsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final j = await ref.read(supabaseProvider).rpc('my_winnings').timeout(const Duration(seconds: 15));
  return Map<String, dynamic>.from(j as Map);
});

final winnersWallProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return cached(ref, 'winners_wall', (s) => s.rpc('winners_wall_list'), (j) => Map<String, dynamic>.from(j as Map));
});
