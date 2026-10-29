// GENERATED from design/tokens.json by design/scripts/tokens-to-dart.mjs. Do not edit by hand.
// ignore_for_file: constant_identifier_names
import 'package:flutter/material.dart';

/// Raw tonal palettes (navy, blue, gold, neutral, green, amber, red).
abstract final class Palette {
  static const navy50 = Color(0xFFEEF2F9);
  static const navy100 = Color(0xFFD9E1EF);
  static const navy200 = Color(0xFFB4C3DD);
  static const navy300 = Color(0xFF8A9FC6);
  static const navy400 = Color(0xFF5F7AAA);
  static const navy500 = Color(0xFF3E5A8C);
  static const navy600 = Color(0xFF2A4573);
  static const navy700 = Color(0xFF1B335E);
  static const navy800 = Color(0xFF13284F);
  static const navy900 = Color(0xFF0B1F44);
  static const navy950 = Color(0xFF06132B);
  static const blue50 = Color(0xFFE7EEF7);
  static const blue100 = Color(0xFFCEDCEE);
  static const blue200 = Color(0xFFB4CAE5);
  static const blue300 = Color(0xFF98B6DB);
  static const blue400 = Color(0xFF7AA0D1);
  static const blue500 = Color(0xFF5887C5);
  static const blue600 = Color(0xFF2563B3);
  static const blue700 = Color(0xFF1F559B);
  static const blue800 = Color(0xFF194783);
  static const blue900 = Color(0xFF13386B);
  static const blue950 = Color(0xFF0D2A53);
  static const gold50 = Color(0xFFFDF3E0);
  static const gold100 = Color(0xFFFBE6BE);
  static const gold200 = Color(0xFFF9D99A);
  static const gold300 = Color(0xFFF6C970);
  static const gold400 = Color(0xFFF2B233);
  static const gold500 = Color(0xFFD99A1E);
  static const gold600 = Color(0xFFB57D12);
  static const gold700 = Color(0xFF8C600F);
  static const gold800 = Color(0xFF66450C);
  static const gold900 = Color(0xFF463008);
  static const gold950 = Color(0xFF2A1C04);
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral25 = Color(0xFFFAFBFD);
  static const neutral50 = Color(0xFFF4F6FA);
  static const neutral100 = Color(0xFFEAEEF4);
  static const neutral200 = Color(0xFFDCE2EB);
  static const neutral300 = Color(0xFFC3CBD8);
  static const neutral400 = Color(0xFF98A3B5);
  static const neutral500 = Color(0xFF6B778C);
  static const neutral600 = Color(0xFF4F5B70);
  static const neutral700 = Color(0xFF384458);
  static const neutral800 = Color(0xFF232E40);
  static const neutral900 = Color(0xFF141D2C);
  static const neutral950 = Color(0xFF0A111D);
  static const green50 = Color(0xFFECFAF2);
  static const green100 = Color(0xFFD2F3E0);
  static const green300 = Color(0xFF7FD8A6);
  static const green500 = Color(0xFF1FA463);
  static const green600 = Color(0xFF14874F);
  static const green700 = Color(0xFF0F6B3F);
  static const green900 = Color(0xFF073821);
  static const amber50 = Color(0xFFFFF5E8);
  static const amber100 = Color(0xFFFFE7C7);
  static const amber300 = Color(0xFFFDB868);
  static const amber500 = Color(0xFFE07B0E);
  static const amber600 = Color(0xFFB8620A);
  static const amber700 = Color(0xFF8F4B08);
  static const amber900 = Color(0xFF4A2603);
  static const red50 = Color(0xFFFDEEEE);
  static const red100 = Color(0xFFFAD7D7);
  static const red300 = Color(0xFFF09A9A);
  static const red500 = Color(0xFFD93A3A);
  static const red600 = Color(0xFFB82828);
  static const red700 = Color(0xFF921F1F);
  static const red900 = Color(0xFF4D1010);
}

