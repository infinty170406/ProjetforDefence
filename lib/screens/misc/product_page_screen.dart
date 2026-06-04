import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';

class ProductPageScreen extends StatelessWidget {
  final String title;

  const ProductPageScreen({super.key, this.title = 'Product Page'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.shield, color: AppColors.primary, size: 120),
                        SizedBox(height: 24),
                        Text(
                          'THE GUARDIAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'The ultimate protection for your family.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textGray400,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ... Contenu marketing ...
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
