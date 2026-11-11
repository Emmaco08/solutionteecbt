import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';

// News v2 (B7, D-141): likes, saved posts, comments with reports, sharing. Counts come from the server
// (news_meta); comment names are shortened there (first name + initial).

typedef NewsMeta = ({int likes, int comments, bool liked, bool saved});

/// Likes, comments and my like/save for the posts in the news list.
final newsMetaProvider = FutureProvider<Map<String, NewsMeta>>((ref) async {
  final ids = [for (final n in ref.watch(newsProvider).value ?? const <Map<String, dynamic>>[]) '${n['id']}'];
  if (ids.isEmpty) return const {};
  try {
    final r = await Supabase.instance.client.rpc('news_meta', params: {'p_ids': ids}).timeout(const Duration(seconds: 12));
    return {
      for (final m in rows(r))
        '${m['post_id']}': (
          likes: (m['likes'] as num?)?.toInt() ?? 0,
          comments: (m['comments'] as num?)?.toInt() ?? 0,
          liked: m['liked'] == true,
          saved: m['saved'] == true,
        ),
    };
  } catch (_) {
    return const {};
  }
});

final newsCommentsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final r = await Supabase.instance.client.rpc('news_comments_list', params: {'p_post': id}).timeout(const Duration(seconds: 12));
  return rows(r);
});

String _uid() => Supabase.instance.client.auth.currentUser?.id ?? '';

/// Like or unlike, save or unsave. Returns false when it could not be saved.
Future<bool> toggleNews(WidgetRef ref, String id, {required String table, required bool on}) async {
  try {
    final t = Supabase.instance.client.from(table);
    on ? await t.upsert({'post_id': id, 'user_id': _uid()}) : await t.delete().match({'post_id': id, 'user_id': _uid()});
    ref.invalidate(newsMetaProvider);
    return true;
  } catch (_) {
    return false;
  }
}

/// WhatsApp first (most students use it); without WhatsApp the text is copied.
Future<void> shareNews(BuildContext context, Map<String, dynamic> n) async {
  final summary = '${n['summary'] ?? ''}'.trim();
  final text = ['${n['title']}', if (summary.isNotEmpty) summary, 'Read more on the SolutionTee CBT app: https://cbt.solutiontee.com'].join('\n\n');
  final ok = await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (ok || !context.mounted) return;
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, 'Copied. Paste it to share.', icon: PhosphorIcons.copy(PhosphorIconsStyle.fill));
}

/// Like · comments · save · share, under the article title.
class NewsActions extends ConsumerStatefulWidget {
  const NewsActions({super.key, required this.n, required this.onComments});
  final Map<String, dynamic> n;
  final VoidCallback onComments;
  @override
  ConsumerState<NewsActions> createState() => _NewsActionsState();
}

class _NewsActionsState extends ConsumerState<NewsActions> {
  bool? _liked, _saved;
  int _likeDelta = 0;

  String get _id => '${widget.n['id']}';

