import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown when a page that requires navigation data is opened directly.
class RouteArgumentErrorScreen extends StatelessWidget {
  final String message;

  const RouteArgumentErrorScreen({
    super.key,
    this.message =
        'Les informations nécessaires pour ouvrir cette page sont absentes.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Retour au tableau de bord'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
