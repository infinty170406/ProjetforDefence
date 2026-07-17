import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';

class OnboardingIntroAiScreen extends StatefulWidget {
  const OnboardingIntroAiScreen({super.key});

  @override
  State<OnboardingIntroAiScreen> createState() =>
      _OnboardingIntroAiScreenState();
}

class _OnboardingIntroAiScreenState extends State<OnboardingIntroAiScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Protection de la Famille',
      'description':
          'Supervisez sereinement la vie numérique de vos enfants grâce à un bouclier système robuste.',
      'icon': Icons.shield_outlined,
      'color': const Color(0xFF6366F1), // Indigo
    },
    {
      'title': 'Localisation Intelligente',
      'description':
          'Suivez la position GPS en temps réel et recevez des alertes automatiques d\'arrivée et de départ.',
      'icon': Icons.location_on_outlined,
      'color': const Color(0xFF0EA5E9), // Sky Blue
    },
    {
      'title': 'Intelligence Artificielle',
      'description':
          'L\'Orchestrateur IA analyse les activités et prévient le cyberharcèlement de manière bienveillante.',
      'icon': Icons.auto_awesome_outlined,
      'color': const Color(0xFF8B5CF6), // Purple
    },
    {
      'title': 'Plateforme Unique',
      'description':
          'Pilotez l\'ensemble des règles de sécurité de tous vos appareils depuis un dashboard unifié.',
      'icon': Icons.family_restroom_outlined,
      'color': const Color(0xFF10B981), // Emerald
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          const Positioned.fill(child: LiquidBackground()),

          // Floating ambient glow behind the current slide icon
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            top: size.height * 0.18,
            left: size.width * 0.5 - 120,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _slides[_currentPage]['color'].withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: _slides[_currentPage]['color'].withOpacity(0.3),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top header with logo & skip button
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/logo.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.security,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'GUARDIAN',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      if (_currentPage < _slides.length - 1)
                        TextButton(
                          onPressed: () {
                            _pageController.animateToPage(
                              _slides.length - 1,
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Text(
                            'Passer',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Page slider
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Glowing Premium Floating Icon Card
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B).withOpacity(0.6)
                                    : Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: slide['color'].withOpacity(0.4),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: slide['color'].withOpacity(0.25),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                slide['icon'] as IconData,
                                color: slide['color'] as Color,
                                size: 64,
                              ),
                            ),
                            const SizedBox(height: 48),
                            // Slide Title
                            Text(
                              slide['title']!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Slide Description
                            Text(
                              slide['description']!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 16,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Controls Section
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32.0, vertical: 24.0),
                  child: Column(
                    children: [
                      // Slide Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _slides.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? _slides[_currentPage]['color'] as Color
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Actions: conditional based on slide
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        crossFadeState: _currentPage == _slides.length - 1
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _slides[_currentPage]['color'] as Color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continuer',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                          ),
                        ),
                        secondChild: Column(
                          children: [
                            // Primary parent sign up button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => context.push('/signup'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Créer un compte Parent',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Secondary parent login button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => context.push('/login'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.white30
                                        : Colors.black26,
                                    width: 1.5,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                child: const Text(
                                  'Se connecter',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
