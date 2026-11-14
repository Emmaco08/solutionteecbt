import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config.dart';
import '../core/house_ads.dart' show rootNavKey;
import '../core/platform.dart';
import '../core/providers.dart';
import '../data/notifications_repo.dart';
import '../features/premium/paywall.dart';
import '../features/xp/streak_ui.dart';
import '../theme/theme.dart';
import '../theme/tokens.g.dart';
import '../ui/kit.dart';
import '../widgets/phosphor.g.dart';

/// Windows / desktop layout (D-166). One stable tree for every route so pages keep their state:
///   [left slot: sidebar | brand panel | nothing] + [content column with a comfortable width].
/// The sidebar replaces the phone's bottom tabs; exams and games open in focus mode (full window, no sidebar);
/// sign-in screens sit next to a brand panel. Under [kDesktopMinWidth] (a snapped half window) the phone layout is used.
const kDesktopMinWidth = 900.0;

enum DesktopMode { phone, auth, focus, normal }

/// Is the desktop sidebar showing (so the phone's bottom tabs must hide)?
class DesktopScope extends InheritedWidget {
  const DesktopScope({super.key, required this.mode, required super.child});
  final DesktopMode mode;
  static DesktopMode modeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DesktopScope>()?.mode ?? DesktopMode.phone;
  static bool sidebar(BuildContext context) => modeOf(context) == DesktopMode.normal;
  @override
  bool updateShouldNotify(DesktopScope old) => old.mode != mode;
}

/// Wide page layouts switch on at this column width (the column is narrower than the window).
bool wideLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= 1000;

/// Grid columns that grow with the column width: the phone's count, one more from 700 px, double from 1000 px.
int gridCols(BuildContext context, int phone) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1000) return (phone * 2).clamp(phone, 6);
  if (w >= 700) return phone + 1;
  return phone;
}

const _authRoutes = {
  '/welcome',
  '/onboarding',
  '/login',
  '/signup',
  '/verify',
  '/forgot',
  '/reset',
  '/setup',
  '/guardian',
  '/age-blocked',
  '/account-paused',
  '/welcome-new',
  '/welcome-back',
  '/subjects',
};
const _bare = {'/splash', '/banned', '/phone-taken', '/phone-banned', '/clone-blocked'};

DesktopMode desktopModeFor(String path) {
  if (_bare.contains(path)) return DesktopMode.focus;
  if (_authRoutes.contains(path)) return DesktopMode.auth;
  final focus =
      path.startsWith('/cbt/') ||
      RegExp(r'^/(test/)?challenges/[^/]+/(play|mock)$').hasMatch(path) ||
      path.startsWith('/games/play/') ||
      path.startsWith('/games/arena/') ||
      path.startsWith('/games/m/') ||
      path.startsWith('/games/find') ||
      path.startsWith('/tutor/quiz/');
  return focus ? DesktopMode.focus : DesktopMode.normal;
}

/// Game Zone pages are designed tall like a phone: on desktop they play in a centred stage over a game backdrop.
bool _isGame(String path) => path == '/games' || path.startsWith('/games/');

/// Content width for a route: dashboards get room, lists a medium width, reading and form pages stay readable.
double desktopWidthFor(String path, DesktopMode mode) {
  if (mode == DesktopMode.auth) return 560;
  if (_isGame(path)) return 620;
  if (mode == DesktopMode.focus) return double.infinity;
  bool under(String p) => path == p || path.startsWith('$p/');
  if (path.startsWith('/news/') || path.startsWith('/community/post/') || path.startsWith('/study/note/') || path.startsWith('/study/novel/')) return 860;
  if (under('/community')) return 820; // a readable feed, like other social apps on desktop
  if (path == '/ai' || path == '/ai/history' || under('/tutor')) return 1040;
  if (['/home', '/test', '/study', '/me'].any((p) => path == p) || path.startsWith('/study/')) return 1280;
  if (['/leaderboard', '/classes', '/news', '/careers', '/badges', '/downloads', '/history', '/test/challenges'].any(under)) return 980;
  return 860;
}

