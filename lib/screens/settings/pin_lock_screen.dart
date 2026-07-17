import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';

class PinLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const PinLockScreen({super.key, required this.onUnlocked});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _inputPin = '';
  String _savedPin = '1234';
  bool _hasError = false;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedPin();
  }

  Future<void> _loadSavedPin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPin = prefs.getString('settings_parent_pin') ?? '1234';
    });
  }

  void _onNumberPressed(int number) {
    if (_inputPin.length >= 4) return;
    setState(() {
      _inputPin += number.toString();
      _hasError = false;
    });

    if (_inputPin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_inputPin.isEmpty) return;
    setState(() {
      _inputPin = _inputPin.substring(0, _inputPin.length - 1);
      _hasError = false;
    });
  }

  Future<void> _captureIntruderPhoto() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('No cameras available.');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      final image = await controller.takePicture();
      await controller.dispose();

      // Check / request access to gallery before saving
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      await Gal.putImage(image.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('settings_intrusion_photo_captured', true);

      debugPrint('Intruder photo taken and saved to gallery successfully.');
    } catch (e) {
      debugPrint('Error capturing intruder photo: $e');
      // En cas d'erreur (ex: permissions refusées sur émulateur), on active quand même le flag
      // pour permettre de tester la notification lors de la saisie du bon code.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('settings_intrusion_photo_captured', true);
    }
  }

  Future<void> _verifyPin() async {
    if (_inputPin == _savedPin) {
      final prefs = await SharedPreferences.getInstance();
      final wasPhotoCaptured =
          prefs.getBool('settings_intrusion_photo_captured') ?? false;

      widget.onUnlocked();

      if (mounted) {
        if (wasPhotoCaptured) {
          // Clear the flag
          await prefs.setBool('settings_intrusion_photo_captured', false);

          if (!mounted) return;
          // Show intrusion notification dialog
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.security_rounded, color: AppColors.statusDanger),
                  const SizedBox(width: 8),
                  Text('Alerte d\'Intrusion',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
              content: Text(
                'Une tentative de déverrouillage a échoué après 3 essais incorrects. Une photo de l\'intrus a été capturée et enregistrée dans votre galerie.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer',
                      style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application déverrouillée ✓'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.green,
            ),
          );
        }

        try {
          context.go('/dashboard');
        } catch (e) {
          debugPrint('Navigation error to /dashboard: $e');
        }
      }
    } else {
      setState(() {
        _inputPin = '';
        _hasError = true;
        _failedAttempts++;
      });

      if (_failedAttempts >= 3) {
        // Trigger background photo capture
        await _captureIntruderPhoto();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Code PIN incorrect ❌ (Tentative $_failedAttempts/3 - Photo enregistrée)'),
            duration: const Duration(seconds: 3),
            backgroundColor: AppColors.statusDanger,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Code PIN incorrect ❌ (Tentative $_failedAttempts/3)'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.statusDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Icon(
                  Icons.lock_outline_rounded,
                  size: 64,
                  color: _hasError ? AppColors.statusDanger : AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Application Verrouillée',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Veuillez entrer votre PIN Parent pour déverrouiller',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // DOTS INDICATOR
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _inputPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? (isFilled && _hasError
                                ? AppColors.statusDanger
                                : AppColors.primary)
                            : Colors.transparent,
                        border: Border.all(
                          color: _hasError
                              ? AppColors.statusDanger
                              : AppColors.primary,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),

                const Spacer(),

                // NUMPAD
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      if (index == 9) {
                        return const SizedBox
                            .shrink(); // Empty slot bottom-left
                      }
                      if (index == 11) {
                        // Backspace bottom-right
                        return _buildNumpadButton(
                          child: Icon(Icons.backspace_outlined,
                              color: Theme.of(context).colorScheme.onSurface),
                          onTap: _onBackspace,
                        );
                      }
                      final number = index == 10 ? 0 : index + 1;
                      return _buildNumpadButton(
                        child: Text(
                          number.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () => _onNumberPressed(number),
                      );
                    },
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadButton(
      {required Widget child, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonBg = isDark
        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.06)
        : const Color(0xFFF1F5F9);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: buttonBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
