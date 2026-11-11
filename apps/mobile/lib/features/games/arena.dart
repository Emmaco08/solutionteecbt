import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/math_text.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../cbt/cbt_screen.dart' show OptionRow, OptState;
import 'games.dart';

/// Live Exam Arena: everyone sees the same question at the same time. The server's clock decides the phase (lobby,
/// question, reveal, done); the app asks every 2 seconds while the screen is open and counts down in between.
class ArenaScreen extends ConsumerStatefulWidget {
  const ArenaScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends ConsumerState<ArenaScreen> {
  Map<String, dynamic>? _s;
  Object? _error;
  Timer? _poll, _tick;
  DateTime _phaseEnd = DateTime.now();
  String? _picked; // my pick for the current question (before the server confirms)
  int? _pickedFor;
  bool _joining = false;

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      final p = _s?['phase'];
      if (p != 'done' && p != 'cancelled') _load();
    });
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && _s != null && _s!['phase'] != 'done') setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = Map<String, dynamic>.from(await _db.rpc('arena_state', params: {'p_arena': widget.id}).timeout(const Duration(seconds: 10)) as Map);
      if (!mounted) return;
      final before = _s?['phase'];
      setState(() {
        _s = r;
        _error = null;
        _phaseEnd = DateTime.now().add(Duration(milliseconds: (r['left_ms'] as num?)?.toInt() ?? 0));
      });
      if (r['phase'] == 'done' && before != 'done') ref.invalidate(arenasProvider);
    } catch (e) {
      if (mounted && _s == null) setState(() => _error = e);
    }
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      final r = Map<String, dynamic>.from(await _db.rpc('arena_join', params: {'p_arena': widget.id}).timeout(const Duration(seconds: 15)) as Map);
      if (!mounted) return;
      if (r['ok'] != true) {
        toast(context, switch ('${r['error']}') {
          'full' => 'This arena is full.',
          'ended' => 'This arena has ended.',
          'no_questions' => 'This arena is not ready yet. Please try again later.',
          _ => 'You cannot join this arena.',
        });
      } else {
        ref.invalidate(arenasProvider);
        toast(context, 'You are in! We will remind you 5 minutes before it starts.', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
      }
      await _load();
    } catch (_) {
      if (mounted) toast(context, 'Could not reach SolutionTee. Check your internet and try again.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _answer(int index, String key) async {
    if (_pickedFor == index) return;
    setState(() => (_picked = key, _pickedFor = index));
    try {
      final r = Map<String, dynamic>.from(
        await _db.rpc('arena_answer', params: {'p_arena': widget.id, 'p_index': index, 'p_choice': key}).timeout(const Duration(seconds: 10)) as Map,
      );
      if (!mounted) return;
      if (r['ok'] != true && r['error'] == 'closed') toast(context, 'Too late for this one. Be quick on the next!');
    } catch (_) {
      if (mounted) {
        setState(() => (_picked = null, _pickedFor = null));
        toast(context, 'Your answer did not reach us. Tap again.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
      }
    }
  }

  String _clock(int ms) {
    final s = (ms / 1000).ceil().clamp(0, 1 << 31);
    if (s >= 3600) return '${s ~/ 3600} h ${(s % 3600) ~/ 60} min';
    if (s >= 60) return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    return '$s';
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      appBar: TopBar(title: '${s?['title'] ?? 'Live Exam Arena'}'),
      body: _error != null && s == null
          ? asyncView<Object?>(AsyncValue.error(_error!, StackTrace.empty), (_) => const SizedBox(), onRetry: _load)
          : s == null
          ? const ListSkeleton(items: 4)
          : s['status'] == 'not_found'
          ? StateBlock(icon: PhosphorIcons.broadcast(PhosphorIconsStyle.fill), title: 'Arena not found', text: 'This arena is not open.')
          : _body(context, s),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> s) {
    final c = context.c;
    final phase = '${s['phase']}';
    final left = _phaseEnd.difference(DateTime.now()).inMilliseconds.clamp(0, 1 << 31);
    final joined = s['joined'] == true;
    final board = [for (final b in (s['board'] as List? ?? const [])) Map<String, dynamic>.from(b as Map)];
    final players = (s['players'] as num?)?.toInt() ?? 0;

    if (phase == 'cancelled') {
      return StateBlock(icon: PhosphorIcons.xCircle(PhosphorIconsStyle.fill), title: 'This arena was cancelled', text: 'Look out for the next one in Games.');
    }
    if (!joined && phase != 'done') {
      return ListView(
        padding: const EdgeInsets.all(Space.s5),
        children: [
          const _ArenaHero(),
          const Gap(Space.s4),
          Text('${s['title']}', style: context.ty.h2, textAlign: TextAlign.center),
          const Gap(Space.s1),
          Text(
            phase == 'lobby' ? 'Starts ${arenaWhen(s['starts_at'])} · in ${_clock(left)}' : 'Live now: join and answer the next question.',
            style: context.ty.sm.col(c.textMuted),
            textAlign: TextAlign.center,
          ),
          const Gap(Space.s4),
          _Facts(
            total: (s['total'] as num?)?.toInt() ?? 0,
            seconds: (s['seconds'] as num?)?.toInt() ?? 20,
            players: players,
            max: (s['max_players'] as num?)?.toInt() ?? 50,
          ),
          const Gap(Space.s5),
          Btn('Join the arena', block: true, loading: _joining, onPressed: _joining ? null : _join),
        ],
      );
    }

    if (phase == 'lobby') {
      return ListView(
        padding: const EdgeInsets.all(Space.s5),
        children: [
          const _ArenaHero(),
          const Gap(Space.s4),
          Text('You are in!', style: context.ty.h2, textAlign: TextAlign.center),
          const Gap(Space.s1),
          Text('Starts in', style: context.ty.sm.col(c.textMuted), textAlign: TextAlign.center),
          Text(_clock(left), style: context.ty.display.tnum, textAlign: TextAlign.center),
          const Gap(Space.s3),
          _Facts(
            total: (s['total'] as num?)?.toInt() ?? 0,
            seconds: (s['seconds'] as num?)?.toInt() ?? 20,
            players: players,
            max: (s['max_players'] as num?)?.toInt() ?? 50,
          ),
          const Gap(Space.s3),
          Text('Keep this screen open when it starts. Faster right answers score more.', style: context.ty.cap.col(c.textMuted), textAlign: TextAlign.center),
        ],
      );
    }

    if (phase == 'done') {
      final rank = (s['rank'] as num?)?.toInt();
      return ListView(
        padding: const EdgeInsets.all(Space.s5),
        children: [
          Center(child: IconTile(PhosphorIcons.flagCheckered(PhosphorIconsStyle.fill), tone: Tone.gold, size: 80, radius: 40)),
          const Gap(Space.s3),
          Text('Arena finished', style: context.ty.h2, textAlign: TextAlign.center),
          if (joined) ...[
            const Gap(Space.s1),
            Text(
              'You came ${rank ?? '-'} of $players with ${s['score'] ?? 0} points (${s['correct'] ?? 0} right).',
              style: context.ty.sm.col(c.textMuted),
              textAlign: TextAlign.center,
            ),
            Text('XP is added within a minute after the end.', style: context.ty.cap.col(c.textSubtle), textAlign: TextAlign.center),
          ],
          const Gap(Space.s5),
          _Board(board: board),
        ],
      );
    }

    // question or reveal
    final index = (s['index'] as num?)?.toInt() ?? 0, total = (s['total'] as num?)?.toInt() ?? 1;
    final q = s['question'] == null ? null : Map<String, dynamic>.from(s['question'] as Map);
    final mine = s['mine'] == null ? null : Map<String, dynamic>.from(s['mine'] as Map);
    final picked = mine?['choice'] ?? (_pickedFor == index ? _picked : null);
    final answer = phase == 'reveal' ? s['answer'] : null;
    final seconds = (s['seconds'] as num?)?.toDouble() ?? 20;
    final opts = [for (final o in (q?['options'] as List? ?? const [])) Map<String, dynamic>.from(o as Map)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s3, Space.s5, Space.s2),
          child: Row(
            children: [
              Pill('LIVE', kind: BadgeKind.error, icon: PhosphorIcons.broadcast(PhosphorIconsStyle.fill)),
              const Gap(Space.s2),
              Expanded(child: Text('$players playing · you are #${s['rank'] ?? '-'}', style: context.ty.cap.col(c.textMuted))),
              Text('${s['score'] ?? 0} pts', style: context.ty.sm.bold.tnum),
            ],
          ),
        ),
        ProgressBar((index + 1) / total, height: 4),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s6),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Question ${index + 1} of $total', style: context.ty.label)),
                  if (phase == 'question')
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: (left / 1000 / seconds).clamp(0, 1),
                            strokeWidth: 4,
                            color: left <= 5000 ? c.error : c.secondary,
                            backgroundColor: c.surfaceSunken,
                          ),
                          Text('${(left / 1000).ceil()}', style: context.ty.sm.bold.tnum),
                        ],
                      ),
                    )
                  else
                    Pill('Next in ${(left / 1000).ceil()}', kind: BadgeKind.neutral),
                ],
              ),
              const Gap(Space.s3),
              if (q != null) ...[
                MathText(
                  '${q['body']}',
                  style: context.ty.body.copyWith(fontSize: TypeScale.question.size, height: TypeScale.question.line / TypeScale.question.size),
                ).animate(key: ValueKey('a$index')).fadeIn(duration: Motion.base),
                const Gap(Space.s4),
                for (final (k, o) in opts.indexed) ...[
                  OptionRow(
                    letter: 'ABCDE'[k],
                    text: '${o['text']}',
                    state: answer != null
                        ? (o['key'] == answer
                              ? OptState.right
                              : o['key'] == picked
                              ? OptState.wrong
                              : OptState.none)
                        : o['key'] == picked
                        ? OptState.selected
                        : OptState.none,
                    tag: answer != null && o['key'] == picked && mine?['correct'] == true ? '+${mine?['points']}' : null,
                    onTap: phase == 'question' && picked == null ? () => _answer(index, '${o['key']}') : null,
                  ),
                  const Gap(Space.s2),
                ],
                const Gap(Space.s2),
                Text(
                  phase == 'question'
                      ? (picked == null ? 'Tap your answer. Faster scores more.' : 'Answer locked in. Wait for the reveal…')
                      : picked == null
                      ? 'You missed this one.'
                      : mine?['correct'] == true
                      ? 'Correct!'
                      : 'Not this time.',
                  textAlign: TextAlign.center,
                  style: context.ty.sm.bold.col(phase == 'reveal' && mine?['correct'] == true ? c.success : c.textMuted),
                ),
              ],
              if (phase == 'reveal') ...[const Gap(Space.s5), _Board(board: board)],
            ],
          ),
        ),
      ],
    );
  }
}

