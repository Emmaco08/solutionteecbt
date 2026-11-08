import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ads.dart';
import 'core/providers.dart';
import 'core/secure_screen.dart';
import 'core/updater.dart';
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
      // In-app "reduce motion" switch adds to the phone's own setting.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(disableAnimations: mq.disableAnimations || settings.reduceMotion, textScaler: mq.textScaler.clamp(maxScaleFactor: 1.4)),
          child: UpdateGate(child: StickyAds(child: child!)),
        );
      },
    );
  }
}
