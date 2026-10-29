import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/phosphor.g.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../data/tests_repo.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/states.dart';

/// Branch order in router.dart: home, study, test, ai, me.
const _branchOf = {'home': 0, 'study': 1, 'test': 2, 'ai_chat': 3, 'profile': 4};

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) ref.read(testsRepoProvider).syncPending();
  }

  @override
  Widget build(BuildContext context) {
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: current < 0 ? 0 : current,
        onDestinationSelected: (i) {
          final b = _branchOf[items[i]['type']]!;
          widget.shell.goBranch(b, initialLocation: b == widget.shell.currentIndex);
        },
        destinations: [
          for (final t in items)
            NavigationDestination(
              icon: Icon(tabIcon(t['type'] as String, false)),
              selectedIcon: Icon(tabIcon(t['type'] as String, true)),
              label: t['title'] as String,
            ),
        ],
      ),
    );
  }

  /// Maintenance mode and forced updates come from the admin (app_settings).
  Widget? _gate(Map<String, dynamic> settings) {
    final m = settings['maintenance'];
    if (m is Map && m['enabled'] == true) {
      return Scaffold(
        body: SafeArea(
          child: StateView(
            icon: PhosphorIcons.wrench(PhosphorIconsStyle.fill),
            tone: 'gold',
            title: 'We are improving SolutionTee',
            message: (m['message'] as String?) ?? 'Please check back soon. Tests you downloaded still work offline.',
          ),
        ),
      );
    }
    final v = settings['min_app_version'];
    if (v is Map && v['force'] == true && _older(Config.appVersion, (v['android'] as String?) ?? '0.0.0')) {
      return Scaffold(
        body: SafeArea(
          child: StateView(
            icon: PhosphorIcons.arrowCircleUp(PhosphorIconsStyle.fill),
            tone: 'navy',
            title: 'Please update SolutionTee',
            message: 'This version is too old. Update to keep practising with the latest questions.',
            action: FilledButton(
              onPressed: () => launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=com.solutiontee.cbt'), mode: LaunchMode.externalApplication),
              child: const Text('Update now'),
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

/// Study and AI tutor arrive in Phase 4.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.kind});
  final String kind;
  @override
  Widget build(BuildContext context) {
    final ai = kind == 'ai';
    return Scaffold(
      appBar: AppBar(title: Text(ai ? 'SolutionTee AI' : 'Study')),
      body: StateView(
        icon: ai ? PhosphorIcons.sparkle(PhosphorIconsStyle.fill) : PhosphorIcons.bookOpenText(PhosphorIconsStyle.fill),
        tone: ai ? 'gold' : 'blue',
        title: ai ? 'Your AI tutor is coming soon' : 'Study is coming soon',
        message: ai
            ? 'Ask any question and get step-by-step explanations, like a good teacher.'
            : 'Past questions with answers, video solutions, lesson notes and novels will be here.',
        action: OutlinedButton(onPressed: () => context.go('/test'), child: const Text('Practise a test now')),
      ),
    );
  }
}

/// Spacing helper used across screens.
const gap2 = SizedBox(height: Space.s2, width: Space.s2);
const gap3 = SizedBox(height: Space.s3, width: Space.s3);
const gap4 = SizedBox(height: Space.s4, width: Space.s4);
const gap5 = SizedBox(height: Space.s5, width: Space.s5);
const gap6 = SizedBox(height: Space.s6, width: Space.s6);
