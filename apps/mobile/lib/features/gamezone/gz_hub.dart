import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/engagement.dart';
import '../../core/providers.dart';
import '../../ui/kit.dart' show toast;
import '../../widgets/fit_text.dart';
import '../../widgets/phosphor.g.dart';
import '../community/community_data.dart' show Json, asJson, asList;
import 'gz_avatar.dart';
import 'gz_data.dart';
import 'gz_fx.dart';
import 'gz_scenes.dart';
import 'gz_sound.dart';
import 'gz_theme.dart';

// Game Zone hub (D-157): your portrait under the spotlights, pick a game, a subject and a way to play, then BATTLE.

const _modes = [('quick', 'QUICK', GzC.blue), ('ai', 'VS AI', GzC.purple), ('friend', 'FRIEND', GzC.cyan), ('ranked', 'RANKED', GzC.red)];

class GzHubScreen extends ConsumerStatefulWidget {
  const GzHubScreen({super.key, this.game});
  final String? game;
  @override
  ConsumerState<GzHubScreen> createState() => _GzHubScreenState();
}

class _GzHubScreenState extends ConsumerState<GzHubScreen> {
  late String _game = GzGame.all.any((g) => g.id == widget.game) ? widget.game! : 'duel';
  String _mode = 'quick';
  String _level = 'medium';
  int? _subject;
  StreamSubscription<(String, Json)>? _invites;

  @override
  void initState() {
    super.initState();
    final st = ref.read(settingsProvider);
    Engagement.visited(context, 'games');
    GzSound.instance.sounds = st.gameSounds;
    GzSound.instance.setMusic(st.gameMusic);
    GzUserFeed.instance.hold();
    _invites = GzUserFeed.instance.events.listen((e) {
      if (e.$1 == 'rematch' && mounted) _showInvite(e.$2);
    });
  }

  @override
  void dispose() {
    _invites?.cancel();
    GzUserFeed.instance.release();
    super.dispose();
  }

  Future<void> _showInvite(Json inv) async {
    final g = GzGame.of('${inv['game']}');
    final ok = await showGzDialog<bool>(
      context,
      title: '${'${inv['name'] ?? 'A friend'}'.toUpperCase()} WANTS A REMATCH',
      body: 'Play ${g.name} again? The invite lasts 2 minutes.',
      yes: 'PLAY',
      no: 'NOT NOW',
    );
    if (ok != true || !mounted) return;
    final (id, err) = await gzJoin('${inv['code']}');
    if (!mounted) return;
    if (id == null) return toast(context, err ?? 'That invite has ended.');
    context.push('/games/m/$id');
  }

  Future<void> _play(Json home) async {
    final g = GzGame.of(_game);
    final games = asList(home['games']);
    final info = games.firstWhere((x) => x['id'] == _game, orElse: () => const {});
    if (info['on'] == false) {
      return toast(context, info['ready'] == false ? 'This game is getting ready. Try another game for now.' : 'This game is paused for now.');
    }
    int? subject;
    if (g.needsSubject) {
      subject = _subject ?? _defaultSubject(home);
      if (subject == null) return toast(context, 'Add your JAMB subjects in your profile first.');
    } else if (g.id == 'memory') {
      subject = _subject;
    }
    final q = <String, String>{'game': g.id, 'mode': _mode, 'level': _level, if (subject != null) 'subject': '$subject'};
    await context.push(Uri(path: '/games/find', queryParameters: q).toString());
    if (mounted) ref.invalidate(gzHomeProvider);
  }

  int? _defaultSubject(Json home) {
    final subs = asList(home['subjects']);
    if (subs.isEmpty) return null;
    final notEng = subs.where((s) => s['code'] != 'eng');
    return gzMs((notEng.isNotEmpty ? notEng.first : subs.first)['id']);
  }

