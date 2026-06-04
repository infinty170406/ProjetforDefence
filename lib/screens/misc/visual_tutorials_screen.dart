import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';

class VisualTutorialsScreen extends StatelessWidget {
  const VisualTutorialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Tutorials',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildTutorialItem('Set up a safe zone', '2 min'),
                        _buildTutorialItem('Read AI reports', '3 min'),
                        _buildTutorialItem('Manage screen time', '4 min'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialItem(String title, String duration) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.play_circle_outline, color: AppColors.primary, size: 40),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text(duration,
                      style: const TextStyle(
                          color: AppColors.textGray400, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
