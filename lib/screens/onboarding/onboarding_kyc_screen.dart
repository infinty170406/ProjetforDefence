import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/custom_button.dart';

class OnboardingKycScreen extends StatelessWidget {
  final String title;

  const OnboardingKycScreen({super.key, this.title = 'Security & KYC'});

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
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'To ensure maximum protection for your family, we need to verify your identity. This process is secure and only takes a few minutes.',
                    style: TextStyle(
                      color: AppColors.textGray400,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Expanded(
                    child: GlassCard(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_user_outlined,
                                color: AppColors.primary, size: 60),
                            SizedBox(height: 24),
                            Text(
                              'Secure Identity Verification',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 12),
                            Text(
                              '• Encrypted Data Transmission\n• Fast Document Processing\n• GDPR Compliant',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.textGray400, height: 1.8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    text: 'Get Started',
                    onPressed: () => context.push('/verify-identity'),
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
