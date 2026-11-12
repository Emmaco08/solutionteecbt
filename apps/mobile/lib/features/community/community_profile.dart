import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import 'community_data.dart';
import 'community_shell.dart' show FeedList;
import 'community_widgets.dart';

// Community profile (D-155): banner with a subject pattern, photo or initials, name, @handle, bio, exams and subjects,
// joined date, following / followers, streak; tabs Posts · Replies, plus Likes · Saved on your own profile.

const headerColors = [Palette.navy900, Palette.blue800, Color(0xFF0F3B26), Color(0xFF3A1F4D), Palette.gold800, Color(0xFF0E3B47)];

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key, this.id, this.handle, this.inShell = false});
  final String? id;
  final String? handle;
  final bool inShell;
  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  Json? _u;
  Object? _err;
  int _tab = 0;
  final _pagers = <String, Pager>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = asJson(await crpc('community_user', {'p_user': widget.id, 'p_handle': widget.handle}));
      if (!mounted) return;
      setState(() => (_u = r, _err = null));
      if (r['me'] == true) ref.read(communityUnreadProvider.notifier).set((r['unread'] as num?)?.toInt() ?? ref.read(communityUnreadProvider));
      _pager(_tabs[_tab].$1).refresh();
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  List<(String, String)> get _tabs => [
    ('posts', 'Posts'),
    if (_u?['is_page'] != true) ('replies', 'Replies'),
    if (_u?['me'] == true) ...[('likes', 'Likes'), ('saved', 'Saved')],
  ];

  Pager _pager(String tab) => _pagers.putIfAbsent(tab, () {
    final id = '${_u!['id']}';
    return Pager((o) async => asList(await crpc('community_user_list', {'p_user': id, 'p_tab': tab, 'p_offset': o})));
  });

  @override
  void dispose() {
    for (final p in _pagers.values) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    ref.listen(communityTickProvider, (_, _) {
      _load();
      for (final p in _pagers.values) {
        if (p.started) p.refresh();
      }
    });
    final u = _u;
    if (u == null) {
      return Scaffold(
        backgroundColor: c.surface,
        appBar: widget.inShell ? null : TopBar(title: 'Profile'),
        body: _err != null
            ? StateBlock(
                icon: PhosphorIcons.wifiSlash(),
                title: 'You are offline',
                text: offlineText,
                action: Btn('Try again', sm: true, onPressed: _load),
              )
            : const PostSkeletons(count: 3),
      );
    }
    if (u['status'] == 'not_found') {
      return Scaffold(
        appBar: TopBar(title: 'Profile'),
        body: StateBlock(icon: PhosphorIcons.user(PhosphorIconsStyle.fill), title: 'Student not found', text: 'This account may have changed its @handle.'),
      );
    }
    final tabs = _tabs;
    final tab = tabs[_tab.clamp(0, tabs.length - 1)].$1;
    final pager = _pager(tab);
    final blocked = u['blocked'] == true || u['blocked_me'] == true;
    final emptyText = switch (tab) {
      'replies' => 'No replies yet.',
      'likes' => 'Posts you like show here. Only you can see them.',
      'saved' => 'Tap the bookmark on a post to save it here. Only you can see them.',
      _ => u['me'] == true ? 'Your posts show here. Say hello to Community!' : 'No posts yet.',
    };
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(u: u, inShell: widget.inShell, onChanged: _load),
        const Gap(Space.s3),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Row(
            children: [
              for (final (i, t) in tabs.indexed)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _tab = i);
                      final p = _pager(t.$1);
                      if (!p.started) p.refresh();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          Text(t.$2, style: i == _tab ? context.ty.body.bold : context.ty.body.col(c.textMuted)),
                          const Gap(10),
                          AnimatedContainer(
                            duration: context.reduceMotion ? Duration.zero : Motion.fast,
                            width: i == _tab ? 40 : 0,
                            height: 4,
                            decoration: BoxDecoration(color: Palette.gold400, borderRadius: BorderRadius.circular(2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    if (blocked) {
      return Scaffold(
        backgroundColor: c.surface,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(u: u, inShell: widget.inShell, onChanged: _load),
            StateBlock(
              icon: PhosphorIcons.prohibit(),
              title: u['blocked'] == true ? 'You blocked @${u['handle']}' : 'You cannot see these posts',
              text: u['blocked'] == true ? 'Unblock to see their posts again.' : null,
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: c.surface,
      body: tab == 'replies'
          ? _RepliesList(pager: pager, header: header, empty: emptyText, onRefresh: _load)
          : FeedList(
              key: ValueKey(tab),
              pager: pager,
              header: header,
              empty: Padding(
                padding: const EdgeInsets.all(Space.s6),
                child: Text(emptyText, style: context.ty.sm.col(c.textMuted), textAlign: TextAlign.center),
              ),
            ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.u, required this.inShell, required this.onChanged});
  final Json u;
  final bool inShell;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final top = MediaQuery.paddingOf(context).top;
    final me = u['me'] == true;
    final color = headerColors[((u['header'] as num?)?.toInt() ?? 0).clamp(0, headerColors.length - 1)];
    final subjects = [for (final s in (u['subjects'] as List? ?? const [])) '$s'];
    final exams = [for (final s in (u['exams'] as List? ?? const [])) '$s'];
    final streak = (u['streak'] as num?)?.toInt() ?? 0;
    Widget count(String n, String label, String kind) => InkWell(
      onTap: () => context.push('/community/follows/${u['id']}?kind=$kind&name=${Uri.encodeComponent('${u['name']}')}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: n, style: context.ty.sm.bold),
              const WidgetSpan(child: SizedBox(width: 5)),
              TextSpan(text: label, style: context.ty.sm.col(c.textMuted)),
            ],
          ),
        ),
      ),
    );
    final page = u['is_page'] == true;
    final followers = (u['followers'] as num?)?.toInt() ?? 0;
    Widget action() {
      if (me) {
        return OutlinedButton(
          onPressed: () async {
            await context.push('/community/edit');
            onChanged();
          },
          style: OutlinedButton.styleFrom(
            shape: const StadiumBorder(),
            side: BorderSide(color: c.borderStrong),
            foregroundColor: c.text,
            minimumSize: const Size(0, 40),
          ),
          child: Text('Edit profile', style: context.ty.sm.bold),
        );
      }
      if (page && u['can_post'] == true) {
        return FilledButton(
          onPressed: () => context.push('/community/compose', extra: {'page': u}),
          style: FilledButton.styleFrom(
            backgroundColor: Palette.gold400,
            foregroundColor: Palette.navy900,
            shape: const StadiumBorder(),
            minimumSize: const Size(0, 40),
          ),
          child: Text('Post as page', style: context.ty.sm.bold.col(Palette.navy900)),
        );
      }
      if (u['blocked'] == true) {
        return OutlinedButton(
          onPressed: () async {
            await crpc('community_block', {'p_user': u['id']});
            ref.read(communityTickProvider.notifier).bump();
          },
          style: OutlinedButton.styleFrom(shape: const StadiumBorder(), foregroundColor: c.error),
          child: const Text('Unblock'),
        );
      }
      if (u['blocked_me'] == true) return const SizedBox.shrink();
      return FollowPill(user: '${u['id']}', following: u['following'] == true, followsMe: u['follows_me'] == true, handle: '${u['handle']}', page: page);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(height: 128 + top, width: double.infinity, color: color, child: const _Pattern()),
            if (!inShell || context.canPop())
              Positioned(
                top: top + 10,
                left: 10,
                child: _Round(icon: PhosphorIcons.caretLeft(), label: 'Back', onTap: () => context.canPop() ? context.pop() : context.go('/community')),
              ),
            if (!me && !page)
              Positioned(
                top: top + 10,
                right: 10,
                child: _Round(icon: PhosphorIcons.dotsThree(), label: 'More', onTap: () => _more(context, ref)),
              ),
            Positioned(
              left: Space.s4,
              bottom: -40,
              child: CAvatar(name: '${u['name']}', photo: u['avatar_path'] as String?, size: 84, ring: c.surface, brand: u['badge'] == 'official'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, 0),
          child: SizedBox(height: 44, child: Row(children: [const Spacer(), action()])),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text('${u['name']}', style: context.ty.h2, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  if (u['badge'] != null) ...[const Gap(Space.s2), CBadge('${u['badge']}', size: 20)],
                ],
              ),
              const Gap(2),
              Wrap(
                spacing: Space.s2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('@${u['handle']}', style: context.ty.body.col(c.textMuted)),
                  if (u['follows_me'] == true && !me)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(4)),
                      child: Text('Follows you', style: context.ty.cap.col(c.textMuted)),
                    ),
                ],
              ),
              if (me && (u['pending_handle'] != null || u['pending_bio'] != null)) ...[
                const Gap(Space.s3),
                CheckingNote(text: u['pending_handle'] != null ? 'Your new @${u['pending_handle']} is being checked.' : 'Your new bio is being checked.'),
              ],
              if (me && u['pending_reason'] != null) ...[const Gap(Space.s3), NotShownNote(reason: '${u['pending_reason']}')],
              if (me && u['banned_until'] != null) ...[const Gap(Space.s3), InfoBanner(kind: BannerKind.err, child: Text(pausedText(u['banned_until'])))],
              if ('${u['bio'] ?? ''}'.isNotEmpty) ...[const Gap(Space.s3), CText('${u['bio']}', style: context.ty.body)],
              const Gap(Space.s4),
              if (exams.isNotEmpty) ...[_Meta(icon: PhosphorIcons.graduationCap(), label: 'Exams', text: exams.join(', ')), const Gap(10)],
              if (subjects.isNotEmpty) ...[_Meta(icon: PhosphorIcons.books(), label: 'Subjects', text: subjects.join(', ')), const Gap(10)],
              _Meta(icon: PhosphorIcons.calendarBlank(), label: 'Joined', text: 'Joined ${monthYear(u['joined'])}'),
              const Gap(Space.s3),
              Wrap(
                spacing: 28,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (!page) count(countText((u['following_count'] as num?)?.toInt() ?? 0), 'Following', 'following'),
                  page
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: countText(followers), style: context.ty.sm.bold),
                                const WidgetSpan(child: SizedBox(width: 5)),
                                TextSpan(text: followers == 1 ? 'Follower' : 'Followers', style: context.ty.sm.col(c.textMuted)),
                              ],
                            ),
                          ),
                        )
                      : count(countText(followers), followers == 1 ? 'Follower' : 'Followers', 'followers'),
                  // Streaks are for students; staff, the official page and other pages do not show one (owner, 13 Nov 2026).
                  if (streak > 0 && (u['badge'] == null || u['badge'] == 'mod') && !page)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIcons.fire(PhosphorIconsStyle.fill), size: 16, color: Palette.gold400),
                        const Gap(4),
                        Text('$streak day streak', style: context.ty.sm.bold.col(context.isDark ? Palette.gold200 : Palette.gold700)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _more(BuildContext context, WidgetRef ref) async {
    final pick = await showSheet<String>(
      context,
      builder: (ctx) => ListCard(
        children: [
          ListRow(title: u['blocked'] == true ? 'Unblock @${u['handle']}' : 'Block @${u['handle']}', onTap: () => Navigator.pop(ctx, 'block')),
          ListRow(title: 'Report @${u['handle']}', onTap: () => Navigator.pop(ctx, 'report')),
        ],
      ),
    );
    if (!context.mounted || pick == null) return;
    try {
      if (pick == 'block') {
        if (u['blocked'] != true && !await confirmBlock(context, '${u['handle']}')) return;
        await crpc('community_block', {'p_user': u['id']});
        ref.read(communityTickProvider.notifier).bump();
      } else {
        final reason = await pickReportReason(context);
        if (reason == null) return;
        await crpc('community_report', {'p_kind': 'post', 'p_ref': 'user:${u['id']}', 'p_reason': reason});
        if (context.mounted) toast(context, 'Thanks. We will look at it.');
      }
    } catch (_) {
      if (context.mounted) toast(context, offlineText);
    }
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkResponse(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: Color(0x73000000), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, required this.text});
  final IconData icon;
  final String label;
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label == 'Joined' ? text : '$label: $text',
    excludeSemantics: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: context.c.textMuted),
        ),
        const Gap(10),
        Expanded(child: Text(text, style: context.ty.sm.col(context.c.textMuted).copyWith(height: 1.45))),
      ],
    ),
  );
}