/// Semantic colour roles for one theme (light or dark).
class AppColors {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.textInverse,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.secondary,
    required this.onSecondary,
    required this.secondarySoft,
    required this.onSecondarySoft,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.link,
    required this.focus,
    required this.success,
    required this.successSoft,
    required this.onSuccessSoft,
    required this.warning,
    required this.warningSoft,
    required this.onWarningSoft,
    required this.error,
    required this.errorSoft,
    required this.onErrorSoft,
    required this.scrim,
    required this.answered,
    required this.unanswered,
    required this.flagged,
    required this.current,
    required this.frame,
    required this.canvas,
  });
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceSunken;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color textInverse;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color onPrimarySoft;
  final Color secondary;
  final Color onSecondary;
  final Color secondarySoft;
  final Color onSecondarySoft;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color onAccentSoft;
  final Color link;
  final Color focus;
  final Color success;
  final Color successSoft;
  final Color onSuccessSoft;
  final Color warning;
  final Color warningSoft;
  final Color onWarningSoft;
  final Color error;
  final Color errorSoft;
  final Color onErrorSoft;
  final Color scrim;
  final Color answered;
  final Color unanswered;
  final Color flagged;
  final Color current;
  final Color frame;
  final Color canvas;

  static const light = AppColors(
    bg: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFAFBFD),
    surfaceSunken: Color(0xFFEAEEF4),
    border: Color(0xFFDCE2EB),
    borderStrong: Color(0xFFC3CBD8),
    text: Color(0xFF06132B),
    textMuted: Color(0xFF4F5B70),
    textSubtle: Color(0xFF6B778C),
    textInverse: Color(0xFFFFFFFF),
    primary: Color(0xFF0B1F44),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFEEF2F9),
    onPrimarySoft: Color(0xFF0B1F44),
    secondary: Color(0xFF2563B3),
    onSecondary: Color(0xFFFFFFFF),
    secondarySoft: Color(0xFFE7EEF7),
    onSecondarySoft: Color(0xFF194783),
    accent: Color(0xFFF2B233),
    onAccent: Color(0xFF0B1F44),
    accentSoft: Color(0xFFFDF3E0),
    onAccentSoft: Color(0xFF66450C),
    link: Color(0xFF1F559B),
    focus: Color(0xFF5887C5),
    success: Color(0xFF14874F),
    successSoft: Color(0xFFECFAF2),
    onSuccessSoft: Color(0xFF0F6B3F),
    warning: Color(0xFF8F4B08),
    warningSoft: Color(0xFFFFF5E8),
    onWarningSoft: Color(0xFF8F4B08),
    error: Color(0xFFB82828),
    errorSoft: Color(0xFFFDEEEE),
    onErrorSoft: Color(0xFF921F1F),
    scrim: Color.fromRGBO(6, 19, 43, 0.48),
    answered: Color(0xFF14874F),
    unanswered: Color(0xFFDCE2EB),
    flagged: Color(0xFFE07B0E),
    current: Color(0xFF2563B3),
    frame: Color(0xFF0A111D),
    canvas: Color(0xFFE3E8F0),
  );
  static const dark = AppColors(
    bg: Color(0xFF060E1D),
    surface: Color(0xFF0D1A30),
    surfaceAlt: Color(0xFF11203A),
    surfaceSunken: Color(0xFF091427),
    border: Color(0xFF1C2D4A),
    borderStrong: Color(0xFF2A3F62),
    text: Color(0xFFEAF0FA),
    textMuted: Color(0xFFA7B4CA),
    textSubtle: Color(0xFF8090AA),
    textInverse: Color(0xFF06132B),
    primary: Color(0xFFDDE6F5),
    onPrimary: Color(0xFF06132B),
    primarySoft: Color(0xFF16284A),
    onPrimarySoft: Color(0xFFDDE6F5),
    secondary: Color(0xFF7AA0D1),
    onSecondary: Color(0xFF06132B),
    secondarySoft: Color(0xFF10284D),
    onSecondarySoft: Color(0xFFB4CAE5),
    accent: Color(0xFFF2B233),
    onAccent: Color(0xFF0B1F44),
    accentSoft: Color(0xFF2B2210),
    onAccentSoft: Color(0xFFF9D99A),
    link: Color(0xFF98B6DB),
    focus: Color(0xFF98B6DB),
    success: Color(0xFF7FD8A6),
    successSoft: Color(0xFF0C2A1D),
    onSuccessSoft: Color(0xFF7FD8A6),
    warning: Color(0xFFFDB868),
    warningSoft: Color(0xFF2E1D08),
    onWarningSoft: Color(0xFFFDB868),
    error: Color(0xFFF09A9A),
    errorSoft: Color(0xFF33121A),
    onErrorSoft: Color(0xFFF09A9A),
    scrim: Color.fromRGBO(2, 6, 14, 0.66),
    answered: Color(0xFF1FA463),
    unanswered: Color(0xFF22365A),
    flagged: Color(0xFFE07B0E),
    current: Color(0xFF7AA0D1),
    frame: Color(0xFF000510),
    canvas: Color(0xFF03070F),
  );
}

