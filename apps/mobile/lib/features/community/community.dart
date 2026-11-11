import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/math_text.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/r2_image.dart';
import '../../widgets/states.dart';

// Community (C15, D-151): learning posts checked by the AI before others see them, comments, likes, follows,
// "@solutiontee" for an AI answer, report and block. Everything goes through community_* functions on the server.

typedef FeedKey = ({String tab, int? subject});

final communityFeedProvider = FutureProvider.family<List<Map<String, dynamic>>, FeedKey>((ref, k) async {
  final uid = currentSession(ref)?.user.id;
  if (uid == null) return const [];
  return cached(
    ref,
    'community:$uid:${k.tab}:${k.subject}',
    (s) => s.rpc('community_feed', params: {'p_tab': k.tab, 'p_subject': k.subject, 'p_offset': 0}),
    rows,
  );
});

final communityPostProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final r = await Supabase.instance.client.rpc('community_post_get', params: {'p_id': id}).timeout(const Duration(seconds: 15));
  return Map<String, dynamic>.from(r as Map);
});

final communityProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final r = await Supabase.instance.client.rpc('community_profile', params: {'p_user': id}).timeout(const Duration(seconds: 15));
  return Map<String, dynamic>.from((r as Map?) ?? const {});
});

void refreshCommunity(WidgetRef ref) {
  ref.invalidate(communityFeedProvider);
}

/// "2 h", "3 d", "12 Nov".
String agoText(Object? iso, [DateTime? now]) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes} min';
  if (diff.inDays < 1) return '${diff.inHours} h';
  if (diff.inDays < 7) return '${diff.inDays} d';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]}';
}

String communityError(Object? e) => switch ('$e') {
  'too_many' => 'You have posted a lot today. Please try again tomorrow.',
  'short' => 'Write a little more (at least 3 letters).',
  'off' => 'Community is paused for now.',
  'image' => 'That picture could not be used. Try another one.',
  'length' => 'Comments can be up to 1,000 characters.',
  'not_found' => 'This post is no longer available.',
  _ => 'Something went wrong. Please try again.',
};

SupabaseClient get _db => Supabase.instance.client;

/// Asks the server to check a post or comment right away (it is also checked within 2 minutes if this fails).
Future<String> checkNow(String kind, Object id) async {
  try {
    final r = await _db.functions.invoke('community', body: {'action': 'check', 'kind': kind, 'id': '$id'}).timeout(const Duration(seconds: 60));
    return '${(r.data as Map?)?['status'] ?? 'pending'}';
  } catch (_) {
    return 'pending';
  }
}

