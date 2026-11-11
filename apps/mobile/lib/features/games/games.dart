import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';

// Games (C14, D-150): Speed Quiz Duel against the SolutionTee bot or a friend, Beat the AI Tutor, and Live Exam
// Arenas. Questions, timing, answers and XP are all on the server (game_* and arena_* functions).

final gamesMineProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const [];
  return cached(ref, 'games:$uid', (s) => s.rpc('games_mine'), rows);
});

final arenasProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const [];
  return cached(ref, 'arenas:$uid', (s) => s.rpc('arenas_list'), rows);
});

const gameModes = {'duel_ai': 'Speed Quiz Duel', 'duel_friend': 'Duel a friend', 'beat_ai': 'Beat the AI Tutor'};

/// Win / lose / draw / waiting line for a finished or open game.
String gameOutcome(Map<String, dynamic>? r) {
  if (r == null) return '';
  final opp = r['opp'] as Map?;
  if (r['finished'] != true) return 'Not finished';
  if (opp == null) return 'Waiting for a friend';
  if (r['won'] == null) return 'Waiting for ${opp['name']}';
  if (r['draw'] == true) return 'Draw';
  return r['won'] == true ? 'You won' : 'You lost';
}

/// "Join my duel" message with the code (WhatsApp first, clipboard when WhatsApp is missing).
Future<void> shareDuelCode(BuildContext context, String code) async {
  final text =
      'I challenge you to a SolutionTee quiz duel! Open the SolutionTee CBT app → Study → Games → Join with a code, and type $code. '
      'Get the app: https://cbt.solutiontee.com';
  final ok = await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (ok || !context.mounted) return;
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, 'Copied. Paste it to your friend.', icon: PhosphorIcons.copy(PhosphorIconsStyle.fill));
}

String gameError(Object? e) => switch ('$e') {
  'too_many' => 'You have played a lot today. Come back tomorrow for more games.',
  'no_questions' => 'There are not enough questions for this subject yet. Try another subject.',
  'off' => 'Games are paused for now. Please try again later.',
  'not_found' => 'We could not find a duel with that code. Check the letters and try again.',
  'ended' => 'That duel has ended. Ask your friend for a new code.',
  'full' => 'Someone already took that duel. Ask your friend for a new code.',
  _ => 'Something went wrong. Please try again.',
};

/// Starts a game of [mode] after the student picks an exam and subject. Returns the game id.
Future<void> startGame(BuildContext context, WidgetRef ref, String mode, {int? exam, int? subject}) async {
  final pick = (exam != null && subject != null) ? (exam, subject) : await pickGameSubject(context, ref, title: gameModes[mode] ?? 'Game');
  if (pick == null || !context.mounted) return;
  try {
    final r = Map<String, dynamic>.from(
      await Supabase.instance.client.rpc('game_create', params: {'p_mode': mode, 'p_exam': pick.$1, 'p_subject': pick.$2}).timeout(const Duration(seconds: 15))
          as Map,
    );
    if (!context.mounted) return;
    if (r['ok'] != true) return toast(context, gameError(r['error']));
    ref.invalidate(gamesMineProvider);
    context.push('/games/play/${r['id']}');
  } catch (_) {
    if (context.mounted) {
      toast(context, 'Could not reach SolutionTee. Check your internet and try again.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    }
  }
}

/// Exam chips, then the subjects of that exam.
Future<(int, int)?> pickGameSubject(BuildContext context, WidgetRef ref, {required String title}) =>
    showSheet<(int, int)>(context, scroll: true, builder: (ctx) => _SubjectPicker(title: title));

class _SubjectPicker extends ConsumerStatefulWidget {
  const _SubjectPicker({required this.title});
  final String title;
  @override
  ConsumerState<_SubjectPicker> createState() => _SubjectPickerState();
}

class _SubjectPickerState extends ConsumerState<_SubjectPicker> {
  int? _exam;
  @override
  Widget build(BuildContext context) {
    final exams = ref.watch(examsProvider).value ?? const <Map<String, dynamic>>[];
    final subjects = ref.watch(subjectsProvider).value ?? const <Map<String, dynamic>>[];
    final links = ref.watch(examSubjectsProvider).value ?? const <Map<String, dynamic>>[];
    final exam = _exam ?? (exams.isEmpty ? null : (exams.first['id'] as num).toInt());
    final ids = {
      for (final l in links)
        if ((l['exam_id'] as num?)?.toInt() == exam) (l['subject_id'] as num).toInt(),
    };
    final shown = [
      for (final s in subjects)
        if (ids.isEmpty || ids.contains((s['id'] as num).toInt())) s,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: context.ty.h3),
        const Gap(Space.s1),
        Text('Pick a subject. 10 quick questions, beat the clock.', style: context.ty.sm.col(context.c.textMuted)),
        const Gap(Space.s3),
        Wrap(
          spacing: Space.s2,
          runSpacing: Space.s2,
          children: [
            for (final e in exams) AppChip('${e['code']}', on: (e['id'] as num).toInt() == exam, onTap: () => setState(() => _exam = (e['id'] as num).toInt())),
          ],
        ),
        const Gap(Space.s3),
        ListCard(
          children: [
            for (final s in shown)
              ListRow(
                title: '${s['name']}',
                icon: PhosphorIcons.bookOpenText(PhosphorIconsStyle.fill),
                tone: Tone.blue,
                onTap: exam == null ? null : () => Navigator.pop(context, (exam, (s['id'] as num).toInt())),
              ),
          ],
        ),
      ],
    );
  }
}

