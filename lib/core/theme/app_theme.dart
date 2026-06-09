import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Couleurs principales (Spécifications de la marque)
  static const Color primary = Color(0xFF4F46E5); // Bleu royal / Bleu violacé
  static const Color primaryDark = Color(0xFF3B82F6); // Bleu azur / Bleu moyen

  // Couleurs de fond
  static const Color backgroundLight = Color(0xFFF4F6FF); // Soft logo-inspired light background
  static const Color backgroundDark = Color(0xFF020617);  // Slate 950 (Noir bleuté profond)

  // Couleurs d'accent
  static const Color accentTeal = Color(0xFF14B8A6); // Vert émeraude / Turquoise
  static const Color accentAmber = Color(0xFFFBBF24); // Jaune ambre

  // Couleurs de l'effet glass (Reste constant pour compatibilité, mais géré dynamiquement dans la UI)
  static const Color glassBorder = Color.fromRGBO(255, 255, 255, 0.08);
  static const Color glassBackground = Color.fromRGBO(30, 30, 30, 0.4);

  // Couleurs de texte
  static const Color textWhite = Colors.white;
  static const Color textGray300 = Color(0xFFD1D5DB);
  static const Color textGray400 = Color(0xFF9CA3AF); // Used on dark bg
  static const Color textGray500 = Color(0xFF6B7280);

  // Couleurs de texte secondaire adaptatives (mode clair)
  // À utiliser à la place de textGray400 sur fond clair
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate-500 — visible & élégant
  static const Color textMutedLight = Color(0xFF94A3B8);    // Slate-400 — pour infos tertiaires

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
  // Thème Clair Premium
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: Color(0xFFFFFFFF),
        surfaceContainerHighest: Color(0xFFF1F5F9),
        onSurface: Color(0xFF1E293B),           // Titres principaux (Slate-800)
        onSurfaceVariant: Color(0xFF64748B),    // Texte secondaire (Slate-500)
        outline: Color(0xFFCBD5E1),             // Bordures (Slate-300)
        outlineVariant: Color(0xFFE2E8F0),      // Bordures légères (Slate-200)
      ),
      textTheme: GoogleFonts.outfitTextTheme(const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w300,
          color: Color(0xFF1E293B),
        ),
        displayMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Color(0xFF334155), // Slate-700
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFF64748B), // Slate-500 — bien lisible en mode clair
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Color(0xFF94A3B8), // Slate-400
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF94A3B8),
        ),
      )),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFDDE3F5), width: 1.2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF475569), // Slate-600 pour les icônes en mode clair
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  // Thème Sombre Premium
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: Color(0xFF0F172A),
        onSurface: AppColors.textWhite,
      ),
      textTheme: GoogleFonts.outfitTextTheme(const TextTheme(
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
      )),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textWhite),
        titleTextStyle: TextStyle(
          color: AppColors.textWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF0B1329),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
