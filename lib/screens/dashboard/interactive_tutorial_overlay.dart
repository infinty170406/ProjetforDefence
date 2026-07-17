import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';

class InteractiveTutorialOverlay extends StatefulWidget {
  final VoidCallback onFinish;

  const InteractiveTutorialOverlay({
    super.key,
    required this.onFinish,
  });

  @override
  State<InteractiveTutorialOverlay> createState() =>
      _InteractiveTutorialOverlayState();
}

class _InteractiveTutorialOverlayState
    extends State<InteractiveTutorialOverlay> {
  int _currentStep = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Ajouter un Enfant',
      'description':
          'Commencez par ajouter le profil de vos enfants pour configurer leurs règles de sécurité.',
      'icon': Icons.add_circle_outline,
      'alignment': Alignment.topCenter,
      'offsetY': 140.0,
      'badge': 'ÉTAPE 1',
    },
    {
      'title': 'Carte Temps Réel',
      'description':
          'Suivez la position géographique en direct de vos enfants et gérez les zones de sécurité (Geofencing).',
      'icon': Icons.map_outlined,
      'alignment': Alignment.center,
      'offsetY': 0.0,
      'badge': 'ÉTAPE 2',
    },
    {
      'title': 'Alertes & SOS',
      'description':
          'Consultez les notifications critiques de cyberharcèlement, de batterie faible ou d\'appels SOS.',
      'icon': Icons.notifications_active_outlined,
      'alignment': Alignment.topRight,
      'offsetY': 60.0,
      'badge': 'ÉTAPE 3',
    },
    {
      'title': 'Orchestrateur IA',
      'description':
          'L\'intelligence artificielle analyse les menaces et résume les activités clés sous forme de rapports.',
      'icon': Icons.auto_awesome_outlined,
      'alignment': Alignment.centerLeft,
      'offsetY': 80.0,
      'badge': 'ÉTAPE 4',
    },
    {
      'title': 'Dashboard Web',
      'description':
          'Accédez à toutes vos fonctionnalités avancées depuis n\'importe quel navigateur de bureau.',
      'icon': Icons.computer_outlined,
      'alignment': Alignment.bottomCenter,
      'offsetY': -80.0,
      'badge': 'ÉTAPE 5',
    },
    {
      'title': 'Famille & Abonnements',
      'description':
          'Gérez vos plans Premium, l\'équipe de parents/gardiens et vos configurations générales.',
      'icon': Icons.settings_outlined,
      'alignment': Alignment.bottomRight,
      'offsetY': -60.0,
      'badge': 'ÉTAPE 6',
    },
  ];

  void _next() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final badge = step['badge'] as String;
    final title = step['title'] as String;
    final desc = step['description'] as String;
    final icon = step['icon'] as IconData;

    return Material(
      color: Colors.black.withOpacity(0.75),
      child: Stack(
        children: [
          // Simulated Highlight circle using a backdrop border cutout or custom painter.
          // For simplicity and high visual quality, we show a gorgeous, animated glowing spotlight overlay.
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 50,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          // Content Card
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: widget.onFinish,
                              child: const Text('Passer le tour',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(icon, color: AppColors.primary, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          desc,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Dots
                            Row(
                              children: List.generate(
                                _steps.length,
                                (index) => Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentStep == index
                                        ? AppColors.primary
                                        : Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _next,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              child: Text(_currentStep == _steps.length - 1
                                  ? 'Terminer'
                                  : 'Suivant'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
