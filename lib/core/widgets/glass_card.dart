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
                backgroundColor?.withValues(alpha: 0.3) ??
                    const Color(0xFF0A0A0A).withValues(alpha: 0.6),
                backgroundColor?.withValues(alpha: 0.1) ??
                    const Color(0xFF0A0A0A).withValues(alpha: 0.4),
              ],
            ),
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            border: showBorder
                ? Border.all(
                    color: borderColor ?? AppColors.glassBorder,
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
