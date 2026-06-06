import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/liquid_background.dart';

class PersistenceHelpScreen extends StatelessWidget {
  const PersistenceHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                const SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  title: Text(
                    'Rester Toujours Actif',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(24.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const Text(
                        'Certains téléphones (Xiaomi, Samsung, Huawei) ferment les applications de protection pour économiser la batterie.',
                        style: TextStyle(
                          color: AppColors.textGray400,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const _HelpStep(
                        index: '1',
                        title: 'Verrouiller l\'application',
                        description:
                            'Ouvrez le menu des applications récentes (carré), cliquez longuement sur Guardian et sélectionnez l\'icône "Cadenas".',
                        icon: Icons.lock_outline_rounded,
                      ),
                      const SizedBox(height: 24),
                      const _HelpStep(
                        index: '2',
                        title: 'Activer le "Lancement Automatique"',
                        description:
                            'Dans les paramètres de l\'application, cherchez "Auto-start" ou "Démarrage automatique" et activez-le.',
                        icon: Icons.settings_power_rounded,
                      ),
                      const SizedBox(height: 24),
                      const _HelpStep(
                        index: '3',
                        title: 'Optimisation de batterie',
                        description:
                            'Vérifiez que l\'application est en mode "Pas de restriction" dans les réglages batterie.',
                        icon: Icons.battery_saver_rounded,
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: AppColors.primary),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Ces étapes garantissent que votre enfant ne pourra pas désactiver la protection en fermant simplement l\'application.',
                                style: TextStyle(
                                  color: AppColors.textWhite,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                    ]),
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

class _HelpStep extends StatelessWidget {
  final String index;
  final String title;
  final String description;
  final IconData icon;

  const _HelpStep({
    required this.index,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              index,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textGray400,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
