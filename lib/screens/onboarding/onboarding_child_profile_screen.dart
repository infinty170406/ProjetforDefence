import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/custom_button.dart';

class OnboardingChildProfileScreen extends StatelessWidget {
  const OnboardingChildProfileScreen({super.key});

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
                  Icon(Icons.child_care, color: AppColors.primary, size: 100),
                  SizedBox(height: 32),
                  Text(
                    'Child Profile',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Create a personalized profile for each child.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 18),
                  ),
                  Spacer(),
                  CustomButton(
                    text: 'Next',
                    onPressed: () => context.push('/onboarding/pairing'),
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
