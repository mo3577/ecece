import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Deep teal + warm ink — admin tool look (not purple / cream AI defaults).
class EceTheme {
  static const Color ink = Color(0xFF0F1C1A);
  static const Color panel = Color(0xFF17302C);
  static const Color card = Color(0xFF1F3D38);
  static const Color accent = Color(0xFF2BBBAD);
  static const Color accentDim = Color(0xFF1A7A72);
  static const Color sand = Color(0xFFE7F0EE);
  static const Color danger = Color(0xFFD64545);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: ink,
        primary: accent,
        secondary: accentDim,
        error: danger,
        onPrimary: ink,
        onSurface: sand,
      ),
      scaffoldBackgroundColor: ink,
    );
    final text = GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme).apply(
      bodyColor: sand,
      displayColor: sand,
    );
    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: panel,
        foregroundColor: sand,
        elevation: 0,
        titleTextStyle: GoogleFonts.ibmPlexSansArabic(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: sand,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: panel,
        selectedIconTheme: IconThemeData(color: accent),
        unselectedIconTheme: IconThemeData(color: sand),
        indicatorColor: Color(0x332BBBAD),
      ),
    );
  }
}
