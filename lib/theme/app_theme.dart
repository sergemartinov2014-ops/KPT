import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Дизайн-система «Сомния» — Apple Liquid Glass (iOS 26 / HIG 2026)
/// Сочетает клиническую строгость CBT-i и физическую оптическую глубину Liquid Glass.
class AppTheme {
  // Apple Liquid Glass Canvas Palette
  static const Color background = Color(0xFF04060C); // Deep OLED Midnight Canvas
  static const Color surface = Color(0xFF0C101B); // Solid Surface Fallback
  static const Color surfaceElevated = Color(0xFF131929); // Elevated Bento Surface
  static const Color surfaceBorder = Color(0xFF1C2436); // Hairline Structural Border

  // Liquid Glass Meta-Material Translucent Layers
  static const Color glassSurface = Color(0x38101728); // 22% Translucent Midnight Glass
  static const Color glassSurfaceElevated = Color(0x5918233C); // 35% Translucent Elevated Glass
  static const Color glassUltraThin = Color(0x280D1424); // 16% Ultra-Thin Floating Glass
  static const Color glassHighlight = Color(0x38FFFFFF); // 22% Specular Reflection Edge
  static const Color glassBorder = Color(0x1AFFFFFF); // 10% Hairline Glass Border

  // Apple Semantic Colors (iOS 26 / HIG)
  static const Color systemIndigo = Color(0xFF6366F1); // Primary Focus & Anchor
  static const Color systemTeal = Color(0xFF38BDF8); // Calm Bio-Teal (Sleep Efficiency)
  static const Color systemPurple = Color(0xFFA855F7); // REM & Nighttime Awareness
  static const Color systemBlue = Color(0xFF3B82F6); // System Actions & Information
  static const Color systemAmber = Color(0xFFF59E0B); // Circadian Alert & Warning
  static const Color systemMint = Color(0xFF10B981); // Success (SE >= 85%)
  static const Color systemRose = Color(0xFFF43F5E); // Critical Floor / Error

  // Backward Compatible Aliases
  static const Color primary = systemIndigo;
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color accent = Color(0xFF8E9AFF); // Moonlight Lavender Mist
  static const Color success = Color(0xFF4FD1C5); // Calm Bio-Teal
  static const Color warning = systemAmber;
  static const Color error = Color(0xFFF87171);

  // Typography Tokens (WCAG 2.2 AA Contrast Guard)
  static const Color textPrimary = Color(0xFFF1F5F9); // Warm Apple Alabaster (Contrast > 17:1)
  static const Color textSecondary = Color(0xFF94A3B8); // Calm Slate (Contrast > 7.5:1)
  static const Color textMuted = Color(0xFF7E8B9B); // High-Legibility Silver (Contrast > 5.5:1, WCAG AA Compliant)

  /// Стиль для цифр, таймеров и индексов (San Francisco Tabular Figures)
  static TextStyle monoFigures({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textPrimary,
    double letterSpacing = -0.5,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: fontSize >= 28 ? -0.8 : (fontSize >= 20 ? -0.4 : letterSpacing),
      height: 1.15,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Заголовок секции по гайдлайнам Apple HIG (Sentence Case)
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
    color: textSecondary,
  );

  /// Декорация карточки в стиле Liquid Glass
  static BoxDecoration liquidGlassBox({
    double radius = 24,
    Color? surfaceColor,
    Gradient? borderGradient,
    Color? glowColor,
    double glowRadius = 0,
  }) {
    return BoxDecoration(
      color: surfaceColor ?? glassSurface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.18),
        width: 1.1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 18,
          offset: const Offset(0, 8),
          spreadRadius: -2,
        ),
        if (glowColor != null && glowRadius > 0)
          BoxShadow(
            color: glowColor.withValues(alpha: 0.25),
            blurRadius: glowRadius,
            spreadRadius: 1,
          ),
      ],
    );
  }

  /// Универсальная декорация Bento-карточки (обратная совместимость с Liquid Glass)
  static BoxDecoration bentoBox({
    Color? color,
    Color? borderColor,
    double radius = 22,
    Gradient? gradient,
  }) {
    return BoxDecoration(
      color: color,
      gradient: gradient ??
          (color == null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E293B).withValues(alpha: 0.35),
                    const Color(0xFF0F172A).withValues(alpha: 0.20),
                  ],
                )
              : null),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.18),
        width: 1.1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.30),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      fontFamilyFallback: const [
        '-apple-system',
        'BlinkMacSystemFont',
        'SF Pro Display',
        'SF Pro Text',
        'SF Pro',
        'Inter',
        'Segoe UI',
        'Roboto',
        'sans-serif',
      ],
      scaffoldBackgroundColor: background,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.dark(
        primary: systemIndigo,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: textPrimary,
        onSecondary: background,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: textSecondary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: glassSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: glassSurfaceElevated,
        thumbColor: textPrimary,
        overlayColor: accent.withValues(alpha: 0.16),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surfaceElevated,
        hourMinuteColor: glassSurfaceElevated,
        hourMinuteTextColor: textPrimary,
        dialBackgroundColor: glassSurfaceElevated,
        dialHandColor: systemIndigo,
        dialTextColor: textPrimary,
        entryModeIconColor: textSecondary,
        dayPeriodColor: glassSurfaceElevated,
        dayPeriodTextColor: textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: textPrimary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.25,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.15,
          height: 1.35,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.5,
          letterSpacing: -0.1,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
          height: 1.45,
          letterSpacing: -0.05,
        ),
        bodySmall: TextStyle(
          color: textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.4,
          letterSpacing: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: systemIndigo,
          foregroundColor: textPrimary,
          disabledBackgroundColor: glassSurfaceElevated,
          disabledForegroundColor: textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
