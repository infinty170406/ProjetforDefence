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
      duration: const Duration(seconds: 3),
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

    return Stack(
      children: [
        // Blob principal en haut à gauche
        Positioned(
          top: -size.height * 0.1,
          left: -size.width * 0.2,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_controller.value * 0.1),
                child: Container(
                  width: size.width * 0.8,
                  height: size.width * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.4),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Blob secondaire en bas à droite
        Positioned(
          bottom: size.height * 0.1,
          right: -size.width * 0.1,
          child: Container(
            width: size.width * 0.6,
            height: size.width * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryDark.withValues(alpha: 0.3),
                  AppColors.primaryDark.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // Blob tertiaire au centre
        Positioned(
          top: size.height * 0.4,
          left: size.width * 0.3,
          child: Container(
            width: size.width * 0.5,
            height: size.width * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF1E3A8A).withValues(alpha: 0.2),
                  const Color(0xFF1E3A8A).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