/// 8-pt spacing scale.
abstract final class Space {
  static const double s0 = 0;
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s7 = 32;
  static const double s8 = 40;
  static const double s9 = 48;
  static const double s10 = 56;
  static const double s11 = 64;
  static const double s12 = 80;
}

/// Corner radii (cards use lg = 16).
abstract final class Radii {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double sheet = 28;
  static const double pill = 999;
}

/// Component sizes (tap targets are at least 48).
abstract final class Sizes {
  static const double tapMin = 48;
  static const double buttonHeight = 52;
  static const double inputHeight = 52;
  static const double appBar = 56;
  static const double bottomNav = 68;
  static const double iconSm = 18;
  static const double icon = 22;
  static const double iconLg = 28;
  static const double phoneWidth = 390;
  static const double phoneHeight = 844;
}

/// Type scale: size, line height, weight, letter spacing.
abstract final class TypeScale {
  static const display = (size: 32.0, line: 38.0, weight: 700, tracking: -0.6);
  static const h1 = (size: 26.0, line: 32.0, weight: 700, tracking: -0.4);
  static const h2 = (size: 21.0, line: 28.0, weight: 700, tracking: -0.2);
  static const h3 = (size: 17.0, line: 24.0, weight: 700, tracking: -0.1);
  static const bodyLg = (size: 17.0, line: 26.0, weight: 500, tracking: 0.0);
  static const body = (size: 15.0, line: 22.0, weight: 500, tracking: 0.0);
  static const bodySm = (size: 13.0, line: 18.0, weight: 500, tracking: 0.0);
  static const label = (size: 14.0, line: 20.0, weight: 700, tracking: 0.1);
  static const caption = (size: 12.0, line: 16.0, weight: 500, tracking: 0.2);
  static const overline = (size: 11.0, line: 14.0, weight: 700, tracking: 0.8);
  static const question = (size: 17.0, line: 27.0, weight: 500, tracking: 0.0);
  static const timer = (size: 18.0, line: 22.0, weight: 700, tracking: 0.4);
}

/// Motion: durations (ms) and easing curves. Respect reduce-motion (MediaQuery.disableAnimations).
abstract final class Motion {
  static const instant = Duration(milliseconds: 100);
  static const fast = Duration(milliseconds: 200);
  static const base = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 400);
  static const celebrate = Duration(milliseconds: 1200);
  static const standard = Cubic(0.2, 0, 0, 1);
  static const out = Cubic(0.16, 1, 0.3, 1);
  static const easeIn = Cubic(0.4, 0, 1, 1);
  static const emphasized = Cubic(0.3, 0, 0, 1.15);
  static const stagger = Duration(milliseconds: 50);
  static const pressScale = 0.97;
}
