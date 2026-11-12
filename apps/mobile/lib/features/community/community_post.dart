import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/fit_text.dart';
import '../../widgets/phosphor.g.dart';
import '../study/note_screens.dart' show NoteBody;
import 'community_data.dart';
import 'community_widgets.dart';

// Community post page and compose page (D-155).

// ---------------------------------------------------------------- post page (thread)

class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.id, this.reply = false});
  final String id;
  final bool reply;
  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  Json? _p;
  Object? _err;
  final _text = TextEditingController();
  final _focus = FocusNode();
  Json? _to; // the reply being answered
  bool _sending = false;

  /// The student tagged @solutiontee: show "SolutionTee AI is typing…" until its reply arrives.
  bool _aiTyping = false;

  int get _aiCount {
    var n = 0;
    for (final r in asList(_p?['replies'])) {
      if (r['from_ai'] == true) n++;
      for (final x in asList(r['reply_list'])) {
        if (x['from_ai'] == true) n++;
      }
    }
    return n;
  }

  final _open = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.reply) WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    // Opening a post (from a push or a link) reads its notifications.
    crpc('community_note_open', {'p_post': widget.id}).then((r) {
      final left = (asJson(r)['unread'] as num?)?.toInt();
      if (mounted && left != null) ref.read(communityUnreadProvider.notifier).set(left);
    }, onError: (_) {});
  }

  Future<void> _load() async {
    try {
      final r = asJson(await crpc('community_thread', {'p_id': widget.id}));
      if (mounted) setState(() => (_p = r, _err = null));
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final r = asJson(await crpc('community_reply', {'p_post': widget.id, 'p_body': body, 'p_parent': _to?['id']}));
      if (!mounted) return;
      if (r['ok'] != true) {
        toast(context, communityError(r['error']));
        return;
      }
      HapticFeedback.lightImpact();
      final parent = _to == null ? null : '${_to!['parent_id'] ?? _to!['id']}';
      _text.clear();
      _focus.unfocus();
      setState(() {
        _to = null;
        if (parent != null) _open.add(parent);
      });
      final asksAi = RegExp('@solutiontee', caseSensitive: false).hasMatch(body);
      final before = _aiCount;
      if (asksAi && r['status'] != 'rejected') setState(() => _aiTyping = true);
      await _load();
      // Replies go live at once and are checked after (D-156): ask the server to check (and let the AI answer) right now.
      if (r['status'] != 'rejected') {
        await checkNow('comment', r['id']);
        if (mounted) await _load();
        for (var i = 0; i < 3 && asksAi && mounted && _aiCount <= before; i++) {
          await Future<void>.delayed(const Duration(seconds: 5));
          if (mounted) await _load();
        }
        if (mounted) setState(() => _aiTyping = false);
      }
    } catch (_) {
      if (mounted) toast(context, offlineText);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _replyTo(Json r) {
    setState(() => _to = r);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = _p;
    final patch = p == null ? null : ref.watch(postPatchesProvider.select((m) => m['${p['id']}']));
    if (patch?['deleted'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.canPop()) context.pop();
      });
    }
    final Widget body;
    if (p == null) {
      body = _err != null
          ? StateBlock(
              icon: PhosphorIcons.wifiSlash(),
              title: 'You are offline',
              text: offlineText,
              action: Btn('Try again', sm: true, onPressed: _load),
            )
          : const PostSkeletons(count: 2);
    } else if (p['status'] == 'not_found') {
      body = StateBlock(icon: PhosphorIcons.chatsTeardrop(PhosphorIconsStyle.fill), title: 'Post not available', text: 'It may have been deleted or hidden.');
    } else {
      final replies = asList(p['replies']);
      body = Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: Space.s5),
                children: [
                  _BigPost(p: {...p, ...?patch}, onReply: () => _focus.requestFocus()),
                  if (replies.isEmpty && p['status'] == 'shown')
                    Padding(
                      padding: const EdgeInsets.all(Space.s6),
                      child: Text('No replies yet. Be the first to help.', style: context.ty.sm.col(c.textMuted), textAlign: TextAlign.center),
                    ),
                  for (final (i, r) in replies.indexed) ...[
                    _ReplyTile(
                      r: r,
                      line: _open.contains('${r['id']}') && asList(r['reply_list']).isNotEmpty,
                      onReply: () => _replyTo(r),
                      onChanged: _load,
                      index: i,
                    ),
                    if (asList(r['reply_list']).isNotEmpty)
                      if (_open.contains('${r['id']}'))
                        for (final (k, x) in asList(r['reply_list']).indexed)
                          _ReplyTile(r: x, nested: true, line: k < asList(r['reply_list']).length - 1, onReply: () => _replyTo(x), onChanged: _load)
                      else
                        Padding(
                          padding: const EdgeInsets.only(left: 68, bottom: Space.s2),
                          child: TextButton.icon(
                            onPressed: () => setState(() => _open.add('${r['id']}')),
                            icon: Container(width: 18, height: 2, color: c.borderStrong),
                            label: Text(
                              'Show ${asList(r['reply_list']).length} ${asList(r['reply_list']).length == 1 ? 'reply' : 'replies'}',
                              style: context.ty.sm.bold.col(c.link),
                            ),
                          ),
                        ),
                    Divider(height: 1, color: c.border),
                  ],
                  if (_aiTyping) const _AiTyping(),
                ],
              ),
            ),
          ),
          if (p['status'] == 'shown') _replyBar(context),
        ],
      );
    }
    return Scaffold(
      backgroundColor: c.surface,
      appBar: TopBar(title: 'Post'),
      body: body,
    );
  }

  Widget _replyBar(BuildContext context) {
    final c = context.c;
    final me = ref.watch(communityMeProvider).value ?? const {};
    final can = _text.text.trim().isNotEmpty && !_sending;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.s3, Space.s2, Space.s3, Space.s2),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_to != null)
              Padding(
                padding: const EdgeInsets.only(left: 46, bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text('Replying to @${_to!['handle']}', style: context.ty.cap.col(c.link))),
                    InkResponse(
                      onTap: () => setState(() => _to = null),
                      child: Icon(PhosphorIcons.x(), size: 16, color: c.textMuted, semanticLabel: 'Stop replying to this person'),
                    ),
                  ],
                ),
              ),
            MentionSuggestions(controller: _text, focus: _focus, maxRows: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: CAvatar(name: '${me['name'] ?? 'Me'}', photo: me['avatar_path'] as String?, size: 34),
                ),
                const Gap(10),
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    style: context.ty.body,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Post your reply',
                      counterText: '',
                      filled: true,
                      fillColor: c.surfaceSunken,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(color: c.focus, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const Gap(Space.s2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: AnimatedOpacity(
                    opacity: can ? 1 : .5,
                    duration: Motion.fast,
                    child: FilledButton(
                      onPressed: can ? _send : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.gold400,
                        foregroundColor: Palette.navy900,
                        disabledBackgroundColor: Palette.gold400,
                        disabledForegroundColor: Palette.navy900,
                        shape: const StadiumBorder(),
                        minimumSize: const Size(72, 44),
                      ),
                      child: _sending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Palette.navy900))
                          : Text('Reply', style: context.ty.sm.bold.col(Palette.navy900)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BigPost extends ConsumerWidget {
  const _BigPost({required this.p, required this.onReply});
  final Json p;
  final VoidCallback onReply;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final status = '${p['status']}';
    final imgs = [for (final x in (p['images'] as List? ?? const [])) '$x'];
    final subjects = ref.watch(subjectsProvider).value ?? const [];
    final subject = subjects.where((s) => s['id'] == p['subject_id']).firstOrNull?['name'];
    final reposts = (p['reposts'] as num?)?.toInt() ?? 0;
    final likes = (p['likes'] as num?)?.toInt() ?? 0;
    final mine = p['mine'] == true;
    final page = p['page_id'] != null;
    // A page post (e.g. the official SolutionTee page) opens the page, not the staff member who wrote it.
    void openUser() => page ? context.push('/community/u/${p['handle']}') : context.push('/community/user/${p['user_id']}');
    Widget stat(int n, String one, String many) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: countText(n), style: context.ty.sm.bold),
          TextSpan(text: ' ${n == 1 ? one : many}', style: context.ty.sm.col(c.textMuted)),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CAvatar(name: '${p['name']}', photo: p['avatar_path'] as String?, size: 48, onTap: openUser, brand: p['badge'] == 'official'),
              const Gap(Space.s3),
              Expanded(
                child: GestureDetector(
                  onTap: openUser,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text('${p['name']}', style: context.ty.body.bold.copyWith(fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          if (p['badge'] != null) ...[const Gap(4), CBadge('${p['badge']}', size: 16)],
                        ],
                      ),
                      Text('@${p['handle']}', style: context.ty.sm.col(c.textMuted)),
                    ],
                  ),
                ),
              ),
              if (!mine || page)
                FollowPill(user: page ? '${p['page_id']}' : '${p['user_id']}', following: p['following'] == true, handle: '${p['handle']}', page: page),
              PostMenu(post: p, onGone: () => context.canPop() ? context.pop() : null),
            ],
          ),
          const Gap(Space.s3),
          if ('${p['body'] ?? ''}'.isNotEmpty) CText('${p['body']}', style: context.ty.lg.copyWith(fontSize: 17, height: 1.45)),
          if (imgs.isNotEmpty) ...[const Gap(Space.s3), ImageGrid(keys: imgs, height: 240)],
          if (p['quote'] is Map) ...[const Gap(Space.s3), QuoteCard(q: asJson(p['quote']))],
          if (status == 'pending') ...[const Gap(Space.s3), const CheckingNote()],
          if (status == 'rejected') ...[const Gap(Space.s3), NotShownNote(reason: p['reason'] as String?)],
          const Gap(Space.s3),
          Wrap(
            spacing: Space.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(fullTime(p['created_at']), style: context.ty.sm.col(c.textMuted)),
              if (subject != null) SubjectChip('$subject', id: p['subject_id'] as int?),
            ],
          ),
          if (status == 'shown') ...[
            if (reposts > 0 || likes > 0) ...[
              const Gap(Space.s3),
              Divider(height: 1, color: c.border),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s3),
                child: Wrap(spacing: 18, children: [if (reposts > 0) stat(reposts, 'Repost', 'Reposts'), if (likes > 0) stat(likes, 'Like', 'Likes')]),
              ),
            ] else
              const Gap(Space.s2),
            Divider(height: 1, color: c.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: PostActions(post: p, onReply: onReply, big: true),
            ),
            Divider(height: 1, color: c.border),
          ] else
            const Gap(Space.s4),
        ],
      ),
    );
  }
}

