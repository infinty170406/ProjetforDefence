import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/api_service.dart';

/// Écran d'accueil du workflow KYC — redirige vers IdentityVerificationScreen.
/// Cet écran est affiché lors de l'onboarding quand le KYC n'est pas encore validé.
class OnboardingKycScreen extends StatelessWidget {
  final String title;
  const OnboardingKycScreen(
      {super.key, this.title = 'Vérification d\'identité'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.1),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.25)),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.primary.withOpacity(0.15),
                                blurRadius: 24,
                                spreadRadius: 2),
                          ],
                        ),
                        child: const Icon(Icons.verified_user_rounded,
                            color: AppColors.primary, size: 56),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 28,
                            fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Une dernière étape pour sécuriser votre compte et protéger votre famille. Cela prend moins de 2 minutes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 15,
                            height: 1.5),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/verify-identity'),
                          icon: const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white),
                          label: const Text('Commencer la vérification',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          ApiService().bypassKyc();
                          context.go('/dashboard');
                        },
                        child: const Text('Faire plus tard',
                            style: TextStyle(color: AppColors.textGray400)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