  Future<void> _like(NewsMeta? m) async {
    final now = !(_liked ?? m?.liked ?? false);
    HapticFeedback.lightImpact();
    setState(() {
      _liked = now;
      _likeDelta += now ? 1 : -1;
    });
    if (!await toggleNews(ref, _id, table: 'news_likes', on: now) && mounted) {
      setState(() {
        _liked = !now;
        _likeDelta += now ? -1 : 1;
      });
      toast(context, 'Could not save. Check your internet.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    }
  }

  Future<void> _save(NewsMeta? m) async {
    final now = !(_saved ?? m?.saved ?? false);
    setState(() => _saved = now);
    final ok = await toggleNews(ref, _id, table: 'news_saves', on: now);
    if (!mounted) return;
    if (!ok) {
      setState(() => _saved = !now);
      return toast(context, 'Could not save. Check your internet.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    }
    toast(context, now ? 'Saved. Find it under Saved in News.' : 'Removed from Saved', icon: PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final m = ref.watch(newsMetaProvider).value?[_id];
    // Once the server answers again, its numbers replace the local guess.
    ref.listen(newsMetaProvider, (_, next) {
      if (next.isLoading || !next.hasValue || !mounted) return;
      setState(() {
        _likeDelta = 0;
        _liked = null;
        _saved = null;
      });
    });
    final liked = _liked ?? m?.liked ?? false;
    final saved = _saved ?? m?.saved ?? false;
    final likes = ((m?.likes ?? 0) + _likeDelta).clamp(0, 1 << 30);
    final commentsOn = widget.n['comments_on'] != false;
    Widget pill(IconData icon, String label, {Color? color, VoidCallback? onTap, String? semantics, Widget? iconWidget}) => Semantics(
      button: true,
      label: semantics ?? label,
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: Space.s3),
          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget ?? Icon(icon, size: 20, color: color ?? c.textMuted),
              if (label.isNotEmpty) ...[const Gap(6), Text(label, style: context.ty.sm.bold.col(color ?? c.text))],
            ],
          ),
        ),
      ),
    );
    final heart = Icon(
      liked ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.heart(),
      size: 20,
      color: liked ? const Color(0xFFE5484D) : c.textMuted,
    );
    return Wrap(
      spacing: Space.s2,
      runSpacing: Space.s2,
      children: [
        pill(
          PhosphorIcons.heart(),
          likes > 0 ? '$likes' : 'Like',
          color: liked ? const Color(0xFFE5484D) : null,
          semantics: liked ? 'Unlike. $likes likes' : 'Like. $likes likes',
          iconWidget: context.reduceMotion || !liked
              ? heart
              : heart.animate(key: ValueKey(liked)).scale(begin: const Offset(.6, .6), duration: 260.ms, curve: Curves.elasticOut),
          onTap: () => _like(m),
        ),
        if (commentsOn) pill(PhosphorIcons.chatCircleText(), '${m?.comments ?? 0}', semantics: 'Comments, ${m?.comments ?? 0}', onTap: widget.onComments),
        pill(
          saved ? PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill) : PhosphorIcons.bookmarkSimple(),
          saved ? 'Saved' : 'Save',
          color: saved ? c.secondary : null,
          onTap: () => _save(m),
        ),
        pill(PhosphorIcons.whatsappLogo(), 'Share', semantics: 'Share on WhatsApp', onTap: () => shareNews(context, widget.n)),
      ],
    );
  }
}

/// Comments under the article: newest at the bottom, write box, report and delete-own.
class NewsComments extends ConsumerStatefulWidget {
  const NewsComments({super.key, required this.postId});
  final String postId;
  @override
  ConsumerState<NewsComments> createState() => _NewsCommentsState();
}