  Future<void> _joinCode() async {
    final code = await showDialog<String>(context: context, builder: (_) => const _CodeDialog());
    if (code == null || code.trim().length < 6 || !mounted) return;
    final (id, err) = await gzJoin(code);
    if (!mounted) return;
    if (id == null) return toast(context, err ?? 'Could not join.');
    context.push('/games/m/$id');
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(gzHomeProvider);
    final page = AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: GzC.ink,
        body: Stack(
          children: [
            const Positioned.fill(child: ArenaScene()),
            SafeArea(
              child: home.when(
                data: (h) => _body(h),
                loading: () => const GzLoading(),
                error: (e, _) => GzErrorView(text: gzErrorText(e), onRetry: () => ref.invalidate(gzHomeProvider)),
              ),
            ),
          ],
        ),
      ),
    );
    return GzMusic(track: 'hub', child: page);
  }

  Future<void> _soundSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(settingsProvider);
          return Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 20 + MediaQuery.paddingOf(context).bottom),
            decoration: const BoxDecoration(
              color: GzC.navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: GzC.ink, width: 4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('SOUND', style: gzFont(22)),
                const SizedBox(height: 12),
                _Toggle(
                  text: 'Sound effects',
                  sub: 'Taps, right and wrong answers, countdowns, wins',
                  on: s.gameSounds,
                  onChanged: (v) {
                    ref.read(settingsProvider.notifier).update((x) => x.copyWith(gameSounds: v));
                    GzSound.instance.sounds = v;
                    if (v) GzFeel.sfx(GzSfx.coin);
                  },
                ),
                const SizedBox(height: 10),
                _Toggle(
                  text: 'Music',
                  sub: 'Game Zone music in the hub and in games',
                  on: s.gameMusic,
                  onChanged: (v) {
                    ref.read(settingsProvider.notifier).update((x) => x.copyWith(gameMusic: v));
                    GzSound.instance.setMusic(v);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _body(Json h) {
    final me = asJson(h['me']);
    final face = GzFace.from(me['avatar']);
    final rating = gzMs(me['rating']) ?? 1000;
    final rank = GzRank.of(rating);
    final week = asJson(h['week']);
    final games = asList(h['games']);
    final g = GzGame.of(_game);
    final info = games.firstWhere((x) => x['id'] == _game, orElse: () => const {});
    final subs = asList(h['subjects']);
    final sel = _subject ?? (g.needsSubject ? _defaultSubject(h) : null);
    final subName = subs.firstWhere((s) => gzMs(s['id']) == sel, orElse: () => const {})['name'];
    final online = gzMs(info['online']) ?? 0;
    final calm = context.calm;
    final active = h['active'];

    final (cta, sub) = switch (_mode) {
      'ai' => ('PRACTISE', '${g.name}${subName != null ? ' · $subName' : ''} vs SolutionTee Bot'),
      'friend' => ('INVITE', 'Get a code and send it to a friend'),
      'ranked' => ('RANKED', '${rank.label}${rank.toNext > 0 ? ' · ${rank.toNext} to ${rank.next}' : ''}'),
      _ => ('BATTLE!', '${g.name}${subName != null ? ' · $subName' : ''} · ${online > 0 ? '$online playing now' : 'a bot joins if nobody is free'}'),
    };

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(gzHomeProvider),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Header.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(
              children: [
                GzRoundIcon(icon: PhosphorIcons.caretLeft(PhosphorIconsStyle.bold), label: 'Back', onTap: () => context.pop()),
                const SizedBox(width: 8),
                RankShield(color: rank.color, text: rank.division == 0 ? 'D' : ['', 'I', 'II', 'III'][rank.division], size: 42),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FitText(rank.label.toUpperCase(), style: gzFont(15), minScale: .7),
                      const SizedBox(height: 3),
                      _Bar(value: rank.progress, color: GzC.mint),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Counter(icon: const _Coin(), text: gzNum(gzMs(week['xp']) ?? 0), label: 'XP this week'),
                const SizedBox(width: 6),
                _Counter(
                  icon: Icon(PhosphorIcons.trophy(PhosphorIconsStyle.fill), size: 20, color: GzC.goldLight),
                  text: '${gzMs(week['won']) ?? 0}',
                  label: 'wins this week',
                ),
                GzRoundIcon(
                  icon: GzSound.instance.music || GzSound.instance.sounds
                      ? PhosphorIcons.speakerHigh(PhosphorIconsStyle.fill)
                      : PhosphorIcons.speakerSlash(PhosphorIconsStyle.fill),
                  label: 'Sound and music',
                  size: 36,
                  onTap: _soundSheet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Name plate: the whole name (owner: never cut a name), the rating under it.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 5, 16, 6),
                decoration: BoxDecoration(
                  color: GzC.navy,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GzC.brand, width: 2.5),
                  boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 3))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FitText('${me['name'] ?? 'You'}'.toUpperCase(), style: gzFont(18, shadow: 0), minScale: .7, textAlign: TextAlign.center),
                    Text(
                      '${rank.label} · ${gzNum(rating)} ★'.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: gzFont(13, color: GzC.goldLight, shadow: 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (active != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GameButton(
                color: GzC.mint,
                height: 48,
                onTap: () => context.push('/games/m/$active'),
                child: Text('BACK TO YOUR GAME', style: gzFont(18, color: GzC.navy, shadow: 0)),
              ),
            ),
          // Your portrait on a pedestal.
          SizedBox(
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned(top: -40, child: SunRays(size: 320)),
                Positioned(
                  bottom: 6,
                  child: CustomPaint(size: const Size(200, 54), painter: _PedestalPainter()),
                ),
                Positioned(
                  bottom: 30,
                  child: GestureDetector(
                    onTap: () => showAvatarEditor(context, ref, face),
                    child: (calm
                        ? GzPortrait(face: face, size: 150, name: 'Your game picture')
                        : GzPortrait(
                            face: face,
                            size: 150,
                            name: 'Your game picture',
                          ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: -6, duration: 1600.ms, curve: Curves.easeInOut)),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  right: MediaQuery.sizeOf(context).width / 2 - 86,
                  child: GzRoundIcon(
                    icon: PhosphorIcons.pencilSimple(PhosphorIconsStyle.bold),
                    label: 'Change your game picture',
                    size: 38,
                    color: GzC.brand,
                    iconColor: GzC.navy,
                    onTap: () => showAvatarEditor(context, ref, face),
                  ),
                ),
              ],
            ),
          ),
          // Selected game.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Text(g.name.toUpperCase(), style: gzFont(26, spacing: 1)),
                const SizedBox(height: 2),
                Text(
                  g.blurb,
                  textAlign: TextAlign.center,
                  style: gzBody(13, color: GzC.subLight),
                ),
              ],
            ),
          ),
          if (g.needsSubject || g.id == 'memory') ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (g.id == 'memory') _SubjectChip(text: 'ALL', on: _subject == null, onTap: () => setState(() => _subject = null)),
                  for (final s in subs)
                    _SubjectChip(text: '${s['name']}'.toUpperCase(), on: gzMs(s['id']) == sel, onTap: () => setState(() => _subject = gzMs(s['id']))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final (id, name, col) in _modes) ...[
                  Expanded(
                    child: _ModeButton(text: name, color: col, on: _mode == id, onTap: () => setState(() => _mode = id)),
                  ),
                  if (id != 'ranked') const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (_mode == 'ai') ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final (id, name) in const [('easy', 'EASY'), ('medium', 'MEDIUM'), ('hard', 'HARD'), ('expert', 'EXPERT'), ('legend', 'LEGEND')]) ...[
                    Expanded(
                      child: _SubjectChip(text: name, on: _level == id, onTap: () => setState(() => _level = id), wide: true),
                    ),
                    if (id != 'legend') const SizedBox(width: 5),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GameButton(
              color: GzC.gold,
              depthColor: GzC.goldDeep,
              height: 78,
              radius: 22,
              depth: 8,
              semantics: '$cta. $sub',
              onTap: () => _play(h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cta, style: gzFont(34, color: GzC.navy, shadow: 0, spacing: 2, height: 1)),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: gzBody(12, color: const Color(0xFF6B4A0A)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('GAMES', style: gzFont(18)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: GzGame.all.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final game = GzGame.all[i];
                final gi = games.firstWhere((x) => x['id'] == game.id, orElse: () => const {});
                final card = _GameCard(
                  game: game,
                  on: _game == game.id,
                  online: gzMs(gi['online']) ?? 0,
                  open: gi['on'] != false,
                  onTap: () => setState(() {
                    _game = game.id;
                    if (!game.needsSubject) _subject = null;
                  }),
                );
                return calm ? card : card.animate(delay: (40 * i).ms).fadeIn(duration: 240.ms).slideX(begin: .2, curve: Curves.easeOut);
              },
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: GameButton(
                    color: GzC.cyan,
                    height: 52,
                    onTap: _joinCode,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIcons.keyhole(PhosphorIconsStyle.fill), color: Colors.white, size: 20),
                        const SizedBox(width: 6),
                        Flexible(child: Text('JOIN A CODE', maxLines: 1, style: gzFont(16))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GameButton(
                    color: GzC.purple,
                    height: 52,
                    onTap: () => context.push('/games/ranks'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIcons.trophy(PhosphorIconsStyle.fill), color: GzC.goldLight, size: 20),
                        const SizedBox(width: 6),
                        Flexible(child: Text('RANKS', maxLines: 1, style: gzFont(16))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GzPanel(
              child: Row(
                children: [
                  _Stat(value: '${gzMs(week['played']) ?? 0}', label: 'played'),
                  _Stat(value: '${gzMs(week['won']) ?? 0}', label: 'won'),
                  _Stat(value: '+${gzNum(gzMs(week['xp']) ?? 0)}', label: 'XP', color: GzC.goldLight),
                ],
              ),
            ),
          ),
          if (asList(h['recent']).isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('RECENT MATCHES', style: gzFont(16)),
            ),
            const SizedBox(height: 8),
            for (final m in asList(h['recent']))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _RecentRow(m: m),
              ),
          ],
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => context.push('/games/classic'),
              icon: Icon(PhosphorIcons.usersThree(PhosphorIconsStyle.fill), color: GzC.subLight, size: 18),
              label: Text('Live Exam Arenas and classic games', style: gzBody(13, color: GzC.subLight)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- hub parts

class _PedestalPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(4, 6, s.width - 8, s.height - 10);
    c.drawOval(r.shift(const Offset(0, 5)), Paint()..color = GzC.ink);
    c.drawOval(r, Paint()..color = GzC.navy);
    c.drawOval(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = GzC.brand,
    );
    c.drawOval(r.deflate(12).shift(const Offset(0, -3)), Paint()..color = const Color(0xFF1B3A6B));
  }

  @override
  bool shouldRepaint(_PedestalPainter o) => false;
}

class _Coin extends StatelessWidget {
  const _Coin();
  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: GzC.brand,
      shape: BoxShape.circle,
      border: Border.all(color: GzC.ink, width: 2),
    ),
    child: Icon(PhosphorIcons.lightning(PhosphorIconsStyle.fill), size: 13, color: GzC.navy),
  );
}

class _Counter extends StatelessWidget {
  const _Counter({required this.icon, required this.text, required this.label});
  final Widget icon;
  final String text;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$text $label',
    child: Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: GzC.ink.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GzC.line, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 5),
          Text(text, style: gzBody(14)),
        ],
      ),
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    height: 12,
    decoration: BoxDecoration(
      color: GzC.navy,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: GzC.ink, width: 2),
    ),
    child: FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: value.clamp(.04, 1),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      ),
    ),
  );
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({required this.text, required this.on, required this.onTap, this.wide = false});
  final String text;
  final bool on;
  final VoidCallback onTap;
  final bool wide;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(right: wide ? 0 : 6, bottom: 4),
    child: Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        onTap: () {
          GzFeel.tap();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 34,
          padding: EdgeInsets.symmetric(horizontal: wide ? 4 : 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? Colors.white : GzC.navy.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GzC.ink, width: 2),
            boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 3))],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, maxLines: 1, style: gzFont(14, color: on ? GzC.navy : GzC.subLight, shadow: 0)),
          ),
        ),
      ),
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.text, required this.color, required this.on, required this.onTap});
  final String text;
  final Color color;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: on,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(19), color: on ? GzC.goldLight : Colors.transparent),
      child: GameButton(
        color: color,
        height: 46,
        radius: 15,
        depth: 5,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onTap: onTap,
        child: FittedBox(child: Text(text, style: gzFont(15))),
      ),
    ),
  );
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.on, required this.online, required this.open, required this.onTap});
  final GzGame game;
  final bool on;
  final int online;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = game.dark ? GzC.navy : Colors.white;
    return Semantics(
      button: true,
      selected: on,
      label: '${game.name}, ${game.players}${open ? '' : ', coming soon'}',
      child: GestureDetector(
        onTap: () {
          GzFeel.tap();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          width: 92,
          margin: EdgeInsets.only(top: on ? 0 : 8, bottom: on ? 8 : 0),
          decoration: BoxDecoration(
            color: game.color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on ? GzC.goldLight : GzC.ink, width: 3),
            boxShadow: [
              const BoxShadow(color: GzC.ink, offset: Offset(0, 5)),
              if (on) BoxShadow(color: GzC.goldLight.withValues(alpha: .5), blurRadius: 14),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                Positioned(left: 0, right: 0, top: 0, height: 8, child: ColoredBox(color: Colors.white.withValues(alpha: .22))),
                Column(
                  children: [
                    const SizedBox(height: 6),
                    GameIcon(game.id, size: 70),
                    Text(
                      game.short,
                      textAlign: TextAlign.center,
                      style: gzFont(13, color: fg, shadow: game.dark ? 0 : 1.5, height: 1.05),
                    ),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      color: GzC.ink.withValues(alpha: .45),
                      child: Text(
                        !open ? 'SOON' : (online > 0 ? '$online ONLINE' : game.players.toUpperCase()),
                        textAlign: TextAlign.center,
                        style: gzFont(10, color: online > 0 && open ? GzC.mint : Colors.white, shadow: 0),
                      ),
                    ),
                  ],
                ),
                if (!open) Positioned.fill(child: ColoredBox(color: GzC.ink.withValues(alpha: .35))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color = Colors.white});
  final String value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: gzFont(22, color: color)),
        Text(label, style: gzBody(12, color: GzC.sub)),
      ],
    ),
  );
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.m});
  final Json m;
  @override
  Widget build(BuildContext context) {
    final g = GzGame.of('${m['game']}');
    final place = gzMs(m['place']) ?? 0;
    final n = gzMs(m['players']) ?? 2;
    final win = place == 1;
    final text = n > 2 && g.id != 'relay' ? (win ? 'WON! 1ST OF $n' : '${_ordinal(place)} OF $n') : (win ? 'WIN' : 'LOSS');
    final delta = gzMs(m['rating_delta']);
    return GestureDetector(
      onTap: () => context.push('/games/m/${m['id']}'),
      child: GzPanel(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 40,
              decoration: BoxDecoration(
                color: g.color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GzC.ink, width: 2),
              ),
              child: Center(child: GameIcon(g.id, size: 36)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: gzFont(15, color: win ? GzC.mint : const Color(0xFFFFB3C3))),
                  Text(
                    '${g.name}${m['vs'] != null && n == 2 ? ' vs ${m['vs']}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: gzBody(12, color: GzC.sub),
                  ),
                ],
              ),
            ),
            if (delta != null && delta != 0) ...[
              Text('${delta > 0 ? '+' : ''}$delta', style: gzFont(14, color: delta > 0 ? GzC.mint : GzC.pink)),
              const SizedBox(width: 8),
            ],
            Text('+${gzMs(m['xp']) ?? 0} XP', style: gzFont(14, color: GzC.goldLight)),
          ],
        ),
      ),
    );
  }
}

