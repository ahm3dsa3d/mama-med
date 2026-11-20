import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/medication.dart';

class PeriodStyle {
  final Color accentColor;
  final Color backgroundColor;
  final Color cardColor;
  final Color textColor;

  const PeriodStyle({
    required this.accentColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.textColor,
  });
}

/// Offline-first GoogleFonts drop-in replacement that never makes HTTP calls
/// and avoids debugger pauses/crashes when offline.
class GoogleFonts {
  GoogleFonts._();

  static TextStyle cairo({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) {
    final style = TextStyle(
      fontFamily: 'Cairo',
      fontFamilyFallback: const ['sans-serif', 'Arial'],
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
    );
    return textStyle != null ? textStyle.merge(style) : style;
  }

  static TextTheme cairoTextTheme([TextTheme? base]) {
    final t = base ?? const TextTheme();
    return t.copyWith(
      displayLarge: cairo(textStyle: t.displayLarge),
      displayMedium: cairo(textStyle: t.displayMedium),
      displaySmall: cairo(textStyle: t.displaySmall),
      headlineLarge: cairo(textStyle: t.headlineLarge),
      headlineMedium: cairo(textStyle: t.headlineMedium),
      headlineSmall: cairo(textStyle: t.headlineSmall),
      titleLarge: cairo(textStyle: t.titleLarge),
      titleMedium: cairo(textStyle: t.titleMedium),
      titleSmall: cairo(textStyle: t.titleSmall),
      bodyLarge: cairo(textStyle: t.bodyLarge),
      bodyMedium: cairo(textStyle: t.bodyMedium),
      bodySmall: cairo(textStyle: t.bodySmall),
      labelLarge: cairo(textStyle: t.labelLarge),
      labelMedium: cairo(textStyle: t.labelMedium),
      labelSmall: cairo(textStyle: t.labelSmall),
    );
  }
}

class AppTheme {
  AppTheme._();

  // ─── Period Color Palette ─────────────────────────────────────────────────
  static const Map<String, PeriodStyle> periodStyles = {
    'morning': PeriodStyle(
      accentColor: Color(0xFFE65100),       // Deep Amber
      backgroundColor: Color(0xFFFFF3E0),   // Warm Cream
      cardColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF4E2000),
    ),
    'afternoon': PeriodStyle(
      accentColor: Color(0xFF0277BD),        // Azure Blue
      backgroundColor: Color(0xFFE1F5FE),   // Ice Blue
      cardColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF01345A),
    ),
    'evening': PeriodStyle(
      accentColor: Color(0xFF4A148C),        // Deep Indigo
      backgroundColor: Color(0xFFEDE7F6),   // Lavender
      cardColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF1A0050),
    ),
    'before_bed': PeriodStyle(
      accentColor: Color(0xFF004D40),        // Night Teal
      backgroundColor: Color(0xFFE0F2F1),   // Mint Cream
      cardColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF001A17),
    ),
  };

  static PeriodStyle styleFor(String period) =>
      periodStyles[period] ??
      const PeriodStyle(
        accentColor: Color(0xFF37474F),
        backgroundColor: Color(0xFFECEFF1),
        cardColor: Color(0xFFFFFFFF),
        textColor: Color(0xFF1C1C1C),
      );

  static PeriodStyle styleForPeriod(MedicationPeriod period) =>
      styleFor(period.key);

  /// Formats a TimeOfDay in 12-hour AM/PM format (e.g. "8:00 ص (AM)", "2:00 م (PM)")
  static String formatTime12H(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'ص (AM)' : 'م (PM)';
    return '$hour:$minute $period';
  }

  // ─── App Colors ───────────────────────────────────────────────────────────
  static const Color scaffoldBg = Color(0xFFF5F5F5);
  static const Color headerBg = Color(0xFF1A237E);       // Deep Navy
  static const Color headerText = Color(0xFFFFFFFF);
  static const Color progressBg = Color(0xFF283593);
  static const Color takenColor = Color(0xFF2E7D32);      // Forest Green
  static const Color uncheckColor = Color(0xFF9E9E9E);

  // ─── Text Styles ──────────────────────────────────────────────────────────
  static TextStyle get appTitleStyle => GoogleFonts.cairo(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: headerText,
    letterSpacing: 0.5,
  );

  static TextStyle get periodHeaderStyle => GoogleFonts.cairo(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static TextStyle get medNameStyle => GoogleFonts.cairo(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static TextStyle get doseStyle => GoogleFonts.cairo(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static TextStyle get bodyStyle => GoogleFonts.cairo(
    fontSize: 20,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get subtitleStyle => GoogleFonts.cairo(
    fontSize: 18,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get labelStyle => GoogleFonts.cairo(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get bigNumberStyle => GoogleFonts.cairo(
    fontSize: 48,
    fontWeight: FontWeight.w800,
  );

  // ─── Theme Data ───────────────────────────────────────────────────────────
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A237E),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        bodyLarge: GoogleFonts.cairo(fontSize: 20),
        bodyMedium: GoogleFonts.cairo(fontSize: 18),
        titleLarge: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.w600),
        labelLarge: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: headerBg,
        foregroundColor: headerText,
        elevation: 0,
        titleTextStyle: appTitleStyle,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      ),
      dividerTheme: const DividerThemeData(
        thickness: 1,
        color: Color(0xFFE0E0E0),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return takenColor;
          return const Color(0xFF9E9E9E);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return const Color(0xFFA5D6A7);
          return const Color(0xFFE0E0E0);
        }),
      ),
    );
  }
}
