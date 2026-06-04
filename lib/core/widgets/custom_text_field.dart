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
  // ADDED: inline error text support
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textGray300,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(
            color: AppColors.textWhite,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textGray500),
            filled: true,
            fillColor: AppColors.glassBackground,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColors.textGray400)
                : null,
            suffixIcon: suffixIcon != null
                ? IconButton(
                    icon: Icon(suffixIcon, color: AppColors.textGray400),
                    onPressed: onSuffixTap,
                  )
                : null,
            // ADDED: errorText shown inline below field
            errorText: errorText,
            errorStyle: const TextStyle(color: AppColors.statusDanger, fontSize: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              // CHANGED: show red border when errorText is set
              borderSide: BorderSide(
                color: errorText != null ? AppColors.statusDanger : AppColors.glassBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.statusDanger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.statusDanger, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
