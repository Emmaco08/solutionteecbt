import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads.dart';
import '../../core/house_ads.dart';
import '../../widgets/phosphor.g.dart';

import '../../core/nav.dart';
import '../../core/engagement.dart';
import '../../core/providers.dart';
import '../../core/tab_scroll.dart';

import 'package:quick_actions/quick_actions.dart';

import '../../core/push.dart';
import '../../core/secure_screen.dart';
import '../../data/tests_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../core/device.dart';
import '../invite/invite_screens.dart';
import '../xp/streak_ui.dart';
import '../notifications/turn_on_sheet.dart';
import '../home/countdown.dart';
import '../premium/payments.dart';
import '../setup/age_gate.dart';
import '../profile/badges.dart';
import '../../core/platform.dart';
import '../../desktop/desktop_frame.dart';

/// Branch order in router.dart: home, study, test, ai, me.
const _branchOf = {'home': 0, 'study': 1, 'test': 2, 'ai_chat': 3, 'profile': 4};

/// The tab types shown in the bottom bar, in order (server `app_tabs`, or the prototype order when offline).
List<String> visibleTabTypes(List<Map<String, dynamic>>? fromServer) {
  final tabs = (fromServer ?? const []).where((t) => _branchOf.containsKey(t['type'])).map((t) => t['type'] as String).toList();
  return tabs.isEmpty ? const ['home', 'study', 'test', 'ai_chat', 'profile'] : tabs.take(5).toList();
}

IconData tabIcon(String type, bool on) {
  final s = on ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular;
  return switch (type) {
    'home' => PhosphorIcons.house(s),
    'study' => PhosphorIcons.bookOpenText(s),
    'test' => PhosphorIcons.exam(s),
    'ai_chat' => PhosphorIcons.sparkle(s),
    _ => PhosphorIcons.userCircle(s),
  };
}