String _path(GoRouter r) {
  try {
    return r.routerDelegate.currentConfiguration.uri.path;
  } catch (_) {
    return '/';
  }
}

class DesktopFrame extends StatefulWidget {
  const DesktopFrame({super.key, required this.router, required this.child});
  final GoRouter router;
  final Widget child;
  @override
  State<DesktopFrame> createState() => _DesktopFrameState();
}

class _DesktopFrameState extends State<DesktopFrame> {
  GoRouter get router => widget.router;

  @override
  void initState() {
    super.initState();
    router.routerDelegate.addListener(_changed);
  }

  @override
  void didUpdateWidget(DesktopFrame old) {
    super.didUpdateWidget(old);
    if (old.router != widget.router) {
      old.router.routerDelegate.removeListener(_changed);
      widget.router.routerDelegate.addListener(_changed);
    }
  }

  @override
  void dispose() {
    router.routerDelegate.removeListener(_changed);
    super.dispose();
  }

  /// The router can announce a new page while the tree is building (first frame): rebuild after that frame then.
  void _changed() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (!isDesktop) return child;
    return Builder(
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        final path = _path(router);
        final mode = size.width < kDesktopMinWidth ? DesktopMode.phone : desktopModeFor(path);
        final maxW = mode == DesktopMode.phone ? double.infinity : desktopWidthFor(path, mode);
        final c = context.c;
        Widget left = const SizedBox.shrink();
        if (mode == DesktopMode.normal) left = DesktopSidebar(router: router, path: path, compact: size.width < 1200);
        if (mode == DesktopMode.auth && size.width >= 1100) left = const _BrandPanel();
        return DesktopScope(
          mode: mode,
          child: _Keys(
            router: router,
            child: Material(
              color: _isGame(path) ? const Color(0xFF15124A) : c.bg,
              child: Container(
                decoration: _isGame(path)
                    ? const BoxDecoration(
                        gradient: RadialGradient(center: Alignment(0, -0.3), radius: 1.2, colors: [Color(0xFF2A2A8F), Color(0xFF15124A), Color(0xFF0B0A2E)]),
                      )
                    : null,
                child: Row(
                  children: [
                    left,
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: maxW.isFinite ? maxW : 100000),
                        duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        builder: (context, w, kid) => LayoutBuilder(
                          builder: (context, box) {
                            final colW = w.clamp(320.0, box.maxWidth);
                            final mq = MediaQuery.of(context);
                            return Center(
                              child: SizedBox(
                                width: colW,
                                child: MediaQuery(
                                  data: mq.copyWith(size: Size(colW, mq.size.height)),
                                  child: kid!,
                                ),
                              ),
                            );
                          },
                        ),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Esc / mouse back button: back. Ctrl+K (or Ctrl+F): search.
class _Keys extends StatelessWidget {
  const _Keys({required this.router, required this.child});
  final GoRouter router;
  final Widget child;

  void _back() {
    final nav = rootNavKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.maybePop();
    } else if (router.canPop()) {
      router.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        if (e.buttons == kBackMouseButton) _back();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _back,
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => router.push('/search'),
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => router.push('/search'),
        },
        child: Focus(autofocus: true, skipTraversal: true, child: child),
      ),
    );
  }
}

/// Mouse wheel, touch pad and mouse dragging all scroll (carousels and card rows need dragging on a laptop).
class DesktopScrollBehavior extends MaterialScrollBehavior {
  const DesktopScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => const {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus};
}

// ---------------------------------------------------------------- sidebar

class _NavItem {
  const _NavItem(this.label, this.route, this.icon, {this.match = const []});
  final String label, route;
  final IconData Function(PhosphorIconsStyle) icon;
  final List<String> match;
  bool active(String p) => p == route || p.startsWith('$route/') || match.any((m) => p == m || p.startsWith('$m/'));
}

final _learn = [
  _NavItem('Home', '/home', PhosphorIcons.house),
  _NavItem('Study', '/study', PhosphorIcons.bookOpenText, match: ['/downloads']),
  _NavItem('Test', '/test', PhosphorIcons.exam, match: ['/history', '/results', '/review', '/challenges']),
  _NavItem('AI Tutor', '/ai', PhosphorIcons.sparkle),
];
final _play = [
  _NavItem('Game Zone', '/games', PhosphorIcons.gameController),
  _NavItem('Community', '/community', PhosphorIcons.usersThree),
  _NavItem('Leaderboard', '/leaderboard', PhosphorIcons.trophy),
];
final _more = [
  _NavItem('Live classes', '/classes', PhosphorIcons.chalkboardTeacher),
  _NavItem('Request a tutor', '/tutor', PhosphorIcons.graduationCap),
  _NavItem('News', '/news', PhosphorIcons.newspaper),
  _NavItem('Careers', '/careers', PhosphorIcons.target),
];

class DesktopSidebar extends ConsumerWidget {
  const DesktopSidebar({super.key, required this.router, required this.path, this.compact = false});
  final GoRouter router;
  final String path;
  final bool compact;

  void _go(String route) => router.go(route);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = compact ? 88.0 : 272.0;
    final profile = ref.watch(profileProvider).value;
    final name = '${profile?['full_name'] ?? ''}'.trim();
    final premium = ref.watch(myPlanProvider).value?['tier'] == 'premium';
    final st = ref.watch(myStreakProvider).value;
    final streak = (st?['current'] as num?)?.toInt() ?? 0;
    final xpMap = st?['xp'];
    final xp = xpMap is Map ? (xpMap['balance'] as num?)?.toInt() ?? (xpMap['total'] as num?)?.toInt() : null;
    final unread = ref.watch(unreadCountProvider);

    Widget section(String title, List<_NavItem> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.s4, Space.s4, Space.s4, Space.s1),
            child: Text(title.toUpperCase(), style: context.ty.cap.bold.copyWith(letterSpacing: 1.4, fontSize: 11).col(const Color(0xFF8FA3C7))),
          )
        else
          const Gap(Space.s4),
        for (final it in items) _SideButton(label: it.label, icon: it.icon, active: it.active(path), compact: compact, onTap: () => _go(it.route)),
      ],
    );

    return Container(
      width: w,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0B1F44), Color(0xFF081734)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 0 : Space.s5, Space.s6, Space.s4, Space.s4),
              child: Row(
                mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  const Mark(height: 34, onDark: true),
                  if (!compact) ...[
                    const Gap(Space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SolutionTee', style: context.ty.h3.col(Colors.white)),
                          Text('CBT · Learn. Think. Solve.', style: context.ty.cap.col(const Color(0xFF9FB2D6))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? Space.s3 : Space.s4),
              child: _SearchButton(compact: compact, onTap: () => router.push('/search')),
            ),
            Expanded(
              child: ScrollConfiguration(
                behavior: const DesktopScrollBehavior().copyWith(scrollbars: false),
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: compact ? Space.s3 : Space.s3, vertical: Space.s2),
                  children: [
                    section('Learn', _learn),
                    section('Play & connect', _play),
                    section('More', _more),
                    if (!premium && !compact) ...[
                      const Gap(Space.s4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s1),
                        child: _PremiumCard(onTap: () => showPaywall(context, reason: 'desktop_sidebar')),
                      ),
                    ],
                    const Gap(Space.s3),
                  ],
                ),
              ),
            ),
            const Divider(color: Color(0x22FFFFFF), height: 1),
            const Gap(Space.s3),
            if (compact) ...[
              _SideButton(
                label: 'Notifications',
                icon: PhosphorIcons.bell,
                active: path.startsWith('/notifications'),
                compact: true,
                badge: unread,
                onTap: () => router.push('/notifications'),
              ),
              _SideButton(
                label: 'Settings',
                icon: PhosphorIcons.gearSix,
                active: path.startsWith('/settings'),
                compact: true,
                onTap: () => router.push('/settings'),
              ),
            ],
            _ProfileTile(
              name: name,
              streak: streak,
              xp: xp,
              premium: premium,
              compact: compact,
              active: path == '/me' || path.startsWith('/me/'),
              unread: unread,
              onTap: () => _go('/me'),
              onBell: () => router.push('/notifications'),
              onSettings: () => router.push('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideButton extends StatefulWidget {
  const _SideButton({required this.label, required this.icon, required this.active, required this.compact, required this.onTap, this.badge = 0});
  final String label;
  final IconData Function(PhosphorIconsStyle) icon;
  final bool active, compact;
  final VoidCallback onTap;
  final int badge;
  @override
  State<_SideButton> createState() => _SideButtonState();
}

class _SideButtonState extends State<_SideButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.active;
    final fg = a ? Colors.white : const Color(0xFFB9C7DE);
    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: widget.compact ? 58 : 42,
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 0 : Space.s3),
      decoration: BoxDecoration(
        color: a ? Colors.white.withValues(alpha: .12) : (_hover ? Colors.white.withValues(alpha: .06) : Colors.transparent),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: widget.compact
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: widget.badge > 0,
                  label: Text(widget.badge > 99 ? '99+' : '${widget.badge}'),
                  backgroundColor: const Color(0xFFE5484D),
                  child: Icon(widget.icon(a ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular), size: 22, color: a ? Palette.gold400 : fg),
                ),
                const Gap(3),
                Text(
                  widget.label.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: context.ty.cap.copyWith(fontSize: 10.5, fontWeight: a ? FontWeight.w700 : FontWeight.w500).col(fg),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: widget.compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (!widget.compact)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 4,
                    height: a ? 22 : 0,
                    margin: const EdgeInsets.only(right: Space.s3),
                    decoration: BoxDecoration(color: Palette.gold500, borderRadius: BorderRadius.circular(4)),
                  ),
                Badge(
                  isLabelVisible: widget.badge > 0,
                  label: Text(widget.badge > 99 ? '99+' : '${widget.badge}'),
                  backgroundColor: const Color(0xFFE5484D),
                  child: Icon(widget.icon(a ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular), size: 22, color: a ? Palette.gold400 : fg),
                ),
                if (!widget.compact) ...[
                  const Gap(Space.s3),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.ty.body.copyWith(fontWeight: a ? FontWeight.w700 : FontWeight.w500).col(fg),
                    ),
                  ),
                ],
              ],
            ),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        button: true,
        selected: a,
        label: widget.label,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: row),
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.compact, required this.onTap});
  final bool compact;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : Space.s3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: Colors.white.withValues(alpha: .10)),
          ),
          child: Row(
            mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(PhosphorIcons.magnifyingGlass(), size: 20, color: const Color(0xFFB9C7DE)),
              if (!compact) ...[
                const Gap(Space.s3),
                Expanded(child: Text('Search questions, topics…', style: context.ty.sm.col(const Color(0xFF9FB2D6)))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(6)),
                  child: Text('Ctrl K', style: context.ty.cap.bold.copyWith(fontSize: 11).col(const Color(0xFFB9C7DE))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Space.s4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF2B233), Color(0xFFFFD27A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Row(
            children: [
              Icon(PhosphorIcons.crownSimple(PhosphorIconsStyle.fill), color: Palette.navy900, size: 26),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Go Premium', style: context.ty.label.bold.col(Palette.navy900)),
                    Text('Every year, every subject', style: context.ty.cap.col(Palette.navy900.withValues(alpha: .8))),
                  ],
                ),
              ),
              Icon(PhosphorIcons.arrowRight(PhosphorIconsStyle.bold), color: Palette.navy900, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.name,
    required this.streak,
    required this.xp,
    required this.premium,
    required this.compact,
    required this.active,
    required this.onTap,
    required this.unread,
    required this.onBell,
    required this.onSettings,
  });
  final String name;
  final int streak, unread;
  final int? xp;
  final bool premium, compact, active;
  final VoidCallback onTap, onBell, onSettings;
  @override
  Widget build(BuildContext context) {
    final initials = name.isEmpty ? 'ME' : name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();
    final avatar = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Palette.blue600,
        border: Border.all(color: premium ? Palette.gold400 : Colors.transparent, width: 2),
      ),
      child: Text(initials, style: context.ty.label.bold.col(Colors.white)),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(Space.s3, 0, Space.s3, Space.s4),
          padding: EdgeInsets.all(compact ? Space.s2 : Space.s3),
          decoration: BoxDecoration(
            color: active ? Colors.white.withValues(alpha: .12) : Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: compact
              ? Center(child: avatar)
              : Row(
                  children: [
                    avatar,
                    const Gap(Space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'My profile' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.ty.label.bold.col(Colors.white),
                          ),
                          const Gap(2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(PhosphorIcons.fire(PhosphorIconsStyle.fill), size: 14, color: const Color(0xFFFF9A3D)),
                                const Gap(4),
                                Text('$streak', style: context.ty.cap.bold.col(const Color(0xFFDCE4F2))),
                                if (xp != null) ...[
                                  const Gap(Space.s2),
                                  Icon(PhosphorIcons.lightning(PhosphorIconsStyle.fill), size: 14, color: Palette.gold400),
                                  const Gap(3),
                                  Text('$xp XP', style: context.ty.cap.bold.col(const Color(0xFFDCE4F2))),
                                ],
                                if (premium) ...[
                                  const Gap(Space.s2),
                                  Icon(PhosphorIcons.crownSimple(PhosphorIconsStyle.fill), size: 14, color: Palette.gold400),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _IconBtn(icon: PhosphorIcons.bell(), tip: 'Notifications', badge: unread, onTap: onBell),
                    _IconBtn(icon: PhosphorIcons.gearSix(), tip: 'Settings', onTap: onSettings),
                  ],
                ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.tip, required this.onTap, this.badge = 0});
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final int badge;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tip,
    child: IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      hoverColor: Colors.white.withValues(alpha: .08),
      icon: Badge(
        isLabelVisible: badge > 0,
        label: Text(badge > 99 ? '99+' : '$badge'),
        backgroundColor: const Color(0xFFE5484D),
        child: Icon(icon, size: 20, color: const Color(0xFFB9C7DE)),
      ),
    ),
  );
}