/// Study card: the way in.
class CommunityCard extends StatelessWidget {
  const CommunityCard({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      onTap: () => context.push('/community'),
      child: Row(
        children: [
          IconTile(PhosphorIcons.chatsTeardrop(PhosphorIconsStyle.fill), tone: Tone.blue, size: 48),
          const Gap(Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Community', style: context.ty.body.bold),
                const Gap(2),
                Text(
                  'Ask questions, share tips, learn with other students.',
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

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  String _tab = 'for_you';
  int? _subject;

  @override
  Widget build(BuildContext context) {
    final key = (tab: _tab, subject: _subject);
    final feed = ref.watch(communityFeedProvider(key));
    final subjects = ref.watch(subjectsProvider).value ?? const <Map<String, dynamic>>[];
    return Scaffold(
      appBar: TopBar(title: 'Community'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final made = await showComposer(context, ref, subject: _subject);
          if (made == true) refreshCommunity(ref);
        },
        icon: Icon(PhosphorIcons.pencilSimple(PhosphorIconsStyle.fill)),
        label: const Text('New post'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(communityFeedProvider(key));
          await ref.read(communityFeedProvider(key).future).catchError((_) => const <Map<String, dynamic>>[]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s3, Space.s5, 96),
          children: [
            Seg<String>(
              value: _tab,
              items: const [('for_you', 'For you'), ('following', 'Following'), ('mine', 'My posts')],
              onChanged: (v) => setState(() => _tab = v),
            ),
            const Gap(Space.s3),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  AppChip('All subjects', on: _subject == null, onTap: () => setState(() => _subject = null)),
                  for (final s in subjects) ...[
                    const Gap(Space.s2),
                    AppChip('${s['name']}', on: _subject == (s['id'] as num).toInt(), onTap: () => setState(() => _subject = (s['id'] as num).toInt())),
                  ],
                ],
              ),
            ),
            const Gap(Space.s3),
            asyncView(
              feed,
              onRetry: () => ref.invalidate(communityFeedProvider(key)),
              loading: const Column(
                children: [
                  Skeleton(height: 160, radius: Radii.lg),
                  Gap(Space.s3),
                  Skeleton(height: 160, radius: Radii.lg),
                ],
              ),
              (list) => list.isEmpty
                  ? StateBlock(
                      icon: PhosphorIcons.chatsTeardrop(PhosphorIconsStyle.fill),
                      title: _tab == 'following'
                          ? 'No posts from people you follow'
                          : _tab == 'mine'
                          ? 'You have not posted yet'
                          : 'No posts here yet',
                      text: _tab == 'following'
                          ? 'Follow students whose posts help you. Their posts show here.'
                          : 'Ask a question or share a study tip. Be the first!',
                    )
                  : Column(
                      children: [
                        for (final (i, p) in list.indexed) ...[
                          context.reduceMotion || i > 6
                              ? PostCard(post: p)
                              : PostCard(post: p).animate().fadeIn(delay: (40 * i).ms, duration: Motion.base).slideY(begin: .05, end: 0, curve: Curves.easeOut),
                          const Gap(Space.s3),
                        ],
                      ],
                    ),
            ),
            const Gap(Space.s2),
            Text(
              'Only learning posts. Every post is checked before others see it. Never share your phone number or meet strangers.',
              style: context.ty.cap.col(context.c.textSubtle),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// One post in a list or at the top of its page.
class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post, this.full = false});
  final Map<String, dynamic> post;
  final bool full;
  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late bool _liked = widget.post['liked'] == true;
  late int _likes = (widget.post['likes'] as num?)?.toInt() ?? 0;

  @override
  void didUpdateWidget(PostCard old) {
    super.didUpdateWidget(old);
    if (old.post != widget.post) {
      _liked = widget.post['liked'] == true;
      _likes = (widget.post['likes'] as num?)?.toInt() ?? 0;
    }
  }

  Future<void> _like() async {
    setState(() => (_liked = !_liked, _likes += _liked ? 1 : -1));
    try {
      final r = Map<String, dynamic>.from(await _db.rpc('community_like', params: {'p_id': widget.post['id']}).timeout(const Duration(seconds: 10)) as Map);
      if (mounted && r['ok'] == true) setState(() => (_liked = r['liked'] == true, _likes = (r['likes'] as num).toInt()));
    } catch (_) {
      if (mounted) setState(() => (_liked = !_liked, _likes += _liked ? 1 : -1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = widget.post;
    final status = '${p['status']}';
    final subject = (ref.watch(subjectsProvider).value ?? const []).where((s) => s['id'] == p['subject_id']).firstOrNull?['name'];
    final body = MathText('${p['body']}', style: context.ty.body);
    return AppCard(
      onTap: widget.full || status != 'shown' ? null : () => context.push('/community/post/${p['id']}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(onTap: () => context.push('/community/user/${p['user_id']}'), child: Avatar('${p['name']}', size: 36)),
              const Gap(Space.s2),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/community/user/${p['user_id']}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p['name']}', style: context.ty.sm.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${agoText(p['created_at'])}${subject != null ? ' · $subject' : ''}', style: context.ty.cap.col(c.textMuted)),
                    ],
                  ),
                ),
              ),
              PostMenu(post: p),
            ],
          ),
          if (status == 'pending') ...[
            const Gap(Space.s2),
            InfoBanner(icon: PhosphorIcons.hourglassMedium(PhosphorIconsStyle.fill), child: const Text('Being checked. Only you can see it for now.')),
          ] else if (status == 'rejected') ...[
            const Gap(Space.s2),
            InfoBanner(kind: BannerKind.err, child: Text('Not shared: ${p['reason'] ?? 'it does not follow the community rules.'}')),
          ],
          const Gap(Space.s2),
          widget.full
              ? body
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ClipRect(child: body),
                ),
          if ('${p['image_path'] ?? ''}'.isNotEmpty) ...[
            const Gap(Space.s3),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: R2Image(imageKey: '${p['image_path']}', semanticLabel: 'Picture in the post'),
              ),
            ),
          ],
          if (status == 'shown') ...[
            const Gap(Space.s2),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _like,
                  icon: Icon(_liked ? PhosphorIcons.heart(PhosphorIconsStyle.fill) : PhosphorIcons.heart(), size: 20, color: _liked ? c.error : c.textMuted),
                  label: Text('$_likes', style: context.ty.sm.tnum.col(c.textMuted)),
                ),
                TextButton.icon(
                  onPressed: widget.full ? null : () => context.push('/community/post/${p['id']}'),
                  icon: Icon(PhosphorIcons.chatCircle(), size: 20, color: c.textMuted),
                  label: Text('${p['comments'] ?? 0}', style: context.ty.sm.tnum.col(c.textMuted)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Report, block, follow or delete.
class PostMenu extends ConsumerWidget {
  const PostMenu({super.key, required this.post});
  final Map<String, dynamic> post;

  Future<void> _rpc(BuildContext context, WidgetRef ref, String fn, Map<String, dynamic> params, String done) async {
    try {
      await _db.rpc(fn, params: params).timeout(const Duration(seconds: 15));
      refreshCommunity(ref);
      if (context.mounted) toast(context, done, icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
    } catch (_) {
      if (context.mounted) toast(context, 'Could not reach SolutionTee. Check your internet and try again.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = post['mine'] == true;
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: Icon(PhosphorIcons.dotsThreeVertical(), color: context.c.textMuted),
      onSelected: (v) async {
        switch (v) {
          case 'delete':
            await _rpc(context, ref, 'community_post_delete', {'p_id': post['id']}, 'Post deleted');
            if (context.mounted && GoRouterState.of(context).uri.path.startsWith('/community/post/')) context.pop();
          case 'report':
            final reason = await pickReportReason(context);
            if (reason != null && context.mounted) {
              await _rpc(context, ref, 'community_report', {'p_kind': 'post', 'p_ref': '${post['id']}', 'p_reason': reason}, 'Thanks. We will look at it.');
            }
          case 'follow':
            await _rpc(context, ref, 'community_follow', {'p_user': post['user_id']}, post['following'] == true ? 'Unfollowed' : 'Following ${post['name']}');
          case 'block':
            await _rpc(context, ref, 'community_block', {'p_user': post['user_id']}, 'Blocked. You will not see each other\'s posts.');
        }
      },
      itemBuilder: (_) => [
        if (mine) const PopupMenuItem(value: 'delete', child: Text('Delete my post')),
        if (!mine) PopupMenuItem(value: 'follow', child: Text(post['following'] == true ? 'Unfollow' : 'Follow ${post['name']}')),
        if (!mine && post['status'] == 'shown') const PopupMenuItem(value: 'report', child: Text('Report')),
        if (!mine) const PopupMenuItem(value: 'block', child: Text('Block this student')),
      ],
    );
  }
}

Future<String?> pickReportReason(BuildContext context) => showSheet<String>(
  context,
  builder: (ctx) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Why are you reporting this?', style: ctx.ty.h3),
      const Gap(Space.s3),
      ListCard(
        children: [
          for (final r in const [
            'Not about learning',
            'Rude or bullying',
            'Sharing phone numbers or links',
            'Exam malpractice (expo)',
            'Wrong or harmful answer',
            'Something else',
          ])
            ListRow(title: r, onTap: () => Navigator.pop(ctx, r)),
        ],
      ),
    ],
  ),
);

/// New post: text (maths with $...$), subject, one picture. Returns true when a post was made.
Future<bool?> showComposer(BuildContext context, WidgetRef ref, {int? subject}) =>
    showSheet<bool>(context, scroll: true, builder: (ctx) => _Composer(subject: subject));

class _Composer extends ConsumerStatefulWidget {
  const _Composer({this.subject});
  final int? subject;
  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _text = TextEditingController();
  late int? _subject = widget.subject;
  File? _photo;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, maxHeight: 1280, imageQuality: 78).catchError((_) => null);
    if (x != null && mounted) setState(() => _photo = File(x.path));
  }

  Future<void> _send() async {
    if (_text.text.trim().length < 3) return setState(() => _error = communityError('short'));
    setState(() => (_busy = true, _error = null));
    try {
      String? key;
      if (_photo != null) {
        final bytes = await _photo!.readAsBytes();
        if (bytes.length > 3 * 1024 * 1024) throw const _Msg('That picture is too big. Choose a smaller one.');
        try {
          final (k, url) = await ref.read(apiProvider).communityUploadLink(bytes.length);
          final r = await http.put(Uri.parse(url), headers: {'content-type': 'image/jpeg'}, body: bytes).timeout(const Duration(seconds: 60));
          if (r.statusCode >= 300) throw Exception('upload');
          key = k;
        } catch (_) {
          throw const _Msg('Could not upload the picture. Post without it or try again.');
        }
      }
      final r = Map<String, dynamic>.from(
        await _db
                .rpc('community_post_create', params: {'p_body': _text.text.trim(), 'p_image': key, 'p_subject': _subject})
                .timeout(const Duration(seconds: 15))
            as Map,
      );
      if (r['ok'] != true) throw _Msg(communityError(r['error']));
      if (!mounted) return;
      toast(context, 'Posted! We are checking it now.', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
      // The sheet closes now; the check runs on and refreshes the feed when the answer comes back.
      final container = ProviderScope.containerOf(context, listen: false);
      Navigator.pop(context, true);
      if (r['status'] == 'pending') {
        await checkNow('post', r['id']);
        container.invalidate(communityFeedProvider);
      }
    } on _Msg catch (e) {
      if (mounted) setState(() => _error = e.text);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach SolutionTee. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final subjects = ref.watch(subjectsProvider).value ?? const <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('New post', style: context.ty.h3),
        const Gap(Space.s1),
        Text('Ask a question or share a tip. Add @solutiontee to get an answer from the AI.', style: context.ty.sm.col(c.textMuted)),
        const Gap(Space.s3),
        TextField(
          controller: _text,
          minLines: 4,
          maxLines: 10,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          style: context.ty.body,
          decoration: const InputDecoration(hintText: r'For example: How do I solve $x^2 - 5x + 6 = 0$? @solutiontee'),
        ),
        DropdownButtonFormField<int?>(
          initialValue: _subject,
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'Subject (optional)'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('No subject')),
            for (final s in subjects) DropdownMenuItem<int?>(value: (s['id'] as num).toInt(), child: Text('${s['name']}')),
          ],
          onChanged: (v) => setState(() => _subject = v),
        ),
        const Gap(Space.s3),
        if (_photo != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: Image.file(_photo!, height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: IconBtn(PhosphorIcons.x(PhosphorIconsStyle.bold), label: 'Remove picture', onPressed: () => setState(() => _photo = null)),
              ),
            ],
          )
        else
          Btn('Add a picture', kind: BtnKind.secondary, sm: true, leading: PhosphorIcons.image(PhosphorIconsStyle.fill), onPressed: _busy ? null : _pick),
        if (_error != null) ...[const Gap(Space.s3), ErrText(_error!)],
        const Gap(Space.s4),
        Btn('Post', block: true, loading: _busy, onPressed: _busy ? null : _send),
        const Gap(Space.s2),
        Text('Learning posts only. No phone numbers, links or exam "expo".', style: context.ty.cap.col(c.textSubtle), textAlign: TextAlign.center),
      ],
    );
  }
}

