import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/custom_button.dart';

class OnboardingVisionAiScreen extends StatelessWidget {
  const OnboardingVisionAiScreen({super.key});

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
                children: [
                  Spacer(),
                  Icon(Icons.visibility, color: AppColors.primary, size: 100),
                  SizedBox(height: 32),
                  Text(
                    'AI Vision',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'AI detects inappropriate content instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 18),
                  ),
                  Spacer(),
                  CustomButton(
                    text: 'Next',
                    onPressed: () => context.push('/onboarding/kyc'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
