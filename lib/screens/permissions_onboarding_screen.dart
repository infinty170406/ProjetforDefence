import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_background.dart';
import 'dashboard/dashboard_screen.dart';
import 'auth/welcome_screen.dart';
import 'help/persistence_help_screen.dart';
import '../services/auth_service.dart';

class PermissionsOnboardingScreen extends StatefulWidget {
  const PermissionsOnboardingScreen({super.key});

  @override
  State<PermissionsOnboardingScreen> createState() => _PermissionsOnboardingScreenState();
}

class _PermissionsOnboardingScreenState extends State<PermissionsOnboardingScreen> with WidgetsBindingObserver {
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // On vérifie immédiatement au montage
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    final appState = Provider.of<AppState>(context, listen: false);
    final allGranted = await appState.checkAllPermissions();

    if (allGranted) {
      if (!mounted) return;
      final isActivated = await AuthService().isDeviceActivated();
      if (!mounted) return;

      if (isActivated) {
        await appState.initialize();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
    } else {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: AppColors.primary,
                      size: 80,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Setup Required',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Five permissions are essential for parental protection to work correctly.',
                      style: TextStyle(
                        color: AppColors.textGray400,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    
                    // Liste des permissions
                    _PermissionCard(
                      title: 'Display over other apps',
                      description: 'Necessary to display the blocking screen.',
                      isGranted: appState.hasOverlayPermission,
                      onTap: appState.requestOverlayPermission,
                    ),
                    const SizedBox(height: 16),
                    _PermissionCard(
                      title: 'Accessibility Service',
                      description: 'Necessary to detect launched applications.',
                      isGranted: appState.hasAccessibilityPermission,
                      onTap: appState.requestAccessibilityPermission,
                    ),
                    const SizedBox(height: 16),
                    _PermissionCard(
                      title: 'Usage Data Access',
                      description: 'Necessary to calculate screen time.',
                      isGranted: appState.hasUsagePermission,
                      onTap: appState.requestUsagePermission,
                    ),
                    const SizedBox(height: 16),
                    _PermissionCard(
                      title: 'Location',
                      description: 'Necessary for real-time GPS tracking.',
                      isGranted: appState.hasLocationPermission,
                      onTap: appState.requestLocationPermission,
                    ),
                    const SizedBox(height: 16),
                    _PermissionCard(
                      title: 'Battery Optimization',
                      description: 'Crucial to prevent the protection from closing itself.',
                      isGranted: appState.hasBatteryExemption,
                      onTap: appState.requestBatteryExemption,
                    ),
                    const SizedBox(height: 32),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PersistenceHelpScreen()),
                        );
                      },
                      icon: const Icon(Icons.help_outline_rounded, size: 20),
                      label: const Text('Help for staying active (Xiaomi, Samsung...)'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textGray400,
                      ),
                    ),
                    const SizedBox(height: 48),
                    if (_isChecking)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 32),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onTap;

  const _PermissionCard({
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGranted ? Colors.green.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isGranted ? Colors.green.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : Icons.pending_rounded,
              color: isGranted ? Colors.green : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textGray500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!isGranted)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('ACTIVATE'),
            ),
        ],
      ),
    );
  }
}