class _ReplyTile extends ConsumerStatefulWidget {
  const _ReplyTile({required this.r, required this.onReply, required this.onChanged, this.nested = false, this.line = false, this.index});
  final Json r;
  final VoidCallback onReply;
  final VoidCallback onChanged;
  final bool nested;
  final bool line;
  final int? index;
  @override
  ConsumerState<_ReplyTile> createState() => _ReplyTileState();
}

class _ReplyTileState extends ConsumerState<_ReplyTile> {
  late bool _liked = widget.r['liked'] == true;
  late int _likes = (widget.r['likes'] as num?)?.toInt() ?? 0;

  @override
  void didUpdateWidget(_ReplyTile old) {
    super.didUpdateWidget(old);
    if (old.r != widget.r) {
      _liked = widget.r['liked'] == true;
      _likes = (widget.r['likes'] as num?)?.toInt() ?? 0;
    }
  }

  Future<void> _like() async {
    HapticFeedback.lightImpact();
    setState(() => (_liked = !_liked, _likes += _liked ? 1 : -1));
    try {
      final x = asJson(await crpc('community_comment_like', {'p_id': widget.r['id']}));
      if (mounted && x['ok'] == true) setState(() => (_liked = x['liked'] == true, _likes = (x['likes'] as num).toInt()));
    } catch (_) {
      if (mounted) setState(() => (_liked = !_liked, _likes += _liked ? 1 : -1));
    }
  }

