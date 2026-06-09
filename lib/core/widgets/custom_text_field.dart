import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final String? errorText;

  const CustomTextField({
    super.key,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // ── Couleurs adaptatives ────────────────────────────────────────────────
    // Mode clair : fond blanc à 92% d'opacité, texte sombre
    // Mode sombre : fond glass sombre historique
    final fillColor = isLight
        ? Colors.white.withValues(alpha: 0.92)
        : AppColors.glassBackground;

    final textColor = isLight
        ? const Color(0xFF1E293B) // Slate-800 — noir doux
        : AppColors.textWhite;

    final hintColor = isLight
        ? const Color(0xFF94A3B8) // Slate-400 — gris doux lisible
        : AppColors.textGray500;

    final iconColor = isLight
        ? const Color(0xFF64748B) // Slate-500
        : AppColors.textGray400;

    final labelColor = isLight
        ? const Color(0xFF475569) // Slate-600
        : AppColors.textGray300;

    final borderColor = isLight
        ? const Color(0xFFCBD5E1) // Slate-300
        : AppColors.glassBorder;

    final errorBorderColor = AppColors.statusDanger;
    final focusedBorderColor = AppColors.primary;

    // Ombre légère en mode clair pour donner du relief au champ
    final boxShadow = isLight
        ? [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
        : <BoxShadow>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: boxShadow,
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            onChanged: onChanged,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: hintColor, fontSize: 15),
              filled: true,
              fillColor: fillColor,
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: iconColor, size: 20)
                  : null,
              suffixIcon: suffixIcon != null
                  ? IconButton(
                      icon: Icon(suffixIcon, color: iconColor, size: 20),
                      onPressed: onSuffixTap,
                    )
                  : null,
              errorText: errorText,
              errorStyle: const TextStyle(
                  color: AppColors.statusDanger, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText != null ? errorBorderColor : borderColor,
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: focusedBorderColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: errorBorderColor),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: errorBorderColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