/// Faint maths and science symbols on the banner.
class _Pattern extends StatelessWidget {
  const _Pattern();
  static const _s = ['x²', 'λ', 'π', 'Σ', 'Δ', '√', 'θ', '∫', 'f(x)', 'Ω', 'α', 'H₂O'];
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Opacity(
      opacity: .16,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 40, 6, 0),
        child: GridView.count(
          crossAxisCount: 6,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          childAspectRatio: 1.4,
          children: [
            for (final s in _s)
              Center(
                child: Text(
                  s,
                  style: const TextStyle(fontFamily: 'serif', fontStyle: FontStyle.italic, fontSize: 22, color: Palette.gold400),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _RepliesList extends StatelessWidget {
  const _RepliesList({required this.pager, required this.header, required this.empty, required this.onRefresh});
  final Pager pager;
  final Widget header;
  final String empty;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: pager,
    builder: (context, _) {
      final c = context.c;
      final items = pager.items;
      return RefreshIndicator(
        onRefresh: () async {
          await onRefresh();
          await pager.refresh();
        },
        child: ListView.builder(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 96),
          itemCount: 2 + items.length,
          itemBuilder: (context, i) {
            if (i == 0) return header;
            if (i == items.length + 1) {
              if (!pager.started || pager.loading) return const PostSkeletons(count: 2);
              if (pager.more) {
                pager.next();
                return const SizedBox(height: 40);
              }
              return items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Space.s6),
                      child: Text(empty, style: context.ty.sm.col(c.textMuted), textAlign: TextAlign.center),
                    )
                  : const SizedBox(height: Space.s6);
            }
            final r = items[i - 1];
            final post = r['post'] is Map ? asJson(r['post']) : null;
            return InkWell(
              onTap: () => context.push('/community/post/${r['post_id']}'),
              child: Container(
                padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, Space.s3),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CAvatar(name: '${r['name']}', photo: r['avatar_path'] as String?, size: 40),
                    const Gap(Space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '${r['name']} ', style: context.ty.sm.bold),
                                TextSpan(text: '@${r['handle']} · ${agoText(r['created_at'])}', style: context.ty.sm.col(c.textMuted)),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (post != null && post['unavailable'] != true) Text('Replying to @${post['handle']}', style: context.ty.cap.col(c.link)),
                          const Gap(2),
                          CText('${r['body']}', style: context.ty.body, maxLines: 8),
                          if (r['status'] == 'pending') ...[const Gap(Space.s2), const CheckingNote()],
                          if (r['status'] == 'rejected') ...[const Gap(Space.s2), NotShownNote(reason: r['reason'] as String?)],
                          if (post != null) ...[const Gap(Space.s2), QuoteCard(q: post)],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

// ---------------------------------------------------------------- edit profile

class CommunityEditScreen extends ConsumerStatefulWidget {
  const CommunityEditScreen({super.key});
  @override
  ConsumerState<CommunityEditScreen> createState() => _CommunityEditScreenState();
}

class _CommunityEditScreenState extends ConsumerState<CommunityEditScreen> {
  Json? _u;
  final _handle = TextEditingController();
  final _bio = TextEditingController();
  bool _photo = true;
  int _header = 0;
  Map<String, bool> _notify = {};
  bool _busy = false;
  String? _err;
  String? _hint;
  bool? _free;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final u = asJson(await crpc('community_user'));
      if (!mounted) return;
      setState(() {
        _u = u;
        _handle.text = '${u['pending_handle'] ?? u['handle']}';
        _bio.text = '${u['pending_bio'] ?? u['bio'] ?? ''}';
        _photo = u['show_photo'] != false;
        _notify = {for (final e in asJson(u['notify']).entries) e.key: e.value == true};
        _header = (u['header'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      if (mounted) setState(() => _err = offlineText);
    }
  }

  void _onHandle(String v) {
    _debounce?.cancel();
    final h = v.trim().replaceFirst('@', '').toLowerCase();
    if (h == _u?['handle'] || h == _u?['pending_handle']) return setState(() => (_hint = null, _free = null));
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final r = asJson(await crpc('community_handle_check', {'p_handle': h}));
        if (!mounted || _handle.text.trim().replaceFirst('@', '').toLowerCase() != h) return;
        setState(() => (_free = r['ok'] == true, _hint = r['ok'] == true ? '@$h is free' : communityError(r['error'])));
      } catch (_) {}
    });
  }

  Future<void> _save() async {
    setState(() => (_busy = true, _err = null));
    try {
      final r = asJson(
        await crpc('community_profile_save', {'p_handle': _handle.text.trim(), 'p_bio': _bio.text.trim(), 'p_show_photo': _photo, 'p_header': _header}),
      );
      if (r['ok'] != true) {
        final next = DateTime.tryParse('${r['next'] ?? ''}')?.toLocal();
        setState(() => _err = r['error'] == 'wait' && next != null ? 'You can change your @handle again on ${dayText(next)}.' : communityError(r['error']));
        return;
      }
      ref.read(communityTickProvider.notifier).bump();
      if (!mounted) return;
      if (r['pending'] == true) {
        toast(context, 'Saved. We are checking your new @handle and bio.', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
        final container = ProviderScope.containerOf(context, listen: false);
        context.pop();
        await checkNow('profile');
        container.read(communityTickProvider.notifier).bump();
      } else {
        toast(context, 'Profile saved', icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
        context.pop();
      }
    } catch (_) {
      if (mounted) setState(() => _err = offlineText);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _handle.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final u = _u;
    final next = DateTime.tryParse('${u?['handle_next'] ?? ''}')?.toLocal();
    return Scaffold(
      appBar: TopBar(title: 'Edit profile'),
      body: u == null
          ? (_err != null ? StateBlock(icon: PhosphorIcons.wifiSlash(), title: 'You are offline', text: _err) : const PostSkeletons(count: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s8),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  child: SizedBox(
                    height: 120,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedContainer(duration: Motion.base, color: headerColors[_header], child: const _Pattern()),
                        ),
                        Positioned(
                          left: Space.s4,
                          bottom: Space.s3,
                          child: CAvatar(name: '${u['name']}', photo: _photo ? u['avatar_path'] as String? : null, size: 64, ring: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(Space.s3),
                Text('Banner colour', style: context.ty.sm.bold),
                const Gap(Space.s2),
                Row(
                  children: [
                    for (final (i, col) in headerColors.indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: Space.s2),
                        child: Semantics(
                          button: true,
                          selected: i == _header,
                          label: 'Banner colour ${i + 1}',
                          child: GestureDetector(
                            onTap: () => setState(() => _header = i),
                            child: AnimatedContainer(
                              duration: Motion.fast,
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: Border.all(color: i == _header ? Palette.gold400 : c.border, width: i == _header ? 3 : 1),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const Gap(Space.s5),
                Text('@handle', style: context.ty.sm.bold),
                const Gap(Space.s2),
                TextField(
                  controller: _handle,
                  enabled: next == null,
                  onChanged: _onHandle,
                  maxLength: 20,
                  autocorrect: false,
                  style: context.ty.body,
                  decoration: InputDecoration(
                    prefixText: '@ ',
                    counterText: '',
                    suffixIcon: _free == null
                        ? null
                        : Icon(
                            _free! ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                            color: _free! ? c.success : c.error,
                          ),
                  ),
                ),
                const Gap(4),
                Text(
                  next != null
                      ? 'You can change your @handle again on ${dayText(next)}.'
                      : _hint ?? 'Small letters, numbers, _ and . only. You can change it once a month.',
                  style: context.ty.cap.col(_free == false ? c.error : c.textMuted),
                ),
                const Gap(Space.s5),
                Text('Bio', style: context.ty.sm.bold),
                const Gap(Space.s2),
                TextField(
                  controller: _bio,
                  maxLength: 160,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: context.ty.body,
                  decoration: const InputDecoration(hintText: 'For example: Aspiring doctor. Biology and Chemistry are my thing.'),
                ),
                const Gap(Space.s3),
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Show my photo in Community', style: context.ty.body.bold),
                            const Gap(2),
                            Text(
                              'Other students see your profile photo next to your posts. Turn it off to show your initials only.',
                              style: context.ty.sm.col(c.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const Gap(Space.s3),
                      Switch(value: _photo, onChanged: (v) => setState(() => _photo = v)),
                    ],
                  ),
                ),
                const Gap(Space.s2),
                Text('To change the photo itself, go to Profile → Edit profile in the app.', style: context.ty.cap.col(c.textSubtle)),
                const Gap(Space.s5),
                Text('Phone notifications', style: context.ty.sm.bold),
                const Gap(4),
                Text('Everything still shows in Community → Notifications. Choose what also buzzes your phone.', style: context.ty.cap.col(c.textMuted)),
                const Gap(Space.s2),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (k, title, on) in const [
                        ('replies', 'Replies to you', true),
                        ('mentions', 'Mentions and quotes', true),
                        ('ai', 'Answers from SolutionTee AI', true),
                        ('follows', 'New followers', true),
                        ('posts', 'Posts from people you talk with most', true),
                        ('milestones', 'Like milestones (10, 25, 50 …)', true),
                        ('digest', 'Your daily summary', true),
                        ('likes', 'Likes and reposts (one alert per post an hour)', true),
                      ])
                        SwitchListTile(
                          title: Text(title, style: context.ty.body),
                          value: _notify[k] ?? on,
                          onChanged: (v) {
                            setState(() => _notify[k] = v);
                            crpc('community_notify_save', {
                              'p_notify': {k: v},
                            }).catchError((_) => null);
                          },
                        ),
                    ],
                  ),
                ),
                if (_err != null) ...[const Gap(Space.s3), ErrText(_err!)],
                const Gap(Space.s5),
                Btn('Save', block: true, loading: _busy, onPressed: _busy || _free == false ? null : _save),
                const Gap(Space.s2),
                Text(
                  'Your @handle and bio are checked quickly to keep Community friendly.',
                  style: context.ty.cap.col(c.textSubtle),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------- followers / following

class FollowListScreen extends StatefulWidget {
  const FollowListScreen({super.key, required this.id, this.kind = 'followers', this.name});
  final String id;
  final String kind;
  final String? name;
  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this, initialIndex: widget.kind == 'following' ? 1 : 0);
  late final _pagers = [
    Pager((o) async => asList(await crpc('community_follow_list', {'p_user': widget.id, 'p_kind': 'followers', 'p_offset': o})), pageSize: 30)..refresh(),
    Pager((o) async => asList(await crpc('community_follow_list', {'p_user': widget.id, 'p_kind': 'following', 'p_offset': o})), pageSize: 30)..refresh(),
  ];

  @override
  void dispose() {
    _tabs.dispose();
    for (final p in _pagers) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: TopBar(title: widget.name ?? 'People'),
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            indicatorSize: TabBarIndicatorSize.label,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: Palette.gold400, width: 4),
              insets: EdgeInsets.symmetric(horizontal: -8),
            ),
            labelColor: c.text,
            unselectedLabelColor: c.textMuted,
            labelStyle: context.ty.body.bold,
            tabs: const [
              Tab(text: 'Followers'),
              Tab(text: 'Following'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (final (i, p) in _pagers.indexed)
                  ListenableBuilder(
                    listenable: p,
                    builder: (context, _) {
                      if (!p.started || (p.loading && p.items.isEmpty)) return const PostSkeletons(count: 4);
                      if (p.items.isEmpty) {
                        return StateBlock(
                          icon: PhosphorIcons.users(PhosphorIconsStyle.fill),
                          title: i == 0 ? 'No followers yet' : 'Not following anyone yet',
                          text: p.error != null ? offlineText : null,
                        );
                      }
                      return ListView.builder(
                        itemCount: p.items.length + (p.more ? 1 : 0),
                        itemBuilder: (_, k) {
                          if (k >= p.items.length) {
                            p.next();
                            return const SizedBox(height: 48);
                          }
                          return PersonRow(p: p.items[k]);
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
