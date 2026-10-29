import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../widgets/phosphor.g.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/exam_logo.dart';
import '../shell/shell.dart';

/// Decides where to go: onboarding (first launch), login, profile setup, or Home.
Future<String> nextRoute(WidgetRef ref) async {
  if (!ref.read(settingsProvider).onboarded) return '/welcome';
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return '/login';
  try {
    final profile = await ref.read(profileProvider.future);
    final exams = (profile?['target_exams'] as List?) ?? const [];
    if (exams.isEmpty) return '/setup';
  } catch (_) {
    // Offline with no cached profile: go Home; setup can happen later.
  }
  return '/home';
}

/// Splash: the SolutionTee loader animation from /brand, then route.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.wait([Future<void>.delayed(const Duration(milliseconds: 1400)), nextRoute(ref)]).then((r) {
      if (mounted) context.go(r[1] as String);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? Palette.navy950 : Palette.neutral0,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: context.reduceMotion
                  ? Image.asset('assets/brand/solutiontee-mark-transparent.png')
                  : Lottie.asset(
                      dark ? 'assets/brand/solutiontee-loader-dark.json' : 'assets/brand/solutiontee-loader-light.json',
                      repeat: false,
                      errorBuilder: (_, _, _) => Image.asset('assets/brand/solutiontee-mark-transparent.png'),
                    ),
            ),
            gap4,
            Text('SolutionTee CBT', style: context.t.headlineSmall),
            gap2,
            Text('Learn. Think. Solve.', style: context.t.bodyMedium?.copyWith(color: context.c.textMuted)),
          ],
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.s5, Space.s8, Space.s5, Space.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/brand/solutiontee-mark-transparent.png',
                height: 64,
                alignment: Alignment.centerLeft,
              ).animate().fadeIn(duration: Motion.slow).slideY(begin: .2, curve: Motion.out),
              gap6,
              Text('Welcome to\nSolutionTee CBT', style: context.t.displaySmall).animate().fadeIn(delay: 100.ms, duration: Motion.slow),
              gap3,
              Text(
                'Practise JAMB, WAEC and NECO the real CBT way, get every answer explained, and see yourself improve.',
                style: context.t.bodyLarge?.copyWith(color: c.textMuted),
              ).animate().fadeIn(delay: 200.ms, duration: Motion.slow),
              gap6,
              Row(
                children: [
                  for (final b in ['JAMB', 'WAEC', 'NECO'])
                    Padding(
                      padding: const EdgeInsets.only(right: Space.s3),
                      child: ExamLogo(b, size: 56),
                    ),
                ],
              ).animate().fadeIn(delay: 300.ms, duration: Motion.slow),
              const Spacer(),
              FilledButton(onPressed: () => context.go('/onboarding'), child: const Text('Get started')),
              gap3,
              OutlinedButton(onPressed: () => context.go('/login'), child: const Text('I already have an account')),
              gap4,
              Text(Config.disclaimer, style: context.t.labelSmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onboarding slides: text comes from the admin (onboarding_slides), with built-in fallbacks.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _i = 0;

  static const _fallback = [
    {'title': 'A real CBT experience', 'body': 'Practise JAMB, WAEC and NECO exactly like the real computer-based test.', 'animation': 'cbt'},
    {'title': 'Past questions, explained', 'body': 'Every answer explained so you learn, not just guess.', 'animation': 'study'},
    {'title': 'See your progress', 'body': 'Track your scores and find your weak topics.', 'animation': 'progress'},
  ];

  IconData _icon(String? a) => switch (a) {
    'trophy' => PhosphorIcons.trophy(PhosphorIconsStyle.fill),
    'study' => PhosphorIcons.bookOpenText(PhosphorIconsStyle.fill),
    'ai' => PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
    'progress' => PhosphorIcons.chartLineUp(PhosphorIconsStyle.fill),
    'classes' => PhosphorIcons.videoCamera(PhosphorIconsStyle.fill),
    _ => PhosphorIcons.exam(PhosphorIconsStyle.fill),
  };

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(onboarded: true));
    if (mounted) context.go('/signup');
  }

  @override
  Widget build(BuildContext context) {
    final slides = ref.watch(onboardingProvider).value ?? _fallback;
    final c = context.c;
    final last = _i >= slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: const Text('Skip')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) {
                  final s = slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(color: i.isEven ? c.secondarySoft : c.accentSoft, shape: BoxShape.circle),
                          child: Icon(_icon(s['animation'] as String?), size: 88, color: i.isEven ? c.onSecondarySoft : c.onAccentSoft),
                        ).animate(key: ValueKey(i)).scale(begin: const Offset(.85, .85), duration: Motion.slow, curve: Motion.out).fadeIn(),
                        gap7,
                        Text(s['title'] as String, style: context.t.headlineMedium, textAlign: TextAlign.center),
                        gap3,
                        Text(
                          s['body'] as String,
                          style: context.t.bodyLarge?.copyWith(color: c.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < slides.length; i++)
                  AnimatedContainer(
                    duration: Motion.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _i ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(color: i == _i ? c.primary : c.borderStrong, borderRadius: BorderRadius.circular(8)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(Space.s5),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: last ? _finish : () => _page.nextPage(duration: Motion.base, curve: Motion.out),
                    child: Text(last ? 'Create my account' : 'Next'),
                  ),
                  gap3,
                  Text(Config.disclaimer, style: context.t.labelSmall, textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const gap7 = SizedBox(height: Space.s7);

/// After sign-up + setup (themed, light and dark).
class WelcomeNewScreen extends ConsumerWidget {
  const WelcomeNewScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = (ref.watch(profileProvider).value?['full_name'] as String? ?? '').split(' ').first;
    return _Hello(
      icon: PhosphorIcons.confetti(PhosphorIconsStyle.fill),
      title: name.isEmpty ? 'You are all set!' : 'Welcome, $name!',
      body: 'Your account is ready. Start with a quick test to see where you stand.',
      button: 'Let\'s go',
    );
  }
}

class WelcomeBackScreen extends ConsumerWidget {
  const WelcomeBackScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = (ref.watch(profileProvider).value?['full_name'] as String? ?? '').split(' ').first;
    return _Hello(
      icon: PhosphorIcons.handWaving(PhosphorIconsStyle.fill),
      title: name.isEmpty ? 'Welcome back!' : 'Welcome back, $name!',
      body: 'Pick up where you stopped. Every day of practice counts.',
      button: 'Continue',
    );
  }
}

class _Hello extends StatelessWidget {
  const _Hello({required this.icon, required this.title, required this.body, required this.button});
  final IconData icon;
  final String title, body, button;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.s6),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                child: Icon(icon, size: 56, color: c.onAccentSoft),
              ).animate().scale(begin: const Offset(.6, .6), duration: Motion.slow, curve: Motion.emphasized),
              gap6,
              Text(title, style: context.t.headlineMedium, textAlign: TextAlign.center).animate().fadeIn(delay: 150.ms),
              gap3,
              Text(
                body,
                style: context.t.bodyLarge?.copyWith(color: c.textMuted),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 250.ms),
              const Spacer(),
              FilledButton(onPressed: () => context.go('/home'), child: Text(button)),
            ],
          ),
        ),
      ),
    );
  }
}