String _ordinal(int n) => n <= 0 ? '-' : '$n${n % 100 >= 11 && n % 100 <= 13 ? 'TH' : (const {1: 'ST', 2: 'ND', 3: 'RD'}[n % 10] ?? 'TH')}';

String gzOrdinal(int n) => _ordinal(n);

// ---------------------------------------------------------------- shared small widgets

class GzRoundIcon extends StatelessWidget {
  const GzRoundIcon({super.key, required this.icon, required this.label, required this.onTap, this.size = 44, this.color, this.iconColor = Colors.white});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final Color? color;
  final Color iconColor;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: () {
        GzFeel.tap();
        onTap();
      },
      child: Container(
        width: size < 48 ? 48 : size,
        height: size < 48 ? 48 : size,
        alignment: Alignment.center,
        color: Colors.transparent,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color ?? GzC.ink.withValues(alpha: .8),
            shape: BoxShape.circle,
            border: Border.all(color: color == null ? GzC.line : GzC.ink, width: 2.5),
            boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 3))],
          ),
          child: Icon(icon, color: iconColor, size: size * .45),
        ),
      ),
    ),
  );
}

class GzLoading extends StatelessWidget {
  const GzLoading({super.key, this.text = 'LOADING'});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = Text(text, style: gzFont(26, spacing: 2));
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 120, height: 96, child: Center(child: GameIcon('duel', size: 110))),
          const SizedBox(height: 12),
          context.calm ? t : t.animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: .45, end: 1, duration: 700.ms),
        ],
      ),
    );
  }
}

