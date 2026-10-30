import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/phosphor.g.dart';
import '../auth/auth_screens.dart';
import '../home/home_screen.dart';
import 'onboarding_art.dart';
import '../../ui/confetti.dart';
import '../../ui/subject_icons.dart';

/// Logged out: Welcome every time (prototype: splash → welcome), or back to the email code if the app was
/// closed while the student was fetching it.
Future<String> nextRoute(WidgetRef ref) async {
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
              child: ClipRect(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const ArtDisc(size: 300),
                    Transform.translate(
                      offset: const Offset(90, -90),
                      child: const ArtDisc(size: 180, tone: Tone.gold, breathe: false),
                    ),
                    rm
                        ? const AppIconArt()
                        : const Float(child: AppIconArt())
                              .animate()
                              .scale(begin: const Offset(.85, .85), duration: Motion.slow, curve: Motion.emphasized)
                              .fadeIn(),
                  ],
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
      'title': 'Win cash prizes every week',
      'body': 'Answer our weekly challenge fast and right to win money. Free and Premium students can join, and play is fair for everyone.',
      'animation': 'trophy',
    },
    {'title': 'SolutionTee AI tutor', 'body': 'Stuck on a question? Ask our AI tutor. It explains step by step, like a patient teacher.', 'animation': 'ai'},
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

// ---------------------------------------------------------------- welcome back (prototype: welcome-back)
/// After log in: greeting with a waving hand, this week's practice days, "Continue my test" when one is unfinished.
class WelcomeBackScreen extends ConsumerWidget {
  const WelcomeBackScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final week = ref.watch(practiceWeekProvider).value ?? const <int>{};
    final today = DateTime.now().weekday - 1; // Monday = 0
    final streak = ref.watch(practiceStreakProvider).value ?? 0;
    final rm = context.reduceMotion;
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final cards = <Widget>[
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
                  child: Icon(PhosphorIcons.fire(PhosphorIconsStyle.fill), size: 24, color: Palette.gold500),
                ),
                const Gap(Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(streak > 0 ? '$streak-day streak' : 'Start your streak', style: context.ty.body.bold),
                      Text(
                        week.contains(today)
                            ? 'You practised today. Well done!'
                            : 'Answer one question today to ${streak > 0 ? 'make it ${streak + 1}' : 'start it'}.',
                        style: context.ty.sm.col(c.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(Space.s3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var k = 0; k < 7; k++)
                  Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: week.contains(k) ? c.accent : c.surfaceSunken,
                          shape: BoxShape.circle,
                          border: k == today && !week.contains(k) ? Border.all(color: c.accent, width: 2) : null,
                        ),
                        child: week.contains(k) ? Icon(PhosphorIcons.check(PhosphorIconsStyle.fill), size: 14, color: c.onAccent) : null,
                      ),
                      const SizedBox(height: 4),
                      Text(days[k], style: context.ty.cap.bold.copyWith(fontSize: 11).col(k == today ? c.text : c.textSubtle)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
      if (unfinished != null) ContinueCard(a: unfinished),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.s6, Space.s7, Space.s6, Space.s5),
                    child: Column(
                      children: [
                        _pop(
                          rm,
                          SizedBox(
                            width: 124,
                            height: 116,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Avatar(name, size: 112),
                                Positioned(
                                  right: -10,
                                  bottom: -4,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, boxShadow: context.shadow(2)),
                                    child: Icon(PhosphorIcons.handWaving(PhosphorIconsStyle.fill), size: 26, color: Palette.gold500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          0,
                        ),
                        const Gap(Space.s3),
                        Text('$hello,', style: context.ty.lg.col(c.textMuted)),
                        const Gap(Space.s3),
                        Text(first.isEmpty ? 'Welcome back' : 'Welcome back, $first', style: context.ty.display, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s5),
                    child: Column(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const Gap(Space.s4),
                          rm ? cards[i] : cards[i].animate(delay: Motion.stagger * i).fadeIn(duration: Motion.slow).slideY(begin: .1, curve: Motion.out),
                        ],
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
                  : Btn('Start practising', block: true, onPressed: () => context.go('/home')),
            ),
          ],
        ),
      ),
    );
  }
}
