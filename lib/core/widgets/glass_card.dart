import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;
  final Color? backgroundColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
    this.showBorder = true,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    // Mode clair : fond blanc élégant et très lisible
    final defaultBgStart = isLight 
        ? Colors.white.withValues(alpha: 0.92) 
        : const Color(0xFF0A0A0A).withValues(alpha: 0.6);
    final defaultBgEnd = isLight 
        ? Colors.white.withValues(alpha: 0.75) 
        : const Color(0xFF0A0A0A).withValues(alpha: 0.4);
    final defaultBorder = isLight 
        ? const Color(0xFFDDE3F5) // Ardoise bleuâtre léger
        : AppColors.glassBorder;

    Widget content = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                backgroundColor?.withValues(alpha: 0.3) ?? defaultBgStart,
                backgroundColor?.withValues(alpha: 0.1) ?? defaultBgEnd,
              ],
            ),
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            border: showBorder
                ? Border.all(
                    color: borderColor ?? defaultBorder,
                    width: 1,
                  )
                : null,
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return GestureDetector(
      onTap: onTap,
      child: content,
    );
  }
}