/// Next to the sign-in screens on a wide window: the brand, what the app does, and the disclaimer.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();
  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.sizeOf(context).width * 0.42).clamp(420.0, 640.0);
    const points = [
      ('Real JAMB, WAEC and NECO CBT', 'Past questions with the real exam timer.'),
      ('Your score the moment you finish', 'JAMB score out of 400, subject by subject.'),
      ('An AI tutor for every question', 'Step-by-step answers, day or night.'),
      ('Games, challenges and live classes', 'Practise with students across Nigeria.'),
    ];
    return Container(
      width: w,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0B1F44), Color(0xFF13306A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -120,
            top: -120,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2563B3).withValues(alpha: .35)),
            ),
          ),
          Positioned(
            left: -80,
            bottom: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF2B233).withValues(alpha: .18)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.s10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Mark(height: 44, onDark: true)]),
                const Spacer(),
                Text('Learn. Think. Solve.', style: context.ty.display.col(Colors.white)),
                const Gap(Space.s3),
                Text('The CBT practice app for Nigerian students, now on your computer.', style: context.ty.lg.col(const Color(0xFFC9D5EA))),
                const Gap(Space.s8),
                for (final (t, s) in points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.s4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(color: Color(0xFFF2B233), shape: BoxShape.circle),
                          child: Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), size: 18, color: Palette.navy900),
                        ),
                        const Gap(Space.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t, style: context.ty.label.bold.col(Colors.white)),
                              Text(s, style: context.ty.sm.col(const Color(0xFFAFC0DD))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Text(Config.disclaimer, style: context.ty.cap.col(const Color(0xFF8FA3C7))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
