import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Couleurs principales
  static const Color primary = Color(0xFFB32BEE);
  static const Color primaryDark = Color(0xFF7B1FA2);

  // Couleurs de fond
  static const Color backgroundLight = Color(0xFFF7F6F8);
  static const Color backgroundDark = Color(0xFF121212);

  // Couleurs d'accent
  static const Color accentTeal = Color(0xFF2DD4BF);
  static const Color accentAmber = Color(0xFFFBBF24);

  // Couleurs de l'effet glass
  static const Color glassBorder = Color.fromRGBO(255, 255, 255, 0.08);
  static const Color glassBackground = Color.fromRGBO(30, 30, 30, 0.4);

  // Couleurs de texte
  static const Color textWhite = Colors.white;
  static const Color textGray300 = Color(0xFFD1D5DB);
  static const Color textGray400 = Color(0xFF9CA3AF);
  static const Color textGray500 = Color(0xFF6B7280);

  // Couleurs de statut
  static const Color statusWarning = accentAmber;
  static const Color statusSafe = accentTeal;
  static const Color statusSuccess = Color(0xFF10B981);
  static const Color statusDanger = Color(0xFFEF4444);

  // Couleurs spécifiques
  static const Color backgroundOnboarding = Color(0xFF0F172A);
  static const Color backgroundDarkDeep = Color(0xFF020617);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: AppColors.backgroundDark,
      ),
      textTheme: GoogleFonts.workSansTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w300,
            color: AppColors.textWhite,
          ),
          displayMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textWhite,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.textWhite,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textGray400,
          ),
        ),
      ),
      useMaterial3: true,
    );
  }
}
