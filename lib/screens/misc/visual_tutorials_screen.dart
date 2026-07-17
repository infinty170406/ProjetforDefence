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
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back,
                        color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => context.pop(),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Tutorials',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 32),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildTutorialItem(
                            context, 'Set up a safe zone', '2 min'),
                        _buildTutorialItem(context, 'Read AI reports', '3 min'),
                        _buildTutorialItem(
                            context, 'Manage screen time', '4 min'),
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

  Widget _buildTutorialItem(
      BuildContext context, String title, String duration) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.play_circle_outline, color: AppColors.primary, size: 40),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text(duration,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