/// Bottom navigation built from the server's `app_tabs` (cached offline). Unknown types are skipped.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  bool _birthAsked = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Send any tests finished offline.
    Future.microtask(() => ref.read(testsRepoProvider).syncPending());
    // Play build: listen to Google Play and finish any purchase that was not checked last time.
    if (store == Store.play) {
      final billing = ref.read(playBillingProvider);
      billing.onPremium = () {
        if (mounted) refreshPlan(ref);
      };
      billing.start();
    }
    Future.microtask(_startPush);
    Future.microtask(_checkAccount);
    Future.microtask(_startShortcuts);
    // Screenshots are blocked in the whole app (D-076); on Android 14+ we can say why.
    _secure = SecureScreen.watch(onScreenshot: _screenshotTried);
  }

  StreamSubscription<MethodCall>? _secure;
  bool _popupsShown = false;
  DateTime? _lastBack;

  /// Long-press on the app icon (D-136): Continue test, Practise now, Ask the AI tutor, Search.
  Future<void> _startShortcuts() async {
    if (isDesktop) return; // app-icon shortcuts are a phone feature
    try {
      const qa = QuickActions();
      await qa.initialize((type) async {
        if (!mounted) return;
        final router = GoRouter.of(context);
        switch (type) {
          case 'continue':
            final a = await ref.read(dbProvider).unfinishedAttempt();
            if (!mounted) return;
            a != null ? router.push('/cbt/${a.id}') : router.go('/test');
          case 'practice':
            router.push('/test/setup?exam=JAMB&mode=quick');
          case 'ai':
            router.go('/ai');
          case 'search':
            router.push('/search');
        }
      });
      await qa.setShortcutItems(const [
        ShortcutItem(type: 'continue', localizedTitle: 'Continue my test', icon: 'ic_shortcut_continue'),
        ShortcutItem(type: 'practice', localizedTitle: 'Quick practice', icon: 'ic_shortcut_practice'),
        ShortcutItem(type: 'ai', localizedTitle: 'Ask the AI tutor', icon: 'ic_shortcut_ai'),
        ShortcutItem(type: 'search', localizedTitle: 'Search', icon: 'ic_shortcut_search'),
      ]);
    } catch (_) {}
  }

  /// The phone's back button on a tab (D-136): another tab goes back to Home; on Home, press twice to leave.
  void _onBack() {
    if (widget.shell.currentIndex != 0) {
      widget.shell.goBranch(0);
      return;
    }
    if (isDesktop) return; // Esc on Home never closes the Windows app (the window's X does)
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Press back again to leave SolutionTee'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
      );
  }

  /// D-082: a milestone celebration (once), else the daily claim pop-up on the first open of the day.
  Future<void> _dailyPopups() async {
    if (_popupsShown || !mounted) return;
    _popupsShown = true;
    await Engagement.countOpen(ref).catchError((_) {});
    // A new student sees the app tour first: the countdown and the other pop-ups wait for their next open (D-154).
    if (!ref.read(settingsProvider).toured || !mounted) return;
    // The exam countdown first (once a day, D-135), then the milestone or daily claim; when none of them showed, maybe
    // the app rating card or a suggestion (owner, 13 Nov 2026). One pop-up an open at most.
    final countdown = await maybeShowDailyCountdown(context, ref);
    if (!mounted) return;
    // Badge levels won since the last visit (D-142), celebrated once.
    await checkBadgeWins(context, ref);
    if (!mounted) return;
    try {
      ref.invalidate(myStreakProvider);
      final st = await ref.read(myStreakProvider.future).timeout(const Duration(seconds: 10));
      if (!mounted || st.isEmpty) return;
      final cel = st['celebrate'];
      if (cel is Map) {
        await showMilestone(context, ref, Map<String, dynamic>.from(cel));
        return;
      }
      final xp = st['xp'];
      final db = ref.read(dbProvider);
      final now = DateTime.now(), today = '${now.year}-${now.month}-${now.day}';
      if (xp is Map && xp['enabled'] == true && xp['claimed_today'] != true && await db.kvGet('claim_sheet_day') != today && mounted) {
        await db.kvSet('claim_sheet_day', today);
        if (mounted) await showDailyClaim(context, ref, st);
        return;
      }
    } catch (_) {}
    if (!countdown && mounted) await Engagement.maybeShowOne(context, ref).catchError((_) => false);
  }

  /// One account per phone and bans (D-078): save this phone (hashed id) and ask the server about this account.
  /// Offline or any error: carry on (the server still refuses a banned account's data).
  Future<void> _checkAccount() async {
    try {
      final ids = await DeviceCheck.ids();
      if (ids.clone) {
        if (mounted) context.go('/clone-blocked');
      }
      final j = await ref.read(supabaseProvider).rpc('device_check_in', params: {'p_ids': ids.list, 'p_flags': ids.flags}).timeout(const Duration(seconds: 15));
      final st = Map<String, dynamic>.from(j as Map);
      ref.read(accountStatusProvider.notifier).set(st);
      if (!mounted || ids.clone) return;
      if (st['phone_banned'] == true) {
        context.go('/phone-banned');
      } else if (st['banned'] == true) {
        context.go('/banned');
      } else if (st['phone_taken'] == true) {
        context.go('/phone-taken');
      } else if (await checkAge(context, ref) && mounted) {
        // Age rules (D-109): under 13, missing parent email or a parent turned the account off.
        await _dailyPopups();
      }
    } catch (_) {}
  }

  void _screenshotTried() {
    if (!mounted || !SecureScreen.protecting) return; // screenshots allowed right now (admin switch, D-080)
    String path = '';
    try {
      path = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    } catch (_) {}
    if (DeviceEvents.ownMessage(path)) return;
    toast(context, 'Screenshots are turned off here to protect our questions.', icon: PhosphorIcons.cameraSlash(PhosphorIconsStyle.fill));
  }

  /// Push (4D, D-063): save this phone's token, match topics to the switches and plan, and open tapped messages.
  /// Like a normal app (owner, D-064): every time the app opens while notifications are off, it asks again:
  /// Android's own box while Android still shows it, then our "Turn on notifications" sheet.
  Future<void> _startPush() async {
    final push = ref.read(pushProvider);
    push.onOpen = (route) {
      if (mounted) openRoute(context, route);
    };
    push.onForeground = (title) {
      if (mounted) toast(context, title, icon: PhosphorIcons.bellRinging(PhosphorIconsStyle.fill));
    };
    final premium = await ref.read(myPlanProvider.future).then((p) => p['tier'] == 'premium').catchError((_) => false);
    await push.register(premium: premium);
    if (push.askedThisRun) return;
    push.askedThisRun = true;
    await Future<void>.delayed(const Duration(milliseconds: 1200)); // let Home appear first
    if (!mounted) return;
    final db = ref.read(dbProvider);
    final allowed = await push.ensureAllowed(
      timesAsked: () async => int.tryParse(await db.kvGet('push_sys_asked') ?? '') ?? 0,
      setTimesAsked: (n) => db.kvSet('push_sys_asked', '$n'),
    );
    ref.invalidate(notificationsOnProvider);
    if (!allowed && mounted) await showTurnOnNotifications(context, ref);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _secure?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) Ads.instance.paused();
    if (s == AppLifecycleState.resumed) {
      Ads.instance.resumed();
      ref.read(testsRepoProvider).syncPending();
      _checkAccount();
      // Back from the phone's settings: notifications may be on now.
      ref.invalidate(notificationsOnProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Plan changed (payment, code, expiry): move this phone between the Free and Premium push topics.
    ref.listen(myPlanProvider, (prev, next) {
      final was = prev?.value?['tier'], now = next.value?['tier'];
      if (now != null && was != now) ref.read(pushProvider).syncTopics(premium: now == 'premium').ignore();
    });
    // Ads (big update 2, step B): read what this student sees; Premium or a plan change reloads it. When ads are on and
    // we do not know the age yet, the birth year must be given once (personalised ads only for 18+).
    ref.listen(myPlanProvider, (prev, next) {
      if (prev?.value?['tier'] != next.value?['tier']) ref.invalidate(adsConfigProvider);
    });
    final ads = ref.watch(adsConfigProvider).value;
    ref.watch(houseAdsProvider); // brand campaigns, ready for breaks
    if (!_birthAsked && ads != null && ads.askBirthYear) {
      _birthAsked = true;
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) askBirthYearOnce(this.context, ref);
      });
    }
    // Maintenance and forced updates are handled for the whole app by AppGate (core/app_gate.dart).

    final tabs = (ref.watch(tabsProvider).value ?? const []).where((t) => _branchOf.containsKey(t['type'])).toList();
    final items = tabs.isEmpty
        ? const [
            {'type': 'home', 'title': 'Home'},
            {'type': 'study', 'title': 'Study'},
            {'type': 'test', 'title': 'Test'},
            {'type': 'ai_chat', 'title': 'AI Tutor'},
            {'type': 'profile', 'title': 'Me'},
          ]
        : tabs.take(5).toList();
    final current = items.indexWhere((t) => _branchOf[t['type']] == widget.shell.currentIndex);

    // The sticky banner floats just above the tab bar, over the screen, and stays while scrolling (owner, 2026-11-07).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: widget.shell),
            Positioned(left: 0, right: 0, bottom: 0, child: ShellStickyBanner(hidden: widget.shell.currentIndex == _branchOf['ai_chat'])),
          ],
        ),
        // Desktop (D-166): the sidebar takes the tabs' place.
        bottomNavigationBar: DesktopScope.sidebar(context)
            ? null
            : _BottomNav(
                items: [for (final t in items) (type: t['type'] as String, title: t['title'] as String)],
                current: current < 0 ? 0 : current,
                onTap: (i) {
                  final b = _branchOf[items[i]['type']]!;
                  // Tapping the tab you are on: back to its first page and up to the top (D-136).
                  if (b == widget.shell.currentIndex) scrollTabToTop(ref, b);
                  widget.shell.goBranch(b, initialLocation: b == widget.shell.currentIndex);
                },
              ),
      ),
    );
  }
}

