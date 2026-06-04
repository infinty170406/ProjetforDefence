import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/custom_button.dart';

class OnboardingIntroAiScreen extends StatefulWidget {
  const OnboardingIntroAiScreen({super.key});

  @override
  State<OnboardingIntroAiScreen> createState() =>
      _OnboardingIntroAiScreenState();
}

class _OnboardingIntroAiScreenState extends State<OnboardingIntroAiScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Intelligent Protection',
      'description': 'The Guardian AI stays on watch for your children in real time.',
      'icon': 'shield',
    },
    {
      'title': 'Predictive Analysis',
      'description':
          'Detect risks before they become problems.',
      'icon': 'insights',
    },
    {
      'title': 'AI Guidance',
      'description':
          'An assistant always there to help with your parenting questions.',
      'icon': 'auto_awesome',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isSmall = constraints.maxHeight < 500;
                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32.0, vertical: 24.0),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight),
                              child: IntrinsicHeight(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (index == 0)
                                      Image.asset(
                                        'assets/Rectangle 69.png',
                                        width: double.infinity,
                                        height: isSmall ? 180 : 260,
                                        fit: BoxFit.contain,
                                      )
                                    else
                                      Icon(
                                        _getIcon(index),
                                        color: AppColors.primary,
                                        size: isSmall ? 80 : 120,
                                      ),
                                    SizedBox(height: isSmall ? 24 : 48),
                                    Text(
                                      _pages[index]['title']!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmall ? 24 : 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _pages[index]['description']!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.textGray400,
                                        fontSize: isSmall ? 15 : 18,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      CustomButton(
                        text: _currentPage == _pages.length - 1
                            ? 'Start'
                            : 'Next',
                        onPressed: () {
                          if (_currentPage < _pages.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            context.go('/login');
                          }
                        },
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text(
                          'Skip introduction',
                          style: TextStyle(color: AppColors.textGray400),
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

  IconData _getIcon(int index) {
    switch (index) {
      case 0:
        return Icons.shield;
      case 1:
        return Icons.insights;
      case 2:
        return Icons.auto_awesome;
      default:
        return Icons.help_outline;
    }
  }
}
