import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ads.dart';
import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/r2_image.dart';
import '../../widgets/states.dart';
import 'news_social.dart';

/// Category → cover gradient + icon (prototype `news-cover c-navy|c-blue|c-gold|c-green`).
/// Categories are the admin's: update, exam, app, tips.
({List<Color> g, Color fg, IconData icon, String label}) newsLook(String? category) => switch (category) {
  'exam' => (
    g: const [Palette.navy900, Palette.blue700],
    fg: Colors.white,
    icon: PhosphorIcons.identificationCard(PhosphorIconsStyle.fill),
    label: 'Exam news',
  ),
  'app' => (g: const [Palette.blue700, Palette.blue400], fg: Colors.white, icon: PhosphorIcons.deviceMobile(PhosphorIconsStyle.fill), label: 'App news'),
  'tips' => (g: const [Palette.green700, Palette.green500], fg: Colors.white, icon: PhosphorIcons.lightbulb(PhosphorIconsStyle.fill), label: 'Study tips'),
  _ => (g: const [Palette.navy900, Palette.blue700], fg: Colors.white, icon: PhosphorIcons.newspaper(PhosphorIconsStyle.fill), label: 'Update'),
};

String newsDate(Map<String, dynamic> n) {
  final d = DateTime.tryParse((n['publish_at'] as String?) ?? '')?.toLocal();
  if (d == null) return '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

int readMins(Map<String, dynamic> n) => (((n['body'] as String?) ?? '').split(RegExp(r'\s+')).length / 200).ceil().clamp(1, 30);

/// News cover: the admin's picture when there is one (signed link, skipped with data saver), drawn over
/// the category gradient so the gradient shows while it loads or if it fails.
class NewsCover extends ConsumerWidget {
  const NewsCover({super.key, required this.n, this.aspect = 16 / 8, this.iconSize = 64, this.thumb = false});
  final Map<String, dynamic> n;
  final double aspect, iconSize;
  final bool thumb;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = newsLook(n['category'] as String?);
    final key = n['image_path'] as String?;
    final show = key != null && !ref.watch(settingsProvider).dataSaver;
    final cover = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: look.g, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: thumb ? BorderRadius.circular(12) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!thumb)
            Positioned(
              right: -30,
              bottom: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), shape: BoxShape.circle),
              ),
            ),
          Icon(look.icon, size: thumb ? 30 : iconSize, color: look.fg.withValues(alpha: .9)),
          if (show)
            Positioned.fill(
              child: R2Image(imageKey: key, semanticLabel: '${n['title'] ?? 'News'} picture', decodeWidth: thumb ? 200 : 900),
            ),
        ],
      ),
    );
    return thumb ? SizedBox(width: 64, height: 64, child: cover) : AspectRatio(aspectRatio: aspect, child: cover);
  }
}

