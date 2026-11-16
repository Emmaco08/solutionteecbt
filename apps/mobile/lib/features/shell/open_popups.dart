import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engagement.dart';
import '../../core/providers.dart';
import '../home/countdown.dart';
import '../home/whatsapp_channel.dart';
import '../profile/badges.dart';
import '../xp/streak_ui.dart';

/// The pop-ups of one app open (D-082, D-135, D-154, D-174), strictly one after the other: each waits until the one
/// before it is closed, so two never show at once.
///  1. A new student gets the app tour (started by Home): nothing else this open.
///  2. The exam countdown (once a day), new badges, then the milestone or daily claim (once a day); when none of those
///     showed, maybe the rating card or a feature suggestion.
///  3. Last, the WhatsApp channel pop-up, until the student taps Join.
Future<void> runOpenPopups(BuildContext context, WidgetRef ref) async {
  await Engagement.countOpen(ref).catchError((_) {});
  if (!ref.read(settingsProvider).toured || !context.mounted) return;
  await _dailyOnes(context, ref);
  if (context.mounted) await maybeShowWhatsAppPopup(context, ref).catchError((_) => false);
}

Future<void> _dailyOnes(BuildContext context, WidgetRef ref) async {
  final countdown = await maybeShowDailyCountdown(context, ref);
  if (!context.mounted) return;
  await checkBadgeWins(context, ref);
  if (!context.mounted) return;
  try {
    ref.invalidate(myStreakProvider);
    final st = await ref.read(myStreakProvider.future).timeout(const Duration(seconds: 10));
    if (!context.mounted || st.isEmpty) return;
    final cel = st['celebrate'];
    if (cel is Map) {
      await showMilestone(context, ref, Map<String, dynamic>.from(cel));
      return;
    }
    final xp = st['xp'];
    final db = ref.read(dbProvider);
    final now = DateTime.now(), today = '${now.year}-${now.month}-${now.day}';
    if (xp is Map && xp['enabled'] == true && xp['claimed_today'] != true && await db.kvGet('claim_sheet_day') != today && context.mounted) {
      await db.kvSet('claim_sheet_day', today);
      if (context.mounted) await showDailyClaim(context, ref, st);
      return;
    }
  } catch (_) {}
  if (!countdown && context.mounted) await Engagement.maybeShowOne(context, ref).catchError((_) => false);
}
