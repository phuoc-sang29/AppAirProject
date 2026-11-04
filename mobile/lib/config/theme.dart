import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bg = Color(0xFF0B1124);
  static const Color surface = Color(0xFF131D38);
  static const Color card = Color(0xFF1A2747);
  static const Color border = Color(0xFF2B3B63);
  static const Color primary = Color(0xFF38BDF8);
  static const Color secondary = Color(0xFF818CF8);
  static const Color good = Color(0xFF34D399);
  static const Color moderate = Color(0xFFFBBF24);
  static const Color poor = Color(0xFFFB923C);
  static const Color bad = Color(0xFFF87171);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);

  static Color levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'tot':
        return good;
      case 'trung_binh':
        return moderate;
      case 'kem':
        return poor;
      case 'xau':
        return bad;
      default:
        return textSecondary;
    }
  }

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: secondary,
          surface: surface,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          bodyLarge: GoogleFonts.inter(color: textPrimary),
          bodyMedium: GoogleFonts.inter(color: textSecondary),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: textPrimary,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: card.withValues(alpha: 0.65),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primary, width: 1.4),
          ),
          labelStyle: const TextStyle(color: textSecondary),
          hintStyle: const TextStyle(color: textSecondary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      );
}
