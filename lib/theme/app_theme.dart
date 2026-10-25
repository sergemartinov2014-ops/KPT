import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Obsidian Sanctuary Palette (Nocturnal Minimalism)
  static const Color background = Color(0xFF06080F); // Deep OLED Obsidian
  static const Color surface = Color(0xFF0C101B); // Matte Midnight Slate
  static const Color surfaceElevated = Color(0xFF131929); // Elevated Bento Surface
  static const Color surfaceBorder = Color(0xFF1C2436); // 1px Hairline Border

  static const Color primary = Color(0xFF6366F1); // Deep Serene Indigo
  static const Color primaryLight = Color(0xFF818CF8); // Soft Periwinkle
  static const Color accent = Color(0xFF8E9AFF); // Moonlight Lavender Mist
  static const Color success = Color(0xFF4FD1C5); // Calm Bio-Teal (SE >= 85%)
  static const Color warning = Color(0xFFEAB308); // Warm Muted Amber
  static const Color error = Color(0xFFF87171); // Soft Terracotta Rose

  static const Color textPrimary = Color(0xFFEDF2F7); // Warm Alabaster (No pure white glare)
  static const Color textSecondary = Color(0xFF8A99AD); // Calm Slate Grey
  static const Color textMuted = Color(0xFF4A5668); // Deep Muted Graphite

  /// Стиль для цифр, времени и клинических индексов (моноширинные глифы)
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
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Строгий микро-заголовок секции (стиль Oura / Linear)
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.3,
    color: textMuted,
  );

  /// Универсальная декорация Bento-карточки
  static BoxDecoration bentoBox({
    Color? color,
    Color? borderColor,
    double radius = 20,
    Gradient? gradient,
  }) {
    return BoxDecoration(
      color: gradient == null ? (color ?? surface) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? surfaceBorder,
        width: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: textPrimary,
        onSecondary: background,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
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
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textSecondary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: surfaceBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: surfaceBorder,
        thickness: 1,
        space: 1,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: surfaceElevated,
        thumbColor: textPrimary,
        overlayColor: accent.withValues(alpha: 0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        hourMinuteColor: surfaceElevated,
        hourMinuteTextColor: textPrimary,
        dialBackgroundColor: surfaceElevated,
        dialHandColor: primary,
        dialTextColor: textPrimary,
        entryModeIconColor: textSecondary,
        dayPeriodColor: surfaceElevated,
        dayPeriodTextColor: textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: surfaceBorder),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: textPrimary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6),
        headlineMedium: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.4),
        titleLarge: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        titleMedium: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.1),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 15, height: 1.5),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13, height: 1.45),
        bodySmall: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textPrimary,
          disabledBackgroundColor: surfaceElevated,
          disabledForegroundColor: textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: surfaceBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: surfaceBorder),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
