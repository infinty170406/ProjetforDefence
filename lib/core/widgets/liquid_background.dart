import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LiquidBackground extends StatefulWidget {
  const LiquidBackground({super.key});

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Opacités adaptées : plus douces en mode clair pour ne pas noyer le texte
    final blobOpacity1 = isLight ? 0.18 : 0.40;
    final blobOpacity2 = isLight ? 0.12 : 0.30;
    final blobOpacity3 = isLight ? 0.08 : 0.20;

    // En mode clair, utilise la couleur de fond comme base (pas transparent sur du blanc)
    final bgColor =
        isLight ? AppColors.backgroundLight : AppColors.backgroundDark;

    return Container(
      color: bgColor,
      child: Stack(
        children: [
          // Blob principal en haut à gauche — violet/indigo
          Positioned(
            top: -size.height * 0.15,
            left: -size.width * 0.25,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_controller.value * 0.08),
                  child: Container(
                    width: size.width * 0.85,
                    height: size.width * 0.85,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: blobOpacity1),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Blob secondaire en bas à droite — bleu azur
          Positioned(
            bottom: size.height * 0.05,
            right: -size.width * 0.15,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.05 - (_controller.value * 0.05),
                  child: Container(
                    width: size.width * 0.65,
                    height: size.width * 0.65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primaryDark.withValues(alpha: blobOpacity2),
                          AppColors.primaryDark.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Blob tertiaire au centre — teal/emeraude
          Positioned(
            top: size.height * 0.35,
            left: size.width * 0.25,
            child: Container(
              width: size.width * 0.55,
              height: size.width * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentTeal.withValues(alpha: blobOpacity3),
                    AppColors.accentTeal.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
