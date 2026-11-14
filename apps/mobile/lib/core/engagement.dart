import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';

import '../features/gamezone/gz_scenes.dart' show GameIcon;
import '../theme/theme.dart';
import '../theme/tokens.g.dart';
import '../ui/confetti.dart';
import '../ui/kit.dart';
import '../widgets/phosphor.g.dart';
import 'config.dart';
import 'providers.dart';
import 'platform.dart';

// App rating and gentle suggestions (owner, 13 Nov 2026). Admin → App ratings sets when they show.
// - Our own rating card (stars + a comment): after a few days and opens, then every N days. Staff read it in Admin.
// - Google's in-app review box: asked for at a happy moment (a good score, a game win), for everyone and never right
//   after our card. Google's rules forbid asking an opinion first or showing their box only to happy students.
// - Suggestions: now and then, one of Community, Game Zone or Request a tutor, preferring ones not opened lately.
// At most one of these per app open, never on top of the countdown, a badge or the daily claim.

Map<String, dynamic> _sec(WidgetRef ref, String k) => _secOf(ref.read(appSettingsProvider).value, k);

Map<String, dynamic> _secOf(Map<String, dynamic>? settings, String k) {
  final e = settings?['engagement'];
  final v = e is Map ? e[k] : null;
  return v is Map ? Map<String, dynamic>.from(v) : const {};
}

int _int(Object? v, int d) => v is num ? v.toInt() : d;

abstract final class Engagement {
  static DateTime? _date(String? s) => s == null ? null : DateTime.tryParse(s);
  static int _daysSince(DateTime? d) => d == null ? 1 << 20 : DateTime.now().difference(d).inDays;

  /// Counts this app open and remembers the first one. Call once per launch.
  static Future<void> countOpen(WidgetRef ref) async {
    final db = ref.read(dbProvider);
    if (await db.kvGet('eng_first') == null) await db.kvSet('eng_first', DateTime.now().toIso8601String());
    final n = int.tryParse(await db.kvGet('eng_opens') ?? '') ?? 0;
    await db.kvSet('eng_opens', '${n + 1}');
  }

  /// A feature screen was opened (so it is not suggested for a week).
  static void visited(BuildContext context, String feature) {
    try {
      final db = ProviderScope.containerOf(context, listen: false).read(dbProvider);
      unawaited(db.kvSet('eng_seen_$feature', DateTime.now().toIso8601String()).catchError((_) {}));
    } catch (_) {}
  }

  /// One of: our rating card, else a suggestion. Returns true when something was shown.
  static Future<bool> maybeShowOne(BuildContext context, WidgetRef ref) async {
    if (await _maybeRating(context, ref)) return true;
    if (!context.mounted) return false;
    return _maybeNudge(context, ref);
  }

  static Future<bool> _maybeRating(BuildContext context, WidgetRef ref) async {
    final s = _sec(ref, 'rating');
    if (s['on'] == false) return false;
    final db = ref.read(dbProvider);
    final first = _date(await db.kvGet('eng_first'));
    final opens = int.tryParse(await db.kvGet('eng_opens') ?? '') ?? 0;
    final next = _date(await db.kvGet('eng_rating_next'));
    if (_daysSince(first) < _int(s['after_days'], 3) || opens < _int(s['after_opens'], 6)) return false;
    if (next != null && DateTime.now().isBefore(next)) return false;
    if (!context.mounted) return false;
    final sent = await showRatingSheet(context, ref);
    // Rated: ask again after the admin's gap. "Not now": in two weeks.
    final gap = sent == true ? _int(s['every_days'], 60) : 14;
    await db.kvSet('eng_rating_next', DateTime.now().add(Duration(days: gap)).toIso8601String());
    await db.kvSet('eng_last_popup', DateTime.now().toIso8601String());
    return true;
  }

  static Future<bool> _maybeNudge(BuildContext context, WidgetRef ref) async {
    final s = _sec(ref, 'nudges');
    if (s['on'] == false) return false;
    final db = ref.read(dbProvider);
    final first = _date(await db.kvGet('eng_first'));
    final last = _date(await db.kvGet('eng_nudge_last'));
    if (_daysSince(first) < _int(s['after_days'], 2) || _daysSince(last) < _int(s['every_days'], 3)) return false;
    final order = [
      for (final f in const ['games', 'community', 'tutor'])
        if (s[f] != false) f,
    ];
    if (order.isEmpty) return false;
    // Rotate, skipping features opened in the last 7 days.
    final start = int.tryParse(await db.kvGet('eng_nudge_i') ?? '') ?? 0;
    String? pick;
    for (var k = 0; k < order.length; k++) {
      final f = order[(start + k) % order.length];
      if (_daysSince(_date(await db.kvGet('eng_seen_$f'))) >= 7) {
        pick = f;
        await db.kvSet('eng_nudge_i', '${(start + k + 1) % order.length}');
        break;
      }
    }
    if (pick == null) return false;
    await db.kvSet('eng_nudge_last', DateTime.now().toIso8601String());
    if (!context.mounted) return false;
    await showNudgeSheet(context, pick);
    return true;
  }

