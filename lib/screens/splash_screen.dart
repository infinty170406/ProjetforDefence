import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth/welcome_screen.dart';
import 'dashboard/dashboard_screen.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/package_service.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_background.dart';
import 'permissions_onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationOnMainThread();
      _checkActivationAndNavigate();
    });
  }

  Future<void> _initLocationOnMainThread() async {
    final granted = await LocationService.requestPermissions();
    if (granted) {
      await LocationService().startTracking();
    }
  }
  Future<void> _checkActivationAndNavigate() async {
    final isActivated = await AuthService().isDeviceActivated();

    // Durée minimale du splash
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Vérifier toutes les permissions critiques (Overlay, Accessibilité, Usage)
    final appState = Provider.of<AppState>(context, listen: false);
    final allPermissionsGranted = await appState.checkAllPermissions();

    if (!allPermissionsGranted) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PermissionsOnboardingScreen()),
        );
      }
      return;
    }

    if (isActivated) {
      if (!mounted) return;
      await Provider.of<AppState>(context, listen: false).initialize();
      // ⚠️ Doit être appelé depuis l'isolate principal (UI thread) car il
      // utilise MethodChannel pour accéder à PackageManager Android.
      // Ne pas appeler depuis MonitoringService (background isolate).
      PackageService().syncInstalledApps();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
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
                    'assets/images/Rectangle 69.png',
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'THE GUARDIAN',
                  style: TextStyle(
                    color: Colors.white,
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
