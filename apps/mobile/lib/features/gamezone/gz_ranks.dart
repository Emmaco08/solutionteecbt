import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/phosphor.g.dart';
import '../community/community_data.dart' show Json, asJson, asList;
import 'gz_avatar.dart';
import 'gz_data.dart';
import 'gz_hub.dart';
import 'gz_scenes.dart';
import 'gz_sound.dart';
import 'gz_theme.dart';

// Game Zone ranks (D-157): the best ratings, for all games or one game, with a podium for the top three.

class GzRanksScreen extends ConsumerStatefulWidget {
  const GzRanksScreen({super.key});
  @override
  ConsumerState<GzRanksScreen> createState() => _GzRanksScreenState();
}

class _GzRanksScreenState extends ConsumerState<GzRanksScreen> {
  String? _game;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(gzLeadersProvider(_game));
    return GzMusic(
      track: 'hub',
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: GzC.ink,
          body: Stack(
            children: [
              const Positioned.fill(
                child: ArenaScene(top: Color(0xFF2A0F5C), mid: Color(0xFF10284D), glow: GzC.purple, beams: false),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(
                        children: [
                          GzRoundIcon(icon: PhosphorIcons.caretLeft(PhosphorIconsStyle.bold), label: 'Back', onTap: () => context.pop()),
                          const SizedBox(width: 8),
                          Text('RANKS', style: gzFont(28, spacing: 1)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _Tab(text: 'ALL GAMES', on: _game == null, onTap: () => setState(() => _game = null)),
                          for (final g in GzGame.all) _Tab(text: g.name.toUpperCase(), on: _game == g.id, onTap: () => setState(() => _game = g.id)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: data.when(
                        data: (d) => _list(d),
                        loading: () => const GzLoading(),
                        error: (e, _) => GzErrorView(text: gzErrorText(e), onRetry: () => ref.invalidate(gzLeadersProvider(_game))),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(Json d) {
    final rows = asList(d['rows']);
    final me = asJson(d['me']);
    final myRating = gzMs(me['rating']) ?? 1000;
    final rank = GzRank.of(myRating);
    final calm = context.calm;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(gzLeadersProvider(_game)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          GzPanel(
            child: Row(
              children: [
                RankShield(color: rank.color, text: rank.division == 0 ? 'D' : ['', 'I', 'II', 'III'][rank.division], size: 46),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOU · ${rank.label}', style: gzFont(17)),
                      Text(
                        (gzMs(me['played']) ?? 0) < 3
                            ? 'Play ${3 - (gzMs(me['played']) ?? 0)} more games to join the board.'
                            : (rank.toNext > 0 ? '${rank.toNext} points to ${rank.next}. Ranked wins move you up.' : 'Top tier. Stay there!'),
                        style: gzBody(12, color: GzC.subLight, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Text(gzNum(myRating), style: gzFont(22, color: GzC.goldLight)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  const GameIcon('duel', size: 90),
                  const SizedBox(height: 10),
                  Text('NO RANKS YET', style: gzFont(22)),
                  const SizedBox(height: 4),
                  Text(
                    'Play 3 games to be the first on the board!',
                    textAlign: TextAlign.center,
                    style: gzBody(14, color: GzC.subLight),
                  ),
                ],
              ),
            )
          else ...[
            if (rows.length >= 3) _Podium(rows: rows.take(3).toList()),
            const SizedBox(height: 12),
            for (final (i, r) in rows.skip(rows.length >= 3 ? 3 : 0).indexed)
              (calm ? _Row(r: r) : _Row(r: r).animate(delay: (30 * i).ms).fadeIn(duration: 200.ms).slideY(begin: .2)),
          ],
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.text, required this.on, required this.onTap});
  final String text;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6, bottom: 4),
    child: GestureDetector(
      onTap: () {
        GzFeel.tap();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? GzC.goldLight : GzC.navy,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GzC.ink, width: 2),
          boxShadow: const [BoxShadow(color: GzC.ink, offset: Offset(0, 3))],
        ),
        child: Text(text, style: gzFont(13, color: on ? GzC.navy : GzC.subLight, shadow: 0)),
      ),
    ),
  );
}

class _Podium extends StatelessWidget {
  const _Podium({required this.rows});
  final List<Json> rows;

  @override
  Widget build(BuildContext context) {
    Widget spot(Json r, int place, double h, Color c) {
      final pic = GzPortrait(face: GzFace.from(r['avatar']), size: place == 1 ? 86 : 68, ring: c, name: '${r['name']}');
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            pic.popIn(delay: (200 * (3 - place)).ms, calm: context.calm),
            const SizedBox(height: 4),
            Text(r['me'] == true ? 'YOU' : '${r['name']}'.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: gzFont(14)),
            Text(gzNum(gzMs(r['rating']) ?? 0), style: gzFont(13, color: GzC.goldLight)),
            const SizedBox(height: 4),
            Container(
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: c,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                border: Border.all(color: GzC.ink, width: 3),
              ),
              alignment: Alignment.center,
              child: Text('$place', style: gzFont(30, color: GzC.navy, shadow: 0)),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [spot(rows[1], 2, 70, const Color(0xFFC9D6EA)), spot(rows[0], 1, 100, GzC.brand), spot(rows[2], 3, 50, const Color(0xFFCD7F4A))],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.r});
  final Json r;
  @override
  Widget build(BuildContext context) {
    final me = r['me'] == true;
    final rating = gzMs(r['rating']) ?? 1000;
    final rank = GzRank.of(rating);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
        decoration: BoxDecoration(
          color: me ? GzC.navy2 : GzC.ink.withValues(alpha: .75),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: me ? GzC.brand : GzC.line, width: 2),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text('${r['rank']}', style: gzFont(16, color: GzC.subLight)),
            ),
            GzPortrait(face: GzFace.from(r['avatar']), size: 38, ring: rank.color, name: '${r['name']}'),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(me ? 'YOU' : '${r['name']}'.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: gzFont(15)),
                  Text('${rank.label} · ${gzMs(r['won']) ?? 0} wins', style: gzBody(11, color: GzC.sub)),
                ],
              ),
            ),
            Text(gzNum(rating), style: gzFont(17, color: GzC.goldLight)),
          ],
        ),
      ),
    );
  }
}
