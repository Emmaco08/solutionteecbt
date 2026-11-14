import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/device.dart';
import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/phosphor.g.dart';
import '../auth/auth_screens.dart';
import '../home/home_screen.dart';
import '../xp/xp_screens.dart';
import '../xp/streak_ui.dart';
import 'onboarding_art.dart';
import '../../ui/confetti.dart';
import '../../ui/subject_icons.dart';

/// Logged out: Welcome every time (prototype: splash → welcome), or back to the email code if the app was
/// closed while the student was fetching it.
Future<String> nextRoute(WidgetRef ref) async {
  // D-079: a cloned / dual copy of the app, or a banned phone, never reaches sign-in.
  final ids = await DeviceCheck.ids();
  if (ids.clone) return '/clone-blocked';
  if (ids.any) {
    try {
      final st = await Supabase.instance.client.rpc('device_status', params: {'p_ids': ids.list}).timeout(const Duration(seconds: 6));
      if (st is Map && st['banned'] == true) return '/phone-banned';
    } catch (_) {
      // Offline: the server checks again at sign-up and sign-in.
    }
  }
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    final pending = await VerifyArgs.restore(ref.read(dbProvider));
    return pending != null ? '/verify' : '/welcome';
  }
  try {
    final profile = await ref.read(profileProvider.future);
    final exams = (profile?['target_exams'] as List?) ?? const [];
    if (exams.isEmpty) return '/setup';
  } catch (_) {
    // Offline with no cached profile: go Home; setup can happen later.
  }
  return '/home';
}