  /// A happy moment (a good score, a game win): maybe ask Google for a Play Store review. Never in the same open as our
  /// rating card; the answer to our card plays no part (Play rules).
  static Future<void> happyMoment(BuildContext context) async {
    try {
      final box = ProviderScope.containerOf(context, listen: false);
      final s = _secOf(box.read(appSettingsProvider).value, 'review');
      if (s['on'] == false) return;
      final db = box.read(dbProvider);
      final first = _date(await db.kvGet('eng_first'));
      final last = _date(await db.kvGet('eng_review_last'));
      final pop = _date(await db.kvGet('eng_last_popup'));
      if (_daysSince(first) < _int(s['after_days'], 5) || _daysSince(last) < _int(s['every_days'], 120)) return;
      if (pop != null && DateTime.now().difference(pop) < const Duration(hours: 12)) return;
      if (isDesktop) return; // no Play review on Windows
      final r = InAppReview.instance;
      if (!await r.isAvailable()) return;
      await db.kvSet('eng_review_last', DateTime.now().toIso8601String());
      await r.requestReview();
    } catch (_) {
      // Not installed from Play, no Play services, or quota used: nothing to do.
    }
  }
}

// ---------------------------------------------------------------- the rating sheet

/// Returns true when the student sent a rating.
Future<bool?> showRatingSheet(BuildContext context, WidgetRef ref) => showModalBottomSheet<bool>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: false,
  backgroundColor: Colors.transparent,
  builder: (_) => const _RatingSheet(),
);

class _RatingSheet extends ConsumerStatefulWidget {
  const _RatingSheet();
  @override
  ConsumerState<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<_RatingSheet> {
  int _stars = 0;
  final _text = TextEditingController();
  bool _sending = false, _done = false;

  static const _faces = ['🤔', '😞', '😕', '😐', '🙂', '😍'];
  static const _words = ['Tap a star', 'Not good', 'Could be better', 'It is okay', 'Good', 'I love it!'];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_stars == 0 || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(supabaseProvider)
          .rpc('app_rating_submit', params: {'p_stars': _stars, 'p_comment': _text.text.trim(), 'p_version': Config.appVersion})
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() => _done = true);
      await Future<void>.delayed(const Duration(milliseconds: 1900));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      toast(context, 'Could not send. Check your internet and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final face = Text(_faces[_stars], style: const TextStyle(fontSize: 64));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s3, Space.s5, Space.s5),
        child: Stack(
          children: [
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.out,
              child: _done
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Gap(Space.s6),
                        Icon(
                          PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                          size: 72,
                          color: Palette.gold400,
                        ).animate().scale(begin: const Offset(.3, .3), curve: Curves.easeOutBack, duration: 500.ms).rotate(begin: -.1, end: 0),
                        const Gap(Space.s3),
                        Text('Thank you!', style: context.ty.h2),
                        const Gap(Space.s1),
                        Text(
                          'Your rating helps us make SolutionTee better for every student.',
                          textAlign: TextAlign.center,
                          style: context.ty.sm.col(c.textMuted),
                        ),
                        const Gap(Space.s6),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(99)),
                          ),
                        ),
                        const Gap(Space.s4),
                        Center(
                          child: rm ? face : face.animate(key: ValueKey(_stars)).scale(begin: const Offset(.6, .6), curve: Curves.elasticOut, duration: 650.ms),
                        ),
                        const Gap(Space.s2),
                        Text('How is SolutionTee for you?', textAlign: TextAlign.center, style: context.ty.h2),
                        const Gap(Space.s1),
                        Text('Tell us honestly. Our team reads every rating.', textAlign: TextAlign.center, style: context.ty.sm.col(c.textMuted)),
                        const Gap(Space.s4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 1; i <= 5; i++)
                              Semantics(
                                button: true,
                                label: '$i ${i == 1 ? 'star' : 'stars'}',
                                child: GestureDetector(
                                  onTap: () => setState(() => _stars = i),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: _Star(on: i <= _stars, index: i, picked: _stars, still: rm),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Gap(Space.s2),
                        Text(_words[_stars], textAlign: TextAlign.center, style: context.ty.label.bold.col(_stars == 0 ? c.textMuted : Palette.gold600)),
                        if (_stars > 0) ...[
                          const Gap(Space.s4),
                          TextField(
                            controller: _text,
                            minLines: 2,
                            maxLines: 4,
                            maxLength: 1000,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: _stars <= 3 ? 'What should we fix or add? (optional)' : 'What do you like most? (optional)',
                              counterText: '',
                            ),
                          ).animate().fadeIn(duration: Motion.base).slideY(begin: .2, curve: Motion.out),
                        ],
                        const Gap(Space.s4),
                        Btn(_sending ? 'Sending…' : 'Send my rating', kind: BtnKind.accent, block: true, onPressed: _stars == 0 || _sending ? null : _send),
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not now')),
                      ],
                    ),
            ),
            if (_done && _stars >= 4 && !rm) const Positioned.fill(child: IgnorePointer(child: Confetti(pieces: 60))),
          ],
        ),
      ),
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.on, required this.index, required this.picked, required this.still});
  final bool on;
  final int index, picked;
  final bool still;
  @override
  Widget build(BuildContext context) {
    final icon = AnimatedContainer(
      duration: Motion.fast,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: on ? [BoxShadow(color: Palette.gold400.withValues(alpha: .45), blurRadius: 14)] : const [],
      ),
      child: Icon(on ? PhosphorIcons.star(PhosphorIconsStyle.fill) : PhosphorIcons.star(), size: 42, color: on ? Palette.gold400 : context.c.textSubtle),
    );
    if (still || !on) return icon;
    // The stars light up one after another when a rating is chosen.
    return icon
        .animate(key: ValueKey('$index-$picked'), delay: (60 * index).ms)
        .scale(begin: const Offset(.6, .6), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 380.ms)
        .rotate(begin: -.08, end: 0, duration: 380.ms);
  }
}