/// Bottom navigation (`.bnav`): surface, top border, the active icon in a gold-soft pill, bold 11 px labels.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.items, required this.current, required this.onTap});
  final List<({String type, String title})> items;
  final int current;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: Sizes.bottomNav + MediaQuery.paddingOf(context).bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                selected: i == current,
                button: true,
                label: items[i].title,
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: Motion.base,
                        curve: Motion.out,
                        width: 56,
                        height: 30,
                        decoration: BoxDecoration(color: i == current ? c.accentSoft : Colors.transparent, borderRadius: BorderRadius.circular(99)),
                        child: Icon(tabIcon(items[i].type, i == current), size: 22, color: i == current ? c.onAccentSoft : c.textSubtle),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.ty.cap.bold.copyWith(fontSize: 11, letterSpacing: 0).col(i == current ? c.text : c.textSubtle),
                        semanticsLabel: '',
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Study and AI tutor arrive in Phase 4.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.kind});
  final String kind;
  @override
  Widget build(BuildContext context) {
    final ai = kind == 'ai';
    return Scaffold(
      appBar: TopBar(
        showBack: false,
        center: Padding(
          padding: const EdgeInsets.only(left: Space.s3),
          child: Text(ai ? 'SolutionTee AI' : 'Study', style: context.ty.h2),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: StateBlock(
            icon: ai ? PhosphorIcons.sparkle(PhosphorIconsStyle.fill) : PhosphorIcons.bookOpenText(PhosphorIconsStyle.fill),
            tone: ai ? Tone.gold : Tone.blue,
            title: ai ? 'Your AI tutor is coming soon' : 'Study is coming soon',
            text: ai
                ? 'Ask any question and get step-by-step explanations, like a patient teacher.'
                : 'Past questions with answers, video solutions, lesson notes and novels will be here.',
            action: Btn('Practise a test now', onPressed: () => context.go('/test')),
          ),
        ),
      ),
    );
  }
}