class _Msg implements Exception {
  const _Msg(this.text);
  final String text;
}

/// A post with its comments and a comment box.
class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final r = Map<String, dynamic>.from(
        await _db.rpc('community_comment_add', params: {'p_post': widget.id, 'p_body': body}).timeout(const Duration(seconds: 15)) as Map,
      );
      if (!mounted) return;
      if (r['ok'] != true) {
        toast(context, communityError(r['error']));
        return;
      }
      _text.clear();
      ref.invalidate(communityPostProvider(widget.id));
      if (r['status'] == 'pending') {
        await checkNow('comment', r['id']);
        if (mounted) ref.invalidate(communityPostProvider(widget.id));
      }
    } catch (_) {
      if (mounted) toast(context, 'Could not reach SolutionTee. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = ref.watch(communityPostProvider(widget.id));
    return Scaffold(
      appBar: TopBar(title: 'Post'),
      body: asyncView(v, onRetry: () => ref.invalidate(communityPostProvider(widget.id)), (p) {
        if (p['status'] == 'not_found') {
          return StateBlock(
            icon: PhosphorIcons.chatsTeardrop(PhosphorIconsStyle.fill),
            title: 'Post not available',
            text: 'It may have been deleted or hidden.',
          );
        }
        final comments = [for (final x in (p['comment_list'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(communityPostProvider(widget.id)),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.s5, Space.s3, Space.s5, Space.s5),
                  children: [
                    PostCard(post: p, full: true),
                    const Gap(Space.s4),
                    SectTitle(comments.isEmpty ? 'No comments yet' : 'Comments'),
                    for (final m in comments) _CommentTile(m: m, postId: widget.id),
                  ],
                ),
              ),
            ),
            if (p['status'] == 'shown')
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(Space.s4, Space.s2, Space.s2, Space.s2),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          style: context.ty.body,
                          decoration: const InputDecoration(hintText: 'Write a helpful comment…', counterText: ''),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const Gap(Space.s2),
                      IconBtn(
                        PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill),
                        label: 'Send comment',
                        onPressed: _sending || _text.text.trim().isEmpty ? null : _send,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({required this.m, required this.postId});
  final Map<String, dynamic> m;
  final String postId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final ai = m['from_ai'] == true;
    final status = '${m['status']}';
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ai ? IconTile(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), tone: Tone.gold, size: 32, radius: 16) : Avatar('${m['name']}', size: 32),
          const Gap(Space.s2),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
              decoration: BoxDecoration(color: ai ? c.accentSoft : c.surfaceSunken, borderRadius: BorderRadius.circular(Radii.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('${m['name']} · ${agoText(m['created_at'])}', style: context.ty.cap.bold.col(ai ? c.onAccentSoft : c.textMuted))),
                      if (!ai)
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          padding: EdgeInsets.zero,
                          icon: Icon(PhosphorIcons.dotsThree(), size: 18, color: c.textMuted),
                          onSelected: (v) async {
                            try {
                              if (v == 'delete') {
                                await _db.rpc('community_comment_delete', params: {'p_id': m['id']});
                              } else {
                                final reason = await pickReportReason(context);
                                if (reason == null) return;
                                await _db.rpc('community_report', params: {'p_kind': 'comment', 'p_ref': '${m['id']}', 'p_reason': reason});
                                if (context.mounted) toast(context, 'Thanks. We will look at it.');
                              }
                              ref.invalidate(communityPostProvider(postId));
                            } catch (_) {
                              if (context.mounted) toast(context, 'Could not reach SolutionTee. Try again.');
                            }
                          },
                          itemBuilder: (_) => [
                            if (m['mine'] == true) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            if (m['mine'] != true) const PopupMenuItem(value: 'report', child: Text('Report')),
                          ],
                        ),
                    ],
                  ),
                  MathText('${m['body']}', style: context.ty.sm),
                  if (status == 'pending') Text('Being checked. Only you can see it for now.', style: context.ty.cap.col(c.textSubtle)),
                  if (status == 'rejected') Text('Not shared: ${m['reason'] ?? 'it does not follow the rules.'}', style: context.ty.cap.col(c.error)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A student's community page: posts, followers, follow and block.
class CommunityUserScreen extends ConsumerWidget {
  const CommunityUserScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final v = ref.watch(communityProfileProvider(id));
    return Scaffold(
      appBar: TopBar(title: 'Student'),
      body: asyncView(v, onRetry: () => ref.invalidate(communityProfileProvider(id)), (p) {
        if (p.isEmpty) return StateBlock(icon: PhosphorIcons.user(PhosphorIconsStyle.fill), title: 'Student not found');
        final list = [for (final x in (p['list'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        Future<void> toggle(String fn) async {
          try {
            await _db.rpc(fn, params: {'p_user': id}).timeout(const Duration(seconds: 15));
            ref.invalidate(communityProfileProvider(id));
            refreshCommunity(ref);
          } catch (_) {
            if (context.mounted) toast(context, 'Could not reach SolutionTee. Try again.');
          }
        }

        Widget stat(String n, String l) => Expanded(
          child: Column(
            children: [
              Text(n, style: context.ty.h3.tnum),
              Text(l, style: context.ty.cap.col(c.textMuted)),
            ],
          ),
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s8),
          children: [
            Center(child: Avatar('${p['name']}', size: 72)),
            const Gap(Space.s2),
            Text('${p['name']}', style: context.ty.h2, textAlign: TextAlign.center),
            const Gap(Space.s3),
            Row(children: [stat('${p['posts']}', 'Posts'), stat('${p['followers']}', 'Followers'), stat('${p['following_count']}', 'Following')]),
            if (p['me'] != true) ...[
              const Gap(Space.s4),
              if (p['blocked'] == true)
                Btn('Unblock', block: true, kind: BtnKind.secondary, onPressed: () => toggle('community_block'))
              else
                Row(
                  children: [
                    Expanded(
                      child: Btn(
                        p['following'] == true ? 'Following' : 'Follow',
                        kind: p['following'] == true ? BtnKind.secondary : BtnKind.primary,
                        onPressed: () => toggle('community_follow'),
                      ),
                    ),
                    const Gap(Space.s2),
                    Btn('Block', kind: BtnKind.ghost, onPressed: () => toggle('community_block')),
                  ],
                ),
            ],
            const Gap(Space.s5),
            if (list.isEmpty)
              Text(p['blocked'] == true ? 'You blocked this student.' : 'No posts yet.', style: context.ty.sm.col(c.textMuted), textAlign: TextAlign.center)
            else
              for (final post in list) ...[PostCard(post: post), const Gap(Space.s3)],
          ],
        );
      }),
    );
  }
}