// ---------------------------------------------------------------- suggestions

Future<void> showNudgeSheet(BuildContext context, String feature) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: false,
  backgroundColor: Colors.transparent,
  builder: (ctx) => _Nudge(feature: feature),
);

class _Nudge extends StatelessWidget {
  const _Nudge({required this.feature});
  final String feature;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final (title, body, cta, route, colors) = switch (feature) {
      'games' => (
        'Fancy a quick game?',
        'Beat a student or the SolutionTee Bot in JAMB Duel, Comprehension Clash and 6 more games. Win XP while you revise.',
        'Play now',
        '/games',
        const [Color(0xFF241552), Color(0xFF13306A)],
      ),
      'community' => (
        'Join the student community',
        'Ask a question, answer one, share tips. Tag @solutiontee and SolutionTee AI explains it for you.',
        'Open Community',
        '/community',
        const [Color(0xFF0E4A8A), Color(0xFF2563B3)],
      ),
      _ => (
        'Stuck on a topic?',
        'Request a tutor and chat with a real teacher who explains it step by step, at your pace.',
        'Request a tutor',
        '/tutor',
        const [Color(0xFF7A4B00), Color(0xFFB57D12)],
      ),
    };
    Widget art() {
      Widget float(Widget w, int delay) =>
          rm ? w : w.animate(onPlay: (x) => x.repeat(reverse: true), delay: delay.ms).moveY(begin: 0, end: -8, duration: 1500.ms, curve: Curves.easeInOut);
      return switch (feature) {
        'games' => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [float(const GameIcon('duel', size: 70), 0), float(const GameIcon('reading', size: 78), 300), float(const GameIcon('rush', size: 70), 600)],
        ),
        'community' => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            float(_Bubble('Can someone explain osmosis? 🤔', left: true), 0),
            const Gap(8),
            float(_Bubble('@solutiontee explained it ✨', left: false), 400),
          ],
        ),
        _ => float(
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), shape: BoxShape.circle),
            child: Icon(PhosphorIcons.chalkboardTeacher(PhosphorIconsStyle.fill), size: 56, color: Colors.white),
          ),
          0,
        ),
      };
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 170,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Stack(
              children: [
                Center(child: art()),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: context.ty.h2).animate().fadeIn(duration: Motion.base).slideY(begin: .2, curve: Motion.out),
                const Gap(Space.s2),
                Text(body, style: context.ty.body.col(c.textMuted)).animate(delay: 80.ms).fadeIn(duration: Motion.base),
                const Gap(Space.s5),
                Btn(
                  cta,
                  kind: BtnKind.accent,
                  block: true,
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push(route);
                  },
                ),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Maybe later')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.text, {required this.left});
  final String text;
  final bool left;
  @override
  Widget build(BuildContext context) => Align(
    alignment: left ? const Alignment(-.5, 0) : const Alignment(.5, 0),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: left ? Colors.white : Palette.gold400,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(left ? 3 : 14),
          bottomRight: Radius.circular(left ? 14 : 3),
        ),
      ),
      child: Text(text, style: context.ty.sm.bold.col(Palette.navy900)),
    ),
  );
}
