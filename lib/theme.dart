import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color background = Color(0xFF060B18);
  static const Color surface = Color(0xFF0D1626);
  static const Color surfaceElevated = Color(0xFF121D33);
  static const Color card = Color(0xFF162035);
  static const Color cardBorder = Color(0xFF1E2D4A);

  static const Color primary = Color(0xFF00D4FF);
  static const Color primaryGlow = Color(0x3300D4FF);
  static const Color accent = Color(0xFF7B61FF);
  static const Color accentGlow = Color(0x337B61FF);

  static const Color gainGreen = Color(0xFF00E5A0);
  static const Color gainGreenGlow = Color(0x3300E5A0);
  static const Color lossRed = Color(0xFFFF4B6E);
  static const Color lossRedGlow = Color(0x33FF4B6E);
  static const Color warningOrange = Color(0xFFFF9F43);

  static const Color textPrimary = Color(0xFFEDF2FF);
  static const Color textSecondary = Color(0xFF8FA3C8);
  static const Color textMuted = Color(0xFF4A5E80);

  static const Color divider = Color(0xFF1A2740);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        background: background,
        error: lossRed,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
      ),
    );
  }
}