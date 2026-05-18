import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Glassboard dark theme — cyberpunk/glassmorphism aesthetic
class AppTheme {
  AppTheme._();

  // ── Brand Colors ───────────────────────────────────────────────────
  static const Color primary = Color(0xFF00FFD1);      // Cyan-teal accent
  static const Color danger  = Color(0xFFFF6B6B);      // Red-coral
  static const Color warning = Color(0xFFFFD700);      // Gold
  static const Color purple  = Color(0xFFA78BFA);      // Soft purple
  static const Color success = Color(0xFF34D399);      // Emerald green
  static const Color orange  = Color(0xFFF97316);      // Warm orange

  // ── Surfaces ───────────────────────────────────────────────────────
  static const Color bg         = Color(0xFF080B10);   // Deep space black
  static const Color surface    = Color(0xFF0D1117);   // Card surface
  static const Color surface2   = Color(0xFF0F1923);   // Slightly lighter
  static const Color border     = Color(0xFF1E293B);   // Subtle border
  static const Color border2    = Color(0xFF334155);   // Medium border

  // ── Text ───────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF64748B);
  static const Color textDim       = Color(0xFF475569);

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: purple,
        error: danger,
        surface: surface,
        onPrimary: bg,
        onSecondary: bg,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.syne(
          fontSize: 40, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: 2),
        displayMedium: GoogleFonts.syne(
          fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary),
        displaySmall: GoogleFonts.syne(
          fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
        headlineLarge: GoogleFonts.syne(
          fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium: GoogleFonts.syne(
          fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
        titleLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 14, color: textSecondary),
        bodyMedium: GoogleFonts.inter(fontSize: 13, color: textSecondary),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: textMuted),
        labelLarge: GoogleFonts.spaceMono(
          fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: textPrimary),
        labelMedium: GoogleFonts.spaceMono(
          fontSize: 11, letterSpacing: 2, color: textMuted),
        labelSmall: GoogleFonts.spaceMono(
          fontSize: 10, letterSpacing: 3, color: textDim),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textSecondary),
        titleTextStyle: TextStyle(
          color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: danger),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textDim),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: bg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.spaceMono(
            fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.spaceMono(
            fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary.withAlpha(38),
        side: const BorderSide(color: border),
        labelStyle: GoogleFonts.spaceMono(fontSize: 10, letterSpacing: 1, color: textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface2,
        contentTextStyle: GoogleFonts.inter(color: textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: border),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textMuted,
        tileColor: Colors.transparent,
        textColor: textPrimary,
      ),
    );
  }
}
