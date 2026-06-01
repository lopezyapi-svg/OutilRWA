// Ce fichier centralise le theme visuel de l'application.
import 'package:flutter/material.dart';

/// Définit les couleurs, espacements et thèmes partagés de l'interface.
class AppTheme {
  static const String fontFamily = 'General Sans';
  static const String dataFontFamily = fontFamily;
  static const String titleFontFamily = fontFamily;
  static const double radius = 5;
  static const double spacing = 10;
  static const double pagePadding = 2;
  static const double pageGap = 2;
  static const Color sidebar = Color(0xFF172B4D);
  static const Color sidebarLight = Color(0xFF23477A);
  static const Color accent = Color(0xFF2563EB);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color background = Color(0xFFF0F1F6);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E7F2);
  static const Color text = Color(0xFF13203A);
  static const Color muted = Color(0xFF64748B);
  static const Color darkBackground = Color(0xFF081028);
  static const Color darkCard = Color(0xFF111827);
  static const Color darkBorder = Color(0xFF1F2937);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkMuted = Color(0xFF94A3B8);

  static ThemeData buildTheme() => _buildTheme(
        brightness: Brightness.light,
        scaffoldBackground: background,
        surfaceColor: card,
        borderColor: border,
        textColor: text,
        mutedColor: muted,
        inputFillColor: const Color(0xFFFBFCFF),
      );

  static ThemeData buildDarkTheme() => _buildTheme(
        brightness: Brightness.dark,
        scaffoldBackground: darkBackground,
        surfaceColor: darkCard,
        borderColor: darkBorder,
        textColor: darkText,
        mutedColor: darkMuted,
        inputFillColor: const Color(0xFF111827),
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffoldBackground,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color mutedColor,
    required Color inputFillColor,
  }) {
    final baseTextTheme = ThemeData(
      brightness: brightness,
      fontFamily: fontFamily,
    ).textTheme.apply(
          bodyColor: textColor,
          displayColor: textColor,
        );
    final textTheme = _buildTextTheme(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: accent,
        primary: accent,
        surface: surfaceColor,
        onSurface: textColor,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(radius)),
          side: BorderSide(color: borderColor),
        ),
      ),
      appBarTheme: AppBarTheme(
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
        toolbarTextStyle: textTheme.titleMedium,
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: textTheme.labelMedium?.copyWith(
          color: textColor,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: textTheme.bodyMedium?.copyWith(
          color: textColor,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: textTheme.labelLarge?.copyWith(color: textColor),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: mutedColor),
      ),
      popupMenuTheme: PopupMenuThemeData(
        textStyle: textTheme.labelMedium?.copyWith(color: textColor),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: mutedColor,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: mutedColor,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: accent, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: danger, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: danger),
        ),
      ),
      scrollbarTheme: const ScrollbarThemeData(
        radius: Radius.circular(999),
        minThumbLength: 36.0,
        thumbColor: WidgetStatePropertyAll<Color?>(Color(0xCC234A84)),
        trackColor: WidgetStatePropertyAll<Color?>(Colors.transparent),
        trackBorderColor: WidgetStatePropertyAll<Color?>(Colors.transparent),
        thickness: WidgetStatePropertyAll<double?>(3.0),
        crossAxisMargin: 2.0,
        mainAxisMargin: 6.0,
      ),
      dividerColor: borderColor,
      iconTheme: IconThemeData(color: textColor),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: _font(base.displayLarge, fontFamily),
      displayMedium: _font(base.displayMedium, fontFamily),
      displaySmall: _font(base.displaySmall, fontFamily),
      headlineLarge: _font(base.headlineLarge, fontFamily),
      headlineMedium: _font(base.headlineMedium, fontFamily),
      headlineSmall: _font(base.headlineSmall, fontFamily),
      titleLarge: _font(base.titleLarge, fontFamily),
      titleMedium: _font(base.titleMedium, fontFamily),
      titleSmall: _font(base.titleSmall, fontFamily),
      labelLarge: _font(base.labelLarge, fontFamily),
      labelMedium: _font(base.labelMedium, fontFamily),
      labelSmall: _font(base.labelSmall, fontFamily),
      bodyLarge: _font(base.bodyLarge, fontFamily),
      bodyMedium: _font(base.bodyMedium, fontFamily),
      bodySmall: _font(base.bodySmall, fontFamily),
    );
  }

  static TextStyle? _font(TextStyle? style, String fontFamily) {
    return style?.copyWith(fontFamily: fontFamily);
  }
}
