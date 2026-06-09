import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/custom_button.dart';

class OnboardingPairingFinalScreen extends StatelessWidget {
  const OnboardingPairingFinalScreen({super.key});

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
                  Icon(Icons.phonelink_setup,
                      color: AppColors.primary, size: 100),
                  SizedBox(height: 32),
                  Text(
                    "You're all set!",
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Pairing is complete. You can now supervise the device.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 18),
                  ),
                  Spacer(),
                  CustomButton(
                    text: 'Go to Dashboard',
                    onPressed: () => context.go('/dashboard'),
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