/// News tile for the Home carousel (`.news-tile`).
class NewsTile extends StatelessWidget {
  const NewsTile({super.key, required this.n});
  final Map<String, dynamic> n;
  @override
  Widget build(BuildContext context) => AppCard(
    pad: false,
    clip: true,
    onTap: () => context.push('/news/${n['id']}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NewsCover(n: n),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, Space.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Pill(newsLook(n['category'] as String?).label),
                  if (n['is_pinned'] == true) ...[
                    const Gap(Space.s2),
                    Pill('Pinned', kind: BadgeKind.gold, icon: PhosphorIcons.pushPin(PhosphorIconsStyle.fill)),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                n['title'] as String,
                style: context.ty.body.bold.copyWith(height: 21 / 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text('${newsDate(n)} · ${readMins(n)} min read', style: context.ty.cap.col(context.c.textMuted)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// News list (prototype: news): featured first item, then a list.
class NewsListScreen extends ConsumerStatefulWidget {
  const NewsListScreen({super.key});
  @override
  ConsumerState<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends ConsumerState<NewsListScreen> {
  /// null = all; a category key; or 'saved' (D-141).
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(newsMetaProvider).value ?? const <String, NewsMeta>{};
    return Scaffold(
      appBar: const TopBar(title: 'News'),
      body: asyncView(ref.watch(newsProvider), (all) {
        final cats = {for (final n in all) '${n['category'] ?? 'update'}'}.toList();
        final list = [
          for (final n in all)
            if (_filter == null || (_filter == 'saved' ? meta['${n['id']}']?.saved == true : '${n['category'] ?? 'update'}' == _filter)) n,
        ];
        final chips = SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              AppChip('All', on: _filter == null, onTap: () => setState(() => _filter = null)),
              for (final k in cats) ...[
                const Gap(Space.s2),
                AppChip(newsLook(k).label, on: _filter == k, onTap: () => setState(() => _filter = _filter == k ? null : k)),
              ],
              const Gap(Space.s2),
              AppChip(
                'Saved',
                on: _filter == 'saved',
                icon: PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill),
                onTap: () => setState(() => _filter = _filter == 'saved' ? null : 'saved'),
              ),
            ],
          ),
        );
        if (all.isNotEmpty && list.isEmpty) {
          return ListView(
            padding: const EdgeInsets.only(top: Space.s2),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.s5),
                child: chips,
              ),
              StateBlock(
                icon: _filter == 'saved' ? PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill) : PhosphorIcons.newspaper(PhosphorIconsStyle.fill),
                tone: Tone.blue,
                title: _filter == 'saved' ? 'Nothing saved yet' : 'No news in this group yet',
                text: _filter == 'saved' ? 'Tap Save on a news post to keep it here.' : 'Try another group.',
              ),
            ],
          );
        }
        if (list.isEmpty) {
          return StateBlock(
            icon: PhosphorIcons.newspaper(PhosphorIconsStyle.fill),
            tone: Tone.blue,
            title: 'No news here yet',
            text: 'We post exam dates, new questions and tips here.',
          );
        }
        final top = list.first, rest = list.skip(1).toList();
        final ads = ref.watch(adsConfigProvider).value ?? AdsConfig.off;
        final every = ads.nativeEvery > 0 ? ads.nativeEvery : (rest.isEmpty ? 1 : rest.length);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(newsProvider);
            ref.invalidate(newsMetaProvider);
            await ref.read(newsProvider.future).catchError((_) => const <Map<String, dynamic>>[]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s3),
                child: chips,
              ),
              const AdBanner(screen: 'news'),
              AppCard(
                pad: false,
                clip: true,
                onTap: () => context.push('/news/${top['id']}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NewsCover(n: top, aspect: 16 / 9, iconSize: 84),
                    Padding(
                      padding: const EdgeInsets.all(Space.s4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Pill(newsLook(top['category'] as String?).label),
                          const Gap(Space.s2),
                          Text(top['title'] as String, style: context.ty.h3),
                          if ((top['summary'] as String?)?.isNotEmpty == true) ...[
                            const Gap(Space.s2),
                            Text(top['summary'] as String, style: context.ty.sm.col(context.c.textMuted)),
                          ],
                          const Gap(Space.s2),
                          Text(_line(top, meta), style: context.ty.cap.col(context.c.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (rest.isNotEmpty && (ads.newsCard || ads.nativeEvery > 0)) const AdNativeCard(placement: 'news'),
              // The other stories in groups, with a card ad between groups as the level says (every N stories).
              for (var g = 0; g < rest.length; g += every) ...[
                if (g > 0) AdNativeCard(key: ValueKey('ad-news-$g'), placement: 'news'),
                const Gap(Space.s4),
                ListCard(
                  children: [
                    for (final n in rest.skip(g).take(every))
                      ListRow(
                        lead: NewsCover(n: n, thumb: true),
                        title: n['title'] as String,
                        caption: '${newsLook(n['category'] as String?).label} · ${_line(n, meta)}',
                        caret: false,
                        onTap: () => context.push('/news/${n['id']}'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      }, onRetry: () => ref.invalidate(newsProvider)),
    );
  }
}

/// "12 Nov 2026 · 3 min read · 5 likes · 2 comments".
String _line(Map<String, dynamic> n, Map<String, NewsMeta> meta) {
  final m = meta['${n['id']}'];
  return [
    newsDate(n),
    '${readMins(n)} min read',
    if ((m?.likes ?? 0) > 0) '${m!.likes} like${m.likes == 1 ? '' : 's'}',
    if ((m?.comments ?? 0) > 0) '${m!.comments} comment${m.comments == 1 ? '' : 's'}',
  ].join(' · ');
}

/// News article (prototype: news-detail): hero cover with glass back button, badge + date, title, summary, body, link.
class NewsDetailScreen extends ConsumerStatefulWidget {
  const NewsDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends ConsumerState<NewsDetailScreen> {
  final _commentsKey = GlobalKey();
  String get id => widget.id;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(newsProvider).value ?? const [];
    final n = list.where((x) => '${x['id']}' == id).firstOrNull;
    if (n == null) {
      return Scaffold(
        appBar: const TopBar(),
        body: StateBlock(icon: PhosphorIcons.newspaper(PhosphorIconsStyle.fill), tone: Tone.blue, title: 'This news is no longer available'),
      );
    }
    final c = context.c;
    final body = ((n['body'] as String?) ?? '').trim();
    final linkType = n['link_type'] as String?, target = n['link_target'] as String?;
    // Related: the same group first, then the newest others (D-141).
    final more = [
      ...list.where((x) => x['id'] != n['id'] && x['category'] == n['category']),
      ...list.where((x) => x['id'] != n['id'] && x['category'] != n['category']),
    ].take(3).toList();
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(bottom: Space.s8 + MediaQuery.paddingOf(context).bottom),
        children: [
          Stack(
            children: [
              NewsCover(n: n, aspect: 16 / 10, iconSize: 96),
              Positioned(
                left: 8,
                top: 8 + MediaQuery.paddingOf(context).top,
                child: IconBtn(PhosphorIcons.arrowLeft(), label: 'Back', glass: true, onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s5, Space.s5, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: Space.s2,
                  runSpacing: Space.s1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Pill(newsLook(n['category'] as String?).label),
                    Text('${newsDate(n)} · ${readMins(n)} min read', style: context.ty.cap.col(c.textMuted)),
                  ],
                ),
                const Gap(Space.s3),
                Text(n['title'] as String, style: context.ty.h1),
                if ((n['summary'] as String?)?.isNotEmpty == true) ...[
                  const Gap(Space.s3),
                  Text(n['summary'] as String, style: context.ty.lg.col(c.textMuted)),
                ],
                const Gap(Space.s4),
                NewsActions(
                  n: n,
                  onComments: () {
                    final ctx = _commentsKey.currentContext;
                    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
                  },
                ),
                const AdBanner(screen: 'news'),
                const Gap(Space.s3),
                for (final para in body.split(RegExp(r'\n\s*\n')))
                  if (para.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s3),
                      child: Text(para.trim(), style: context.ty.body.copyWith(fontSize: 16, height: 27 / 16)),
                    ),
                if (linkType == 'screen' && target != null && target.isNotEmpty)
                  Btn('Open', block: true, icon: PhosphorIcons.arrowRight(), onPressed: () => context.push(target.startsWith('/') ? target : '/$target')),
                if (linkType == 'url' && target != null && target.isNotEmpty)
                  Btn(
                    'Read more',
                    block: true,
                    icon: PhosphorIcons.arrowSquareOut(),
                    onPressed: () => launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication),
                  ),
                const Gap(Space.s4),
                NewsActions(n: n, onComments: () {}),
                const Gap(Space.s5),
                const AdNativeCard(placement: 'news_article'),
                if (n['comments_on'] != false) ...[
                  const Gap(Space.s6),
                  KeyedSubtree(
                    key: _commentsKey,
                    child: NewsComments(postId: '${n['id']}'),
                  ),
                ],
                if (more.isNotEmpty) ...[
                  const Gap(Space.s6),
                  Text('Related news', style: context.ty.h3),
                  const Gap(Space.s3),
                  for (final m in more) ...[NewsTile(n: m), const Gap(Space.s3)],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
