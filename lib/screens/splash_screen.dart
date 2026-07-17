import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/auth_service.dart';
import '../services/package_service.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_background.dart';
import 'auth/welcome_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'permissions_onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkActivationAndNavigate());
    });
  }

  Future<void> _checkActivationAndNavigate() async {
    final isActivated = await AuthService().isDeviceActivated();
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    if (!isActivated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
      return;
    }

    final appState = context.read<AppState>();
    await appState.initialize();
    if (!mounted) return;

    final allPermissionsGranted = await appState.checkAllPermissions();
    if (!mounted) return;

    if (!allPermissionsGranted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PermissionsOnboardingScreen(),
        ),
      );
      return;
    }

    // L'inventaire requiert le canal Android de l'isolate UI.
    unawaited(PackageService().syncInstalledApps());
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          const LiquidBackground(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'THE GUARDIAN',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Protector of Digital Freedom',
                  style: TextStyle(
                    color: AppColors.textGray400,
                    fontSize: 14,
                    letterSpacing: 1.2,
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