/// Study card: the way in.
class GamesCard extends StatelessWidget {
  const GamesCard({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      onTap: () => context.push('/games'),
      child: Row(
        children: [
          IconTile(PhosphorIcons.gameController(PhosphorIconsStyle.fill), tone: Tone.red, size: 48),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Games', style: context.ty.body.bold),
                const Gap(2),
                Text(
                  'Quiz duels, beat the AI Tutor and live arenas. Earn XP.',
                  style: context.ty.cap.col(c.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(PhosphorIcons.caretRight(), size: 18, color: c.textSubtle),
        ],
      ),
    );
  }
}

class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(gamesMineProvider);
    ref.invalidate(arenasProvider);
    await ref.read(arenasProvider.future).catchError((_) => const <Map<String, dynamic>>[]);
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final code = TextEditingController();
    final go = await showSheet<bool>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Join a friend\'s duel', style: ctx.ty.h3),
          const Gap(Space.s1),
          Text('Type the 6-letter code your friend sent you.', style: ctx.ty.sm.col(ctx.c.textMuted)),
          const Gap(Space.s3),
          Field(
            label: 'Duel code',
            controller: code,
            caps: TextCapitalization.characters,
            maxLength: 6,
            mono: true,
            autofocus: true,
            onSubmitted: (_) => Navigator.pop(ctx, true),
          ),
          const Gap(Space.s4),
          Btn('Join duel', block: true, onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    final text = code.text.trim().toUpperCase();
    code.dispose();
    if (go != true || text.length != 6 || !context.mounted) return;
    try {
      final r = Map<String, dynamic>.from(
        await Supabase.instance.client.rpc('game_join', params: {'p_code': text}).timeout(const Duration(seconds: 15)) as Map,
      );
      if (!context.mounted) return;
      if (r['ok'] != true) return toast(context, gameError(r['error']));
      ref.invalidate(gamesMineProvider);
      context.push('/games/play/${r['id']}');
    } catch (_) {
      if (context.mounted) {
        toast(context, 'Could not reach SolutionTee. Check your internet and try again.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final rm = context.reduceMotion;
    final arenas = ref.watch(arenasProvider);
    final mine = ref.watch(gamesMineProvider).value ?? const <Map<String, dynamic>>[];
    final subjectName = {for (final s in ref.watch(subjectsProvider).value ?? const <Map<String, dynamic>>[]) (s['id'] as num).toInt(): '${s['name']}'};
    final modes = [
      (
        'duel_ai',
        'Speed Quiz Duel',
        'Race the SolutionTee bot: 10 questions, 15 seconds each. Faster right answers score more.',
        PhosphorIcons.lightning(PhosphorIconsStyle.fill),
        Tone.gold,
      ),
      (
        'beat_ai',
        'Beat the AI Tutor',
        'Harder questions. The AI Tutor gets most of them right. Can you score higher?',
        PhosphorIcons.robot(PhosphorIconsStyle.fill),
        Tone.navy,
      ),
    ];
    return Scaffold(
      appBar: TopBar(title: 'Games'),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s3, Space.s5, Space.s8),
          children: [
            for (final (i, m) in modes.indexed) ...[
              Builder(
                builder: (context) {
                  final card = _ModeCard(title: m.$2, caption: m.$3, icon: m.$4, tone: m.$5, onTap: () => startGame(context, ref, m.$1));
                  return rm ? card : card.animate().fadeIn(delay: (60 * i).ms, duration: Motion.base).slideY(begin: .08, end: 0, curve: Curves.easeOut);
                },
              ),
              const Gap(Space.s3),
            ],
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconTile(PhosphorIcons.usersThree(PhosphorIconsStyle.fill), tone: Tone.blue, size: 48),
                      const Gap(Space.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Duel a friend', style: context.ty.body.bold),
                            Text('Same 10 questions. Play now, send the code, see who wins.', style: context.ty.cap.col(c.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap(Space.s3),
                  Row(
                    children: [
                      Expanded(child: Btn('Start a duel', sm: true, onPressed: () => startGame(context, ref, 'duel_friend'))),
                      const Gap(Space.s2),
                      Expanded(
                        child: Btn('Join with a code', sm: true, kind: BtnKind.secondary, onPressed: () => _join(context, ref)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(Space.s6),
            const SectTitle('Live Exam Arena'),
            asyncView(
              arenas,
              onRetry: () => ref.invalidate(arenasProvider),
              loading: const Skeleton(height: 96, radius: Radii.lg),
              (list) => list.isEmpty
                  ? AppCard(
                      child: Row(
                        children: [
                          IconTile(PhosphorIcons.broadcast(PhosphorIconsStyle.fill), tone: Tone.neutral, size: 40),
                          const Gap(Space.s3),
                          Expanded(
                            child: Text(
                              'No arena is planned yet. When one is, it shows here: up to 50 students, the same question at the same time, a live board.',
                              style: context.ty.sm.col(c.textMuted),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        for (final a in list) ...[ArenaCard(a: a, subjectName: subjectName), const Gap(Space.s2)],
                      ],
                    ),
            ),
            if (mine.isNotEmpty) ...[
              const Gap(Space.s6),
              const SectTitle('My recent games'),
              ListCard(
                children: [
                  for (final g in mine.take(10))
                    Builder(
                      builder: (context) {
                        final r = g['result'] == null ? null : Map<String, dynamic>.from(g['result'] as Map);
                        final out = gameOutcome(r);
                        final opp = (r?['opp'] as Map?)?['name'];
                        return ListRow(
                          icon: switch ('${g['mode']}') {
                            'beat_ai' => PhosphorIcons.robot(PhosphorIconsStyle.fill),
                            'duel_friend' => PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
                            _ => PhosphorIcons.lightning(PhosphorIconsStyle.fill),
                          },
                          tone: out == 'You won'
                              ? Tone.green
                              : out == 'You lost'
                              ? Tone.red
                              : Tone.neutral,
                          title: '${subjectName[(g['subject_id'] as num?)?.toInt()] ?? 'Quiz'}${opp != null ? ' vs $opp' : ''}',
                          caption: '$out · ${r?['score'] ?? 0} points',
                          onTap: () => context.push('/games/play/${g['id']}'),
                        );
                      },
                    ),
                ],
              ),
            ],
            const Gap(Space.s4),
            Text('Games give XP, never money. There is a daily limit on game XP.', style: context.ty.cap.col(c.textSubtle), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.title, required this.caption, required this.icon, required this.tone, required this.onTap});
  final String title, caption;
  final IconData icon;
  final Tone tone;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Row(
      children: [
        IconTile(icon, tone: tone, size: 48),
        const Gap(Space.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.ty.body.bold),
              const Gap(2),
              Text(caption, style: context.ty.cap.col(context.c.textMuted)),
            ],
          ),
        ),
        Icon(PhosphorIcons.play(PhosphorIconsStyle.fill), size: 20, color: context.c.secondary),
      ],
    ),
  );
}

/// "Fri 13 Nov · 7:00 pm".
String arenaWhen(Object? iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} · $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
}

class ArenaCard extends StatelessWidget {
  const ArenaCard({super.key, required this.a, required this.subjectName});
  final Map<String, dynamic> a;
  final Map<int, String> subjectName;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final now = DateTime.now();
    final start = DateTime.tryParse('${a['starts_at']}')?.toLocal();
    final end = DateTime.tryParse('${a['ends_at']}')?.toLocal();
    final live = start != null && end != null && now.isAfter(start) && now.isBefore(end);
    final over = end != null && now.isAfter(end);
    final players = (a['players'] as num?)?.toInt() ?? 0, max = (a['max_players'] as num?)?.toInt() ?? 50;
    return AppCard(
      onTap: () => context.push('/games/arena/${a['id']}'),
      child: Row(
        children: [
          IconTile(PhosphorIcons.broadcast(PhosphorIconsStyle.fill), tone: live ? Tone.red : Tone.blue, size: 44),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a['title']}', style: context.ty.sm.bold, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(
                  '${arenaWhen(a['starts_at'])} · ${subjectName[(a['subject_id'] as num?)?.toInt()] ?? 'Use of English'} · $players/$max players',
                  style: context.ty.cap.col(c.textMuted),
                ),
              ],
            ),
          ),
          const Gap(Space.s2),
          Pill(
            over
                ? 'Ended'
                : live
                ? 'Live'
                : a['joined'] == true
                ? 'Joined'
                : 'Join',
            kind: over
                ? BadgeKind.neutral
                : live
                ? BadgeKind.error
                : a['joined'] == true
                ? BadgeKind.success
                : BadgeKind.soft,
          ),
        ],
      ),
    );
  }
}
