import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/phosphor.g.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../core/nav.dart';
import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/push.dart';
import '../../core/secure_screen.dart';
import '../../data/tests_repo.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../notifications/turn_on_sheet.dart';
import '../premium/payments.dart';

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
    // Screenshots are blocked in the whole app (D-076); on Android 14+ we can say why.
    _secure = SecureScreen.watch(onScreenshot: _screenshotTried);
  }

  StreamSubscription<MethodCall>? _secure;

  void _screenshotTried() {
    if (!mounted) return;
    String path = '';
    try {
      path = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    } catch (_) {}
    if (DeviceEvents.ownMessage(path)) return;
    toast(context, 'Screenshots are turned off in SolutionTee CBT to protect our questions.', icon: PhosphorIcons.cameraSlash(PhosphorIconsStyle.fill));
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
    if (s == AppLifecycleState.resumed) {
      ref.read(testsRepoProvider).syncPending();
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
    final settings = ref.watch(appSettingsProvider).value ?? const {};
    final gate = _gate(settings);
    if (gate != null) return gate;

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

    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: _BottomNav(
        items: [for (final t in items) (type: t['type'] as String, title: t['title'] as String)],
        current: current < 0 ? 0 : current,
        onTap: (i) {
          final b = _branchOf[items[i]['type']]!;
          widget.shell.goBranch(b, initialLocation: b == widget.shell.currentIndex);
        },
      ),
    );
  }

  /// Maintenance mode and forced updates come from the admin (app_settings).
  Widget? _gate(Map<String, dynamic> settings) {
    final m = settings['maintenance'];
    if (m is Map && m['enabled'] == true) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: StateBlock(
              icon: PhosphorIcons.wrench(PhosphorIconsStyle.fill),
              tone: Tone.gold,
              title: 'We are improving SolutionTee',
              text: (m['message'] as String?) ?? 'Please check back soon. Tests you downloaded still work offline.',
            ),
          ),
        ),
      );
    }
    final v = settings['min_app_version'];
    if (v is Map && v['force'] == true && _older(Config.appVersion, (v['android'] as String?) ?? '0.0.0')) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: StateBlock(
              icon: PhosphorIcons.arrowCircleUp(PhosphorIconsStyle.fill),
              title: 'Please update SolutionTee',
              text: 'This version is too old. Update to keep practising with the latest questions.',
              action: Btn(
                'Update now',
                onPressed: () =>
                    launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=com.solutiontee.cbt'), mode: LaunchMode.externalApplication),
              ),
            ),
          ),
        ),
      );
    }
    return null;
  }

  static bool _older(String a, String b) {
    List<int> p(String s) => s.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    final x = p(a), y = p(b);
    for (var i = 0; i < 3; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d < 0;
    }
    return false;
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
