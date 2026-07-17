import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PALETTE — The Guardian
// ══════════════════════════════════════════════════════════════════════════════
class AppColors {
  // Couleur principale : Violet identitaire
  static const Color primary = Color(0xFF6C4DFF);
  static const Color primaryDark = Color(0xFF5A3FD6);

  // Couleur secondaire : Bleu doux
  static const Color accent = Color(0xFF5DA9FF);
  static const Color accentTeal = Color(0xFF14B8A6);
  static const Color accentAmber = Color(0xFFFBBF24);

  // Fonds — Thème clair (design indépendant, pas un thème sombre blanchi)
  static const Color backgroundLight = Color(0xFFF8F9FC); // #F8F9FC
  static const Color surfaceLight = Color(0xFFFFFFFF); // Cartes
  static const Color surfaceVariantLight = Color(0xFFF0F2F8); // Inputs

  // Fonds — Thème sombre
  static const Color backgroundDark = Color(0xFF020617);
  static const Color backgroundDarkDeep = Color(0xFF020617);

  // Ombre douce (thème clair)
  static const Color shadowLight = Color(0x14000000);

  // Texte
  static const Color textWhite = Colors.white;
  static const Color textDark = Color(0xFF1A1D2E);
  static const Color textGray300 = Color(0xFFD1D5DB);
  static const Color textGray400 = Color(0xFF9CA3AF);
  static const Color textGray500 = Color(0xFF6B7280);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // Statuts
  static const Color statusSuccess = Color(0xFF4CAF50); // Vert pastel
  static const Color statusWarning = Color(0xFFFF9800); // Orange
  static const Color statusDanger = Color(0xFFE53935); // Rouge doux
  static const Color statusSafe = Color(0xFF14B8A6); // Teal

  // Glassmorphism (thème sombre)
  static const Color glassBorder = Color.fromRGBO(255, 255, 255, 0.08);
  static const Color glassBackground = Color.fromRGBO(30, 30, 30, 0.4);

  // Dégradés onboarding
  static const Color backgroundOnboarding = Color(0xFFEBE8F9);
  static const Color gradientStart = Color(0xFFEBE8F9);
  static const Color gradientEnd = Color(0xFFE3F2FD);
}

// ══════════════════════════════════════════════════════════════════════════════
// THÈMES
// ══════════════════════════════════════════════════════════════════════════════
class AppTheme {
  // ── THÈME CLAIR ───────────────────────────────────────────────────────────
  // Design indépendant inspiré de Google Home / Apple Santé / Notion Calendar
  // Fond principal : #F8F9FC  |  Cartes : #FFFFFF  |  Violet identitaire
  // ─────────────────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surfaceLight,
        surfaceContainerHighest: AppColors.surfaceVariantLight,
        onSurface: AppColors.textDark,
        onSurfaceVariant: AppColors.textSecondaryLight,
        outline: Color(0xFFDDE3F0),
        outlineVariant: Color(0xFFEBEEF8),
        error: AppColors.statusDanger,
      ),
      textTheme: GoogleFonts.outfitTextTheme(TextTheme(
        displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w300,
            color: AppColors.textDark,
            height: 1.2),
        displayMedium: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            height: 1.3),
        titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark),
        titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark),
        bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF334155)),
        bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondaryLight),
        bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.textMutedLight),
        labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textMutedLight),
      )),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textDark),
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
      ),
      // Cartes : blanc pur, rayon 24px, ombre très légère
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        shadowColor: AppColors.shadowLight,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEBEEF8),
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: Color(0xFF64748B)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantLight,
        hintStyle: const TextStyle(color: Color(0xFFB0B8CC)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDE3F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDE3F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.statusDanger),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Outfit'),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.primary
                : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.primary.withOpacity(0.4)
                : const Color(0xFFDDE3F0)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
        shadowColor: AppColors.shadowLight,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              fontFamily: 'Outfit'),
        ),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.textGray500,
              size: 24,
            )),
      ),
    );
  }

  // ── THÈME SOMBRE ──────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: Color(0xFF0F172A),
        onSurface: AppColors.textWhite,
        onSurfaceVariant: AppColors.textGray400,
        error: AppColors.statusDanger,
      ),
      textTheme: GoogleFonts.outfitTextTheme(TextTheme(
        displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w300,
            color: AppColors.textWhite),
        displayMedium: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppColors.textWhite),
        titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textWhite),
        titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textWhite),
        bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.textWhite),
        bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textGray400),
        bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.textGray500),
        labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textGray500),
      )),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textWhite),
        titleTextStyle: TextStyle(
            color: AppColors.textWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit'),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF0B1329),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Outfit'),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.primary : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.primary.withOpacity(0.4)
                : const Color(0xFF334155)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF0F172A),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF0F172A),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}
