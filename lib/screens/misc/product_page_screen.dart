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
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(Icons.close,
                        color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => context.pop(),
                  ),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.shield, color: AppColors.primary, size: 120),
                        SizedBox(height: 24),
                        Text(
                          'THE GUARDIAN',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'The ultimate protection for your family.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
