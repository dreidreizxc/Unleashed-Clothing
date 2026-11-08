import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Unleashed Clothing brand tokens.
///
/// The visual language is editorial streetwear: near-black ink, warm off-white
/// paper, oversized display type, sharp edges and a single burnt-orange accent
/// reserved for decisive actions and live status.
class AppColors {
  AppColors._();

  /// Primary brand black.
  static const Color ink = Color(0xFF0A0303);

  /// Warm off-white page background.
  static const Color paper = Color(0xFFEBEBEB);

  /// Card / sheet surface.
  static const Color surface = Color(0xFFFFFFFF);

  /// Slightly warmer surface used for inset panels.
  static const Color surfaceAlt = Color(0xFFF4F2EF);

  /// Warm gray from the brand palette (decorative / large labels only).
  static const Color warmGray = Color(0xFF9B9995);

  /// Dark gray panel.
  static const Color charcoal = Color(0xFF242424);

  /// High-contrast muted text (accessible on paper and white).
  static const Color muted = Color(0xFF5D5A55);

  /// Hairline border.
  static const Color line = Color(0xFFD7D3CD);

  /// Very light fill.
  static const Color subtle = Color(0xFFF0EEEA);

  /// Burnt-orange accent. Use sparingly.
  static const Color accent = Color(0xFFE32301);

  static const Color success = Color(0xFF1D6B40);
  static const Color danger = Color(0xFFB3261E);
  static const Color warning = Color(0xFF8A5A00);
}

/// Shared motion timings so every interaction feels related.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve curve = Curves.easeOutCubic;
}

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.light(
    primary: AppColors.ink,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.danger,
    onError: Colors.white,
    outline: AppColors.line,
  );

  const baseTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 54,
      fontWeight: FontWeight.w900,
      letterSpacing: -2.6,
      height: 0.92,
      color: AppColors.ink,
    ),
    displayMedium: TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.9,
      height: 0.94,
      color: AppColors.ink,
    ),
    displaySmall: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.2,
      height: 0.98,
      color: AppColors.ink,
    ),
    headlineLarge: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.9,
      height: 1.02,
      color: AppColors.ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.1,
      color: AppColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: AppColors.ink),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: AppColors.ink),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.5,
      color: AppColors.muted,
    ),
    labelLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
    ),
    labelMedium: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.4,
      color: AppColors.ink,
    ),
    labelSmall: TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.8,
      color: AppColors.muted,
    ),
  );

  final sharpShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(0),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.paper,
    textTheme: baseTextTheme,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      titleTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.6,
        color: AppColors.ink,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.line,
        disabledForegroundColor: AppColors.muted,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shape: sharpShape,
        textStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.white.withValues(alpha: 0.12);
          }
          return null;
        }),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.ink, width: 1),
        shape: sharpShape,
        textStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      hintStyle: const TextStyle(color: AppColors.warmGray, fontSize: 13.5),
      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      floatingLabelStyle: const TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 11,
        letterSpacing: 1.1,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(0),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(0),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(0),
        borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(0),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(0),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      errorMaxLines: 3,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.ink,
      disabledColor: AppColors.subtle,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppColors.ink,
      ),
      secondaryLabelStyle: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: Colors.white,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
        color: AppColors.ink,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 13.5,
        height: 1.5,
        color: AppColors.muted,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.ink,
      unselectedItemColor: AppColors.warmGray,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.ink,
      linearTrackColor: AppColors.subtle,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.ink;
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: const BorderSide(color: AppColors.warmGray, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return AppColors.warmGray;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.ink;
        return AppColors.line;
      }),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
