import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ads.dart';
import 'core/app_gate.dart';
import 'core/providers.dart';
import 'core/secure_screen.dart';
import 'core/updater.dart';
import 'core/platform.dart';
import 'desktop/desktop_frame.dart';
import 'features/tutor/tutor_banner.dart';
import 'router.dart';
import 'theme/theme.dart';

class SolutionTeeApp extends ConsumerWidget {
  const SolutionTeeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    StickyPlace.attach(router); // where the sticky banner goes (above the tab bar or at the bottom)
    // Screenshots / screen recording follow the admin's switches (D-080) whenever the settings load (same values = no-op).
    final all = ref.watch(appSettingsProvider).value;
    final cp = all?['cash_prizes'], lg = all?['exam_logos'];
    cashPrizesOn = cp is Map && cp['on'] == true;
    examLogosOn = lg is Map && lg['on'] == true;
    adsConsent = ref.watch(profileProvider).value?['ads_consent'] == true;
    final p = all?['screen_protection'];
    SecureScreen.policy(wholeApp: p is Map && p['whole_app'] == true, exams: !(p is Map && p['exams'] == false));
    return MaterialApp.router(
      title: 'SolutionTee CBT',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.theme,
      routerConfig: router,
      scrollBehavior: isDesktop ? const DesktopScrollBehavior() : null,
      // In-app "reduce motion" switch adds to the phone's own setting.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(disableAnimations: mq.disableAnimations || settings.reduceMotion, textScaler: appTextScaler(mq)),
          child: UpdateGate(
            child: AppGate(
              child: StickyAds(
                child: TutorLiveBanner(
                  child: DesktopFrame(router: router, child: child!),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Text size that suits the phone (owner, 12 Nov 2026): the phone's own font size is followed but kept between 90% and
/// 115% (very large settings broke the layout on some phones), and narrow screens (under 360 dp) scale down a little.
TextScaler appTextScaler(MediaQueryData mq, {bool? desktop}) {
  final system = (mq.textScaler.scale(14) / 14).clamp(.9, 1.15);
  final w = mq.size.width, h = mq.size.height;
  if (desktop ?? isDesktop) return TextScaler.linear((system * desktopTextFactor(w, h)).clamp(.85, 1.3));
  final narrow = w > 0 && w < 360 ? (w / 360).clamp(.86, 1.0) : 1.0;
  return TextScaler.linear((system * narrow).clamp(.82, 1.15));
}

/// Windows (owner, 16 Nov 2026: "make the font change based on the screen of the laptop"): text follows the window,
/// measured in Windows' own scaled pixels, so a 1366 x 768 laptop gets slightly smaller text that fits, a common
/// 1536 x 864 or 1440 x 900 screen the normal size, and a big 1920 x 1080 or larger screen bigger, easier text.
/// The window's shorter side counts most, so a half-height window does not get huge text.
double desktopTextFactor(double w, double h) {
  if (w <= 0 || h <= 0) return 1;
  final f = (w / 1440 + h / 900) / 2;
  return (f < (h / 900) + .12 ? f : (h / 900) + .12).clamp(.92, 1.12);
}