// ---------------------------------------------------------------- splash (prototype: splash)
/// Navy splash: brand loader (intro, then loop), name, "Learn. Think. Solve." with the last word in gold.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    final rm = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations || ref.read(settingsProvider).reduceMotion;
    _next = nextRoute(ref);
    Future.wait([Future<void>.delayed(Duration(milliseconds: rm ? 1200 : 3400)), _next]).then((r) => _go());
  }

  late final Future<String> _next;
  bool _gone = false;

  /// Tapping the splash skips the wait (prototype).
  Future<void> _go() async {
    if (_gone) return;
    _gone = true;
    final r = await _next;
    if (mounted) context.go(r);
  }

  @override
  Widget build(BuildContext context) {
    const fg = Color(0xFFF4F7FC);
    final rm = context.reduceMotion;
    Widget rise(Widget w, int ms) => rm ? w : w.animate().fadeIn(delay: ms.ms, duration: Motion.slow).slideY(begin: .3, curve: Motion.out);
    return Scaffold(
      backgroundColor: Palette.navy900,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 168, height: 168, child: rm ? const Center(child: Mark(height: 96, onDark: true)) : const _Loader()),
              const Gap(Space.s4),
              rise(Text('SolutionTee CBT', style: context.ty.h2.copyWith(fontSize: 24, letterSpacing: -.3).col(fg)), 1100),
              const Gap(Space.s4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  rise(Text('Learn.', style: context.ty.body.col(const Color(0xFFAFC0DD))), 1350),
                  const SizedBox(width: 8),
                  rise(Text('Think.', style: context.ty.body.col(const Color(0xFFAFC0DD))), 1550),
                  const SizedBox(width: 8),
                  rise(Text('Solve.', style: context.ty.body.col(Palette.gold400)), 1750),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The brand loader (brand/solutiontee-loader-dark.json): intro frames 0–52 once, then frames 52–149 on a loop.
class _Loader extends StatefulWidget {
  const _Loader();
  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Lottie.asset(
    'assets/brand/solutiontee-loader-dark.json',
    controller: _c,
    onLoaded: (comp) {
      final frames = comp.endFrame - comp.startFrame;
      double at(double f) => ((f - comp.startFrame) / frames).clamp(0, 1);
      _c.duration = comp.duration;
      _c.animateTo(at(52)).then((_) {
        if (mounted) _c.repeat(min: at(52), max: at(149));
      });
    },
    errorBuilder: (_, _, _) => const Center(child: Mark(height: 96, onDark: true)),
  );
}

// ---------------------------------------------------------------- welcome (prototype: welcome)
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    final copy = <Widget>[
      Text('Welcome to\nSolutionTee CBT', style: context.ty.display),
      Text(
        'Practise real JAMB, WAEC and NECO CBT questions. Learn from clear solutions. Walk into your exam ready.',
        style: context.ty.lg.col(context.c.textMuted),
      ),
      Row(
        children: [
          const ExamLogo('JAMB', size: LogoSize.sm),
          const Gap(Space.s2),
          const ExamLogo('WAEC', size: LogoSize.sm),
          const Gap(Space.s2),
          const ExamLogo('NECO', size: LogoSize.sm),
          const SizedBox(width: Space.s2 + 4),
          Text('All three exams, one app', style: context.ty.sm.col(context.c.textMuted)),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: Space.s2),
        child: Btn('Get started', block: true, icon: PhosphorIcons.arrowRight(), onPressed: () => context.go('/onboarding')),
      ),
      Btn('I already have an account', kind: BtnKind.ghost, onPressed: () => context.go('/login')),
      const Disclaimer(Config.disclaimer),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // The navy disc, the gold disc (up and right, like the prototype) and the app icon, kept whole:
              // the group is 330 × 330 and shrinks to fit shorter phones instead of being cut.
              child: Padding(
                padding: const EdgeInsets.all(Space.s3),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 330,
                      height: 330,
                      child: Stack(
                        children: [
                          const Positioned(left: 0, top: 30, child: ArtDisc(size: 300)),
                          const Positioned(left: 150, top: 0, child: ArtDisc(size: 180, tone: Tone.gold, breathe: false)),
                          Positioned(
                            left: 150 - 54,
                            top: 180 - 54,
                            child: rm
                                ? const AppIconArt()
                                : const Float(child: AppIconArt())
                                      .animate()
                                      .scale(begin: const Offset(.85, .85), duration: Motion.slow, curve: Motion.emphasized)
                                      .fadeIn(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.s5, 0, Space.s5, Space.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < copy.length; i++) ...[
                    if (i > 0) const Gap(Space.s4),
                    rm ? copy[i] : copy[i].animate(delay: Motion.stagger * i).fadeIn(duration: Motion.slow).slideY(begin: .12, curve: Motion.out),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- onboarding slides (prototype: onboard)
/// Six slides. Titles and text come from the admin (onboarding_slides); the picture is chosen by its
/// `animation` key: cbt, trophy, study, ai, progress, classes (same art as the prototype).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _i = 0;

  static const _fallback = [
    {
      'title': 'A real CBT experience',
      'body': 'Timed exams that look and feel like JAMB, WAEC and NECO CBT. Practise until the real day feels familiar.',
      'animation': 'cbt',
    },
    {
      'title': 'Weekly challenges',
      'body': 'Answer fast and right to climb the leaderboard and win Premium days and XP. Free and Premium students can join, and play is fair for everyone.',
      'animation': 'trophy',
    },
    {
      'title': 'Game Zone: learn by playing',
      'body': 'Battle other students or the SolutionTee Bot in fast exam games. Every game is real practice, and every win earns XP.',
      'animation': 'games',
    },
    {'title': 'SolutionTee AI tutor', 'body': 'Stuck on a question? Ask our AI tutor. It explains step by step, like a patient teacher.', 'animation': 'ai'},
    {
      'title': 'Learn together',
      'body': 'Ask any question and get help fast from other students and SolutionTee AI. Share tips and help others too.',
      'animation': 'community',
    },
    {
      'title': 'Your own real tutor',
      'body': 'Book a real teacher for one-to-one lessons in chat. Any topic, explained step by step, at your pace.',
      'animation': 'tutor',
    },
    {
      'title': 'Past questions, videos and notes',
      'body': 'Every answer comes with a clear explanation. Watch video solutions and read simple lesson notes.',
      'animation': 'study',
    },
    {'title': 'See your progress', 'body': 'Track your scores, find your weak topics and practise them until they become strong.', 'animation': 'progress'},
    {
      'title': 'Join live JAMB classes',
      'body': 'Learn with real teachers online. Join classes, ask questions and get study materials.',
      'animation': 'classes',
    },
  ];

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(onboarded: true));
    if (mounted) context.go('/signup');
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fromDb = ref.watch(onboardingProvider).value;
    final slides = (fromDb == null || fromDb.isEmpty) ? _fallback : fromDb;
    final last = _i >= slides.length - 1;
    return Scaffold(
      appBar: TopBar(
        showBack: false,
        actions: [Btn('Skip', kind: BtnKind.ghost, onPressed: _finish)],
      ),
      body: Column(
        children: [
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Center(
                          child: SlideArt(kind: s['animation'] as String? ?? 'cbt', current: i == _i),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 150),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: Space.s4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['title'] as String, style: context.ty.h1),
                              const Gap(Space.s2),
                              Text(s['body'] as String, style: context.ty.lg.col(context.c.textMuted)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          FooterCta(
            clean: true,
            child: Row(
              children: [
                Dots(count: slides.length, index: _i),
                const Spacer(),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 140),
                  child: Btn(
                    last ? 'Create account' : 'Next',
                    icon: last ? null : PhosphorIcons.arrowRight(),
                    onPressed: last ? _finish : () => _page.nextPage(duration: Motion.slow, curve: Motion.out),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- welcome (new account) (prototype: welcome-new)
/// Shown once after profile setup: avatar ring, the plan we made (exams, subjects, target, Free plan),
/// "Take a 30-second tour" or "Skip, go to Home". Light: soft gold glow; dark: the navy celebration.
class WelcomeNewScreen extends ConsumerWidget {
  const WelcomeNewScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = context.isDark;
    final p = ref.watch(profileProvider).value ?? const {};
    final name = (p['full_name'] as String?) ?? '';
    final first = name.split(' ').first;
    final exams = [for (final e in (p['target_exams'] as List? ?? const [])) e as String];
    final subjCodes = [for (final s in (p['jamb_subjects'] as List? ?? const [])) s as String];
    final subjects = ref.watch(subjectsProvider).value ?? const [];
    String subjName(String code) => (subjects.where((s) => s['code'] == code).firstOrNull?['name'] as String?) ?? code.toUpperCase();
    final target = (p['target_score'] as num?)?.toInt();
    final freeYears = ref.watch(freePlanSummaryProvider).value;

    final text = dark ? const Color(0xFFF4F7FC) : context.c.text;
    final muted = dark ? const Color(0xFFAFC0DD) : context.c.textMuted;
    final body = dark ? const Color(0xFFDCE4F2) : context.c.textMuted;
    final rowBg = dark ? Colors.white.withValues(alpha: .06) : context.c.surface;
    final rowBorder = dark ? Colors.white.withValues(alpha: .08) : context.c.border;
    final chipBg = dark ? Colors.white.withValues(alpha: .1) : context.c.primarySoft;
    final chipFg = dark ? const Color(0xFFF4F7FC) : context.c.onPrimarySoft;
    final icBg = dark ? const Color.fromRGBO(242, 178, 51, .16) : context.c.accentSoft;
    final icFg = dark ? Palette.gold400 : context.c.onAccentSoft;
    final link = dark ? Palette.gold400 : context.c.link;
    final rm = context.reduceMotion;

    Widget chip(Widget child) => Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(99)),
      child: DefaultTextStyle(style: context.ty.sm.bold.col(chipFg), child: child),
    );
    Widget row(IconData ic, Widget content) => Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: rowBorder),
        boxShadow: dark ? null : context.shadow(1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: icBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(ic, size: 18, color: icFg),
          ),
          const Gap(Space.s3),
          Expanded(child: content),
        ],
      ),
    );
    Widget label(String t) => Text(t, style: context.ty.cap.bold.copyWith(letterSpacing: .4).col(muted));

    final rows = <Widget>[
      if (exams.isNotEmpty)
        row(
          PhosphorIcons.exam(PhosphorIconsStyle.fill),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label('Your exams'),
              const Gap(Space.s2),
              Wrap(
                spacing: Space.s2,
                runSpacing: Space.s2,
                children: [
                  for (final e in exams)
                    chip(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExamLogo(e, size: LogoSize.sm, px: 22),
                          const Gap(Space.s2),
                          Text(e),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      if (subjCodes.isNotEmpty)
        row(
          PhosphorIcons.books(PhosphorIconsStyle.fill),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label('JAMB subjects'),
              const Gap(Space.s2),
              Wrap(
                spacing: Space.s2,
                runSpacing: Space.s2,
                children: [
                  for (final s in subjCodes)
                    chip(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(subjectIcon(s), size: 16, color: chipFg),
                          const SizedBox(width: 6),
                          Text(subjName(s)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      if (target != null)
        row(
          PhosphorIcons.target(PhosphorIconsStyle.fill),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: label('Target score')),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$target', style: context.ty.body.bold.tnum.col(text)),
                        TextSpan(text: ' / 400', style: context.ty.body.col(muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(Space.s2),
              ProgressBar(target / 400, color: Palette.gold400, track: dark ? Colors.white.withValues(alpha: .14) : context.c.surfaceSunken),
            ],
          ),
        ),
      row(
        PhosphorIcons.gift(PhosphorIconsStyle.fill),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('Free plan'),
            const Gap(Space.s1),
            Text.rich(
              TextSpan(
                style: context.ty.sm.col(body),
                children: [
                  TextSpan(text: freeYears ?? 'Some past years of each exam are free. '),
                  TextSpan(text: ' Premium is coming soon.', style: context.ty.sm.bold.col(link)),
                ],
              ),
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: dark ? Palette.navy900 : context.c.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -1),
                  radius: 1.2,
                  colors: dark ? const [Palette.navy700, Palette.navy900] : [Palette.gold50, context.c.bg],
                  stops: dark ? const [0, .6] : const [0, .55],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Space.s6, Space.s6, Space.s6, Space.s5),
                        child: Column(
                          children: [
                            _AvatarBadge(
                              name: name,
                              ring: dark ? Palette.gold400 : Palette.gold500,
                              track: dark ? Colors.white.withValues(alpha: .12) : context.c.surfaceSunken,
                              cut: dark ? Palette.navy900 : context.c.bg,
                            ),
                            const Gap(Space.s3),
                            Text('Welcome to SolutionTee${first.isEmpty ? '' : ', $first'}!', style: context.ty.h1.col(text), textAlign: TextAlign.center),
                            const Gap(Space.s3),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: Text(
                                'Your account is ready. Here is the plan we made for you.',
                                style: context.ty.body.col(muted),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Space.s5, 0, Space.s5, Space.s4),
                        child: Column(
                          children: [
                            for (var i = 0; i < rows.length; i++) ...[
                              if (i > 0) const Gap(Space.s3),
                              rm ? rows[i] : rows[i].animate(delay: (700 + 90 * i).ms).fadeIn(duration: Motion.slow).slideY(begin: .12, curve: Motion.out),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                FooterCta(
                  clean: true,
                  transparent: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Btn(
                        'Take a 30-second tour',
                        kind: BtnKind.accent,
                        block: true,
                        leading: PhosphorIcons.mapTrifold(PhosphorIconsStyle.fill),
                        onPressed: () => context.go('/home?tour=1'),
                      ),
                      const Gap(Space.s2),
                      TextButton(
                        onPressed: () {
                          context.go('/home');
                          Future.delayed(const Duration(milliseconds: 400), () {
                            if (context.mounted) {
                              toast(context, 'You can replay the tour any time from Me, then Help.', icon: PhosphorIcons.mapTrifold(PhosphorIconsStyle.fill));
                            }
                          });
                        },
                        child: Text('Skip, go to Home', style: context.ty.label.bold.col(dark ? const Color(0xFFDCE4F2) : context.c.link)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!rm) const IgnorePointer(child: Confetti(delay: Duration(milliseconds: 650))),
        ],
      ),
    );
  }
}

/// Free-plan line for the welcome screen, from the server's open years (e.g. "JAMB 2001 to 2003 are free.").
final freePlanSummaryProvider = FutureProvider.autoDispose<String?>((ref) async {
  final years = await ref.watch(openYearsProvider.future);
  final exams = await ref.watch(examsProvider.future);
  final jambId = exams.where((e) => e['code'] == 'JAMB').map((e) => e['id']).firstOrNull;
  final open = {
    for (final y in years)
      if (y['exam_id'] == jambId && y['cbt_open'] == true) (y['year'] as num).toInt(),
  }.toList()..sort();
  if (open.isEmpty) return null;
  return open.length == 1 ? 'JAMB ${open.first} is free.' : 'JAMB ${open.first} to ${open.last} are free.';
});

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.name, required this.ring, required this.track, required this.cut});
  final String name;
  final Color ring, track, cut;
  @override
  Widget build(BuildContext context) {
    final rm = context.reduceMotion;
    return SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: rm ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Motion.out,
              builder: (_, v, _) => CircularProgressIndicator(value: v, strokeWidth: 5, color: ring, backgroundColor: track, strokeCap: StrokeCap.round),
            ),
          ),
          rm
              ? Avatar(name, size: 132)
              : Avatar(name, size: 132).animate().scale(begin: const Offset(.85, .85), duration: Motion.slow, curve: Motion.emphasized),
          Positioned(
            right: 10,
            bottom: 10,
            child: _pop(
              rm,
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.c.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: cut, width: 4),
                ),
                child: Icon(PhosphorIcons.checkFat(PhosphorIconsStyle.fill), size: 18, color: Colors.white),
              ),
              900,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _pop(bool rm, Widget w, int delayMs) =>
    rm ? w : w.animate().scale(delay: delayMs.ms, begin: const Offset(.85, .85), duration: Motion.slow, curve: Motion.emphasized).fadeIn(delay: delayMs.ms);

// ---------------------------------------------------------------- welcome back (prototype: welcome-back, D-082)
/// After log in: the student's photo in a gold streak ring, the flame, this week, today's XP to claim and the next
/// streak bonus, then "Start practising" (or "Continue my test"). The server's streak when online; this phone's
/// tests when offline.
class WelcomeBackScreen extends ConsumerStatefulWidget {
  const WelcomeBackScreen({super.key});
  @override
  ConsumerState<WelcomeBackScreen> createState() => _WelcomeBackScreenState();
}

class _WelcomeBackScreenState extends ConsumerState<WelcomeBackScreen> {
  bool _busy = false;
  int? _got;

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      final g = await claimDailyXp(ref);
      HapticFeedback.mediumImpact();
      ref.invalidate(myStreakProvider);
      if (mounted) setState(() => _got = g);
    } catch (_) {
      if (mounted) toast(context, 'Could not claim. Check your internet and try again.', icon: PhosphorIcons.wifiSlash());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final name = (ref.watch(profileProvider).value?['full_name'] as String?) ?? '';
    final first = name.split(' ').first;
    final h = DateTime.now().hour;
    final hello = h < 12
        ? 'Good morning'
        : h < 17
        ? 'Good afternoon'
        : 'Good evening';
    final unfinished = ref.watch(unfinishedProvider).value;
    final st = ref.watch(myStreakProvider).value ?? const <String, dynamic>{};
    final local = ref.watch(practiceStatsProvider).value;
    final today = DateTime.now().weekday - 1;
    final week = st['week'] is List
        ? rows(st['week'])
        : [
            for (var k = 0; k < 7; k++) {'done': local?.week.contains(k) ?? false, 'today': k == today},
          ];
    final days = (st['current'] as num?)?.toInt() ?? local?.streak ?? 0;
    final todayDone = st['today_done'] == true || (local?.week.contains(today) ?? false);
    final xp = st['xp'] is Map ? Map<String, dynamic>.from(st['xp'] as Map) : const <String, dynamic>{};
    final next = st['next'] is Map ? Map<String, dynamic>.from(st['next'] as Map) : null;
    final rm = context.reduceMotion;
    Widget enter(Widget w, int i) =>
        rm ? w : w.animate(delay: (Motion.stagger * i) + 200.ms).fadeIn(duration: Motion.slow).slideY(begin: .12, curve: Motion.out);

    final streakCard = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StreakFlame(days: days, size: 40, lit: days > 0),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(days > 0 ? '$days-day streak' : 'Start your streak', style: context.ty.h3),
                    Text(
                      todayDone ? 'You practised today. Well done!' : 'Answer one question today to ${days > 0 ? 'make it ${days + 1}' : 'start it'}.',
                      style: context.ty.sm.col(c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(Space.s4),
          StreakWeek(week: week),
          if (next != null) ...[
            const Gap(Space.s3),
            Row(
              children: [
                Icon(PhosphorIcons.target(PhosphorIconsStyle.fill), size: 16, color: Palette.gold500),
                const Gap(Space.s2),
                Expanded(
                  child: Text(
                    '${next['left']} ${next['left'] == 1 ? 'day' : 'days'} to your ${next['days']}-day bonus${xp['enabled'] == true ? ' (+${next['xp']} XP)' : ''}',
                    style: context.ty.cap.col(c.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final xpCard = xp['enabled'] != true
        ? null
        : Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(Space.s4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Palette.navy900, Color(0xFF13306A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
                child: Row(
                  children: [
                    const XpCoin(size: 44),
                    const Gap(Space.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${xpText(((xp['balance'] as num?) ?? 0) + (_got ?? 0))} XP', style: context.ty.h3.tnum.col(Colors.white)),
                          Text(
                            _got != null || xp['claimed_today'] == true ? 'Today\'s XP claimed. See you tomorrow!' : 'Your daily XP is ready',
                            style: context.ty.cap.col(const Color(0xFFB8C4DA)),
                          ),
                        ],
                      ),
                    ),
                    if (_got == null && xp['claimed_today'] != true)
                      Btn('Claim +${xp['daily_claim']}', kind: BtnKind.accent, sm: true, loading: _busy, onPressed: _busy ? null : _claim)
                    else
                      Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: Palette.gold500),
                  ],
                ),
              ),
              if ((_got ?? 0) > 0) const Positioned.fill(child: CoinBurst(count: 10)),
            ],
          );

    final cards = <Widget>[streakCard, ?xpCard, if (unfinished != null) ContinueCard(a: unfinished)];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.s6, Space.s6, Space.s6, Space.s5),
                    child: Column(
                      children: [
                        _pop(rm, StreakPhoto(name: name, days: days, todayDone: todayDone), 0),
                        const Gap(Space.s4),
                        Text('$hello,', style: context.ty.lg.col(c.textMuted)).animate().fadeIn(delay: 150.ms, duration: Motion.slow),
                        const Gap(Space.s2),
                        Text(
                          first.isEmpty ? 'Welcome back' : 'Welcome back, $first',
                          style: context.ty.display,
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 250.ms, duration: Motion.slow).slideY(begin: .2, curve: Motion.out),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s5),
                    child: Column(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[if (i > 0) const Gap(Space.s3), enter(cards[i], i)],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            FooterCta(
              clean: true,
              child: unfinished != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Btn('Continue my test', block: true, onPressed: () => context.go('/cbt/${unfinished.id}')),
                        const Gap(Space.s2),
                        Btn('Go to Home', kind: BtnKind.ghost, onPressed: () => context.go('/home')),
                      ],
                    )
                  : Btn(todayDone ? 'Go to Home' : 'Start practising', block: true, onPressed: () => context.go('/home')),
            ),
          ],
        ),
      ),
    );
  }
}