class _ArenaHero extends StatelessWidget {
  const _ArenaHero();
  @override
  Widget build(BuildContext context) => Center(child: IconTile(PhosphorIcons.broadcast(PhosphorIconsStyle.fill), tone: Tone.red, size: 80, radius: 40));
}

class _Facts extends StatelessWidget {
  const _Facts({required this.total, required this.seconds, required this.players, required this.max});
  final int total, seconds, players, max;
  @override
  Widget build(BuildContext context) => ListCard(
    children: [
      ListRow(icon: PhosphorIcons.listNumbers(PhosphorIconsStyle.fill), title: '$total questions', caption: '$seconds seconds each, the same for everyone'),
      ListRow(
        icon: PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
        tone: Tone.blue,
        title: '$players of $max players',
        caption: 'Live board after every question',
      ),
      ListRow(icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill), tone: Tone.gold, title: 'XP for playing', caption: 'Extra XP for the top 3'),
    ],
  );
}

class _Board extends StatelessWidget {
  const _Board({required this.board});
  final List<Map<String, dynamic>> board;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (board.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectTitle('Top 10'),
        ListCard(
          children: [
            for (final (i, b) in board.indexed)
              ListRow(
                lead: SizedBox(
                  width: 28,
                  child: Text('${i + 1}', style: context.ty.body.bold.tnum.col(i < 3 ? c.secondary : c.textMuted), textAlign: TextAlign.center),
                ),
                title: b['me'] == true ? '${b['name']} (you)' : '${b['name']}',
                trailing: Text('${b['score']}', style: context.ty.sm.bold.tnum),
              ),
          ],
        ),
      ],
    );
  }
}
