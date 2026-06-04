import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/api_service.dart';

class SplashWelcomeScreen extends StatefulWidget {
  const SplashWelcomeScreen({super.key});

  @override
  State<SplashWelcomeScreen> createState() => _SplashWelcomeScreenState();
}

class _SplashWelcomeScreenState extends State<SplashWelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
    _checkSession();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    try {
      // ── STEP 1: Fast startup delay ─────────────────────────────────────
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      // ── STEP 2: Privacy dialog on first launch ─────────────────────────
      final privacyAccepted = await StorageService().getPrivacyAccepted();
      if (!privacyAccepted && mounted) {
        await _showPrivacyDialog();
      }
      if (!mounted) return;

      // ── STEP 3: Child device detection (PRIORITY) ──────────────────────
      // A child device is never authenticated with Firebase.
      // It only has a pairing stored in SharedPreferences.
      final pairing = await StorageService().getChildPairing();
      if (pairing['mode'] == 'child' &&
          pairing['childId'] != null &&
          pairing['parentId'] != null) {
        // Restore anonymous Firebase Auth session if lost (e.g. after reinstall).
        // Firebase normally persists anonymous sessions, but this is a safety net.
        if (FirebaseAuth.instance.currentUser == null) {
          try {
            await FirebaseAuth.instance.signInAnonymously();
          } catch (_) {
            // Non-critical: Firestore reads may fail until next pairing.
          }
        }
        if (mounted) context.go('/child/dashboard');
        return;
      }

      // ── STEP 4: Parent device session check ────────────────────────────
      final apiService = ApiService();
      await apiService.initialize();
      final token = await StorageService().getToken();

      if (mounted) {
        if (token != null) {
          context.go('/dashboard');
        } else {
          context.go('/onboarding');
        }
      }
    } catch (e) {
      if (mounted) context.go('/onboarding');
    }
  }

  Future<void> _showPrivacyDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined,
                    color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'Privacy & Data Policy',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const SingleChildScrollView(
                child: Text(
                  'The Guardian collects location data, app usage statistics, and device information to help you monitor and protect your children.\n\n'
                  '• Data is encrypted and stored securely on Firebase\n'
                  '• Only you can access your children\'s data\n'
                  '• We never sell your personal information\n'
                  '• You can delete your data at any time from Settings\n\n'
                  'By continuing, you agree to our Terms of Service and Privacy Policy.',
                  style: TextStyle(
                      color: Color(0xFFAAAAAA), fontSize: 13, height: 1.6),
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await StorageService().savePrivacyAccepted(true);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                  ),
                  child: const Text('I Understand & Accept',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // SAME build method - no design change
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
                    'assets/Rectangle 69.png',
                    width: 180,
                    height: 180,
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
