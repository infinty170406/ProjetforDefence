import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import 'connection_success_screen.dart';

class ConnectingScreen extends StatefulWidget {
  const ConnectingScreen({super.key});

  @override
  State<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Start connection
    _startConnection();
  }

  Future<void> _startConnection() async {
    try {
      // Minimum wait for animation
      final minWait = Future.delayed(const Duration(seconds: 2));

      // Initialize AppState
      final initialization =
          Provider.of<AppState>(context, listen: false).initialize();

      await Future.wait([minWait, initialization]);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ConnectionSuccessScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection error. Retrying...'),
            backgroundColor: AppColors.statusDanger,
            duration: Duration(seconds: 2),
          ),
        );
        // Retry after delay
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) _startConnection();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.8,
            colors: [
              Color(0x197B61FF),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Top bar
              const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Opacity(
                      opacity: 0.4,
                      child:
                          Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                    Text(
                      'The Guardian',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 24),
                  ],
                ),
              ),
              // Central content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulsing shield
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ping animation
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) => Container(
                            width: 160 + (_pulseController.value * 20),
                            height: 160 + (_pulseController.value * 20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 
                                  0.05 * (1 - _pulseController.value)),
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) => Transform.scale(
                            scale: 1.0 + (_pulseController.value * 0.05),
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 
                                        0.4 * _pulseController.value),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.favorite_border,
                                color: AppColors.primary,
                                size: 56,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'Connecting to parent\naccount…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This may take a few seconds.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 64),
                    // Indeterminate progress bar
                    SizedBox(
                      width: 160,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.grey[900],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Footer
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user,
                        color: AppColors.primary.withValues(alpha: 0.4), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'SECURED',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                        letterSpacing: 3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
