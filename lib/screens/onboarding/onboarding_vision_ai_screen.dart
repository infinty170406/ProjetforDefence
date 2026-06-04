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
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Spacer(),
                  const Icon(Icons.visibility, color: AppColors.primary, size: 100),
                  const SizedBox(height: 32),
                  const Text(
                    'AI Vision',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'AI detects inappropriate content instantly.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppColors.textGray400, fontSize: 18),
                  ),
                  const Spacer(),
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