  Future<void> _menu() async {
    final r = widget.r;
    final pick = await showSheet<String>(
      context,
      builder: (ctx) => ListCard(
        children: [
          ListRow(title: 'Copy text', onTap: () => Navigator.pop(ctx, 'copy')),
          if (r['mine'] == true) ListRow(title: 'Delete reply', onTap: () => Navigator.pop(ctx, 'delete')),
          if (r['mine'] != true && r['from_ai'] != true) ListRow(title: 'Report reply', onTap: () => Navigator.pop(ctx, 'report')),
          if (r['mine'] != true && ref.read(communityMeProvider).value?['mod'] == true)
            ListRow(title: 'Remove reply (moderator)', onTap: () => Navigator.pop(ctx, 'mod')),
        ],
      ),
    );
    if (!mounted || pick == null) return;
    try {
      switch (pick) {
        case 'copy':
          await Clipboard.setData(ClipboardData(text: '${r['body']}'));
          if (mounted) toast(context, 'Copied', icon: PhosphorIcons.copy());
        case 'delete':
          if (!await confirmDelete(context, 'Delete this reply?')) return;
          await crpc('community_comment_delete', {'p_id': r['id']});
          widget.onChanged();
        case 'mod':
          final why = await pickRemoveReason(context);
          if (why == null) return;
          await crpc('community_mod_remove', {'p_kind': 'comment', 'p_id': '${r['id']}', 'p_reason': why});
          if (mounted) toast(context, 'Removed. The student is told why.');
          widget.onChanged();
        case 'report':
          final reason = await pickReportReason(context);
          if (reason == null) return;
          await crpc('community_report', {'p_kind': 'comment', 'p_ref': '${r['id']}', 'p_reason': reason});
          if (mounted) toast(context, 'Thanks. We will look at it.');
      }
    } catch (_) {
      if (mounted) toast(context, offlineText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = widget.r;
    final ai = r['from_ai'] == true;
    final status = '${r['status']}';
    final size = widget.nested ? 32.0 : 40.0;
    final tile = InkWell(
      onLongPress: _menu,
      child: Padding(
        padding: EdgeInsets.fromLTRB(widget.nested ? 68 : Space.s4, Space.s3, Space.s3, 0),
        child: Stack(
          children: [
            if (widget.line)
              Positioned(
                left: size / 2 - 1,
                top: size + 4,
                bottom: 0,
                child: Container(width: 2, color: c.border),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CAvatar(
                  name: '${r['name']}',
                  photo: r['avatar_path'] as String?,
                  size: size,
                  ai: ai,
                  onTap: ai ? null : () => context.push('/community/user/${r['user_id']}'),
                ),
                const Gap(Space.s3),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Space.s2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: NameLine(
                                name: '${r['name']}',
                                nameStyle: context.ty.sm.bold,
                                badge: r['badge'] != null ? CBadge('${r['badge']}', size: 14) : null,
                                handle: '${r['handle']}',
                                time: agoText(r['created_at']),
                                metaStyle: context.ty.sm.col(c.textMuted),
                              ),
                            ),
                            InkResponse(
                              onTap: _menu,
                              radius: 18,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(PhosphorIcons.dotsThree(), size: 18, color: c.textMuted, semanticLabel: 'More'),
                              ),
                            ),
                          ],
                        ),
                        if (widget.nested && r['reply_to_handle'] != null) Text('Replying to @${r['reply_to_handle']}', style: context.ty.cap.col(c.link)),
                        const Gap(2),
                        // SolutionTee AI writes Markdown (bold, lists, maths): a soft card, long answers fold.
                        if (ai) AiReplyBody(text: '${r['body']}') else CText('${r['body']}', style: context.ty.body),
                        if (status == 'pending') ...[const Gap(Space.s2), const CheckingNote(text: 'Being checked. Only you can see it for now.')],
                        if (status == 'rejected') ...[const Gap(Space.s2), NotShownNote(reason: r['reason'] as String?)],
                        if (status == 'shown')
                          Transform.translate(
                            offset: const Offset(-8, 0),
                            child: Row(
                              children: [
                                ActionBtn(icon: PhosphorIcons.chatCircle(), label: 'Reply', onTap: widget.onReply),
                                ActionBtn(
                                  icon: PhosphorIcons.heart(),
                                  label: _liked ? 'Unlike' : 'Like',
                                  count: _likes,
                                  color: _liked ? kLike : null,
                                  onTap: _like,
                                  child: HeartIcon(on: _liked, size: 17),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final i = widget.index;
    if (i == null || i > 8 || context.reduceMotion) return tile;
    return tile.animate().fadeIn(delay: (40 * i).ms, duration: Motion.base);
  }
}

// ---------------------------------------------------------------- compose

/// SolutionTee AI's reply in a thread: Markdown in a soft card; answers longer than about 9 lines fold with "Show more".
class _AiTyping extends StatelessWidget {
  const _AiTyping();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dots = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(color: c.textMuted, shape: BoxShape.circle),
          ).animate(onPlay: (a) => a.repeat()).fade(begin: .3, end: 1, delay: (150 * i).ms, duration: 450.ms).then().fade(begin: 1, end: .3, duration: 450.ms),
      ],
    );
    return Semantics(
      liveRegion: true,
      label: 'SolutionTee AI is typing',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, Space.s3),
        child: Row(
          children: [
            const CAvatar(name: 'SolutionTee AI', ai: true, size: 40),
            const Gap(Space.s3),
            Text('SolutionTee AI is typing', style: context.ty.sm.bold.col(c.textMuted)),
            const Gap(6),
            context.reduceMotion ? const SizedBox.shrink() : dots,
          ],
        ),
      ),
    );
  }
}

class AiReplyBody extends StatefulWidget {
  const AiReplyBody({super.key, required this.text});
  final String text;
  @override
  State<AiReplyBody> createState() => _AiReplyBodyState();
}

class _AiReplyBodyState extends State<AiReplyBody> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final long = widget.text.length > 420 || '\n'.allMatches(widget.text).length > 7;
    final body = NoteBody(text: widget.text, scale: .88);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 2),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.standard,
            alignment: Alignment.topCenter,
            child: !long || _open
                ? body
                : ClipRect(
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (r) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black, Colors.black, Colors.transparent],
                        stops: [0, .7, 1],
                      ).createShader(r),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: body),
                      ),
                    ),
                  ),
          ),
          if (long)
            TextButton(
              onPressed: () => setState(() => _open = !_open),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(48, 36), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(_open ? 'Show less' : 'Show more', style: context.ty.sm.bold.col(c.link)),
            ),
        ],
      ),
    );
  }
}

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key, this.quote, this.subject, this.text, this.page});
  final Json? quote;

  /// Staff posting as a SolutionTee page (the page's id, name and handle).
  final Json? page;
  final int? subject;
  final String? text;
  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  late Json? _as = widget.page;
  int get max => _as != null ? 1000 : 500;
  late final _text = TextEditingController(text: widget.text ?? '');
  final _focus = FocusNode();
  late int? _subject = widget.subject ?? (widget.quote?['subject_id'] as num?)?.toInt();
  final _photos = <File>[];
  bool _busy = false;
  bool _preview = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _text.selection = const TextSelection.collapsed(offset: 0);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final left = 4 - _photos.length;
    if (left <= 0) return;
    try {
      final xs = await ImagePicker().pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 78, limit: left);
      if (!mounted || xs.isEmpty) return;
      setState(() => _photos.addAll(xs.take(left).map((x) => File(x.path))));
    } catch (_) {
      if (mounted) toast(context, 'Could not open your photos.');
    }
  }

  void _insert(String s) {
    final t = _text.text;
    final sel = _text.selection;
    final at = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    final add = (at > 0 && t[at - 1] != ' ' && s.startsWith('#')) ? ' $s' : s;
    _text.value = TextEditingValue(
      text: t.replaceRange(at, end, add),
      selection: TextSelection.collapsed(offset: at + add.length),
    );
    _focus.requestFocus();
    setState(() {});
  }

  Future<void> _pickSubject() async {
    final subjects = ref.read(subjectsProvider).value ?? const <Map<String, dynamic>>[];
    final v = await showSheet<int>(
      context,
      scroll: true,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Which subject is it about?', style: ctx.ty.h3),
          const Gap(Space.s3),
          ListCard(
            children: [
              ListRow(title: 'No subject', onTap: () => Navigator.pop(ctx, -1)),
              for (final s in subjects) ListRow(title: '${s['name']}', onTap: () => Navigator.pop(ctx, (s['id'] as num).toInt())),
            ],
          ),
        ],
      ),
    );
    if (v != null && mounted) setState(() => _subject = v < 0 ? null : v);
  }

  Future<bool> _leave() async {
    if (_text.text.trim().isEmpty && _photos.isEmpty) return true;
    final ok = await showAppDialog<bool>(
      context,
      title: 'Discard this post?',
      body: 'What you wrote will be lost.',
      actions: [
        Builder(
          builder: (ctx) => Row(
            children: [
              Expanded(
                child: Btn('Keep writing', kind: BtnKind.secondary, onPressed: () => Navigator.pop(ctx, false)),
              ),
              const Gap(Space.s3),
              Expanded(
                child: Btn('Discard', kind: BtnKind.danger, onPressed: () => Navigator.pop(ctx, true)),
              ),
            ],
          ),
        ),
      ],
    );
    return ok == true;
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty && _photos.isEmpty) return setState(() => _error = communityError('short'));
    setState(() => (_busy = true, _error = null));
    try {
      final keys = <String>[];
      for (final f in _photos) {
        final bytes = await f.readAsBytes();
        if (bytes.length > 3 * 1024 * 1024) throw const _Msg('One picture is too big. Choose a smaller one.');
        try {
          final (k, url) = await ref.read(apiProvider).communityUploadLink(bytes.length);
          final r = await http.put(Uri.parse(url), headers: {'content-type': 'image/jpeg'}, body: bytes).timeout(const Duration(seconds: 60));
          if (r.statusCode >= 300) throw Exception('upload');
          keys.add(k);
        } catch (_) {
          throw const _Msg('Could not upload a picture. Check your internet and try again.');
        }
      }
      final r = asJson(
        _as != null
            ? await crpc('community_page_post', {'p_page': _as!['id'], 'p_body': body, 'p_images': keys, 'p_subject': _subject})
            : await crpc('community_post_send', {'p_body': body, 'p_images': keys, 'p_subject': _subject, 'p_quote': widget.quote?['id']}),
      );
      if (r['ok'] != true) throw _Msg(r['error'] == 'banned' ? pausedText(r['until']) : communityError(r['error']));
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      toast(context, r['status'] == 'pending' ? 'Posted! We are checking it now.' : 'Posted!', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(communityTickProvider.notifier).bump();
      context.pop(true);
      if (r['status'] != 'rejected') {
        await checkNow('post', r['id']);
        container.read(communityTickProvider.notifier).bump();
      }
    } on _Msg catch (e) {
      if (mounted) setState(() => _error = e.text);
    } catch (_) {
      if (mounted) setState(() => _error = offlineText);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = ref.watch(communityMeProvider).value ?? const {};
    final subjects = ref.watch(subjectsProvider).value ?? const [];
    final subject = subjects.where((s) => s['id'] == _subject).firstOrNull?['name'];
    final n = _text.text.characters.length;
    final left = max - n;
    final can = (n > 0 || _photos.isNotEmpty) && left >= 0 && !_busy;
    final askAi = RegExp(r'@solutiontee\b', caseSensitive: false).hasMatch(_text.text);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) async {
        if (did) return;
        if (await _leave() && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: c.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.s2, Space.s2, Space.s3, Space.s2),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        if (await _leave() && context.mounted) context.pop();
                      },
                      style: TextButton.styleFrom(foregroundColor: c.text, minimumSize: const Size(64, 44)),
                      child: Text('Cancel', style: context.ty.body),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: can ? 1 : .45,
                      duration: Motion.fast,
                      child: FilledButton(
                        onPressed: can ? _send : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Palette.gold400,
                          foregroundColor: Palette.navy900,
                          disabledBackgroundColor: Palette.gold400,
                          disabledForegroundColor: Palette.navy900,
                          shape: const StadiumBorder(),
                          minimumSize: const Size(84, 44),
                        ),
                        child: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Palette.navy900))
                            : Text(widget.quote != null ? 'Quote' : 'Post', style: context.ty.body.bold.col(Palette.navy900)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.s4, Space.s1, Space.s4, Space.s4),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _as != null
                            ? CAvatar(
                                name: '${_as!['name']}',
                                photo: _as!['avatar_path'] as String?,
                                size: 40,
                                brand: _as!['official'] == true || _as!['badge'] == 'official',
                              )
                            : CAvatar(name: '${me['name'] ?? 'Me'}', photo: me['avatar_path'] as String?, size: 40),
                        const Gap(Space.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (me['banned_until'] != null && _as == null) ...[
                                InfoBanner(kind: BannerKind.err, child: Text(pausedText(me['banned_until']))),
                                const Gap(Space.s3),
                              ],
                              if ((me['pages'] as List? ?? const []).isNotEmpty && widget.quote == null) ...[
                                _PostAs(me: me, value: _as, onChanged: (v) => setState(() => _as = v)),
                                const Gap(Space.s2),
                              ],
                              GestureDetector(
                                onTap: _pickSubject,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(Radii.pill),
                                    border: Border.all(color: Palette.blue600),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(subject != null ? '$subject' : 'Add a subject', style: context.ty.sm.bold.col(c.link)),
                                      const Gap(4),
                                      Icon(PhosphorIcons.caretDown(), size: 14, color: c.link),
                                    ],
                                  ),
                                ),
                              ),
                              TextField(
                                controller: _text,
                                focusNode: _focus,
                                minLines: 4,
                                maxLines: null,
                                textCapitalization: TextCapitalization.sentences,
                                keyboardType: TextInputType.multiline,
                                style: context.ty.lg.copyWith(fontSize: 19, height: 1.42),
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: 'Ask a question, share a tip or say hello',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: EdgeInsets.symmetric(vertical: Space.s3),
                                ),
                              ),
                              MentionSuggestions(controller: _text, focus: _focus),
                              if (_preview && _text.text.contains(r'$')) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(Space.s3),
                                  decoration: BoxDecoration(
                                    color: c.surfaceSunken,
                                    borderRadius: BorderRadius.circular(Radii.md),
                                    border: Border.all(color: c.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('MATHS PREVIEW', style: context.ty.over),
                                      const Gap(6),
                                      CText(_text.text, style: context.ty.body),
                                    ],
                                  ),
                                ),
                                const Gap(Space.s3),
                              ],
                              if (_photos.isNotEmpty || widget.quote == null)
                                SizedBox(
                                  height: 120,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      for (final (i, f) in _photos.indexed)
                                        Padding(
                                          padding: const EdgeInsets.only(right: Space.s2),
                                          child: Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(Radii.lg),
                                                child: Image.file(f, width: 120, height: 120, fit: BoxFit.cover, cacheWidth: 360),
                                              ),
                                              Positioned(
                                                top: 6,
                                                right: 6,
                                                child: Semantics(
                                                  button: true,
                                                  label: 'Remove photo ${i + 1}',
                                                  child: GestureDetector(
                                                    onTap: () => setState(() => _photos.removeAt(i)),
                                                    child: Container(
                                                      width: 28,
                                                      height: 28,
                                                      decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                                                      child: Icon(PhosphorIcons.x(), size: 15, color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ).animate().scale(
                                          begin: const Offset(.85, .85),
                                          duration: context.reduceMotion ? 0.ms : 220.ms,
                                          curve: Curves.easeOutBack,
                                        ),
                                      if (_photos.length < 4)
                                        InkWell(
                                          onTap: _pick,
                                          borderRadius: BorderRadius.circular(Radii.lg),
                                          child: Container(
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(Radii.lg),
                                              border: Border.all(color: c.borderStrong, width: 1.5),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(PhosphorIcons.image(), color: c.link),
                                                const Gap(4),
                                                Text(
                                                  _photos.isEmpty ? 'Add photos' : 'Add (${4 - _photos.length} left)',
                                                  style: context.ty.cap.bold.col(c.link),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              if (widget.quote != null) ...[const Gap(Space.s3), QuoteCard(q: widget.quote!, onTap: () {})],
                              const Gap(Space.s3),
                              AnimatedContainer(
                                duration: Motion.base,
                                padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: 10),
                                decoration: BoxDecoration(
                                  color: askAi ? c.accentSoft : c.surfaceSunken,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: askAi ? Palette.gold400 : c.border),
                                ),
                                child: Row(
                                  children: [
                                    const CAvatar(name: 'SolutionTee AI', ai: true, size: 22),
                                    const Gap(Space.s2),
                                    Expanded(
                                      child: askAi
                                          ? Text('SolutionTee AI will answer once your post is shown.', style: context.ty.sm.col(c.onAccentSoft))
                                          : Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(text: 'Type ', style: context.ty.sm.col(c.textMuted)),
                                                  TextSpan(
                                                    text: '@solutiontee',
                                                    style: context.ty.sm.bold.col(context.isDark ? Palette.gold400 : Palette.gold700),
                                                  ),
                                                  TextSpan(text: ' and SolutionTee AI answers your question.', style: context.ty.sm.col(c.textMuted)),
                                                ],
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_error != null) ...[const Gap(Space.s3), ErrText(_error!)],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s2),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.globeHemisphereWest(), size: 15, color: c.textMuted),
                    const Gap(6),
                    Expanded(child: Text('Everyone in Community can reply · Checked quickly before others see it', style: context.ty.cap.col(c.textMuted))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(Space.s2, Space.s1, Space.s3, Space.s1),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    IconBtn(PhosphorIcons.image(), label: 'Add photos', color: c.link, onPressed: _photos.length < 4 && widget.quote == null ? _pick : null),
                    IconBtn(
                      PhosphorIcons.function(),
                      label: _preview ? 'Hide maths preview' : 'Show maths preview',
                      color: _preview ? Palette.gold500 : c.link,
                      onPressed: () {
                        if (!_text.text.contains(r'$')) _insert(r'$x^2$');
                        setState(() => _preview = !_preview || !_text.text.contains(r'$'));
                      },
                    ),
                    IconBtn(PhosphorIcons.bookOpen(), label: 'Subject', color: c.link, onPressed: _pickSubject),
                    IconBtn(PhosphorIcons.hash(), label: 'Add a topic', color: c.link, onPressed: () => _insert('#')),
                    const Spacer(),
                    if (left < 60) Text('$left', style: context.ty.sm.tnum.col(left < 20 ? kLike : Palette.gold500)),
                    const Gap(Space.s2),
                    _Ring(used: n / max, left: left),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Msg implements Exception {
  const _Msg(this.text);
  final String text;
}

/// The ring that fills as you type (blue, gold near the end, red over).
class _Ring extends StatelessWidget {
  const _Ring({required this.used, required this.left});
  final double used;
  final int left;
  @override
  Widget build(BuildContext context) {
    final col = left < 20 ? kLike : (left < 60 ? Palette.gold400 : Palette.blue600);
    return Semantics(
      label: '$left characters left',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: used.clamp(0, 1)),
        duration: context.reduceMotion ? Duration.zero : Motion.fast,
        builder: (_, v, _) => SizedBox(width: 26, height: 26, child: CustomPaint(painter: _RingPainter(v, col, context.c.border))),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.col, this.track);
  final double v;
  final Color col;
  final Color track;
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: s.width / 2 - 2);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = track,
    );
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * v,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = col,
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.col != col;
}

/// Staff choose who posts: themselves or a SolutionTee page they manage.
class _PostAs extends StatelessWidget {
  const _PostAs({required this.me, required this.value, required this.onChanged});
  final Json me;
  final Json? value;
  final ValueChanged<Json?> onChanged;
  @override
  Widget build(BuildContext context) {
    final pages = asList(me['pages']);
    final c = context.c;
    return Wrap(
      spacing: Space.s2,
      runSpacing: Space.s2,
      children: [
        ChoiceChip(label: Text('Me (@${me['handle'] ?? 'you'})'), selected: value == null, onSelected: (_) => onChanged(null)),
        for (final p in pages)
          ChoiceChip(
            avatar: CBadge(p['official'] == true ? 'official' : 'page', size: 16),
            label: Text('${p['name']}'),
            selected: value?['id'] == p['id'],
            selectedColor: c.accentSoft,
            onSelected: (_) => onChanged(p),
          ),
      ],
    );
  }
}
