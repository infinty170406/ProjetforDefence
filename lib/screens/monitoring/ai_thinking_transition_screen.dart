import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';

class AiThinkingTransitionScreen extends StatelessWidget {
  final String title;

  const AiThinkingTransitionScreen({super.key, this.title = 'AI Analysis'});

  @override
  Widget build(BuildContext context) {
    // Simulation d'une transition
    Future.delayed(const Duration(seconds: 3), () {
      if (context.mounted) context.pop();
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          const LiquidBackground(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppColors.accentTeal, size: 100),
                const SizedBox(height: 32),
                const Text(
                  'AI is thinking...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 200,
                  height: 2,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.accentTeal),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
