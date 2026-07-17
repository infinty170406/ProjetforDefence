import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class CinematicSplashScreen extends StatelessWidget {
  final String title;

  const CinematicSplashScreen({super.key, this.title = 'Screen'});

  @override
  Widget build(BuildContext context) {
    // Simulation d'une cinématique
    Future.delayed(const Duration(seconds: 4), () {
      if (context.mounted) context.go('/onboarding');
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animation cinématique ici
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            SizedBox(height: 24),
            Text(
              'Get ready...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
