import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/phosphor.g.dart';
import 'community_data.dart';
import 'community_profile.dart';
import 'community_widgets.dart';

// Community v2 shell (D-155): its own full-screen space like X. Bottom bar Home · Explore · Notifications · Profile, a gold
// compose button, bars that slide away while scrolling down and come back on scrolling up. Back returns to Study.

class CommunityShell extends ConsumerStatefulWidget {
  const CommunityShell({super.key, this.tab = 0});
  final int tab;
  @override
  ConsumerState<CommunityShell> createState() => _CommunityShellState();
}

class _CommunityShellState extends ConsumerState<CommunityShell> {
  late int _tab = widget.tab;
  bool _bars = true;
  NoteListener? _notes;
  final _homeKey = GlobalKey<_HomeTabState>();
  final _notesKey = GlobalKey<_NotesTabState>();
  final _seen = <int>{};

  @override
  void initState() {
    super.initState();
    _seen.add(_tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      loadUnread(ref);
      final uid = currentUserId();
      if (uid != null) {
        _notes = NoteListener(uid, (n) {
          if (!mounted) return;
          if (_tab == 2) {
            _notesKey.currentState?.reload();
          } else {
            ref.read(communityUnreadProvider.notifier).bump();
          }
        })..open();
      }
    });
  }

  @override
  void dispose() {
    _notes?.close();
    super.dispose();
  }

  void _go(int i) {
    HapticFeedback.selectionClick();
    if (i == _tab) {
      if (i == 0) _homeKey.currentState?.toTop();
      return;
    }
    setState(() => (_tab = i, _bars = true, _seen.add(i)));
    if (i == 2) ref.read(communityUnreadProvider.notifier).set(0);
  }

  bool _onScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final show = n.direction == ScrollDirection.forward || n.metrics.pixels < 40;
    final hide = n.direction == ScrollDirection.reverse && n.metrics.pixels > 80;
    if (show && !_bars) setState(() => _bars = true);
    if (hide && _bars) setState(() => _bars = false);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final unread = ref.watch(communityUnreadProvider);
    final rm = context.reduceMotion;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final pages = [
      _HomeTab(key: _homeKey, bars: _bars, onMe: () => _go(3)),
      const _ExploreTab(),
      _NotesTab(key: _notesKey, active: _tab == 2),
      const ProfileView(inShell: true),
    ];
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (did, _) {
        if (!did) _go(0);
      },
      child: Scaffold(
        backgroundColor: c.surface,
        body: NotificationListener<UserScrollNotification>(
          onNotification: _onScroll,
          child: Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(index: _tab, children: [for (var i = 0; i < pages.length; i++) _seen.contains(i) ? pages[i] : const SizedBox.shrink()]),
              ),
              // Compose
              if (_tab != 2)
                Positioned(
                  right: 18,
                  bottom: 64 + bottom + 18,
                  child: AnimatedSlide(
                    offset: _bars ? Offset.zero : const Offset(0, .4),
                    duration: rm ? Duration.zero : Motion.base,
                    curve: Motion.out,
                    child: AnimatedOpacity(
                      opacity: _bars ? 1 : .55,
                      duration: rm ? Duration.zero : Motion.base,
                      child: Semantics(
                        button: true,
                        label: 'New post',
                        child: GestureDetector(
                          onTap: () => context.push('/community/compose'),
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Palette.gold400,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Palette.gold400.withValues(alpha: .35), blurRadius: 22, offset: const Offset(0, 8))],
                            ),
                            child: Icon(PhosphorIcons.plus(), color: Palette.navy900, size: 28),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Bottom bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedSlide(
                  offset: _bars ? Offset.zero : const Offset(0, 1),
                  duration: rm ? Duration.zero : Motion.base,
                  curve: Motion.out,
                  child: Container(
                    padding: EdgeInsets.only(top: 6, bottom: bottom + 6),
                    decoration: BoxDecoration(
                      color: c.surface.withValues(alpha: .97),
                      border: Border(top: BorderSide(color: c.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NavIcon(
                          icon: PhosphorIcons.house(),
                          on: PhosphorIcons.house(PhosphorIconsStyle.fill),
                          label: 'Home',
                          selected: _tab == 0,
                          onTap: () => _go(0),
                        ),
                        _NavIcon(
                          icon: PhosphorIcons.magnifyingGlass(),
                          on: PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.fill),
                          label: 'Explore',
                          selected: _tab == 1,
                          onTap: () => _go(1),
                        ),
                        _NavIcon(
                          icon: PhosphorIcons.bell(),
                          on: PhosphorIcons.bell(PhosphorIconsStyle.fill),
                          label: unread > 0 ? 'Notifications, $unread new' : 'Notifications',
                          selected: _tab == 2,
                          badge: unread,
                          onTap: () => _go(2),
                        ),
                        _NavIcon(
                          icon: PhosphorIcons.user(),
                          on: PhosphorIcons.user(PhosphorIconsStyle.fill),
                          label: 'Profile',
                          selected: _tab == 3,
                          onTap: () => _go(3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.on, required this.label, required this.selected, required this.onTap, this.badge = 0});
  final IconData icon;
  final IconData on;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          width: 56,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: rm ? Duration.zero : Motion.fast,
                child: Icon(selected ? on : icon, size: 26, color: selected ? c.text : c.textMuted),
              ),
              if (badge > 0)
                Positioned(
                  top: 6,
                  right: 8,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Palette.gold400,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: c.surface, width: 2),
                    ),
                    child: Text(badge > 9 ? '9+' : '$badge', style: context.ty.cap.bold.copyWith(fontSize: 10, height: 1).col(Palette.navy900)),
                  ).animate(key: ValueKey(badge)).scale(begin: const Offset(.6, .6), duration: rm ? 0.ms : 260.ms, curve: Curves.easeOutBack),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Home

class _HomeTab extends ConsumerStatefulWidget {
  const _HomeTab({super.key, required this.bars, required this.onMe});
  final bool bars;
  final VoidCallback onMe;
  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this)..addListener(_onTab);
  late final _pagers = [_make('for_you'), _make('following')];
  final _scroll = [ScrollController(), ScrollController()];
  Timer? _poll;
  int _new = 0;

  Pager _make(String tab) {
    final uid = currentUserId() ?? 'anon';
    return Pager(
      (o) async => asList(await crpc('community_home', {'p_tab': tab, 'p_offset': o})),
      cacheKey: 'community:home:$uid:$tab',
      db: ref.read(dbProvider),
    );
  }

  @override
  void initState() {
    super.initState();
    _pagers[0].refresh();
    _poll = Timer.periodic(const Duration(seconds: 45), (_) => _checkNew());
  }

  void _onTab() {
    if (_tabs.indexIsChanging) return;
    final p = _pagers[_tabs.index];
    if (!p.started) p.refresh();
    setState(() => _new = 0);
  }

  Future<void> _checkNew() async {
    final p = _pagers[_tabs.index];
    final since = p.loadedAt;
    if (since == null || !mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    try {
      final n =
          (await crpc('community_new_count', {'p_tab': _tabs.index == 0 ? 'for_you' : 'following', 'p_since': since.toUtc().toIso8601String()}) as num?)
              ?.toInt() ??
          0;
      if (mounted && n != _new) setState(() => _new = n);
    } catch (_) {}
  }

  void toTop() {
    final s = _scroll[_tabs.index];
    if (s.hasClients && s.offset > 0) {
      s.animateTo(0, duration: context.reduceMotion ? Duration.zero : Motion.slow, curve: Motion.out);
    } else {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() => _new = 0);
    await _pagers[_tabs.index].refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tabs.dispose();
    for (final p in _pagers) {
      p.dispose();
    }
    for (final s in _scroll) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rm = context.reduceMotion;
    final top = MediaQuery.paddingOf(context).top;
    const head = 104.0;
    ref.listen(communityTickProvider, (_, _) {
      for (final p in _pagers) {
        if (p.started) p.refresh();
      }
    });
    final me = ref.watch(communityMeProvider).value ?? const {};
    return Stack(
      children: [
        Positioned.fill(
          child: TabBarView(
            controller: _tabs,
            children: [
              for (var i = 0; i < 2; i++)
                FeedList(
                  pager: _pagers[i],
                  controller: _scroll[i],
                  topPad: top + head,
                  empty: i == 0
                      ? _Empty(
                          icon: PhosphorIcons.chatsTeardrop(PhosphorIconsStyle.fill),
                          title: 'Say hello to Community',
                          text: 'Ask a question, share a study tip or say good morning. Add @solutiontee for an answer from the AI.',
                          action: 'Write the first post',
                          onAction: () => context.push('/community/compose'),
                        )
                      : _Empty(
                          icon: PhosphorIcons.users(PhosphorIconsStyle.fill),
                          title: 'Follow students to fill this page',
                          text: 'Posts and reposts from people you follow show here. Find people in Explore.',
                        ),
                ),
            ],
          ),
        ),
        // Header
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: AnimatedSlide(
            offset: widget.bars ? Offset.zero : const Offset(0, -1),
            duration: rm ? Duration.zero : Motion.base,
            curve: Motion.out,
            child: Container(
              padding: EdgeInsets.only(top: top),
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: .97),
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        const Gap(Space.s1),
                        IconBtn(PhosphorIcons.caretLeft(), label: 'Back to Study', onPressed: () => context.canPop() ? context.pop() : context.go('/study')),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Container(color: Colors.white, padding: const EdgeInsets.all(3), child: const Mark(height: 20, onDark: false)),
                              ),
                              const Gap(Space.s2),
                              Text('Community', style: context.ty.h3),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: Space.s3, left: Space.s1),
                          child: CAvatar(name: '${me['name'] ?? 'Me'}', photo: me['avatar_path'] as String?, size: 34, onTap: widget.onMe),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: TabBar(
                      controller: _tabs,
                      dividerHeight: 0,
                      indicatorSize: TabBarIndicatorSize.label,
                      indicator: const UnderlineTabIndicator(
                        borderSide: BorderSide(color: Palette.gold400, width: 4),
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                        insets: EdgeInsets.symmetric(horizontal: -8),
                      ),
                      labelColor: c.text,
                      unselectedLabelColor: c.textMuted,
                      labelStyle: context.ty.body.bold,
                      unselectedLabelStyle: context.ty.body,
                      tabs: const [
                        Tab(text: 'For you'),
                        Tab(text: 'Following'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // N new posts
        Positioned(
          top: top + head + 12,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSwitcher(
              duration: rm ? Duration.zero : Motion.base,
              transitionBuilder: (w, a) => SlideTransition(
                position: Tween(begin: const Offset(0, -.8), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Motion.out)),
                child: FadeTransition(opacity: a, child: w),
              ),
              child: _new == 0
                  ? const SizedBox.shrink()
                  : Semantics(
                      button: true,
                      child: GestureDetector(
                        key: const ValueKey('pill'),
                        onTap: () {
                          final s = _scroll[_tabs.index];
                          if (s.hasClients) s.jumpTo(0);
                          _refresh();
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
                          decoration: BoxDecoration(
                            color: Palette.blue600,
                            borderRadius: BorderRadius.circular(Radii.pill),
                            boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 18, offset: Offset(0, 6))],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(PhosphorIcons.arrowUp(), size: 14, color: Colors.white),
                              const Gap(6),
                              Text(_new == 1 ? '1 new post' : '$_new new posts', style: context.ty.sm.bold.col(Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A feed with pull to refresh, endless scroll, offline note, loading and empty states.
class FeedList extends StatelessWidget {
  const FeedList({super.key, required this.pager, required this.empty, this.controller, this.topPad = 0, this.header});
  final Pager pager;
  final Widget empty;
  final ScrollController? controller;
  final double topPad;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 96;
    return ListenableBuilder(
      listenable: pager,
      builder: (context, _) {
        final items = pager.items;
        final Widget body;
        if (!pager.started || (pager.loading && items.isEmpty)) {
          body = ListView(
            controller: controller,
            padding: EdgeInsets.only(top: topPad, bottom: bottom),
            children: [?header, const PostSkeletons()],
          );
        } else if (pager.error != null && items.isEmpty) {
          body = ListView(
            controller: controller,
            padding: EdgeInsets.only(top: topPad, bottom: bottom),
            children: [
              ?header,
              _Empty(icon: PhosphorIcons.wifiSlash(), title: 'You are offline', text: offlineText, action: 'Try again', onAction: pager.refresh),
            ],
          );
        } else if (items.isEmpty) {
          body = ListView(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: topPad, bottom: bottom),
            children: [?header, empty],
          );
        } else {
          final extra = header == null ? 0 : 1;
          final offline = pager.offline ? 1 : 0;
          body = ListView.builder(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: topPad, bottom: bottom),
            itemCount: extra + offline + items.length + 1,
            itemBuilder: (context, i) {
              if (extra == 1 && i == 0) return header!;
              if (offline == 1 && i == extra) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, 0),
                  child: InfoBanner(icon: PhosphorIcons.wifiSlash(), child: const Text('You are offline. These are the posts saved on your phone.')),
                );
              }
              final k = i - extra - offline;
              if (k >= items.length) {
                if (pager.more) {
                  pager.next();
                  return const Padding(
                    padding: EdgeInsets.all(Space.s5),
                    child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(Space.s6),
                  child: Text('You are all caught up', style: context.ty.sm.col(context.c.textSubtle), textAlign: TextAlign.center),
                );
              }
              final p = items[k];
              return PostCell(
                key: ValueKey('${p['id']}:${p['reposted_by'] is Map ? (p['reposted_by'] as Map)['id'] : ''}'),
                post: p,
                animateIndex: k,
                onGone: () => pager.remove('${p['id']}'),
              );
            },
          );
        }
        return RefreshIndicator(edgeOffset: topPad, onRefresh: pager.refresh, child: body);
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, this.text, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String? text;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => StateBlock(
    icon: icon,
    title: title,
    text: text,
    action: action == null ? null : Btn(action!, sm: true, onPressed: onAction),
  );
}

// ---------------------------------------------------------------- Explore

class _ExploreTab extends ConsumerStatefulWidget {
  const _ExploreTab();
  @override
  ConsumerState<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends ConsumerState<_ExploreTab> {
  final _q = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  Json? _results;
  bool _searching = false;
  Json? _explore;
  Object? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = asJson(await crpc('community_explore'));
      if (mounted) setState(() => (_explore = r, _err = null));
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  void _onQ(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) return setState(() => _results = null);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      try {
        final r = asJson(await crpc('community_search', {'p_q': v.trim(), 'p_kind': 'top'}));
        if (mounted && _q.text.trim() == v.trim()) setState(() => _results = r);
      } catch (_) {
        if (mounted) toast(context, offlineText);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  static const _tileColors = [
    (Color(0xFF10284D), Palette.blue300, Palette.blue50, Palette.blue700),
    (Color(0xFF0F3B26), Palette.green300, Palette.green50, Palette.green700),
    (Color(0xFF2B2210), Palette.gold200, Palette.gold50, Palette.gold700),
    (Color(0xFF2A1633), Color(0xFFD7B4F0), Color(0xFFF4ECFA), Color(0xFF6B3A8C)),
    (Color(0xFF13233F), Color(0xFFA7B4CA), Palette.neutral100, Palette.neutral700),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom + 96;
    final search = Padding(
      padding: EdgeInsets.fromLTRB(Space.s4, top + Space.s3, Space.s4, 10),
      child: TextField(
        controller: _q,
        focusNode: _focus,
        onChanged: _onQ,
        textInputAction: TextInputAction.search,
        style: context.ty.body,
        decoration: InputDecoration(
          hintText: 'Search posts, people and #topics',
          prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 18, color: c.textMuted),
          suffixIcon: _q.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: Icon(PhosphorIcons.xCircle(PhosphorIconsStyle.fill), size: 18, color: c.textMuted),
                  onPressed: () {
                    _q.clear();
                    setState(() => _results = null);
                  },
                ),
          filled: true,
          fillColor: c.surfaceSunken,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.pill), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.pill), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.pill),
            borderSide: BorderSide(color: c.focus, width: 1.5),
          ),
        ),
      ),
    );
    final List<Widget> body;
    if (_results != null || _searching) {
      final people = asList(_results?['people']);
      final posts = asList(_results?['posts']);
      body = [
        if (_searching && _results == null) const PostSkeletons(count: 2),
        if (people.isNotEmpty) ...[_H('People'), for (final p in people) PersonRow(p: p)],
        if (posts.isNotEmpty) ...[_H('Posts'), for (final (i, p) in posts.indexed) PostCell(post: p, animateIndex: i)],
        if (_results != null && people.isEmpty && posts.isEmpty)
          _Empty(icon: PhosphorIcons.magnifyingGlass(), title: 'Nothing found', text: 'Try another word, a #topic or an @handle.'),
      ];
    } else if (_explore == null) {
      body = [
        if (_err != null)
          _Empty(icon: PhosphorIcons.wifiSlash(), title: 'You are offline', text: offlineText, action: 'Try again', onAction: _load)
        else
          const PostSkeletons(count: 3),
      ];
    } else {
      final trending = asList(_explore!['trending']);
      final subjects = asList(_explore!['subjects']);
      final people = asList(_explore!['people']);
      body = [
        _H(trending.isEmpty ? 'Trending' : 'Trending today'),
        if (trending.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s4, 0, Space.s4, Space.s3),
            child: Text('No #topics yet. Add one to your post, like #JAMB2027.', style: context.ty.sm.col(c.textMuted)),
          ),
        for (final (i, t) in trending.indexed)
          InkWell(
            onTap: () => context.push('/community/tag/${Uri.encodeComponent('${t['tag']}')}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1} · ${t['subject'] ?? 'Community'}', style: context.ty.cap.col(c.textMuted)),
                        Text('#${t['tag']}', style: context.ty.lg.bold),
                        Text('${countText((t['posts'] as num).toInt())} ${t['posts'] == 1 ? 'post' : 'posts'}', style: context.ty.cap.col(c.textMuted)),
                      ],
                    ),
                  ),
                  if (t['rising'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(Radii.sm)),
                      child: Text('Rising', style: context.ty.cap.bold.col(c.onAccentSoft)),
                    ),
                ],
              ),
            ),
          ),
        if (subjects.isNotEmpty) ...[
          _H('Subjects'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s4),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Space.s2,
              crossAxisSpacing: Space.s2,
              childAspectRatio: 1.7,
              children: [
                for (final (i, s) in subjects.take(5).indexed)
                  _SubjectTile(
                    name: '${s['name']}',
                    today: (s['today'] as num?)?.toInt() ?? 0,
                    colors: _tileColors[i % _tileColors.length],
                    onTap: () => context.push('/community/subject/${s['id']}'),
                  ),
                InkWell(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  onTap: () => context.push('/community/subjects'),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.lg),
                      border: Border.all(color: c.borderStrong),
                    ),
                    child: Text('All subjects', style: context.ty.sm.bold.col(c.link)),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (people.isNotEmpty) ...[const Gap(Space.s2), _H('Who to follow'), for (final p in people) PersonRow(p: p, why: p['why'] as String?)],
      ];
    }
    return RefreshIndicator(
      edgeOffset: top,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.only(bottom: bottom),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [search, ...body],
      ),
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.s4, Space.s3, Space.s4, 6),
    child: Text(text, style: context.ty.h3, semanticsLabel: text),
  );
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.name, required this.today, required this.colors, required this.onTap});
  final String name;
  final int today;
  final (Color, Color, Color, Color) colors;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final bg = dark ? colors.$1 : colors.$3;
    final fg = dark ? colors.$2 : colors.$4;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: context.ty.sm.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(today == 0 ? 'Start one' : '$today today', style: context.ty.cap.col(fg)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Notifications

class _NotesTab extends ConsumerStatefulWidget {
  const _NotesTab({super.key, required this.active});
  final bool active;
  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
  late final _pagers = [
    Pager((o) async => asList(await crpc('community_notes_list', {'p_tab': 'all', 'p_offset': o})), pageSize: 30),
    Pager((o) async => asList(await crpc('community_notes_list', {'p_tab': 'mentions', 'p_offset': o})), pageSize: 30),
  ];

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(_NotesTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) reload();
  }

  Future<void> reload() async {
    await Future.wait([for (final p in _pagers) p.refresh()]);
    try {
      await crpc('community_notes_read');
      if (mounted) ref.read(communityUnreadProvider.notifier).set(0);
    } catch (_) {}
  }

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
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.only(top: top),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.s4, 14, Space.s4, 4),
                child: Text('Notifications', style: context.ty.h2),
              ),
              TabBar(
                controller: _tabs,
                dividerHeight: 0,
                indicatorSize: TabBarIndicatorSize.label,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(color: Palette.gold400, width: 4),
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                  insets: EdgeInsets.symmetric(horizontal: -8),
                ),
                labelColor: c.text,
                unselectedLabelColor: c.textMuted,
                labelStyle: context.ty.body.bold,
                unselectedLabelStyle: context.ty.body,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Mentions'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              for (final p in _pagers)
                ListenableBuilder(
                  listenable: p,
                  builder: (context, _) {
                    final bottom = MediaQuery.paddingOf(context).bottom + 80;
                    if (!p.started || (p.loading && p.items.isEmpty)) return const PostSkeletons(count: 5);
                    if (p.error != null && p.items.isEmpty) {
                      return _Empty(icon: PhosphorIcons.wifiSlash(), title: 'You are offline', text: offlineText, action: 'Try again', onAction: reload);
                    }
                    return RefreshIndicator(
                      onRefresh: reload,
                      child: p.items.isEmpty
                          ? ListView(
                              children: [
                                _Empty(
                                  icon: PhosphorIcons.bellSimple(PhosphorIconsStyle.fill),
                                  title: p == _pagers[0] ? 'Nothing yet' : 'No mentions yet',
                                  text: 'Likes, replies, reposts, new followers and answers from SolutionTee AI show here.',
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: EdgeInsets.only(bottom: bottom),
                              itemCount: p.items.length + (p.more ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i >= p.items.length) {
                                  p.next();
                                  return const Padding(
                                    padding: EdgeInsets.all(Space.s5),
                                    child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))),
                                  );
                                }
                                final row = NoteRow(n: p.items[i]);
                                return i > 8 || context.reduceMotion ? row : row.animate().fadeIn(delay: (30 * i).ms, duration: Motion.base);
                              },
                            ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class NoteRow extends StatelessWidget {
  const NoteRow({super.key, required this.n});
  final Json n;

  (IconData, Color) _icon(BuildContext context) {
    final c = context.c;
    return switch ('${n['kind']}') {
      'like' || 'comment_like' => (PhosphorIcons.heart(PhosphorIconsStyle.fill), kLike),
      'repost' || 'quote' => (PhosphorIcons.repeat(), repostColor(context)),
      'follow' => (PhosphorIcons.userPlus(), c.link),
      'reply' => (PhosphorIcons.chatCircle(), c.link),
      'mention' => (PhosphorIcons.at(), c.link),
      'shown' => (PhosphorIcons.checkCircle(), c.success),
      'rejected' => (PhosphorIcons.prohibit(), c.error),
      'profile' => (PhosphorIcons.identificationBadge(), c.link),
      _ => (PhosphorIcons.bell(), c.link),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final kind = '${n['kind']}';
    final actors = asList(n['actors']);
    final unread = n['unread'] == true;
    final post = n['post'] is Map ? asJson(n['post']) : null;
    final snippet = switch (kind) {
      'reply' || 'mention' || 'quote' || 'ai' || 'rejected' => '${n['body'] ?? ''}',
      'profile' => '',
      _ => '${post?['body'] ?? ''}',
    };
    final (icon, tone) = _icon(context);
    void open() {
      if (kind == 'follow' && actors.isNotEmpty) {
        context.push('/community/user/${actors.first['id']}');
      } else if (n['post_id'] != null) {
        context.push('/community/post/${n['post_id']}');
      } else if (kind == 'profile') {
        context.push('/community/edit');
      }
    }

    return InkWell(
      onTap: open,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.s4, 14, Space.s4, 14),
        decoration: BoxDecoration(
          color: unread ? c.secondarySoft.withValues(alpha: context.isDark ? .45 : .6) : null,
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 30,
              child: kind == 'ai' ? const CAvatar(name: 'SolutionTee AI', ai: true, size: 28) : Icon(icon, size: 26, color: tone),
            ),
            const Gap(Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (actors.isNotEmpty && kind != 'ai')
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s2),
                      child: SizedBox(
                        height: 30,
                        child: Stack(
                          children: [
                            for (final (i, a) in actors.take(3).indexed)
                              Positioned(
                                left: i * 22.0,
                                child: CAvatar(name: '${a['name']}', photo: a['avatar_path'] as String?, size: 30, ring: c.surface),
                              ),
                            if (((n['count'] as num?)?.toInt() ?? 0) > 3)
                              Positioned(
                                left: 66,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Palette.blue400,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: c.surface, width: 2),
                                  ),
                                  child: Text('+${(n['count'] as num).toInt() - 3}', style: context.ty.cap.bold.copyWith(fontSize: 10).col(Palette.navy900)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: noteText(n), style: context.ty.body),
                        TextSpan(text: '  ${agoText(n['at'])}', style: context.ty.sm.col(c.textMuted)),
                      ],
                    ),
                  ),
                  if (snippet.isNotEmpty) ...[const Gap(4), Text(snippet, style: context.ty.sm.col(c.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis)],
                ],
              ),
            ),
            if (kind == 'follow' && actors.isNotEmpty) ...[
              const Gap(Space.s2),
              FollowPill(user: '${actors.first['id']}', following: actors.first['following'] == true, followsMe: true, handle: '${actors.first['handle']}'),
            ] else if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(color: Palette.gold400, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- tag, subject

/// Posts with one #topic or one subject, newest first.
class TagFeedScreen extends ConsumerStatefulWidget {
  const TagFeedScreen({super.key, this.tag, this.subject});
  final String? tag;
  final int? subject;
  @override
  ConsumerState<TagFeedScreen> createState() => _TagFeedScreenState();
}

class _TagFeedScreenState extends ConsumerState<TagFeedScreen> {
  late final _pager = Pager(
    (o) async => asList(await crpc('community_home', {'p_tab': 'for_you', 'p_offset': o, 'p_subject': widget.subject, 'p_tag': widget.tag})),
  )..refresh();

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider).value ?? const [];
    final name = widget.tag != null ? '#${widget.tag}' : '${subjects.where((s) => s['id'] == widget.subject).firstOrNull?['name'] ?? 'Subject'}';
    return Scaffold(
      appBar: TopBar(title: name),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New post',
        backgroundColor: Palette.gold400,
        foregroundColor: Palette.navy900,
        shape: const CircleBorder(),
        onPressed: () => context.push('/community/compose', extra: {'subject': widget.subject, 'text': widget.tag != null ? ' #${widget.tag}' : null}),
        child: Icon(PhosphorIcons.plus()),
      ),
      body: FeedList(
        pager: _pager,
        empty: _Empty(icon: PhosphorIcons.hash(), title: 'No posts here yet', text: 'Be the first to post about $name.'),
      ),
    );
  }
}

class AllSubjectsScreen extends ConsumerWidget {
  const AllSubjectsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider).value ?? const <Map<String, dynamic>>[];
    return Scaffold(
      appBar: TopBar(title: 'Subjects'),
      body: ListView(
        padding: const EdgeInsets.all(Space.s4),
        children: [
          ListCard(
            children: [for (final s in subjects) ListRow(title: '${s['name']}', onTap: () => context.push('/community/subject/${s['id']}'))],
          ),
        ],
      ),
    );
  }
}
