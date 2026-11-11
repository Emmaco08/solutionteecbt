import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/math_text.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import '../cbt/cbt_screen.dart' show OptionRow, OptState;
import 'games.dart';

/// One duel or Beat the AI game. The server sends one question at a time without the answer; after each answer it
/// says what was right, the points and (against the bot) how the bot did on that question.
class GamePlayScreen extends ConsumerStatefulWidget {
  const GamePlayScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends ConsumerState<GamePlayScreen> {
  Map<String, dynamic>? _q; // game_next
  Map<String, dynamic>? _last; // game_answer of the question on screen
  Object? _error;
  bool _busy = false;
  Timer? _tick;
  DateTime _deadline = DateTime.now();
  double _left = 0;

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => (_error = null, _last = null));
    try {
      final r = Map<String, dynamic>.from(await _db.rpc('game_next', params: {'p_game': widget.id}).timeout(const Duration(seconds: 15)) as Map);
      if (!mounted) return;
      setState(() => _q = r);
      _tick?.cancel();
      if (r['status'] == 'playing') {
        _deadline = DateTime.now().add(Duration(milliseconds: (r['left_ms'] as num?)?.toInt() ?? 15000));
        _left = ((r['left_ms'] as num?)?.toDouble() ?? 15000) / 1000;
        _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
          if (!mounted || _last != null) return;
          final l = _deadline.difference(DateTime.now()).inMilliseconds / 1000;
          setState(() => _left = l.clamp(0, 60));
          if (l <= 0) _answer(null);
        });
      } else {
        ref.invalidate(gamesMineProvider);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _answer(String? key) async {
    if (_busy || _last != null || _q?['status'] != 'playing') return;
    _busy = true;
    _tick?.cancel();
    try {
      final r = Map<String, dynamic>.from(
        await _db.rpc('game_answer', params: {'p_game': widget.id, 'p_index': _q!['index'], 'p_choice': key}).timeout(const Duration(seconds: 15)) as Map,
      );
      if (!mounted) return;
      if (r['ok'] != true) {
        _busy = false;
        await _load();
        return;
      }
      setState(() => _last = {...r, 'picked': key});
      await Future<void>.delayed(Duration(milliseconds: context.reduceMotion ? 900 : 1400));
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        toast(context, 'Could not reach SolutionTee. Check your internet.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
        _busy = false;
        await _load();
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    final mode = '${q?['mode'] ?? ''}';
    return Scaffold(
      appBar: TopBar(title: gameModes[mode] ?? 'Game'),
      body: _error != null && q == null
          ? asyncView<Object?>(AsyncValue.error(_error!, StackTrace.empty), (_) => const SizedBox(), onRetry: _load)
          : q == null
          ? const ListSkeleton(items: 4)
          : switch ('${q['status']}') {
              'playing' => _playing(context, q),
              'finished' => _GameResult(
                data: q,
                onAgain: () => startGame(context, ref, mode, exam: (q['exam_id'] as num?)?.toInt(), subject: (q['subject_id'] as num?)?.toInt()),
              ),
              _ => StateBlock(
                icon: PhosphorIcons.question(PhosphorIconsStyle.fill),
                title: 'Game not found',
                text: 'This game is not yours or has been removed.',
                action: Btn('Back to games', onPressed: () => context.go('/games')),
              ),
            },
    );
  }

  Widget _playing(BuildContext context, Map<String, dynamic> q) {
    final c = context.c;
    final index = (q['index'] as num).toInt(), total = (q['total'] as num).toInt();
    final seconds = (q['seconds'] as num?)?.toDouble() ?? 15;
    final r = Map<String, dynamic>.from((q['result'] as Map?) ?? const {});
    final opp = r['opp'] == null ? null : Map<String, dynamic>.from(r['opp'] as Map);
    final last = _last;
    final answer = last?['answer'];
    final myScore = (last?['score'] as num?)?.toInt() ?? (q['score'] as num?)?.toInt() ?? 0;
    var botScore = (opp?['score'] as num?)?.toInt() ?? 0;
    final bot = last?['bot'] as Map?;
    if (bot != null) botScore += (bot['p'] as num?)?.toInt() ?? 0;
    final opts = [for (final o in (q['options'] as List? ?? const [])) Map<String, dynamic>.from(o as Map)];
    final code = q['code'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (code != null && q['waiting'] == true)
          Container(
            color: c.accentSoft,
            padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s2, Space.s2),
            child: Row(
              children: [
                Expanded(child: Text('Your duel code: $code. Send it to a friend.', style: context.ty.sm.bold.col(c.onAccentSoft))),
                TextButton(onPressed: () => shareDuelCode(context, code), child: const Text('Share')),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s3, Space.s5, Space.s2),
          child: Row(
            children: [
              Expanded(
                child: _ScoreTag(name: 'You', score: myScore, me: true),
              ),
              const Gap(Space.s2),
              Text('vs', style: context.ty.cap.bold.col(c.textMuted)),
              const Gap(Space.s2),
              Expanded(
                child: _ScoreTag(
                  name: '${opp?['name'] ?? 'Friend'}',
                  score: botScore,
                  note: opp == null
                      ? 'Not joined yet'
                      : q['mode'] == 'duel_friend'
                      ? (opp['finished'] == true ? 'Finished' : 'Plays in turn')
                      : null,
                ),
              ),
            ],
          ),
        ),
        ProgressBar((index + (last != null ? 1 : 0)) / total, height: 4),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s6),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Question ${index + 1} of $total', style: context.ty.label)),
                  _TimerRing(value: _left / seconds, label: '${_left.ceil()}', low: _left <= 5),
                ],
              ),
              const Gap(Space.s3),
              MathText(
                '${q['body']}',
                style: context.ty.body.copyWith(fontSize: TypeScale.question.size, height: TypeScale.question.line / TypeScale.question.size),
              ).animate(key: ValueKey('q$index')).fadeIn(duration: Motion.base),
              const Gap(Space.s4),
              for (final (k, o) in opts.indexed) ...[
                OptionRow(
                  letter: 'ABCDE'[k],
                  text: '${o['text']}',
                  state: answer == null
                      ? OptState.none
                      : o['key'] == answer
                      ? OptState.right
                      : o['key'] == last?['picked']
                      ? OptState.wrong
                      : OptState.none,
                  tag: answer != null && o['key'] == last?['picked'] && last?['correct'] == true ? '+${last?['points']}' : null,
                  onTap: last == null ? () => _answer('${o['key']}') : null,
                ),
                const Gap(Space.s2),
              ],
              if (last != null) ...[
                const Gap(Space.s2),
                Text(
                  last['picked'] == null
                      ? 'Time is up!'
                      : last['correct'] == true
                      ? 'Correct! +${last['points']} points'
                      : 'Not quite.',
                  textAlign: TextAlign.center,
                  style: context.ty.body.bold.col(last['correct'] == true ? c.success : c.error),
                ).animate().fadeIn(duration: Motion.fast).scale(begin: const Offset(.9, .9), duration: Motion.fast),
                if (bot != null)
                  Text(
                    '${opp?['name'] ?? 'Bot'} ${bot['c'] == true ? 'got it right (+${bot['p']})' : 'got it wrong'}',
                    textAlign: TextAlign.center,
                    style: context.ty.cap.col(c.textMuted),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreTag extends StatelessWidget {
  const _ScoreTag({required this.name, required this.score, this.me = false, this.note});
  final String name;
  final int score;
  final bool me;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
      decoration: BoxDecoration(
        color: me ? c.primary : c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: me ? null : Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: context.ty.cap.bold.col(me ? c.onPrimary : c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          AnimatedSwitcher(
            duration: Motion.fast,
            child: Text('$score', key: ValueKey(score), style: context.ty.h3.tnum.col(me ? c.onPrimary : c.text)),
          ),
          if (note != null) Text(note!, style: context.ty.cap.col(c.textSubtle), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.value, required this.label, required this.low});
  final double value;
  final String label;
  final bool low;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(value: value.clamp(0, 1), strokeWidth: 4, color: low ? c.error : c.secondary, backgroundColor: c.surfaceSunken),
          Text(label, style: context.ty.sm.bold.tnum.col(low ? c.error : c.text)),
        ],
      ),
    );
  }
}

class _GameResult extends ConsumerWidget {
  const _GameResult({required this.data, required this.onAgain});
  final Map<String, dynamic> data;
  final VoidCallback onAgain;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final r = Map<String, dynamic>.from((data['result'] as Map?) ?? const {});
    final opp = r['opp'] == null ? null : Map<String, dynamic>.from(r['opp'] as Map);
    final out = gameOutcome(r);
    final won = r['won'] == true, waiting = r['won'] == null;
    final code = data['code'] as String?;
    final xp = (r['xp'] as num?)?.toInt() ?? 0;
    final rm = context.reduceMotion;
    final icon = IconTile(
      waiting
          ? PhosphorIcons.hourglassMedium(PhosphorIconsStyle.fill)
          : won
          ? PhosphorIcons.trophy(PhosphorIconsStyle.fill)
          : PhosphorIcons.handshake(PhosphorIconsStyle.fill),
      tone: waiting
          ? Tone.blue
          : won
          ? Tone.gold
          : Tone.navy,
      size: 88,
      radius: 44,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s6, Space.s5, Space.s8),
      children: [
        Center(
          child: rm ? icon : icon.animate().scale(begin: const Offset(.6, .6), duration: Motion.slow, curve: Curves.easeOutBack),
        ),
        const Gap(Space.s4),
        Text(
          waiting
              ? out
              : won
              ? 'You won!'
              : r['draw'] == true
              ? 'It is a draw'
              : 'Good game!',
          style: context.ty.h1,
          textAlign: TextAlign.center,
        ),
        const Gap(Space.s1),
        Text(
          waiting
              ? 'We will tell you when ${opp?['name'] ?? 'your friend'} has played.'
              : won
              ? 'Great speed and accuracy.'
              : 'Practise this subject and try again.',
          style: context.ty.sm.col(c.textMuted),
          textAlign: TextAlign.center,
        ),
        const Gap(Space.s5),
        Row(
          children: [
            Expanded(
              child: _Final(
                name: 'You',
                score: (r['score'] as num?)?.toInt() ?? 0,
                correct: (r['correct'] as num?)?.toInt() ?? 0,
                total: (r['total'] as num?)?.toInt() ?? 10,
                me: true,
              ),
            ),
            const Gap(Space.s3),
            Expanded(
              child: opp == null
                  ? AppCard(
                      child: Text('No friend yet', style: context.ty.sm.col(c.textMuted), textAlign: TextAlign.center),
                    )
                  : _Final(
                      name: '${opp['name']}',
                      score: (opp['score'] as num?)?.toInt() ?? 0,
                      correct: (opp['correct'] as num?)?.toInt() ?? 0,
                      total: (r['total'] as num?)?.toInt() ?? 10,
                      note: opp['finished'] == true ? null : 'Still to play',
                    ),
            ),
          ],
        ),
        if (xp > 0) ...[
          const Gap(Space.s4),
          Center(
            child: Pill('+$xp XP', kind: BadgeKind.gold, icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill)),
          ),
        ],
        const Gap(Space.s6),
        if (code != null && data['waiting'] == true) ...[
          Btn('Send the code $code', block: true, leading: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill), onPressed: () => shareDuelCode(context, code)),
          const Gap(Space.s2),
        ],
        Btn(
          data['mode'] == 'duel_friend' ? 'New duel' : 'Play again',
          block: true,
          kind: code != null && data['waiting'] == true ? BtnKind.secondary : BtnKind.primary,
          onPressed: onAgain,
        ),
        const Gap(Space.s2),
        Btn('Back to games', block: true, kind: BtnKind.ghost, onPressed: () => context.canPop() ? context.pop() : context.go('/games')),
      ],
    );
  }
}

class _Final extends StatelessWidget {
  const _Final({required this.name, required this.score, required this.correct, required this.total, this.me = false, this.note});
  final String name;
  final int score, correct, total;
  final bool me;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      color: me ? c.primarySoft : null,
      child: Column(
        children: [
          Text(name, style: context.ty.sm.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('$score', style: context.ty.h2.tnum),
          Text(note ?? '$correct of $total right', style: context.ty.cap.col(c.textMuted)),
        ],
      ),
    );
  }
}
