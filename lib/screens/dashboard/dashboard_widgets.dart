import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/premium/entitlement_service.dart';
import '../../core/premium/feature_flags.dart';
import '../../features/subscription/widgets/locked_feature_sheet.dart';

// ── Hero Card ──────────────────────────────────────────────────────────────────
class DashHeroCard extends StatelessWidget {
  final dynamic child;
  final bool isOnline;
  final String lastActivity;

  const DashHeroCard({
    super.key,
    required this.child,
    required this.isOnline,
    required this.lastActivity,
  });

  @override
  Widget build(BuildContext context) {
    final name = child['displayName'] ?? 'Enfant';
    final location = child['location'] ?? 'Localisation inconnue';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('🛡️', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Protection',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const Spacer(),
              _StatusBadge(isOnline: isOnline),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 20),
          Row(
            children: [
              _HeroStat(icon: '📍', label: location),
              const SizedBox(width: 20),
              _HeroStat(
                icon: '📶',
                label: isOnline ? 'Connecté' : 'Hors ligne',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '⏱ Dernière activité  $lastActivity',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isOnline;
  const _StatusBadge({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.statusSuccess : Colors.white54,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Protégé' : 'Hors ligne',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String icon;
  final String label;
  const _HeroStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Actions rapides ────────────────────────────────────────────────────────────
class DashQuickActions extends StatelessWidget {
  final dynamic child;
  const DashQuickActions({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {'emoji': '📍', 'label': 'Localiser', 'route': '/map', 'badge': 'PRO'},
      {'emoji': '⏱', 'label': 'Temps écran', 'route': '/child/details'},
      {'emoji': '📱', 'label': 'Applications', 'route': '/child/details'},
      {'emoji': '⚙️', 'label': 'Paramètres', 'route': '/settings/general'},
    ];

    return Row(
      children: actions.map((a) {
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (a['route'] == '/map') {
                final entitlement = context.read<EntitlementService>();
                if (entitlement
                    .isFeatureEnabled(FeatureFlags.realTimeLocation)) {
                  context.push(a['route']!);
                } else {
                  LockedFeatureSheet.show(
                    context,
                    featureName: "Localisation en temps réel",
                    featureDescription:
                        "Suivez vos enfants en direct et recevez des mises à jour régulières sur leur position géographique.",
                    requiredPlan: "Guardian Plus",
                    benefits: const [
                      "Position GPS actualisée en permanence",
                      "Historique complet des trajets sur 30 jours",
                      "Cartographie interactive multi-enfants",
                    ],
                  );
                }
              } else if (a['route'] == '/child/details') {
                context.push(a['route']!, extra: child);
              } else {
                context.push(a['route']!);
              }
            },
            child: _QuickActionButton(
              emoji: a['emoji']!,
              label: a['label']!,
              badgeText: a['badge'],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String emoji;
  final String label;
  final String? badgeText;
  const _QuickActionButton(
      {required this.emoji, required this.label, this.badgeText});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B1329) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFEBEEF8)),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                        color: AppColors.shadowLight,
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (badgeText != null)
          Positioned(
            top: -4,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeText == 'PRO' ? Colors.blue : Colors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Carte alertes ──────────────────────────────────────────────────────────────
class DashAlertsCard extends StatelessWidget {
  final List<dynamic> alerts;
  final dynamic child;
  const DashAlertsCard({super.key, required this.alerts, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unread = alerts.where((a) => a['read'] == false).toList();

    if (unread.isEmpty) {
      return _InfoCard(
        isDark: isDark,
        child: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aucune alerte aujourd\'hui',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                Text('Tout se passe bien 👌',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13)),
              ],
            ),
          ],
        ),
      );
    }

    final latest = unread.first;
    final isSos =
        (latest['type'] ?? '').toString().toUpperCase().contains('SOS');
    final alertColor = isSos ? AppColors.statusDanger : AppColors.statusWarning;

    return GestureDetector(
      onTap: () => context.push('/child/alerts', extra: child),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: alertColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: alertColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Text(isSos ? '🚨' : '⚠️', style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    latest['message'] ??
                        (isSos ? 'Alerte SOS' : 'Nouvelle activité'),
                    style: TextStyle(
                        color: alertColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (unread.length > 1)
                    Text('${unread.length} alertes non lues',
                        style: TextStyle(
                            color: alertColor.withOpacity(0.75), fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: alertColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Voir',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Résumé du jour ─────────────────────────────────────────────────────────────
class DashDailySummary extends StatelessWidget {
  final dynamic child;
  final String screenTime;
  final int newApps;
  final bool bypassAttempted;

  const DashDailySummary({
    super.key,
    required this.child,
    required this.screenTime,
    required this.newApps,
    required this.bypassAttempted,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _InfoCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aujourd\'hui',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 14),
          _SummaryRow(emoji: '✅', text: 'Protection active'),
          const SizedBox(height: 8),
          _SummaryRow(emoji: '✅', text: 'Temps d\'écran : $screenTime'),
          const SizedBox(height: 8),
          _SummaryRow(
              emoji: newApps > 0 ? '⚠️' : '✅',
              text:
                  '$newApps nouvelle${newApps > 1 ? 's' : ''} application${newApps > 1 ? 's' : ''}'),
          const SizedBox(height: 8),
          _SummaryRow(
            emoji: bypassAttempted ? '🚨' : '✅',
            text: bypassAttempted
                ? 'Tentative de contournement détectée'
                : 'Aucune tentative de contournement',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String emoji;
  final String text;
  const _SummaryRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14)),
        ),
      ],
    );
  }
}

// ── Carte enfant ───────────────────────────────────────────────────────────────
class DashChildCard extends StatelessWidget {
  final dynamic child;
  final bool isOnline;
  final String screenTime;
  final VoidCallback onTap;

  const DashChildCard({
    super.key,
    required this.child,
    required this.isOnline,
    required this.screenTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = child['displayName'] ?? 'Enfant';
    final location = child['location'] ?? 'Position inconnue';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B1329) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color:
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFEBEEF8)),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: AppColors.shadowLight,
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('📍 $location',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12)),
                      const SizedBox(width: 12),
                      Text('⏱ $screenTime',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: (isOnline ? AppColors.statusSuccess : Colors.grey)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isOnline ? '🟢 En sécurité' : '⚪ Hors ligne',
                style: TextStyle(
                  color: isOnline ? AppColors.statusSuccess : Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte Guardian IA ──────────────────────────────────────────────────────────
class DashAiInsight extends StatelessWidget {
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  const DashAiInsight({
    super.key,
    required this.message,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(isDark ? 0.2 : 0.07),
            AppColors.accent.withOpacity(isDark ? 0.1 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Text('💡', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Guardian IA',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: onAction,
                    child: Text(actionLabel!,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _InfoCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1329) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEBEEF8)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 10,
                    offset: const Offset(0, 3)),
              ],
      ),
      child: child,
    );
  }
}
