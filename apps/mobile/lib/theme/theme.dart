import 'package:flutter/material.dart';
import 'tokens.g.dart';

/// Material 3 theme built only from design tokens (design/tokens.json → tokens.g.dart).
/// One font family (Plus Jakarta Sans, bundled), two weights (500 regular, 700 bold).
const kFont = 'PlusJakartaSans';

/// Theme extension so widgets can read every semantic role: `context.c.textMuted`.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette(this.c);
  final AppColors c;
  @override
  AppPalette copyWith({AppColors? c}) => AppPalette(c ?? this.c);
  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) => t < .5 ? this : (other as AppPalette? ?? this);
}

extension AppThemeX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppPalette>()!.c;
  TextTheme get t => Theme.of(this).textTheme;
  bool get reduceMotion => MediaQuery.of(this).disableAnimations;
}

TextStyle _ts(({double size, double line, int weight, double tracking}) s, Color color) => TextStyle(
      fontFamily: kFont,
      fontSize: s.size,
      height: s.line / s.size,
      fontWeight: s.weight >= 700 ? FontWeight.w700 : FontWeight.w500,
      letterSpacing: s.tracking,
      color: color,
    );

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.primarySoft,
    onPrimaryContainer: c.onPrimarySoft,
    secondary: c.secondary,
    onSecondary: c.onSecondary,
    secondaryContainer: c.secondarySoft,
    onSecondaryContainer: c.onSecondarySoft,
    tertiary: c.accent,
    onTertiary: c.onAccent,
    tertiaryContainer: c.accentSoft,
    onTertiaryContainer: c.onAccentSoft,
    error: c.error,
    onError: Colors.white,
    errorContainer: c.errorSoft,
    onErrorContainer: c.onErrorSoft,
    surface: c.surface,
    onSurface: c.text,
    onSurfaceVariant: c.textMuted,
    surfaceContainerLowest: c.surface,
    surfaceContainerLow: c.surfaceAlt,
    surfaceContainer: c.bg,
    surfaceContainerHigh: c.surfaceSunken,
    outline: c.borderStrong,
    outlineVariant: c.border,
    scrim: c.scrim,
  );
  final text = TextTheme(
    displaySmall: _ts(TypeScale.display, c.text),
    headlineMedium: _ts(TypeScale.h1, c.text),
    headlineSmall: _ts(TypeScale.h2, c.text),
    titleMedium: _ts(TypeScale.h3, c.text),
    bodyLarge: _ts(TypeScale.bodyLg, c.text),
    bodyMedium: _ts(TypeScale.body, c.text),
    bodySmall: _ts(TypeScale.bodySm, c.textMuted),
    labelLarge: _ts(TypeScale.label, c.text),
    labelSmall: _ts(TypeScale.caption, c.textMuted),
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    fontFamily: kFont,
    textTheme: text,
    extensions: [AppPalette(c)],
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _ts(TypeScale.h3, c.text),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: c.border)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(Sizes.buttonHeight),
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        textStyle: _ts(TypeScale.label, c.onPrimary).copyWith(fontSize: 15),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(Sizes.buttonHeight),
        foregroundColor: c.text,
        side: BorderSide(color: c.borderStrong, width: 1.5),
        textStyle: _ts(TypeScale.label, c.text).copyWith(fontSize: 15),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(Sizes.tapMin, Sizes.tapMin),
        foregroundColor: c.link,
        textStyle: _ts(TypeScale.label, c.link),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: c.borderStrong, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: c.borderStrong, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: c.secondary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: c.error, width: 1.5)),
      hintStyle: _ts(TypeScale.body, c.textSubtle),
      labelStyle: _ts(TypeScale.label, c.textMuted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: Sizes.bottomNav,
      backgroundColor: c.surface,
      indicatorColor: c.accentSoft,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => _ts(TypeScale.caption, s.contains(WidgetState.selected) ? c.text : c.textSubtle).copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    ),
    dialogTheme: DialogThemeData(backgroundColor: c.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl))),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.primary,
      contentTextStyle: _ts(TypeScale.bodySm, c.onPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    }),
  );
}