class _NewsCommentsState extends ConsumerState<NewsComments> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.length < 2) return;
    setState(() => _sending = true);
    try {
      await Supabase.instance.client.from('news_comments').insert({'post_id': widget.postId, 'body': body});
      _text.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      ref.invalidate(newsCommentsProvider(widget.postId));
      ref.invalidate(newsMetaProvider);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = switch (e.message) {
        'no_links' => 'Links are not allowed in comments.',
        'too_many' => 'You are commenting very fast. Wait a little and try again.',
        _ => e.code == '42501' ? 'Comments are closed on this post.' : 'Could not post. Try again.',
      };
      toast(context, msg, icon: PhosphorIcons.warningCircle(PhosphorIconsStyle.fill));
    } catch (_) {
      if (mounted) toast(context, 'Could not post. Check your internet.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _menu(Map<String, dynamic> cm) async {
    final mine = cm['mine'] == true;
    final pick = await showSheet<String>(
      context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(mine ? 'Your comment' : 'Report this comment', style: context.ty.h3),
            const Gap(Space.s3),
            ListCard(
              children: mine
                  ? [
                      ListRow(
                        icon: PhosphorIcons.trash(PhosphorIconsStyle.fill),
                        title: 'Delete comment',
                        danger: true,
                        onTap: () => Navigator.of(context).pop('delete'),
                      ),
                    ]
                  : [
                      for (final (k, label) in const [
                        ('rude', 'Rude or bullying'),
                        ('spam', 'Spam or advert'),
                        ('wrong', 'Wrong or harmful information'),
                        ('other', 'Something else'),
                      ])
                        ListRow(icon: PhosphorIcons.flag(PhosphorIconsStyle.fill), tone: Tone.red, title: label, onTap: () => Navigator.of(context).pop(k)),
                    ],
            ),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    try {
      if (pick == 'delete') {
        await Supabase.instance.client.from('news_comments').delete().eq('id', '${cm['id']}');
        ref.invalidate(newsMetaProvider);
      } else {
        await Supabase.instance.client.from('news_comment_reports').insert({'comment_id': '${cm['id']}', 'reason': pick});
      }
      ref.invalidate(newsCommentsProvider(widget.postId));
      if (mounted) {
        toast(context, pick == 'delete' ? 'Comment deleted' : 'Thanks. Our team will look at it.', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
      }
    } on PostgrestException catch (e) {
      if (mounted) toast(context, e.code == '23505' ? 'You already reported this comment.' : 'Could not send. Try again.');
    } catch (_) {
      if (mounted) toast(context, 'Could not send. Check your internet.', icon: PhosphorIcons.wifiSlash(PhosphorIconsStyle.fill));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final async = ref.watch(newsCommentsProvider(widget.postId));
    final list = async.value ?? const <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(list.isEmpty ? 'Comments' : 'Comments (${list.where((x) => x['hidden'] != true).length})', style: context.ty.h3),
        const Gap(Space.s3),
        if (async.isLoading && list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(Space.s4),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (async.hasError && list.isEmpty)
          Text('Comments could not load. Pull down to try again.', style: context.ty.sm.col(c.textMuted))
        else if (list.isEmpty)
          Text('No comments yet. Be the first to say something kind or helpful.', style: context.ty.sm.col(c.textMuted))
        else
          for (final cm in list)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Avatar('${cm['name']}', size: 36),
                  const Gap(Space.s3),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(Space.s3, Space.s2, Space.s1, Space.s2),
                      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [cm['mine'] == true ? 'You' : '${cm['name']}', _ago('${cm['created_at']}'), if (cm['hidden'] == true) 'hidden'].join(' · '),
                                  style: context.ty.cap.bold.col(c.textMuted),
                                ),
                                const Gap(2),
                                Text('${cm['body']}', style: context.ty.sm),
                              ],
                            ),
                          ),
                          IconBtn(
                            PhosphorIcons.dotsThreeVertical(),
                            label: cm['mine'] == true ? 'Comment options' : 'Report comment',
                            size: 18,
                            onPressed: () => _menu(cm),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        const Gap(Space.s2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                style: context.ty.body,
                decoration: const InputDecoration(hintText: 'Write a comment…', counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Gap(Space.s2),
            IconBtn(
              PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill),
              label: 'Post comment',
              color: _text.text.trim().length >= 2 ? c.secondary : c.textSubtle,
              onPressed: _sending || _text.text.trim().length < 2 ? null : _send,
            ),
          ],
        ),
        const Gap(Space.s1),
        Text('Be kind. No links. Your first name and initial show.', style: context.ty.cap.col(c.textSubtle)),
      ],
    );
  }
}

String _ago(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final s = DateTime.now().difference(d.toLocal());
  if (s.inMinutes < 1) return 'now';
  if (s.inHours < 1) return '${s.inMinutes} min';
  if (s.inDays < 1) return '${s.inHours} h';
  if (s.inDays < 7) return '${s.inDays} d';
  final l = d.toLocal();
  return '${l.day}/${l.month}/${l.year}';
}