class GzErrorView extends StatelessWidget {
  const GzErrorView({super.key, required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: GzPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill), color: GzC.goldLight, size: 40),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: gzBody(15)),
            const SizedBox(height: 16),
            GameButton(
              color: GzC.gold,
              height: 50,
              onTap: onRetry,
              child: Text('TRY AGAIN', style: gzFont(18, color: GzC.navy, shadow: 0)),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => context.pop(),
              child: Text('Go back', style: gzBody(14, color: GzC.subLight)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A game-style yes/no dialog.
Future<T?> showGzDialog<T>(BuildContext context, {required String title, required String body, required String yes, String? no}) => showDialog<T>(
  context: context,
  barrierColor: GzC.ink.withValues(alpha: .7),
  builder: (ctx) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(24),
    child: GzPanel(
      color: GzC.navy,
      border: GzC.ink,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, textAlign: TextAlign.center, style: gzFont(22)),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: gzBody(14, color: GzC.subLight, weight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (no != null) ...[
                Expanded(
                  child: GameButton(
                    color: GzC.navy2,
                    height: 50,
                    onTap: () => Navigator.pop(ctx, false),
                    child: Text(no, style: gzFont(16)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: GameButton(
                  color: GzC.gold,
                  height: 50,
                  onTap: () => Navigator.pop(ctx, true),
                  child: Text(yes, style: gzFont(16, color: GzC.navy, shadow: 0)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();
  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(24),
    child: GzPanel(
      color: GzC.navy,
      border: GzC.ink,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('JOIN A FRIEND', style: gzFont(22)),
          const SizedBox(height: 6),
          Text(
            'Type the 6-letter code your friend sent you.',
            textAlign: TextAlign.center,
            style: gzBody(14, color: GzC.subLight, weight: FontWeight.w500),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _c,
            autofocus: true,
            textAlign: TextAlign.center,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')), _Upper()],
            style: gzFont(32, color: GzC.navy, shadow: 0, spacing: 8),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: GzC.cream,
              hintText: 'ABC123',
              hintStyle: gzFont(32, color: GzC.sub, shadow: 0, spacing: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: GzC.ink, width: 3),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: GzC.ink, width: 3),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: GzC.brand, width: 3),
              ),
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder(
            valueListenable: _c,
            builder: (_, v, _) => GameButton(
              color: GzC.gold,
              height: 52,
              onTap: v.text.length == 6 ? () => Navigator.pop(context, v.text) : null,
              child: Text('JOIN', style: gzFont(20, color: GzC.navy, shadow: 0)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Upper extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) => n.copyWith(text: n.text.toUpperCase());
}

// ---------------------------------------------------------------- avatar editor

Future<void> showAvatarEditor(BuildContext context, WidgetRef ref, GzFace face) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AvatarEditor(face: face),
  );
  if (saved == true) ref.invalidate(gzHomeProvider);
}

class _AvatarEditor extends StatefulWidget {
  const _AvatarEditor({required this.face});
  final GzFace face;
  @override
  State<_AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<_AvatarEditor> {
  late GzLook _look = widget.face.look;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final r = await gzSaveAvatar(_look.toJson());
    if (!mounted) return;
    setState(() => _saving = false);
    if (r == null) return toast(context, 'Could not save. Check your internet and try again.');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final usePhoto = widget.face.hasPhoto && _look.photo;
    final preview = GzFace(photo: usePhoto ? widget.face.photo : null, look: _look, hasPhoto: widget.face.hasPhoto);
    return DraggableScrollableSheet(
      initialChildSize: .86,
      maxChildSize: .95,
      minChildSize: .5,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: GzC.navy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: GzC.ink, width: 4)),
        ),
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(16, 10, 16, 24 + MediaQuery.paddingOf(context).bottom),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: GzC.line, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 10),
            Center(child: Text('YOUR GAME PICTURE', style: gzFont(22))),
            const SizedBox(height: 12),
            Center(
              child: GzPortrait(face: preview, size: 140, name: 'Preview'),
            ),
            const SizedBox(height: 14),
            if (widget.face.hasPhoto)
              _Toggle(
                text: 'Use my photo',
                sub: _look.photo ? 'Other players see your photo.' : 'Other players see the avatar below.',
                on: _look.photo,
                onChanged: (v) => setState(() => _look = _look.copyWith(photo: v)),
              )
            else
              Text(
                'Add a profile photo in Community and it shows here. Until then, build your avatar.',
                textAlign: TextAlign.center,
                style: gzBody(13, color: GzC.subLight, weight: FontWeight.w500),
              ),
            if (!usePhoto) ...[
              _Label('SKIN'),
              _Swatches(
                colors: GzLook.skins,
                value: _look.skin,
                onPick: (c) => setState(() => _look = _look.copyWith(skin: c)),
              ),
              _Label('HAIR'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final h in GzLook.hairs)
                    _LookTile(
                      on: _look.hair == h,
                      label: GzLook.hairNames[h]!,
                      onTap: () => setState(() => _look = _look.copyWith(hair: h)),
                      child: CustomPaint(painter: CartoonPainter(_look.copyWith(hair: h))),
                    ),
                ],
              ),
              _Label('HAIR COLOUR'),
              _Swatches(
                colors: GzLook.hairColors,
                value: _look.hairColor,
                onPick: (c) => setState(() => _look = _look.copyWith(hairColor: c)),
              ),
              _Label('SHIRT'),
              _Swatches(
                colors: GzLook.shirts,
                value: _look.shirt,
                onPick: (c) => setState(() => _look = _look.copyWith(shirt: c)),
              ),
              _Label('FACE'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in GzLook.faces)
                    _LookTile(
                      on: _look.face == f,
                      label: GzLook.faceNames[f]!,
                      onTap: () => setState(() => _look = _look.copyWith(face: f)),
                      child: CustomPaint(painter: CartoonPainter(_look.copyWith(face: f))),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _Toggle(
                text: 'Glasses',
                on: _look.glasses,
                onChanged: (v) => setState(() => _look = _look.copyWith(glasses: v)),
              ),
              _Label('BACKGROUND'),
              _Swatches(
                colors: GzLook.bgs,
                value: _look.bg,
                onPick: (c) => setState(() => _look = _look.copyWith(bg: c)),
              ),
            ],
            const SizedBox(height: 20),
            GameButton(
              color: GzC.gold,
              height: 56,
              onTap: _saving ? null : _save,
              child: Text(_saving ? 'SAVING…' : 'SAVE', style: gzFont(22, color: GzC.navy, shadow: 0)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 16, 0, 8),
    child: Text(text, style: gzFont(15, color: GzC.subLight)),
  );
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.colors, required this.value, required this.onPick});
  final List<Color> colors;
  final Color value;
  final ValueChanged<Color> onPick;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final c in colors)
        Semantics(
          button: true,
          selected: c.toARGB32() == value.toARGB32(),
          label: 'Colour',
          child: GestureDetector(
            onTap: () {
              GzFeel.tap();
              onPick(c);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: c.toARGB32() == value.toARGB32() ? GzC.goldLight : GzC.ink, width: c.toARGB32() == value.toARGB32() ? 4 : 2.5),
                boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 3))],
              ),
            ),
          ),
        ),
    ],
  );
}

class _LookTile extends StatelessWidget {
  const _LookTile({required this.on, required this.label, required this.onTap, required this.child});
  final bool on;
  final String label;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: on,
    label: label,
    child: GestureDetector(
      onTap: () {
        GzFeel.tap();
        onTap();
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: on ? GzC.goldLight : GzC.ink, width: on ? 4 : 2.5),
              boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 3))],
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
          ),
          const SizedBox(height: 4),
          Text(label, style: gzBody(11, color: on ? GzC.goldLight : GzC.subLight)),
        ],
      ),
    ),
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.text, required this.on, required this.onChanged, this.sub});
  final String text;
  final String? sub;
  final bool on;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => GzPanel(
    padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: gzBody(15)),
              if (sub != null)
                Text(
                  sub!,
                  style: gzBody(12, color: GzC.sub, weight: FontWeight.w500),
                ),
            ],
          ),
        ),
        Switch(value: on, onChanged: onChanged, activeTrackColor: GzC.mint, activeThumbColor: Colors.white),
      ],
    ),
  );
}
