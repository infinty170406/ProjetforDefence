import 'package:flutter/material.dart';

class AppColors {
  // Couleurs principales
  static const Color primary = Color(0xFF4F46E5); // Bleu royal / Bleu violacé
  static const Color primaryDark = Color(0xFF3B82F6); // Bleu azur / Bleu moyen

  // Couleurs de fond
  static const Color backgroundLight = Color(0xFFFFFFFF); // Blanc pur
  static const Color backgroundDark = Color(0xFF121212);

  // Couleurs d'accent
  static const Color accentTeal = Color(0xFF14B8A6); // Vert émeraude / Turquoise
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
  static const Color backgroundOnboarding = Color(0xFFEBE8F9); // Violet très clair / Lavande
  static const Color backgroundDarkDeep = Color(0xFF020617);
  
  // Couleurs de dégradé (Fond du logo)
  static const Color gradientStart = Color(0xFFEBE8F9); // Violet très clair / Lavande
  static const Color gradientEnd = Color(0xFFE3F2FD); // Bleu ciel / Turquoise très clair
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
      textTheme: const TextTheme(
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
    );
  }
}
